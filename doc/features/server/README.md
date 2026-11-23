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
- `tools/course-pipeline/sync_courses_to_supabase.py` — 公式コースを Supabase へ同期

## 資料

| 資料 | 内容 | 状態 |
|---|---|---|
| [server-feature-design.md](server-feature-design.md) | サーバー機能全体の設計書(フェーズ計画・テーブル設計・API) | 現行(フェーズ1実装中) |
| [phase1_schema.sql](phase1_schema.sql) | フェーズ1の Supabase スキーマ(SQL Editor で実行) | 本番適用済み |
