#!/usr/bin/env python3
"""
courses/*.json を読み取って store/index.json を生成するスクリプト。

使い方（store_course/ フォルダで実行）:
    python3 generate_store_index.py

オプション:
    --courses-dir   コース JSON フォルダのパス（デフォルト: courses）
    --output        出力先 index.json のパス（デフォルト: store/index.json）
    --order         表示順を制御するファイル名リスト（カンマ区切り、省略時は既存順 → アルファベット順）

例（表示順を指定する場合）:
    python3 generate_store_index.py \
        --order tokyo_shitamachi_walk_001,continued_100_castles_course
"""

import argparse
import json
import os
from datetime import datetime, timezone


def count_spots(course: dict) -> int:
    """spots または sections.spots の総数を数える"""
    if "spots" in course and course["spots"]:
        return len(course["spots"])
    if "sections" in course and course["sections"]:
        return sum(len(sec.get("spots", [])) for sec in course["sections"])
    return 0


def build_summary(course: dict, json_filename: str) -> dict:
    """コース JSON から updatedAt を除いた StoreCourseSummary を構築する"""
    return {
        "id": course["id"],
        "title": course["title"],
        "summary": course.get("summary"),
        "categories": course.get("categories") or [],
        "version": course.get("version", 1),
        "coverImageUrl": course.get("coverImageUrl"),
        "spotCount": count_spots(course),
        "jsonPath": f"courses/{json_filename}",
    }


def load_existing_index(output_path: str) -> dict:
    """既存の index.json を取得する"""
    if not os.path.exists(output_path):
        return {}
    with open(output_path, encoding="utf-8") as f:
        return json.load(f)


def load_existing_order(output_path: str) -> list[str]:
    """既存の index.json からコース ID の順序を取得する"""
    data = load_existing_index(output_path)
    return [c["id"] for c in data.get("courses", [])]


def course_has_changed(new_summary: dict, existing_summary: dict) -> bool:
    """updatedAt を除くコース概要に差分があるか判定する"""
    comparable_existing = {
        key: value for key, value in existing_summary.items() if key != "updatedAt"
    }
    return new_summary != comparable_existing


def main():
    parser = argparse.ArgumentParser(description="store/index.json を生成する")
    parser.add_argument(
        "--courses-dir",
        default="courses",
        help="コース JSON フォルダのパス（デフォルト: courses）",
    )
    parser.add_argument(
        "--output",
        default="store/index.json",
        help="出力先 index.json のパス（デフォルト: store/index.json）",
    )
    parser.add_argument(
        "--order",
        default="",
        help="表示順（ファイル名をカンマ区切りで指定、拡張子なし）",
    )
    args = parser.parse_args()

    courses_dir = args.courses_dir
    output_path = args.output

    if not os.path.isdir(courses_dir):
        print(f"エラー: フォルダが見つかりません: {courses_dir}")
        exit(1)

    # courses/ 配下の JSON を全て読み込む
    summaries_by_id: dict[str, dict] = {}
    filename_by_id: dict[str, str] = {}

    for filename in os.listdir(courses_dir):
        if not filename.endswith(".json"):
            continue
        filepath = os.path.join(courses_dir, filename)
        with open(filepath, encoding="utf-8") as f:
            course = json.load(f)
        summary = build_summary(course, filename)
        summaries_by_id[course["id"]] = summary
        filename_by_id[course["id"]] = filename

    if not summaries_by_id:
        print("コース JSON が見つかりませんでした。")
        exit(0)

    existing_index = load_existing_index(output_path)
    existing_courses_by_id = {
        course["id"]: course for course in existing_index.get("courses", [])
    }
    now = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

    # 表示順の決定
    if args.order:
        # --order で明示指定された場合
        order_names = [n.strip() for n in args.order.split(",")]
        ordered_ids = []
        for name in order_names:
            fname = name if name.endswith(".json") else name + ".json"
            matched = [cid for cid, fn in filename_by_id.items() if fn == fname]
            if matched:
                ordered_ids.append(matched[0])
        # 指定されなかったコースは末尾に追加
        for cid in sorted(summaries_by_id.keys()):
            if cid not in ordered_ids:
                ordered_ids.append(cid)
    else:
        # 既存 index.json の順序を引き継ぎ、新規コースは末尾に追加
        existing_order = load_existing_order(output_path)
        ordered_ids = [cid for cid in existing_order if cid in summaries_by_id]
        for cid in sorted(summaries_by_id.keys()):
            if cid not in ordered_ids:
                ordered_ids.append(cid)

    ordered_courses = []
    changed_course_ids: list[str] = []
    new_course_ids: list[str] = []

    for cid in ordered_ids:
        summary = summaries_by_id[cid]
        existing_summary = existing_courses_by_id.get(cid)

        if existing_summary is None:
            summary["updatedAt"] = now
            new_course_ids.append(cid)
        elif course_has_changed(summary, existing_summary):
            summary["updatedAt"] = now
            changed_course_ids.append(cid)
        else:
            summary["updatedAt"] = existing_summary.get("updatedAt", now)

        ordered_courses.append(summary)

    # index.json を生成
    index = {
        "schemaVersion": 1,
        "generatedAt": now,
        "courses": ordered_courses,
    }

    if (
        existing_index
        and existing_index.get("schemaVersion") == index["schemaVersion"]
        and existing_index.get("courses") == index["courses"]
    ):
        index["generatedAt"] = existing_index.get("generatedAt", now)
        if existing_index == index:
            print(f"変更なし: {output_path}")
            return

    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(index, f, ensure_ascii=False, indent=2)
        f.write("\n")

    print(f"生成完了: {output_path}")
    if new_course_ids:
        print(f"  新規追加: {len(new_course_ids)} 件")
    if changed_course_ids:
        print(f"  差分更新: {len(changed_course_ids)} 件")
    for c in ordered_courses:
        print(f"  - {c['title']} ({c['spotCount']} スポット, v{c['version']})")


if __name__ == "__main__":
    main()
