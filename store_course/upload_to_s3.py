#!/usr/bin/env python3
"""
S3アップロードスクリプト

使用方法:
  python upload_to_s3.py                    # 全ターゲットをアップロード
  python upload_to_s3.py images             # images のみ
  python upload_to_s3.py courses store      # courses と store を複数指定

ターゲット:
  images    画像ファイル（images/）
  courses   コース JSON（courses/）
  store     ストアインデックス（store/）
"""

import sys
import subprocess
import os

# ============================================================
# 設定（環境に合わせて変更してください）
# ============================================================
S3_BUCKET = "kokokita-resources"              # S3 バケット名
S3_PREFIX = "course"                # S3 上のプレフィックス（末尾スラッシュなし）
CLOUDFRONT_DISTRIBUTION_ID = "E2SLZOSHR82S8Q"    # CloudFront ディストリビューション ID
# ============================================================

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))

TARGETS = {
    "images": {
        "local": os.path.join(SCRIPT_DIR, "images"),
        "s3": f"s3://{S3_BUCKET}/{S3_PREFIX}/images/",
        # 画像は Content-Type を aws に自動判定させる
        "extra_args": ["--cache-control", "public, max-age=86400"],
        "cf_paths": [f"/{S3_PREFIX}/images/*"],
    },
    "courses": {
        "local": os.path.join(SCRIPT_DIR, "courses"),
        "s3": f"s3://{S3_BUCKET}/{S3_PREFIX}/courses/",
        "extra_args": [
            "--content-type", "application/json",
            "--cache-control", "public, max-age=3600",
        ],
        "cf_paths": [f"/{S3_PREFIX}/courses/*"],
    },
    "store": {
        "local": os.path.join(SCRIPT_DIR, "store"),
        "s3": f"s3://{S3_BUCKET}/{S3_PREFIX}/store/",
        "extra_args": [
            "--content-type", "application/json",
            "--cache-control", "public, max-age=300",
        ],
        "cf_paths": [f"/{S3_PREFIX}/store/*"],
    },
}


def upload(target_name: str) -> int:
    target = TARGETS[target_name]
    local = target["local"]
    s3_path = target["s3"]

    print(f"\n{'─' * 50}")
    print(f"[{target_name}] アップロード開始")
    print(f"  ローカル : {local}")
    print(f"  S3       : {s3_path}")
    print(f"{'─' * 50}")

    cmd = ["aws", "s3", "sync", local, s3_path, "--delete"] + target.get("extra_args", [])
    result = subprocess.run(cmd)

    if result.returncode == 0:
        print(f"✅ [{target_name}] S3 アップロード完了")
    else:
        print(f"❌ [{target_name}] S3 アップロード失敗（終了コード: {result.returncode}）")

    return result.returncode


def invalidate_cloudfront(targets: list[str]) -> int:
    if not CLOUDFRONT_DISTRIBUTION_ID:
        print("\n⚠️  CLOUDFRONT_DISTRIBUTION_ID が未設定のためキャッシュ削除をスキップします")
        return 0

    # アップロードしたターゲットのパスをまとめて無効化
    paths = []
    for t in targets:
        paths.extend(TARGETS[t]["cf_paths"])

    print(f"\n{'─' * 50}")
    print(f"[CloudFront] キャッシュ削除")
    print(f"  ディストリビューション : {CLOUDFRONT_DISTRIBUTION_ID}")
    print(f"  パス : {', '.join(paths)}")
    print(f"{'─' * 50}")

    cmd = [
        "aws", "cloudfront", "create-invalidation",
        "--distribution-id", CLOUDFRONT_DISTRIBUTION_ID,
        "--paths", *paths,
    ]
    result = subprocess.run(cmd)

    if result.returncode == 0:
        print("✅ [CloudFront] キャッシュ削除リクエスト送信完了")
    else:
        print(f"❌ [CloudFront] キャッシュ削除失敗（終了コード: {result.returncode}）")

    return result.returncode


def main():
    args = sys.argv[1:]

    # 引数なしは全ターゲット
    if not args:
        targets = list(TARGETS.keys())
    else:
        invalid = [a for a in args if a not in TARGETS]
        if invalid:
            print(f"エラー: 不明なターゲット: {', '.join(invalid)}")
            print(f"有効なターゲット: {', '.join(TARGETS.keys())}")
            sys.exit(1)
        # 重複を除いて順序を保持
        seen = set()
        targets = [a for a in args if not (a in seen or seen.add(a))]

    print(f"アップロードターゲット: {', '.join(targets)}")

    # S3 アップロード
    upload_errors = []
    for target in targets:
        code = upload(target)
        if code != 0:
            upload_errors.append(target)

    # アップロード成功分のみ CloudFront 無効化
    succeeded = [t for t in targets if t not in upload_errors]
    cf_error = 0
    if succeeded:
        cf_error = invalidate_cloudfront(succeeded)

    print(f"\n{'═' * 50}")
    if upload_errors:
        print(f"❌ S3 アップロードに失敗したターゲット: {', '.join(upload_errors)}")
    if cf_error != 0:
        print("❌ CloudFront キャッシュ削除に失敗しました")
    if not upload_errors and cf_error == 0:
        print("✅ すべての処理が完了しました")

    if upload_errors or cf_error != 0:
        sys.exit(1)


if __name__ == "__main__":
    main()
