#!/bin/bash
set -e

S3_PATH="s3://kokokita-resources/course/manage/index.html"
CF_DIST_ID="E2SLZOSHR82S8Q"
CF_PATH="/course/manage/index.html"
LOCAL_FILE="$(dirname "$0")/index.html"

echo "▶ S3 にアップロード中..."
aws s3 cp "$LOCAL_FILE" "$S3_PATH" \
  --content-type "text/html; charset=utf-8" \
  --cache-control "no-cache, no-store, must-revalidate"

echo "▶ CloudFront キャッシュをクリア中..."
INVALIDATION_ID=$(aws cloudfront create-invalidation \
  --distribution-id "$CF_DIST_ID" \
  --paths "$CF_PATH" \
  --query 'Invalidation.Id' \
  --output text)

echo "✓ 完了"
echo "  S3:  $S3_PATH"
echo "  CF invalidation ID: $INVALIDATION_ID"
