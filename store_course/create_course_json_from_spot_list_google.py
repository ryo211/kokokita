#!/usr/bin/env python3
"""
スポット名を1行ずつ並べたテキストファイルから、コース JSON を生成するスクリプト。

主な仕様
- 入力テキストの各行を 1 spot として扱う
- `-- セクション名` 形式の行があれば sections 形式で出力する
- Google Places API / Geocoding API で address / latitude / longitude / spotDescription を補完する
- top-level フィールドは手動補完前提で、文字列系は空文字・任意項目は null / [] を基本値にする
- spotId は指定した接頭辞に 001 からの連番を付与する
- recognitionRadiusMeters は未指定時 null、指定時はその値を top-level に設定する

使い方
- 入力: スポット名を1行ずつ並べた UTF-8 テキストファイル
- 実行: python3 store_course/create_course_json_from_spot_list_google.py <input.txt> --spot-id-prefix <prefix> [-o output.json]
- API key: --api-key または環境変数 GOOGLE_MAPS_API_KEY を使用

入力例
東京国立博物館
東京都美術館
国立新美術館

実行例
python3 store_course/create_course_json_from_spot_list_google.py spots.txt \
  --spot-id-prefix museum-tokyo \
  --recognition-radius 250 \
  -o store_course/courses/tokyo_museums_001.json
"""

from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path
from typing import Any, Dict, List, Optional

from fill_course_spot_geocode_google import (
    DEFAULT_DELAY_SECONDS,
    DEFAULT_LANGUAGE_CODE,
    DEFAULT_REGION_CODE,
    DEFAULT_TIMEOUT_SECONDS,
    GeocodingError,
    GoogleMapsClient,
    JsonCache,
    build_queries,
    choose_best_places_candidate,
    round_coord,
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="スポット名リストから Google API でコース JSON を生成する")
    parser.add_argument("input", help="スポット名を1行ずつ並べた入力テキストファイル")
    parser.add_argument("-o", "--output", help="出力 JSON ファイルパス。省略時は <input>.json")
    parser.add_argument(
        "--spot-id-prefix",
        required=True,
        help="spotId の接頭辞。例: aq-jp -> aq-jp-001",
    )
    parser.add_argument(
        "--recognition-radius",
        type=float,
        default=None,
        help="コース全体の recognitionRadiusMeters。未指定時は null",
    )
    parser.add_argument("--cache", default=".google_geocode_cache.json", help="API レスポンスキャッシュ JSON")
    parser.add_argument(
        "--api-key",
        default=os.environ.get("GOOGLE_MAPS_API_KEY"),
        help="Google Maps API key。未指定時は環境変数 GOOGLE_MAPS_API_KEY",
    )
    parser.add_argument("--delay", type=float, default=DEFAULT_DELAY_SECONDS, help="API 呼び出し間隔（秒）")
    parser.add_argument("--timeout", type=int, default=DEFAULT_TIMEOUT_SECONDS, help="HTTP timeout 秒")
    parser.add_argument("--language", default=DEFAULT_LANGUAGE_CODE, help="languageCode / language")
    parser.add_argument("--region", default=DEFAULT_REGION_CODE, help="regionCode / region。例: JP")
    parser.add_argument(
        "--preferred-keyword",
        default=None,
        help="Places 候補選定の補助キーワード。例: 水族館 / 城 / 神社",
    )
    parser.add_argument("--dry-run", action="store_true", help="ファイル保存しない")
    return parser.parse_args()


def parse_input_lines(path: Path) -> tuple[List[str], Optional[List[Dict[str, Any]]]]:
    flat_spot_names: List[str] = []
    sections: List[Dict[str, Any]] = []
    current_section: Optional[Dict[str, Any]] = None
    has_section_marker = False

    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line:
            continue

        if line.startswith("--"):
            section_name = line[2:].strip()
            if not section_name:
                continue
            has_section_marker = True
            current_section = {
                "sectionId": None,
                "name": section_name,
                "sectionDescription": None,
                "orderIndex": len(sections),
                "coverImageUrl": None,
                "spotNames": [],
            }
            sections.append(current_section)
            continue

        flat_spot_names.append(line)
        if current_section is not None:
            current_section["spotNames"].append(line)

    if has_section_marker:
        sections = [section for section in sections if section["spotNames"]]
        return flat_spot_names, sections

    return flat_spot_names, None


def resolve_spot(
    name: str,
    *,
    client: GoogleMapsClient,
    preferred_keyword: Optional[str],
) -> Dict[str, Any]:
    result = None
    for query in build_queries(name, None):
        candidates = client.places_text_search(query)
        chosen = choose_best_places_candidate(
            candidates,
            name=name,
            preferred_keyword=preferred_keyword,
        )
        if chosen and chosen.latitude is not None and chosen.longitude is not None:
            result = chosen
            break

    if result is None:
        for query in build_queries(name, None):
            candidate = client.geocode_address(query)
            if candidate and candidate.latitude is not None and candidate.longitude is not None:
                result = candidate
                break

    if result is None:
        raise GeocodingError("lookup result not found")

    details = client.place_details(result.place_id) if result.place_id else None
    resolved_name = result.display_name or name
    return {
        "name": resolved_name,
        "address": result.address,
        "latitude": round_coord(result.latitude),
        "longitude": round_coord(result.longitude),
        "spotDescription": details.editorial_summary if details else None,
        "googlePlaceId": result.place_id,
    }


def make_spot(name: str, *, spot_id_prefix: str, order_index: int, sequence_number: int) -> Dict[str, Any]:
    return {
        "spotId": f"{spot_id_prefix}-{sequence_number:03d}",
        "name": name,
        "address": None,
        "latitude": None,
        "longitude": None,
        "spotDescription": None,
        "orderIndex": order_index,
        "recognitionRadiusMeters": None,
    }


def build_course_json(
    spot_names: List[str],
    *,
    spot_id_prefix: str,
    recognition_radius: Optional[float],
    section_inputs: Optional[List[Dict[str, Any]]] = None,
) -> Dict[str, Any]:
    course = {
        "id": "",
        "courseType": "",
        "title": "",
        "summary": "",
        "source": "",
        "isUserCreated": False,
        "version": 1,
        "recognitionRadiusMeters": recognition_radius,
        "detailUrl": None,
        "coverImageUrl": None,
        "categories": [],
    }

    if section_inputs is not None:
        sequence_number = 1
        sections: List[Dict[str, Any]] = []
        for section in section_inputs:
            spots: List[Dict[str, Any]] = []
            for index, name in enumerate(section["spotNames"]):
                spots.append(
                    make_spot(
                        name,
                        spot_id_prefix=spot_id_prefix,
                        order_index=index,
                        sequence_number=sequence_number,
                    )
                )
                sequence_number += 1
            sections.append(
                {
                    "sectionId": section["sectionId"],
                    "name": section["name"],
                    "sectionDescription": section["sectionDescription"],
                    "orderIndex": section["orderIndex"],
                    "coverImageUrl": section["coverImageUrl"],
                    "spots": spots,
                }
            )
        course["sections"] = sections
    else:
        course["spots"] = [
            make_spot(
                name,
                spot_id_prefix=spot_id_prefix,
                order_index=index,
                sequence_number=index + 1,
            )
            for index, name in enumerate(spot_names)
        ]

    return course


def iter_course_spots(course: Dict[str, Any]) -> List[Dict[str, Any]]:
    if "sections" in course and course["sections"]:
        return [spot for section in course["sections"] for spot in section.get("spots", [])]
    return course.get("spots", [])


def main() -> int:
    args = parse_args()

    if not args.api_key:
        print("[ERROR] Google Maps API key が未指定です。--api-key または GOOGLE_MAPS_API_KEY を設定してください。", file=sys.stderr)
        return 1

    input_path = Path(args.input)
    if not input_path.exists():
        print(f"[ERROR] 入力ファイルが存在しません: {input_path}", file=sys.stderr)
        return 1

    output_path = Path(args.output) if args.output else input_path.with_suffix(".json")
    spot_names, section_inputs = parse_input_lines(input_path)
    if not spot_names:
        print("[ERROR] 入力テキストにスポット名がありません。", file=sys.stderr)
        return 1

    client = GoogleMapsClient(
        api_key=args.api_key,
        delay_seconds=args.delay,
        timeout_seconds=args.timeout,
        cache=JsonCache(Path(args.cache)),
        language_code=args.language,
        region_code=args.region,
    )

    course = build_course_json(
        spot_names,
        spot_id_prefix=args.spot_id_prefix,
        recognition_radius=args.recognition_radius,
        section_inputs=section_inputs,
    )

    failed_count = 0
    course_spots = iter_course_spots(course)
    for spot in course_spots:
        try:
            resolved = resolve_spot(
                spot["name"],
                client=client,
                preferred_keyword=args.preferred_keyword,
            )
        except Exception as exc:
            failed_count += 1
            print(f"[FAILED ] {spot['spotId']} {spot['name']} -> {exc}")
            continue

        spot.update(resolved)
        print(
            f"[UPDATED] {spot['spotId']} {spot['name']} -> "
            f"({spot['latitude']}, {spot['longitude']}) {spot['address']}"
        )

    if args.dry_run:
        print("\n[DRY RUN] 保存は行っていません。")
    else:
        output_path.write_text(json.dumps(course, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print(f"\nSaved: {output_path}")

    section_count = len(course.get("sections", [])) if course.get("sections") else 0
    print(
        "Summary: "
        f"spots={len(course_spots)}, "
        f"updated={len(course_spots) - failed_count}, "
        f"failed={failed_count}"
    )
    if section_count:
        print(f"Sections: {section_count}")
    return 0 if failed_count == 0 else 2


if __name__ == "__main__":
    raise SystemExit(main())
