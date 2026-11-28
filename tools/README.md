# tools

アプリ本体(`kokokita/`)以外の補助ツール置き場。手順の説明は `doc/operations/` に書き、ここにはコードだけを置く。
コース JSON・画像・ジオコーディングキャッシュなどの作業データはコミットしない(正本は S3)。
一般公開する Web サイト(巡礼ガイド)は補助ツールではないため、別リポジトリ `ryo211/kokokita-web` に置いている。

| フォルダ | 内容 | 手順書 |
|---|---|---|
| [course-pipeline/](course-pipeline/) | コース JSON の生成・座標補完、Supabase への同期スクリプト | [doc/operations/course-publishing.md](../doc/operations/course-publishing.md) |
| [course-admin/](course-admin/) | コース管理画面(`index.html`)と管理 API(Lambda / SAM) | 同上 |
| [course-stats-batch/](course-stats-batch/README.md) | コース統計の日次集計 Lambda | [README](course-stats-batch/README.md) |

新しいツールを追加するときは、`tools/<用途>/` のフォルダを作り、この表に1行追加する。
