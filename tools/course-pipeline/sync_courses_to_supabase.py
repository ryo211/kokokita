#!/usr/bin/env python3
"""
本番配信中の公式コースJSON（https://kokokita-app.irodoriq.com/course/store/index.json
および個別の courses/{id}.json）から courses / course_spots をSupabaseへ同期するスクリプト。

【注意】通常運用でのcourses/course_spots同期は、tools/course-admin/lambda/handler.py の
publish/delete-course が自動で行うため、このスクリプトを都度実行する必要は無い。
これは course-admin のSupabase連携を導入する前に公開済みだったコースを
一括で取り込むための backfill 専用ツールとして残している。

使い方（tools/course-pipeline/ フォルダで実行）:
    python3 sync_courses_to_supabase.py --dry-run   # 変更内容を確認するだけ（書き込みなし）
    python3 sync_courses_to_supabase.py              # 実際に反映

認証情報（どちらも必須）:
    --url          または環境変数 SUPABASE_URL          例: https://xxxx.supabase.co
    --service-key  または環境変数 SUPABASE_SERVICE_ROLE_KEY

    service_role（secret, "sb_secret_..."）キーが必要。anon/publishableキーでは
    RLSにより書き込みが拒否される。このキーは絶対にアプリやリポジトリに含めないこと。

取得元:
    --base-url（デフォルト: https://kokokita-app.irodoriq.com/course/）配下の
    store/index.json を取得し、各コースの jsonPath から個別JSONを取得する。
    ローカルファイルでのテスト用に --courses-dir を指定した場合のみそちらを使う。

設計方針:
    同じ実在の場所が複数コースに登場しても（例: 姫路城が100名城コースと世界遺産コースの
    両方に登場）、コースごとに到達判定の半径や求める写真の文脈が異なるため、
    場所の正規化（dedup）は行わない。到達者数・「◯人目」はすべて (course_id, spot_id)
    単位で独立に扱う。

依存: requests（fill_course_spot_geocode_google.py と同じ）
"""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys

import requests

DEFAULT_BASE_URL = "https://kokokita-app.irodoriq.com/course/"


def flatten_spots(course: dict) -> list[dict]:
    """sections / spots のどちらの形式でも、順序を保ったスポット一覧を返す"""
    if course.get("sections"):
        spots: list[dict] = []
        for sec in course["sections"]:
            spots.extend(sec.get("spots", []))
        return spots
    return course.get("spots") or []


def load_courses_from_dir(courses_dir: str) -> list[dict]:
    """ローカルのコースJSONフォルダから読み込む（テスト用。本番取得は fetch_courses_from_web を使う）"""
    courses = []
    for filename in sorted(os.listdir(courses_dir)):
        if not filename.endswith(".json"):
            continue
        filepath = os.path.join(courses_dir, filename)
        with open(filepath, encoding="utf-8") as f:
            courses.append(json.load(f))
    return courses


def fetch_courses_from_web(base_url: str) -> list[dict]:
    """本番配信中の store/index.json を取得し、各コースの個別JSONを取得して返す。
    CloudFront配信先はTLS要件の都合でPython(requests/urllib3)から直接繋がらない環境があるため、
    curlコマンドに委譲する（aws CLIに委譲する他のスクリプトと同じ考え方）"""
    base = base_url.rstrip("/")
    index = _fetch_json_via_curl(f"{base}/store/index.json")

    summaries = index.get("courses", [])
    print(f"index.json: {len(summaries)} 件のコースが登録されています")

    courses = []
    for i, summary in enumerate(summaries, start=1):
        json_path = summary["jsonPath"]
        courses.append(_fetch_json_via_curl(f"{base}/{json_path}"))
        print(f"  [{i}/{len(summaries)}] 取得完了: {summary.get('title', summary['id'])}")
    return courses


def _fetch_json_via_curl(url: str) -> dict:
    result = subprocess.run(["curl", "-sS", "-f", url], capture_output=True)
    if result.returncode != 0:
        raise RuntimeError(f"curl失敗 ({result.returncode}): {url}\n{result.stderr.decode('utf-8', errors='replace')}")
    return json.loads(result.stdout)


class SupabaseClient:
    def __init__(self, url: str, service_key: str):
        self.base = url.rstrip("/")
        # service_role（secret）キーは apikey ヘッダのみに乗せる。
        # Authorizationヘッダに入れると不正リクエストとして拒否されるため絶対に入れない
        self.headers = {
            "apikey": service_key,
            "Content-Type": "application/json",
        }

    @staticmethod
    def _raise_with_body(resp: requests.Response) -> None:
        if resp.ok:
            return
        print(f"\n--- HTTPエラー詳細 ({resp.status_code}) ---", file=sys.stderr)
        print(resp.text, file=sys.stderr)
        print("---\n", file=sys.stderr)
        resp.raise_for_status()

    def upsert(self, path: str, rows: list[dict], on_conflict: str) -> None:
        if not rows:
            return
        headers = {**self.headers, "Prefer": "resolution=merge-duplicates,return=minimal"}
        resp = requests.post(
            f"{self.base}/rest/v1/{path}",
            headers=headers,
            params={"on_conflict": on_conflict},
            json=rows,
        )
        self._raise_with_body(resp)


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--base-url", default=DEFAULT_BASE_URL, help="コース配信元のベースURL")
    parser.add_argument("--courses-dir", default=None, help="（テスト用）ローカルのコースJSONフォルダを使う場合に指定")
    parser.add_argument("--url", default=os.environ.get("SUPABASE_URL"))
    parser.add_argument("--service-key", default=os.environ.get("SUPABASE_SERVICE_ROLE_KEY"))
    parser.add_argument("--dry-run", action="store_true", help="実際には書き込まず、集計結果の表示のみ行う")
    args = parser.parse_args()

    if not args.url or not args.service_key:
        print(
            "エラー: --url / --service-key（または環境変数 SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY）が必要です。",
            file=sys.stderr,
        )
        print("service_role（secret）キーが必須です。anon/publishableキーでは書き込めません。", file=sys.stderr)
        sys.exit(1)

    if args.courses_dir:
        if not os.path.isdir(args.courses_dir):
            print(f"エラー: フォルダが見つかりません: {args.courses_dir}", file=sys.stderr)
            sys.exit(1)
        courses = load_courses_from_dir(args.courses_dir)
        print(f"{len(courses)} 件のコースJSONをローカルから読み込みました（テストモード）")
    else:
        courses = fetch_courses_from_web(args.base_url)
        print(f"\n{len(courses)} 件のコースJSONを本番サーバーから取得しました")

    course_rows = []
    spot_rows_by_course: dict[str, list[dict]] = {}
    no_coordinate_count = 0

    for course in courses:
        course_id = course["id"]
        course_rows.append(
            {
                "id": course_id,
                "source": "official",
                "title": course["title"],
                "summary": course.get("summary"),
                "categories": course.get("categories") or [],
                "current_version": course.get("version", 1),
                "status": "published",
            }
        )

        spot_rows = []
        for spot in flatten_spots(course):
            lat = spot.get("latitude")
            lng = spot.get("longitude")
            if lat is None or lng is None:
                no_coordinate_count += 1

            spot_rows.append(
                {
                    "course_id": course_id,
                    "spot_id": spot["spotId"],
                    "name": spot["name"],
                    "lat": lat,
                    "lng": lng,
                    "order_index": spot.get("orderIndex", 0),
                }
            )

        spot_rows_by_course[course_id] = spot_rows

    total_spots = sum(len(v) for v in spot_rows_by_course.values())
    print("\n--- 集計 ---")
    print(f"コース数: {len(course_rows)}")
    print(f"スポット数: {total_spots}")
    print(f"  座標無し: {no_coordinate_count}")

    if args.dry_run:
        print("\n--dry-run のため書き込みは行いません")
        return

    client = SupabaseClient(args.url, args.service_key)

    client.upsert("courses", course_rows, on_conflict="id")
    print(f"\ncourses upsert完了: {len(course_rows)} 件")

    all_spot_rows = [row for rows in spot_rows_by_course.values() for row in rows]
    client.upsert("course_spots", all_spot_rows, on_conflict="course_id,spot_id")
    print(f"course_spots upsert完了: {len(all_spot_rows)} 件")

    print("\n完了しました")


if __name__ == "__main__":
    main()
