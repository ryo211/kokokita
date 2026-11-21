#!/usr/bin/env bash
# course-stats-batch をCloudFormationで一括構築・更新するデプロイスクリプト。
# Lambda・IAMロール・EventBridgeスケジュールをすべてこのスクリプト1回の実行で作成する。
#
# 使い方:
#   ./deploy.sh <ArtifactBucket> <SupabaseUrl> <SupabaseAnonKey> <TargetBucket> \
#               [CloudFrontDistributionId] [TargetKey] [MinDisplayCount]
#
# 例:
#   ./deploy.sh kokokita-resources https://xxxx.supabase.co sb_publishable_xxx \
#               kokokita-resources E2SLZOSHR82S8Q
#
# 前提: aws CLIが設定済み（store_course/upload_to_s3.pyと同じ認証情報を使う）
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

ARTIFACT_BUCKET="${1:?ArtifactBucketを指定してください（Lambdaのzipを置くS3バケット。既存のコース配信バケットでよい）}"
SUPABASE_URL="${2:?SupabaseのプロジェクトURLを指定してください}"
SUPABASE_ANON_KEY="${3:?Supabaseのanon/publishableキーを指定してください}"
TARGET_BUCKET="${4:?stats.jsonを書き出す先のS3バケットを指定してください}"
CLOUDFRONT_DISTRIBUTION_ID="${5:-}"
TARGET_KEY="${6:-course/store/stats.json}"
MIN_DISPLAY_COUNT="${7:-10}"

STACK_NAME="kokokita-course-stats-batch"

# コード内容のハッシュをS3キーに含めることで、コードを変更して再実行した際に
# CloudFormationが確実にLambdaのコード更新を検知するようにする
CODE_HASH="$(shasum -a 256 "${SCRIPT_DIR}/handler.py" | cut -c1-12)"
ARTIFACT_KEY="course-stats-batch/handler-${CODE_HASH}.zip"

echo "1/3: Lambdaコードをzip化してS3へアップロード (${ARTIFACT_KEY})"
BUILD_DIR="$(mktemp -d)"
cp "${SCRIPT_DIR}/handler.py" "${BUILD_DIR}/"
(cd "$BUILD_DIR" && zip -q handler.zip handler.py)
aws s3 cp "${BUILD_DIR}/handler.zip" "s3://${ARTIFACT_BUCKET}/${ARTIFACT_KEY}"
rm -rf "$BUILD_DIR"

echo "2/3: CloudFormationテンプレートを検証"
aws cloudformation validate-template --template-body "file://${SCRIPT_DIR}/template.yaml" > /dev/null

echo "3/3: CloudFormationスタックをデプロイ（初回は作成、以降は更新）"
aws cloudformation deploy \
  --stack-name "$STACK_NAME" \
  --template-file "${SCRIPT_DIR}/template.yaml" \
  --capabilities CAPABILITY_NAMED_IAM \
  --parameter-overrides \
    SupabaseUrl="$SUPABASE_URL" \
    SupabaseAnonKey="$SUPABASE_ANON_KEY" \
    TargetBucket="$TARGET_BUCKET" \
    TargetKey="$TARGET_KEY" \
    CloudFrontDistributionId="$CLOUDFRONT_DISTRIBUTION_ID" \
    MinDisplayCount="$MIN_DISPLAY_COUNT" \
    ArtifactBucket="$ARTIFACT_BUCKET" \
    ArtifactKey="$ARTIFACT_KEY"

echo ""
echo "完了しました。スタック名: ${STACK_NAME}"
aws cloudformation describe-stacks --stack-name "$STACK_NAME" --query "Stacks[0].Outputs" --output table
