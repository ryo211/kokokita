"""
course JSON 座標補完スクリプト
Google Maps Geocoding API を使って各スポットの緯度経度を上書きする。

使い方:
    python geocode_course.py <course_json_path>

例:
    python geocode_course.py course-jujutsu-kaisen-001.json
"""

import json
import sys
import time
import urllib.request
import urllib.parse
from typing import Optional, Tuple

# =====================
# APIキーをここに設定
# =====================
API_KEY = ""

GEOCODING_URL = "https://maps.googleapis.com/maps/api/geocode/json"


def geocode(query: str) -> Optional[Tuple[float, float]]:
    """クエリ文字列を緯度経度に変換する。失敗時は None を返す。"""
    params = urllib.parse.urlencode({"address": query, "key": API_KEY, "language": "ja"})
    url = f"{GEOCODING_URL}?{params}"
    try:
        with urllib.request.urlopen(url, timeout=10) as res:
            data = json.loads(res.read().decode())
        if data["status"] == "OK":
            loc = data["results"][0]["geometry"]["location"]
            return loc["lat"], loc["lng"]
        else:
            print(f"  [WARN] Geocoding失敗 status={data['status']} query={query!r}")
            return None
    except Exception as e:
        print(f"  [ERROR] リクエスト失敗: {e}")
        return None


def build_query(spot: dict) -> str:
    """スポット名 + 住所からクエリ文字列を組み立てる。"""
    name = spot.get("name", "")
    address = spot.get("address") or ""
    # 住所があれば「名前 住所」、なければ名前だけ
    return f"{name} {address}".strip()


def get_all_spots(course: dict) -> list[dict]:
    """sections形式・spots形式どちらにも対応してスポット一覧を返す。"""
    if "sections" in course:
        spots = []
        for section in course["sections"]:
            spots.extend(section["spots"])
        return spots
    return course.get("spots", [])


def main():
    if len(sys.argv) < 2:
        print("使い方: python geocode_course.py <course_json_path>")
        sys.exit(1)

    path = sys.argv[1]
    with open(path, encoding="utf-8") as f:
        course = json.load(f)

    spots = get_all_spots(course)
    print(f"コース: {course['title']}")
    print(f"スポット数: {len(spots)}\n")

    updated = 0
    skipped = 0

    for spot in spots:
        name = spot.get("name", "")
        old_lat = spot.get("latitude")
        old_lng = spot.get("longitude")

        # latitude/longitude が null のスポットはGPS対象外なのでスキップ
        if old_lat is None and old_lng is None:
            print(f"[SKIP] {name}（座標なし・GPS対象外）")
            skipped += 1
            continue

        query = build_query(spot)
        print(f"[検索] {query}")

        result = geocode(query)
        if result is None:
            print(f"  → 取得失敗。元の座標を維持します。\n")
            skipped += 1
            continue

        new_lat, new_lng = result
        lat_diff = abs(new_lat - (old_lat or 0))
        lng_diff = abs(new_lng - (old_lng or 0))

        print(f"  旧: ({old_lat}, {old_lng})")
        print(f"  新: ({new_lat}, {new_lng})")

        # 差分が大きい場合（0.01度 ≈ 約1km）は警告
        if lat_diff > 0.01 or lng_diff > 0.01:
            print(f"  [!] 座標が大きくズレています（Δlat={lat_diff:.4f}, Δlng={lng_diff:.4f}）要確認")

        spot["latitude"] = new_lat
        spot["longitude"] = new_lng
        updated += 1
        print()

        # API制限対策: 1リクエストあたり0.1秒待機
        time.sleep(0.1)

    # 上書き保存
    out_path = path.replace(".json", "_geocoded.json")
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(course, f, ensure_ascii=False, indent=2)

    print(f"--- 完了 ---")
    print(f"更新: {updated}件 / スキップ: {skipped}件")
    print(f"保存先: {out_path}")


if __name__ == "__main__":
    main()