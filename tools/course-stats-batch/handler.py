"""
AWS Lambda: Supabaseの集計RPC（compute_course_stats）を呼び、stats.jsonをS3へ書き出し、
CloudFrontのキャッシュを無効化する。

EventBridge Schedulerから1日1回起動される想定（doc/features/server/server-feature-design.md フェーズ1「表示」参照）。

標準ライブラリ＋boto3のみで動くため、追加の依存パッケージ・Lambda Layerは不要。
（urllib.requestのみでSupabaseへのHTTP呼び出しを行い、requestsは使わない）

環境変数:
    SUPABASE_URL                 例: https://xxxx.supabase.co
    SUPABASE_ANON_KEY             公開可能なanon/publishableキー（service_roleキーは不要・持たせない）
    S3_BUCKET                     例: kokokita-resources
    S3_KEY                        例: course/store/stats.json
    CLOUDFRONT_DISTRIBUTION_ID    任意。指定時のみキャッシュ無効化を行う
    MIN_DISPLAY_COUNT             任意。デフォルト10（doc/features/server/phase1_schema.sql と揃えること）

必要なIAM権限（Lambda実行ロール）:
    s3:PutObject                 対象バケット・キーに対して
    cloudfront:CreateInvalidation 対象ディストリビューションに対して（CLOUDFRONT_DISTRIBUTION_ID使用時のみ）
"""

import json
import os
import time
import urllib.error
import urllib.request

import boto3


def handler(event, context):
    supabase_url = _require_env("SUPABASE_URL").rstrip("/")
    anon_key = _require_env("SUPABASE_ANON_KEY")
    bucket = _require_env("S3_BUCKET")
    key = _require_env("S3_KEY")
    min_display_count = int(os.environ.get("MIN_DISPLAY_COUNT", "10"))
    distribution_id = os.environ.get("CLOUDFRONT_DISTRIBUTION_ID")

    stats_json = fetch_stats(supabase_url, anon_key, min_display_count)
    upload_to_s3(bucket, key, stats_json)

    if distribution_id:
        invalidate_cloudfront(distribution_id, key)

    return {"statusCode": 200, "body": "stats.json updated"}


def fetch_stats(supabase_url: str, anon_key: str, min_display_count: int) -> bytes:
    """compute_course_stats RPCを呼び、レスポンス本文（stats.jsonそのもの）を返す。
    PostgRESTはjsonbを返すスカラー関数の結果をラップせずそのまま返すため、
    レスポンス本文がそのままstats.jsonの内容になる"""
    url = f"{supabase_url}/rest/v1/rpc/compute_course_stats"
    payload = json.dumps({"p_min_display_count": min_display_count}).encode("utf-8")
    req = urllib.request.Request(
        url,
        data=payload,
        method="POST",
        headers={
            "apikey": anon_key,
            "Content-Type": "application/json",
        },
    )
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            return resp.read()
    except urllib.error.HTTPError as e:
        detail = e.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"Supabase RPC失敗 (HTTP {e.code}): {detail}") from e


def upload_to_s3(bucket: str, key: str, body: bytes) -> None:
    s3 = boto3.client("s3")
    s3.put_object(
        Bucket=bucket,
        Key=key,
        Body=body,
        ContentType="application/json",
        CacheControl="public, max-age=300",
    )


def invalidate_cloudfront(distribution_id: str, key: str) -> None:
    cf = boto3.client("cloudfront")
    cf.create_invalidation(
        DistributionId=distribution_id,
        InvalidationBatch={
            "Paths": {"Quantity": 1, "Items": [f"/{key}"]},
            "CallerReference": str(time.time()),
        },
    )


def _require_env(name: str) -> str:
    value = os.environ.get(name)
    if not value:
        raise RuntimeError(f"環境変数 {name} が未設定です")
    return value
