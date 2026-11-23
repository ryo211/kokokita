# ドキュメント索引と配置ルール

> 最終更新: 2026-11-24
>
> このリポジトリのドキュメントは、すべてこのファイルのルールに従って配置する。
> **新しくドキュメントを作るとき・移動するときは、必ずこのファイルを確認してから置き場所を決めること。**(人間・AIエージェント共通)

---

## 1. フォルダ構成

```
doc/
├── README.md              ← このファイル(索引と配置ルール)
├── app-overview.md        ← 機能概要書(一般の人向け。CLAUDE.md のルールで常に最新化)
│
├── architecture/          ← アプリ全体に効く「ルール」
│   ├── architecture-guide.md      アーキテクチャ・フォルダ構成・コーディング方針
│   ├── implementation-guide.md    実装手順とチェックリスト
│   ├── coredata-error-handling.md CoreData のエラーハンドリング方針
│   ├── troubleshooting.md         よくあるビルドエラー・Xcode プロジェクトの扱い
│   └── adr/                       設計判断の記録(ADR)
│
├── features/              ← 機能ごとの「仕様・設計」(1機能 = 1フォルダ)
│   ├── course/            コース・聖地巡礼(配信、作成、JSON仕様)
│   ├── server/            サーバー連携(Supabase、統計、SQLスキーマ)
│   ├── auto-record/       自動記録
│   └── onboarding/        オンボーディング(設計書とモック)
│
├── operations/            ← 開発・リリース・運用の「手順」
│   ├── branching-strategy.md      ブランチ戦略・バージョン管理
│   ├── firebase-crashlytics-setup.md
│   └── course-publishing.md       公式コースの作成〜公開手順
│
├── legal/                 ← 規約・ポリシー類
│   └── privacy-policy.md          (LP 掲載用は別管理。こちらはリポジトリ内の原本)
│
├── templates/             ← 新規作成時にコピーするテンプレート
│   ├── design-template.md
│   └── adr-template.md
│
└── archive/               ← 役目を終えた資料(参照のみ。更新しない)
```

ドキュメント以外の補助ツール(スクリプト・管理画面・Lambda)は `doc/` ではなく [`tools/`](../tools/README.md) に置く。

---

## 2. どこに置くか(判断フロー)

上から順に当てはめ、最初に該当した場所に置く。

| 書きたい内容 | 置き場所 |
|---|---|
| アプリ全体の機能を一般向けに説明する | `doc/app-overview.md` に追記(新規ファイルは作らない) |
| 特定の機能の仕様・設計・計画・データ形式 | `doc/features/<機能名>/` |
| 「なぜこの技術・方式を選んだか」という判断 | `doc/architecture/adr/NNN-タイトル.md` |
| 複数機能にまたがる実装ルール・規約 | `doc/architecture/` の既存ガイドに追記(足りなければ新規) |
| 作業手順(デプロイ、データ投入、セットアップ、リリース) | `doc/operations/` |
| 規約・ポリシー・法務 | `doc/legal/` |
| 実装が完了して参照されなくなった計画・移行ガイド | `doc/archive/` へ移動 |

### やってはいけないこと
- リポジトリのルート直下にドキュメントを置かない(例外: `CLAUDE.md` のみ)
- `doc/` 直下に機能別の設計書を置かない(必ず `features/<機能名>/` の中へ)
- 同じ機能の資料を複数フォルダに分散させない
- `.docx` などのバイナリ形式で設計書を置かない(Markdown で書く)
- 一時的な検討メモや中間データ(CSV・JSON の作業ファイル)をコミットしない

---

## 3. 機能フォルダ(`features/<機能名>/`)のルール

- **フォルダ名**: 英小文字のケバブケース(例: `auto-record`, `course`)。アプリのコード上の機能名(`kokokita/Shared/Features/` 等)に揃える
- **README.md を必ず置く**。内容は次の4点だけでよい
  1. この機能は何か(2〜3行)
  2. 現在の状態(検討中 / 実装中 / 実装済 / 廃止)と対象バージョン
  3. 関連するコードの場所
  4. フォルダ内の資料一覧(資料ごとの状態つき)
- **資料のファイル名**: 内容がわかる英小文字ケバブケース(例: `course-json-spec.md`)。特定リリースに紐づく設計書は `vX.Y.Z-タイトル.md` としてもよい
- 機能に付随する SQL・モック・画像はその機能フォルダ内に置く(例: `server/phase1_schema.sql`、`onboarding/mock/`)
- 新しい機能フォルダを作ったら、この README の「1. フォルダ構成」にも1行追加する

---

## 4. 各ドキュメントの書き方(粒度を揃えるための共通ルール)

**冒頭に次の3行を書く**(新規作成時は必須。既存のものは次に更新するときに追加する)

```markdown
> ステータス: 検討中 / 実装中 / 実装済 / 廃止
> 最終更新: YYYY-MM-DD
> 対象バージョン: vX.Y.Z
```

**種類ごとの書く範囲**

| 種類 | 書く範囲 | 書かないこと |
|---|---|---|
| 機能設計書(features) | 何を作るか・画面/データ/処理の仕様・エッジケース | 技術選定の議論の経緯(→ ADR へ) |
| ADR | 判断・その理由・却下した選択肢 | 実装手順の詳細 |
| ガイド(architecture) | 全機能に共通するルール | 特定機能だけの仕様 |
| 手順書(operations) | コマンドと順序、前提条件 | 設計の背景 |

**共通の心がけ**
- 形式より内容の新しさを優先する。実装が変わったら同じ作業の中で更新する
- 古くなった記述は残さず削除するか、資料ごと `archive/` へ移す
- 図が必要なら mermaid を使う
- ユーザーから見える機能を変えたら `app-overview.md` も更新する(CLAUDE.md のルール)

---

## 5. 新しく作るときの手順

### 機能設計書
1. `features/<機能名>/` があるか確認する。無ければ作り、README.md を書く
2. [templates/design-template.md](templates/design-template.md) をコピーして資料を書く(全セクションを埋める必要はない)
3. 機能フォルダの README の資料一覧に追加する

### ADR
1. [architecture/adr/](architecture/adr/) の既存番号を確認し、次の番号を振る
2. [templates/adr-template.md](templates/adr-template.md) をコピーして `NNN-タイトル.md` を作る
3. ステータスは「採用 / 却下 / 置き換え」のいずれか。置き換えるときは古い ADR にも新 ADR へのリンクを書く

### アーカイブするとき
1. `git mv` で `archive/` へ移動する(履歴を残すため)
2. 機能フォルダの README など、リンク元を直す

---

## 6. ドキュメント一覧

| 場所 | 内容 |
|---|---|
| [app-overview.md](app-overview.md) | 機能概要書(一般向け) |
| [architecture/architecture-guide.md](architecture/architecture-guide.md) | アーキテクチャガイド |
| [architecture/implementation-guide.md](architecture/implementation-guide.md) | 実装ガイド |
| [architecture/coredata-error-handling.md](architecture/coredata-error-handling.md) | CoreData エラーハンドリング |
| [architecture/troubleshooting.md](architecture/troubleshooting.md) | よくあるビルドエラー・Xcode プロジェクトの扱い |
| [architecture/adr/](architecture/adr/README.md) | ADR 001〜005 |
| [features/course/](features/course/README.md) | コース・聖地巡礼 |
| [features/server/](features/server/README.md) | サーバー連携 |
| [features/auto-record/](features/auto-record/README.md) | 自動記録 |
| [features/onboarding/](features/onboarding/README.md) | オンボーディング |
| [operations/branching-strategy.md](operations/branching-strategy.md) | ブランチ戦略 |
| [operations/firebase-crashlytics-setup.md](operations/firebase-crashlytics-setup.md) | Crashlytics セットアップ |
| [operations/course-publishing.md](operations/course-publishing.md) | 公式コースの作成〜公開手順 |
| [legal/privacy-policy.md](legal/privacy-policy.md) | プライバシーポリシー |
| [archive/](archive/) | MVVM→MV 移行ガイド、旧エージェント連携ガイド |
