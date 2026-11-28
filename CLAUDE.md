# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 重要な規約

**このリポジトリでは、すべてのコード、コメント、ドキュメントを日本語で記述してください。**
- 変数名、関数名、クラス名は英語でも構いませんが、コメントや説明は日本語で記述すること
- エラーメッセージやログ出力も可能な限り日本語で記述すること
- コードレビューやコミットメッセージも日本語で記述すること

## プロジェクト概要

**kokokita** は、SwiftUIとCore Dataを使用したiOS向けの位置情報ベースの訪問記録アプリです。GPS座標を暗号署名付きで記録し、なりすましを防止します。写真、ラベル、グループ、メンバーを使って訪問記録を管理できます。

## アーキテクチャ

**Feature-based MV + `@Observable` Store** 構成です(詳細は [doc/architecture/architecture-guide.md](doc/architecture/architecture-guide.md)、判断の経緯は [ADR-001](doc/architecture/adr/001-フォルダ構成とアーキテクチャの再設計.md))。

```
kokokita/
├── App/              # エントリポイント・ルート(KokokitaApp, RootView, RootTabView, AppUIState, AppModeManager)
├── Features/         # 画面単位の機能(HomeScreen, VisitFormScreen, CourseScreen, AutoRecordScreen など)
└── Shared/
    ├── Features/     # 複数画面で共有するドメイン(Visit, Course, AutoRecord, SpotArrival, Taxonomy, Premium など)
    │                 #   それぞれ Models / Services / Views を持つ
    ├── Infrastructure/  # Persistence(CoreDataStack 等), Location, Security(DefaultIntegrityService), Map, Notifications
    ├── Components/   # 再利用 UI 部品(Media/ImageStore など)
    ├── Config/       # AppConfig, UIConstants, LocalizedString
    └── Utilities/    # DependencyContainer, Logger, NavigationRouter, Extensions
```

アプリ外の補助ツール(コース生成スクリプト、管理画面、Lambda)は [tools/](tools/README.md) に、公開Webサイト(巡礼ガイド、Astro)は、コードも資料も別リポジトリ `ryo211/kokokita-web`(ローカルでは `../kokokita-web`)にあります。

### 依存性注入
**DependencyContainer.swift** (`AppContainer.shared`) で集中的にサービスを初期化。すべてのリポジトリとサービスはここでインスタンス化され、ビューモデルに注入されます。

## 主要な技術詳細

### 改ざん検出システム
訪問記録には改ざんを検出するための不変な暗号署名が含まれます:
- ペイロードに含まれるもの: `id`、`timestampUTC`、`lat`、`lon`、`acc`、`isSimulatedBySoftware`、`isProducedByAccessory`
- P256 ECDSA署名をDER形式(base64)で保存
- 各訪問記録と共に公開鍵を保存して検証
- 秘密鍵はKeychainにタグ `jp.kokokita.signingkey.soft` で永続化

### Core Dataモデル
- **VisitEntity**: 不変な訪問データと改ざん検出フィールドを保存
- **VisitDetailsEntity**: 可変なメタデータ(タイトル、施設情報、コメント)を保存
- **VisitPhotoEntity**: 写真ファイルパスの順序付き関係
- **LabelEntity**、**GroupEntity**、**MemberEntity**: 多対多関係を持つタクソノミーエンティティ

写真はファイルシステムにファイルパスとして保存され、`ImageStore` (kokokita/Shared/Components/Media/) で管理されます。

### 位置情報ソース検出
アプリは偽装された位置情報を検出して防止します:
- `CLLocation.sourceInformation`から`isSimulatedBySoftware`と`isProducedByAccessory`をチェック
- 位置情報がシミュレートされている場合は訪問記録作成を拒否(`CreateEditViewModel.createNew()`参照)

### POI統合 ("ココカモ" / Kokokamo)
近隣の興味地点を検索し、施設情報を訪問記録に適用できます:
- 検索半径: 100m (`AppConfig.poiSearchRadius`で設定)
- リトライロジックでレート制限と一時的なエラーを処理
- 結果には名前、住所、電話番号、MapKitカテゴリが含まれる

## 開発でよく使うコマンド

### ビルドと実行
```bash
# Xcodeでプロジェクトを開く
open kokokita.xcodeproj

# コマンドラインからビルド
xcodebuild -project kokokita.xcodeproj -scheme kokokita -sdk iphoneos build

# シミュレータ向けビルド
xcodebuild -project kokokita.xcodeproj -scheme kokokita -sdk iphonesimulator build
```

### テスト
現在、コードベースには自動テストはありません。ユニットテストは通常、別のテストターゲットに追加されます。

## 設定

### AppConfig.swift
アプリの集中設定:
- `poiSearchRadius`: 100m
- `mapDisplayRadius`: 5000m
- `maxPhotosPerVisit`: 4
- `locationAccuracy`: `kCLLocationAccuracyBest`
- `locationTimeout`: 30秒
- 画像圧縮と共有設定

### ローカライゼーション
- 日本語(`ja.lproj`)と英語(`en.lproj`)をサポート
- ローカライズ文字列は`L`列挙型経由でアクセス(例: `L.Home.title`、`L.Error.locationSimulated`)
- `kokokita/Support/Localization/LocalizedString.swift`を参照

## 重要なパターン

### ナビゲーション
- `RootTabView`を介したタブベースナビゲーション(Home、Create/"ココキタ"、Menu)
- `NavigationRouter`ユーティリティでナビゲーションを処理

### 状態管理
- `AppUIState`: `KokokitaApp`で`@StateObject`として管理されるグローバルUI状態
- ビューモデルはリアクティブなUI更新のために`@Published`プロパティを使用
- タクソノミー変更は`NotificationCenter`(`.taxonomyChanged`通知)で配信

### 写真管理
写真は`PhotoEditService`を通じて管理されます:
- トランザクション型編集: `discardEditingIfNeeded()`で変更を破棄可能
- ファイルパスはCore Dataに保存、実際の画像はアプリのDocumentsディレクトリに保存
- ファイル操作には`ImageStore`を使用(保存/削除)

### フィルタリングと検索
`HomeViewModel`は複数条件のフィルタリングをサポート:
- ラベル、グループ、メンバー、カテゴリフィルタ
- タイトルと住所のキーワード検索
- 日付範囲フィルタ
- メンバーとカテゴリはクライアントサイドフィルタリング、ラベル/グループ/日付はサーバーサイド(Core Data述語)でフィルタリング

## コード規約

- Swiftコードには必要に応じて日本語コメントを使用
- カスタム`Logger`ユーティリティ(kokokita/Support/Logger.swift)でエラーログを記録
- 型ごとに整理された拡張機能は`kokokita/Support/Extensions/`に配置
- UI定数は`UIConstants.swift`に集約

### ローカライズ必須ルール

**ユーザーに表示される文言は必ずローカライズすること。ハードコーディングは厳禁です。**

1. **文言表示の原則**
   - UI上のすべてのテキスト（ボタン、ラベル、メッセージ、エラー文等）は`L`列挙型経由でローカライズ文字列を使用
   - 例: `Text("保存")` ❌ → `Text(L.Common.save)` ✅
   - 例: `"記録を削除"` ❌ → `L.Detail.deleteVisitTitle` ✅

2. **新規文言追加の手順**
   - `ja.lproj/Localizable.strings`に日本語の文字列を追加
   - `en.lproj/Localizable.strings`に英語の文字列を追加
   - `LocalizedString.swift`の`L`列挙型に対応するプロパティを追加
   - コード内で`L.カテゴリ.キー名`形式で参照

3. **チェックポイント**
   - 実装完了前に、すべての表示文字列がローカライズされているか確認
   - Grepで`Text("`や`"記録`などのパターンを検索してハードコードを検出
   - アラートのタイトル、メッセージも必ずローカライズ

4. **例外**
   - ログ出力やデバッグ用の文字列（ユーザーに表示されないもの）
   - 技術的な識別子やキー（例: UserDefaultsのキー名）

### ドキュメント配置ルール

**ドキュメントを新規作成・移動するときは、必ず先に [doc/README.md](doc/README.md) を読み、そこに定めたフォルダ構成と判断フローに従って配置してください。**

- 機能の仕様・設計書 → `doc/features/<機能名>/`(フォルダごとに README.md 必須)
- 設計判断の記録 → `doc/architecture/adr/`、全体ルール → `doc/architecture/`
- 作業手順 → `doc/operations/`、規約・ポリシー → `doc/legal/`、役目を終えた資料 → `doc/archive/`
- リポジトリのルート直下や `doc/` 直下に設計書を置かない。`.docx` 等のバイナリや作業用データ(CSV・JSON)はコミットしない
- 補助スクリプト・管理画面・Lambda は `tools/<用途>/` に置く
- 一般公開する Web サイト(巡礼ガイド)は、コードも資料も別リポジトリ `kokokita-web` に置く
- 新規ドキュメントの冒頭には「ステータス・最終更新・対象バージョン」の3行を書く
- 新しい機能フォルダやツールを追加したら `doc/README.md` / `tools/README.md` の一覧も更新する

### 機能概要書の更新ルール

**[doc/app-overview.md](doc/app-overview.md) は、一般の人がアプリの全体像を理解するための機能概要書です。ユーザーから見える機能を変えたときは、同じ作業の中で必ず更新してください。**

1. **更新が必要なとき**
   - 機能の追加・削除・名称変更
   - 画面構成・タブ構成・操作手順の変更
   - Premium 機能・料金プランの変更
   - サーバーに送るデータや、プライバシーに関わる挙動の変更
   - 制限値の変更(写真の枚数上限、検索半径、ゴミ箱の保存期間など)
2. **更新しなくてよいとき**
   - 内部のリファクタリング、バグ修正、パフォーマンス改善など、ユーザーから見える挙動が変わらないもの
3. **書き方**
   - 一般の人向けの言葉で書く。技術的な説明は「💡技術メモ」として必要なときだけ短く添える
   - 冒頭の「最終更新」と末尾の「更新履歴」(日付・バージョン・内容)も更新する
4. **チェックポイント**
   - 実装完了前に、機能概要書の記述が実装と合っているか確認する

## 最近の変更

最近のコミットに基づく変更:
- メンバー機能追加
- キーワード検索を住所フィールドにも拡張
- POI検索のエラーハンドリング改善(レート制限、座標検証、リトライロジック)
- キーボード入力の完了ボタンの統一

## AI開発ツールの活用方針

### インターネット検索の積極活用

**Claudeは以下の場合に必ずインターネット検索を実行してください:**

1. **最新のベストプラクティスの確認**
   - SwiftUI、iOS 17+の新機能
   - @Observableマクロの最新の使用方法
   - Core Dataのパフォーマンス最適化
   - セキュリティのベストプラクティス

2. **技術的な疑問の解決**
   - エラーメッセージの調査
   - 新しいAPIの使用方法
   - パフォーマンス問題のトラブルシューティング
   - 非推奨APIの代替手段

3. **設計判断のための情報収集**
   - アーキテクチャパターンの評価
   - ライブラリやフレームワークの選定
   - セキュリティ脆弱性の確認
   - アクセシビリティのガイドライン

4. **最新情報の確認が必要な場合**
   - Xcode、Swiftのバージョン情報
   - iOS SDKの変更点
   - Apple公式ドキュメントの更新
   - コミュニティのベストプラクティス

**検索のタイミング:**
- 実装前: 最新のベストプラクティスを確認
- エラー発生時: 解決策を検索
- 設計判断時: 複数の選択肢を比較
- レビュー時: セキュリティやパフォーマンスの観点を確認

**検索クエリの例:**
- "SwiftUI @Observable best practices 2025"
- "iOS 17 Core Data performance optimization"
- "Swift CryptoKit P256 signature implementation"
- "SwiftUI navigation patterns 2025"

### エージェントシステムの活用

**タスクに応じて適切なエージェントに委譲してください:**

- `/manager`: 複雑なタスクの統括管理
- `/designer`: 新機能の詳細設計
- `/reviewer`: コードレビューと品質チェック
- `/documentor`: ドキュメント作成・更新

### 実装の基本フロー

1. **情報収集** → インターネット検索 + 関連ドキュメント(`doc/README.md` の索引から探す)
2. **設計** → 最新のベストプラクティスを確認
3. **実装** → 既存コードのパターンに合わせて実装
4. **検証** → エラーは [doc/architecture/troubleshooting.md](doc/architecture/troubleshooting.md) とインターネットで解決
5. **ドキュメント** → 得た知見は `doc/README.md` の配置ルールに従って記録

この方針により、常に最新の情報に基づいた高品質な実装が可能になります。
