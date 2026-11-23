# コース・聖地巡礼

> ステータス: 実装済
> 最終更新: 2026-11-24
> 対象バージョン: v3.0〜(現行 v3.6.3)

## この機能について

公式コース(聖地巡礼・名城・世界遺産など)や、ユーザーが自分で作ったコースのスポットを巡り、到達を記録する機能。
公式コースはサーバー(S3 + CloudFront)から配信し、アプリ起動時に自動同期する(旧方式のアプリ同梱は廃止済み)。

## 関連コード

- `kokokita/Shared/Features/Course/` — モデル・リポジトリ・配信同期(`CourseStoreService` など)
- `kokokita/Features/CourseScreen/` — コース一覧・詳細画面
- `kokokita/Features/PilgrimageHomeScreen/`、`kokokita/Features/StampScreen/`、`kokokita/Features/CheckInScreen/`

## 資料

| 資料 | 内容 | 状態 |
|---|---|---|
| [course-json-spec.md](course-json-spec.md) | 配信コース JSON の仕様(spotId 不変ルールを含む) | 現行仕様 |
| [course-creation.md](course-creation.md) | ユーザーによるコース作成機能の実装仕様 | 現行仕様 |
| [pilgrimage-plan.md](pilgrimage-plan.md) | 聖地巡礼機能の初期計画書(v3.0 前) | 計画時点の資料。現行仕様は上の2つを優先 |

## 関連

- 公式コースの作成〜公開手順: [operations/course-publishing.md](../../operations/course-publishing.md)
- 到達記録・統計のサーバー連携: [features/server/](../server/README.md)
