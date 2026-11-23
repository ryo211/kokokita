# 公式コースの作成〜公開手順

> ステータス: 実装済
> 最終更新: 2026-11-24
> 対象バージョン: v3.x〜

公式コースの正本は **S3(`kokokita-resources` バケットの `course/` 以下)** にあり、CloudFront(`https://kokokita-app.irodoriq.com/course/`)から配信される。
リポジトリにはコース JSON や画像を置かない。

## 全体の流れ

```mermaid
flowchart LR
  A[スポット名リスト] -->|create_course_json_from_spot_list_google.py| B[コースJSON 下書き]
  B -->|fill_course_spot_geocode_google.py<br>(必要なら)| C[座標・住所を補完]
  C -->|管理画面で JSON アップロード| D[S3 ドラフト]
  D -->|管理画面で画像・内容を編集して公開| E[本番JSON + store/index.json]
  E -->|sync_courses_to_supabase.py| F[Supabase courses / course_spots]
```

## 手順

### 1. コース JSON を作る(`tools/course-pipeline/`)

```bash
cd tools/course-pipeline
export GOOGLE_MAPS_API_KEY=...   # キーはリポジトリに書かない
python3 create_course_json_from_spot_list_google.py spots.txt \
  --spot-id-prefix <接頭辞> --recognition-radius 250 -o <コースID>.json
```

- 入力の `spots.txt` は作業用ファイルなのでコミットしない
- タイトル・説明などのトップレベル項目は手で補完する
- JSON の仕様は [features/course/course-json-spec.md](../features/course/course-json-spec.md) を参照(**公開後に spotId を変えない**)
- 座標を補正し直したい場合は `fill_course_spot_geocode_google.py` を使う

### 2. 管理画面で登録・公開する(`tools/course-admin/`)

- 管理画面は `https://kokokita-app.irodoriq.com/course/manage/index.html`(`tools/course-admin/index.html` を配信)
- 「JSON をアップロード」で手順1の JSON をドラフトとして登録する
- 画像(Wikimedia Commons から検索できる)と内容を編集し、「公開」する
  - 公開すると本番 JSON の `version` が自動で増え、`store/index.json` が更新され、CloudFront のキャッシュが消される
- 管理画面自体を更新したときは `tools/course-admin/deploy.sh`、API を更新したときは `tools/course-admin/lambda/`(SAM)をデプロイする

### 3. Supabase に同期する(`tools/course-pipeline/`)

```bash
cd tools/course-pipeline
python3 sync_courses_to_supabase.py --dry-run   # 変更内容の確認
python3 sync_courses_to_supabase.py              # 反映
```

- 本番配信中の `store/index.json` から取得するため、ローカルにファイルは不要
- `SUPABASE_SERVICE_ROLE_KEY` は環境変数で渡し、リポジトリやアプリに含めない

## 関連

- コース統計の日次集計: [tools/course-stats-batch/README.md](../../tools/course-stats-batch/README.md)
