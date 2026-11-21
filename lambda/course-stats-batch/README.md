# course-stats-batch

Supabaseの集計RPC（`compute_course_stats`、`doc/sql/phase1_schema.sql`参照）を呼び、
`stats.json`をS3へ書き出してCloudFrontのキャッシュを無効化するLambda。
EventBridgeで1日1回起動する想定（`doc/server-feature-design.md` フェーズ1「表示」参照）。

標準ライブラリ（`urllib.request`）とboto3のみで動作する。boto3はLambdaのPython実行環境に
標準で含まれているため、追加の依存パッケージ・Lambda Layerは不要。

## 構成

| ファイル | 役割 |
|---|---|
| `handler.py` | Lambda本体 |
| `template.yaml` | CloudFormationテンプレート（IAMロール・Lambda・EventBridgeルールを定義） |
| `deploy.sh` | ビルド（zip化）→S3アップロード→CloudFormationデプロイを1コマンドで行うスクリプト |

## 前提

- `doc/sql/phase1_schema.sql`の`compute_course_stats`RPCがSupabase側に作成済みであること
- 本番のコース配信（S3 + CloudFront、`store_course/upload_to_s3.py`が使っているものと同じバケット）
- `aws` CLIが設定済み（`store_course/upload_to_s3.py`と同じ認証情報を使う。SAM/CDK/Terraform等の
  追加ツールは不要）

## デプロイ（1コマンド）

```bash
cd lambda/course-stats-batch
./deploy.sh <ArtifactBucket> <SupabaseUrl> <SupabaseAnonKey> <TargetBucket> \
            [CloudFrontDistributionId] [TargetKey] [MinDisplayCount]
```

例:

```bash
./deploy.sh kokokita-resources https://xxxx.supabase.co sb_publishable_xxx \
            kokokita-resources E2SLZOSHR82S8Q
```

| 引数 | 必須 | 説明 |
|---|:---:|---|
| `ArtifactBucket` | ✅ | Lambdaのコードzipを置くS3バケット（既存のコース配信バケットでよい） |
| `SupabaseUrl` | ✅ | 例: `https://xxxx.supabase.co`（アプリの`Info.plist`と同じ値） |
| `SupabaseAnonKey` | ✅ | `sb_publishable_...`。**anon/publishableキーのみ。service_roleキーは絶対に渡さない** |
| `TargetBucket` | ✅ | `stats.json`を書き出す先。`store_course/upload_to_s3.py`の`S3_BUCKET`と同じ |
| `CloudFrontDistributionId` | - | `store_course/upload_to_s3.py`の`CLOUDFRONT_DISTRIBUTION_ID`と同じ。省略時はキャッシュ無効化を行わない |
| `TargetKey` | - | デフォルト`course/store/stats.json` |
| `MinDisplayCount` | - | デフォルト`10`。`doc/sql/phase1_schema.sql`の既定値と揃える |

スクリプトの内容:

1. `handler.py`をzip化し、コード内容のハッシュを含むキー名でS3へアップロード（再デプロイ時に
   CloudFormationが確実にコード更新を検知するための工夫）
2. `aws cloudformation validate-template`でテンプレートを検証
3. `aws cloudformation deploy`でスタックを作成・更新。以下が一括で構築される
   - Lambda実行用のIAMロール（S3書き込み・CloudFrontキャッシュ無効化の権限のみを付与）
   - Lambda関数本体（Python 3.12、`handler.handler`）
   - EventBridgeルール（`cron(0 3 * * ? *)` = 毎日03:00 UTC = 日本時間12:00）とLambda起動権限

コードを変更したときは、同じコマンドを再実行すれば差分だけ更新される（スタックは
`kokokita-course-stats-batch`という名前で作成される）。

## 動作確認

デプロイ後、Lambdaのテスト実行（空のイベントでよい）を1回実行し、以下を確認する。

- CloudWatch Logsにエラーが出ていないこと
- `https://<CloudFrontのドメイン>/course/store/stats.json`が意図した形式
  （`doc/server-feature-design.md`の`stats.json`構造）で取得できること

テスト実行はAWSコンソールから、またはCLIから直接呼べる:

```bash
aws lambda invoke --function-name course-stats-batch /tmp/out.json && cat /tmp/out.json
```

## 削除する場合

```bash
aws cloudformation delete-stack --stack-name kokokita-course-stats-batch
```

（アップロードしたzip自体はS3に残るので、不要になったら`ArtifactBucket`の
`course-stats-batch/`プレフィックス配下を別途削除する）

## 注意

- `SUPABASE_ANON_KEY`はRLSで保護される公開可能な鍵だが、`compute_course_stats`自体はsecurity
  definerで全ユーザー横断の集計を行う。返す内容が集計済みの数値のみであることを前提にしているため、
  RPCの実装を変更する際は「個々のユーザーを特定できる情報を返さない」ことを必ず確認すること
- `service_role`（secret）キーはこのLambdaに**絶対に設定しない**。anonキーだけで完結する設計
- `template.yaml`はこの環境で実際にAWSへデプロイして検証したものではない（YAML構文は確認済みだが、
  CloudFormation側の意味的な検証は未実施）。初回デプロイ時にエラーが出た場合は内容を教えてほしい
