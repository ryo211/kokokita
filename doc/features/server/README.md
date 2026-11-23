# サーバー連携

> ステータス: 実装中(フェーズ1)
> 最終更新: 2026-11-24
> 対象バージョン: v3.6.3〜

## この機能について

Supabase を使ったサーバー機能。フェーズ1では、匿名認証・スポット到達記録の送信・「◯人目」表示・コースへの関心度イベント送信・コース統計の日次集計を扱う。
以降のフェーズでメタ情報、写真投稿、コース投稿を予定している。

## 関連コード

- `kokokita/Shared/Features/SpotArrival/` — Supabase 認証・API クライアント
- `tools/course-stats-batch/` — コース統計を集計して `stats.json` を出力する Lambda
- `tools/course-admin/lambda/handler.py` — コース管理画面のAPI。`publish`/`delete-course`時に
  `courses`/`course_spots`テーブルへ自動反映する（Supabase連携の正式な同期経路）。
  `/stats`エンドポイントで到達人数・お気に入り数・閲覧数の集計も返す
  （`doc/features/server/admin_stats_function.sql`のRPCを使用）
- `tools/course-pipeline/sync_courses_to_supabase.py` — course-admin導入前に公開済みだった
  コースを一括で取り込むための backfill 専用ツール（通常運用では不要）

## 資料

| 資料 | 内容 | 状態 |
|---|---|---|
| [server-feature-design.md](server-feature-design.md) | サーバー機能全体の設計書(フェーズ計画・テーブル設計・API) | 現行(フェーズ1実装中) |
| [phase1_schema.sql](phase1_schema.sql) | フェーズ1の Supabase スキーマ(SQL Editor で実行) | 本番適用済み |
| [admin_stats_function.sql](admin_stats_function.sql) | コース管理画面の統計表示用RPC(SQL Editor で追加実行) | 本番適用が必要 |
