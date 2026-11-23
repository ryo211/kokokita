#!/usr/bin/env python3
"""
Google Maps Platform を使って、コース JSON の spot.name / address / latitude / longitude を補完するスクリプト。

主な仕様
- top-level spots 形式 / sections[].spots 形式の両方に対応
- spot.name で Places API (New) Text Search を実行し、最適候補を選定
- レスポンスの displayName を正として spot.name を更新（古い名前を修正）
- レスポンスの formattedAddress / location で address / 緯度経度を補完
- 元の address は検索クエリ・補完のいずれにも使用しない
- API レスポンスはローカル JSON キャッシュに保存
- --overwrite で既存の address / lat / lon も上書き可能
- name は Places API で候補が見つかった場合は常に更新

前提
- Google Cloud で billing を有効化
- Geocoding API と Places API を有効化
- API key を用意

参考
- Places API (New) Text Search は POST /v1/places:searchText を使い、FieldMask が必須
- Geocoding API は key と address / latlng を指定して利用
"""

from __future__ import annotations

import argparse
import copy
import json
import os
import re
import sys
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Dict, Iterable, List, Optional, Tuple
from urllib.parse import urlencode

import requests


PLACES_TEXT_SEARCH_URL = "https://places.googleapis.com/v1/places:searchText"
PLACE_DETAILS_URL_TEMPLATE = "https://places.googleapis.com/v1/{place_name}"
GEOCODE_URL = "https://maps.googleapis.com/maps/api/geocode/json"
DEFAULT_DELAY_SECONDS = 0.05
DEFAULT_TIMEOUT_SECONDS = 20
DEFAULT_LANGUAGE_CODE = "ja"
DEFAULT_REGION_CODE = "JP"
DEFAULT_PLACES_FIELD_MASK = ",".join(
    [
        "places.id",
        "places.name",
        "places.types",
        "places.formattedAddress",
        "places.location",
        "places.displayName",
    ]
)


class GeocodingError(RuntimeError):
    pass


@dataclass
class LookupResult:
    latitude: Optional[float]
    longitude: Optional[float]
    address: Optional[str]
    raw: Dict[str, Any]
    query: str
    source: str  # places_text / geocode / reverse_geocode / place_details
    place_id: Optional[str] = None
    display_name: Optional[str] = None
    editorial_summary: Optional[str] = None


@dataclass
class SpotRef:
    spot: Dict[str, Any]
    path: str


@dataclass
class SpotProcessResult:
    path: str
    name: str
    status: str
    query_used: Optional[str]
    latitude: Optional[float]
    longitude: Optional[float]
    address: Optional[str]
    note: Optional[str]


class JsonCache:
    def __init__(self, path: Path):
        self.path = path
        if path.exists():
            try:
                self.data: Dict[str, Any] = json.loads(path.read_text(encoding="utf-8"))
            except Exception:
                self.data = {}
        else:
            self.data = {}

    def get(self, key: str) -> Optional[Any]:
        return self.data.get(key)

    def set(self, key: str, value: Any) -> None:
        self.data[key] = value

    def save(self) -> None:
        self.path.parent.mkdir(parents=True, exist_ok=True)
        self.path.write_text(json.dumps(self.data, ensure_ascii=False, indent=2), encoding="utf-8")


class GoogleMapsClient:
    def __init__(
        self,
        *,
        api_key: str,
        delay_seconds: float,
        timeout_seconds: int,
        cache: JsonCache,
        language_code: str,
        region_code: str,
    ):
        self.api_key = api_key
        self.delay_seconds = delay_seconds
        self.timeout_seconds = timeout_seconds
        self.cache = cache
        self.language_code = language_code
        self.region_code = region_code
        self._last_request_ts = 0.0
        self.session = requests.Session()
        self.session.headers.update({"User-Agent": "kokokita-course-geocoder/1.0"})

    def _throttle(self) -> None:
        elapsed = time.monotonic() - self._last_request_ts
        wait = self.delay_seconds - elapsed
        if wait > 0:
            time.sleep(wait)

    def _request_json(
        self,
        *,
        method: str,
        url: str,
        cache_key: str,
        params: Optional[Dict[str, Any]] = None,
        headers: Optional[Dict[str, str]] = None,
        json_body: Optional[Dict[str, Any]] = None,
    ) -> Any:
        cached = self.cache.get(cache_key)
        if cached is not None:
            return cached

        self._throttle()
        response = self.session.request(
            method=method,
            url=url,
            params=params,
            headers=headers,
            json=json_body,
            timeout=self.timeout_seconds,
        )
        self._last_request_ts = time.monotonic()

        if not response.ok:
            raise GeocodingError(f"Google API error: {response.status_code} {response.text[:500]}")

        data = response.json()
        self.cache.set(cache_key, data)
        self.cache.save()
        return data

    def places_text_search(self, query: str, *, page_size: int = 5) -> List[LookupResult]:
        body = {
            "textQuery": query,
            "languageCode": self.language_code,
            "regionCode": self.region_code,
            "pageSize": page_size,
        }
        headers = {
            "Content-Type": "application/json",
            "X-Goog-Api-Key": self.api_key,
            "X-Goog-FieldMask": DEFAULT_PLACES_FIELD_MASK,
        }
        cache_key = f"places_text::{json.dumps(body, ensure_ascii=False, sort_keys=True)}"
        data = self._request_json(
            method="POST",
            url=PLACES_TEXT_SEARCH_URL,
            cache_key=cache_key,
            headers=headers,
            json_body=body,
        )
        places = data.get("places", [])
        results: List[LookupResult] = []
        for place in places:
            location = place.get("location") or {}
            display_name = ((place.get("displayName") or {}).get("text") if isinstance(place.get("displayName"), dict) else None)
            place_name = place.get("name") or ""
            place_id = place_name.split("/")[-1] if "/" in place_name else place.get("id")
            results.append(
                LookupResult(
                    latitude=location.get("latitude"),
                    longitude=location.get("longitude"),
                    address=place.get("formattedAddress"),
                    raw=place,
                    query=query,
                    source="places_text",
                    place_id=place_id,
                    display_name=display_name,
                    editorial_summary=None,
                )
            )
        return results

    def place_details(self, place_name_or_id: str) -> Optional[LookupResult]:
        if place_name_or_id.startswith("places/"):
            place_name = place_name_or_id
        else:
            place_name = f"places/{place_name_or_id}"
        url = PLACE_DETAILS_URL_TEMPLATE.format(place_name=place_name)
        params = {
            "fields": "id,name,displayName,formattedAddress,location,types,editorialSummary",
            "key": self.api_key,
            "languageCode": self.language_code,
            "regionCode": self.region_code,
        }
        cache_key = f"place_details::{place_name}::{urlencode(sorted(params.items()))}"
        data = self._request_json(method="GET", url=url, cache_key=cache_key, params=params)
        if not data:
            return None
        location = data.get("location") or {}
        display_name = ((data.get("displayName") or {}).get("text") if isinstance(data.get("displayName"), dict) else None)
        editorial_summary = (
            (data.get("editorialSummary") or {}).get("text")
            if isinstance(data.get("editorialSummary"), dict)
            else None
        )
        place_id = data.get("id") or place_name.split("/")[-1]
        return LookupResult(
            latitude=location.get("latitude"),
            longitude=location.get("longitude"),
            address=data.get("formattedAddress"),
            raw=data,
            query=place_name_or_id,
            source="place_details",
            place_id=place_id,
            display_name=display_name,
            editorial_summary=editorial_summary,
        )

    def geocode_address(self, address: str) -> Optional[LookupResult]:
        params = {
            "address": address,
            "key": self.api_key,
            "language": self.language_code,
            "region": self.region_code.lower(),
        }
        cache_key = f"geocode::{urlencode(sorted(params.items()))}"
        data = self._request_json(method="GET", url=GEOCODE_URL, cache_key=cache_key, params=params)
        status = data.get("status")
        if status != "OK":
            if status == "ZERO_RESULTS":
                return None
            raise GeocodingError(f"Geocoding API status={status}")
        item = data["results"][0]
        location = item.get("geometry", {}).get("location", {})
        place_id = item.get("place_id")
        return LookupResult(
            latitude=location.get("lat"),
            longitude=location.get("lng"),
            address=item.get("formatted_address"),
            raw=item,
            query=address,
            source="geocode",
            place_id=place_id,
            display_name=None,
            editorial_summary=None,
        )

    def reverse_geocode(self, latitude: float, longitude: float) -> Optional[LookupResult]:
        params = {
            "latlng": f"{latitude},{longitude}",
            "key": self.api_key,
            "language": self.language_code,
            "region": self.region_code.lower(),
        }
        cache_key = f"reverse_geocode::{urlencode(sorted(params.items()))}"
        data = self._request_json(method="GET", url=GEOCODE_URL, cache_key=cache_key, params=params)
        status = data.get("status")
        if status != "OK":
            if status == "ZERO_RESULTS":
                return None
            raise GeocodingError(f"Reverse Geocoding status={status}")
        item = data["results"][0]
        location = item.get("geometry", {}).get("location", {})
        place_id = item.get("place_id")
        return LookupResult(
            latitude=location.get("lat", latitude),
            longitude=location.get("lng", longitude),
            address=item.get("formatted_address"),
            raw=item,
            query=f"{latitude},{longitude}",
            source="reverse_geocode",
            place_id=place_id,
            display_name=None,
            editorial_summary=None,
        )


def iter_spots(course: Dict[str, Any]) -> Iterable[SpotRef]:
    sections = course.get("sections")
    if isinstance(sections, list):
        for i, section in enumerate(sections):
            for j, spot in enumerate(section.get("spots", [])):
                yield SpotRef(spot=spot, path=f"sections[{i}].spots[{j}]")
        return

    spots = course.get("spots")
    if isinstance(spots, list):
        for i, spot in enumerate(spots):
            yield SpotRef(spot=spot, path=f"spots[{i}]")
        return

    raise ValueError("JSON に spots も sections もありません。")


def is_missing(value: Any) -> bool:
    return value is None or (isinstance(value, str) and value.strip() == "")


def normalize_text(value: Optional[str]) -> str:
    if not value:
        return ""
    value = value.strip().lower()
    value = re.sub(r"\s+", "", value)
    value = value.replace("（", "(").replace("）", ")")
    value = value.replace("・", "")
    return value


def round_coord(value: Optional[float]) -> Optional[float]:
    return None if value is None else round(float(value), 7)


def build_queries(name: Optional[str], course_title: Optional[str]) -> List[str]:
    """name と course_title のみでクエリを構築する。address は使用しない。"""
    queries: List[str] = []
    name = (name or "").strip()
    course_title = (course_title or "").strip()

    def add(q: str) -> None:
        q = q.strip()
        if q and q not in queries:
            queries.append(q)

    if name:
        add(name)
    if name and course_title:
        add(f"{name} {course_title}")
    return queries


def score_place_candidate(
    candidate: LookupResult,
    *,
    name: str,
    preferred_keyword: Optional[str],
) -> Tuple[int, str]:
    """name との一致度でスコアリングする。address は評価しない。"""
    score = 0
    reasons: List[str] = []
    n_name = normalize_text(name)
    n_display = normalize_text(candidate.display_name)
    n_candidate_addr = normalize_text(candidate.address)

    if n_name and n_display == n_name:
        score += 120
        reasons.append("exact_name")
    elif n_name and n_name in n_display:
        score += 80
        reasons.append("name_contains")
    elif n_name and n_display and (n_display in n_name or n_name[:4] in n_display):
        score += 40
        reasons.append("partial_name")

    if preferred_keyword:
        n_keyword = normalize_text(preferred_keyword)
        raw_types = candidate.raw.get("types") or []
        type_text = normalize_text(" ".join(str(x) for x in raw_types))
        if n_keyword in n_display or n_keyword in n_candidate_addr or n_keyword in type_text:
            score += 15
            reasons.append("preferred_keyword")

    return score, ",".join(reasons)


def choose_best_places_candidate(
    candidates: List[LookupResult],
    *,
    name: str,
    preferred_keyword: Optional[str],
) -> Optional[LookupResult]:
    if not candidates:
        return None

    scored: List[Tuple[int, int, LookupResult]] = []
    for idx, candidate in enumerate(candidates):
        score, _ = score_place_candidate(
            candidate,
            name=name,
            preferred_keyword=preferred_keyword,
        )
        scored.append((score, -idx, candidate))

    scored.sort(reverse=True, key=lambda x: (x[0], x[1]))
    return scored[0][2]



def should_process_spot(spot: Dict[str, Any], *, overwrite: bool) -> bool:
    lat_missing = is_missing(spot.get("latitude"))
    lon_missing = is_missing(spot.get("longitude"))
    addr_missing = is_missing(spot.get("address"))
    description_missing = is_missing(spot.get("spotDescription"))
    if overwrite:
        return True
    return lat_missing or lon_missing or addr_missing or description_missing


def process_spot(
    spot: Dict[str, Any],
    *,
    path: str,
    course_title: Optional[str],
    client: GoogleMapsClient,
    overwrite: bool,
    preferred_keyword: Optional[str],
) -> SpotProcessResult:
    """
    spot.name で Places API を検索し、以下を更新する。
    - spot["name"]    : レスポンスの displayName で常に上書き（古い名前を修正）
    - spot["address"] : レスポンスの formattedAddress で補完（overwrite 時は上書き）
    - spot["latitude"] / ["longitude"] : レスポンスの location で補完（overwrite 時は上書き）
    元の address は検索クエリ・補完のいずれにも使用しない。
    """
    name = (spot.get("name") or "").strip()
    if not name:
        return SpotProcessResult(path, "", "skipped", None, None, None, None, "name が空")

    current_lat = None if is_missing(spot.get("latitude")) else float(spot["latitude"])
    current_lon = None if is_missing(spot.get("longitude")) else float(spot["longitude"])
    current_address = (spot.get("address") or "").strip() or None
    current_description = (spot.get("spotDescription") or "").strip() or None

    lat_missing = current_lat is None
    lon_missing = current_lon is None
    addr_missing = current_address is None
    description_missing = current_description is None

    result: Optional[LookupResult] = None
    note_parts: List[str] = []

    # 1) Places Text Search（name のみでクエリ。address は使用しない）
    for query in build_queries(name, course_title):
        candidates = client.places_text_search(query)
        chosen = choose_best_places_candidate(
            candidates,
            name=name,
            preferred_keyword=preferred_keyword,
        )
        if chosen and chosen.latitude is not None and chosen.longitude is not None:
            result = chosen
            note_parts.append("resolved_by=places_text")
            break

    # 2) Places で見つからなければ Geocoding API で name を検索（fallback）
    if result is None:
        for query in build_queries(name, course_title):
            candidate = client.geocode_address(query)
            if candidate and candidate.latitude is not None and candidate.longitude is not None:
                result = candidate
                note_parts.append("resolved_by=geocode_name")
                break

    if result is None or result.latitude is None or result.longitude is None:
        return SpotProcessResult(
            path=path,
            name=name,
            status="failed",
            query_used=None,
            latitude=current_lat,
            longitude=current_lon,
            address=current_address,
            note="lookup result not found",
        )

    details_result: Optional[LookupResult] = None
    if result.place_id and (overwrite or description_missing):
        details_result = client.place_details(result.place_id)
        if details_result and details_result.editorial_summary:
            note_parts.append("description_resolved_by=place_details")

    # name をレスポンスの displayName で更新（常に上書き）
    if result.display_name:
        spot["name"] = result.display_name
        if result.display_name != name:
            note_parts.append(f"name_updated: {name!r} -> {result.display_name!r}")

    # lat / lon を更新
    if overwrite or lat_missing:
        spot["latitude"] = round_coord(result.latitude)
    if overwrite or lon_missing:
        spot["longitude"] = round_coord(result.longitude)

    # address を更新（formattedAddress を優先。元の address は無視）
    if overwrite or addr_missing:
        if result.address:
            spot["address"] = result.address

    if overwrite or description_missing:
        if details_result and details_result.editorial_summary:
            spot["spotDescription"] = details_result.editorial_summary

    # place_id を保存
    if result.place_id and (overwrite or is_missing(spot.get("googlePlaceId"))):
        spot["googlePlaceId"] = result.place_id

    return SpotProcessResult(
        path=path,
        name=spot.get("name", name),
        status="updated",
        query_used=result.query,
        latitude=spot.get("latitude"),
        longitude=spot.get("longitude"),
        address=spot.get("address"),
        note=", ".join(note_parts) if note_parts else None,
    )


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Google Maps Platform でコース JSON の住所・緯度経度を補完する")
    parser.add_argument("input", help="入力 JSON ファイルパス")
    parser.add_argument("-o", "--output", help="出力 JSON ファイルパス。省略時は <input>.filled.json")
    parser.add_argument("--cache", default=".google_geocode_cache.json", help="API レスポンスキャッシュ JSON")
    parser.add_argument("--api-key", default=os.environ.get("GOOGLE_MAPS_API_KEY"), help="Google Maps API key。未指定時は環境変数 GOOGLE_MAPS_API_KEY")
    parser.add_argument("--delay", type=float, default=DEFAULT_DELAY_SECONDS, help="API 呼び出し間隔（秒）")
    parser.add_argument("--timeout", type=int, default=DEFAULT_TIMEOUT_SECONDS, help="HTTP timeout 秒")
    parser.add_argument("--language", default=DEFAULT_LANGUAGE_CODE, help="languageCode / language")
    parser.add_argument("--region", default=DEFAULT_REGION_CODE, help="regionCode / region。例: JP")
    parser.add_argument("--overwrite", action="store_true", help="既存の address / lat / lon も上書きする")
    parser.add_argument(
        "--preferred-keyword",
        default=None,
        help="Places 候補選定の補助キーワード。例: 水族館 / 城 / 神社",
    )
    parser.add_argument("--dry-run", action="store_true", help="ファイル保存しない")
    return parser.parse_args()


def main() -> int:
    args = parse_args()

    if not args.api_key:
        print("[ERROR] Google Maps API key が未指定です。--api-key または GOOGLE_MAPS_API_KEY を設定してください。", file=sys.stderr)
        return 1

    input_path = Path(args.input)
    if not input_path.exists():
        print(f"[ERROR] 入力ファイルが存在しません: {input_path}", file=sys.stderr)
        return 1

    output_path = Path(args.output) if args.output else input_path.with_name(f"{input_path.stem}.filled{input_path.suffix}")
    cache_path = Path(args.cache)

    course = json.loads(input_path.read_text(encoding="utf-8"))
    original = copy.deepcopy(course)

    client = GoogleMapsClient(
        api_key=args.api_key,
        delay_seconds=args.delay,
        timeout_seconds=args.timeout,
        cache=JsonCache(cache_path),
        language_code=args.language,
        region_code=args.region,
    )

    processed_count = 0
    updated_count = 0
    failed_count = 0
    skipped_count = 0

    for ref in iter_spots(course):
        spot = ref.spot
        if not should_process_spot(spot, overwrite=args.overwrite):
            skipped_count += 1
            print(f"[SKIPPED] {ref.path} {spot.get('name') or ''} -> already complete")
            continue

        processed_count += 1
        try:
            result = process_spot(
                spot,
                path=ref.path,
                course_title=course.get("title"),
                client=client,
                overwrite=args.overwrite,
                preferred_keyword=args.preferred_keyword,
            )
        except Exception as exc:
            result = SpotProcessResult(
                path=ref.path,
                name=spot.get("name") or "",
                status="failed",
                query_used=None,
                latitude=spot.get("latitude"),
                longitude=spot.get("longitude"),
                address=spot.get("address"),
                note=str(exc),
            )

        if result.status == "updated":
            updated_count += 1
            print(f"[UPDATED] {result.path} {result.name} -> ({result.latitude}, {result.longitude}) {result.address} [{result.note or ''}]")
        elif result.status == "failed":
            failed_count += 1
            print(f"[FAILED ] {result.path} {result.name} -> {result.note}")
        else:
            skipped_count += 1
            print(f"[SKIPPED] {result.path} {result.name} -> {result.note}")

    if args.dry_run:
        print("\n[DRY RUN] 保存は行っていません。")
    else:
        if course != original:
            output_path.write_text(json.dumps(course, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
            print(f"\nSaved: {output_path}")
        else:
            print("\n変更はありませんでした。")

    print(f"Summary: processed={processed_count}, updated={updated_count}, failed={failed_count}, skipped={skipped_count}")
    return 0 if failed_count == 0 else 2


if __name__ == "__main__":
    raise SystemExit(main())
