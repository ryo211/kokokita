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

コードベースは**クリーンアーキテクチャ**の原則に従い、関心事の明確な分離を実現しています。

### ドメイン層 (`kokokita/Domain/`)
- **Models.swift**: コアドメインモデル。`Visit`(改ざん防止署名付きの不変な位置情報データ)、`VisitDetails`(可変なメタデータ)、`VisitAggregate`(両者を結合)、タクソノミー型(`LabelTag`、`GroupTag`、`MemberTag`)を定義
- **Protocols.swift**: データアクセスとビジネスロジックの契約を定義するリポジトリとサービスのインターフェース

### インフラ層 (`kokokita/Infrastructure/`)
- **CoreDataStack.swift**: Core Dataの永続化コンテナを管理。自動マイグレーション有効化
- **CoreDataVisitRepository.swift**: `VisitRepository`と`TaxonomyRepository`プロトコルを実装。すべてのCore Data CRUD操作を処理
- **DefaultIntegrityService.swift**: CryptoKitのP256鍵を使用した暗号署名/検証。鍵はKeychainに保存

### プレゼンテーション層 (`kokokita/Presentation/`)
- **ViewModels/**: MVVMパターンで`@MainActor`付きビューモデル(`HomeViewModel`、`CreateEditViewModel`)
- **Views/**: 機能ごとに整理されたSwiftUIビュー(Home、Create、Detail、Menu、共通コンポーネント)

### サービス層 (`kokokita/Services/`)
- **DefaultLocationService.swift**: 位置情報権限とワンショットGPS取得を処理。ソースフラグ検出(シミュレート/アクセサリ)付き
- **LocationGeocodingService.swift**: 位置情報取得と逆ジオコーディングを組み合わせ
- **POICoordinatorService.swift**: 近隣POI検索をリトライロジック付きで管理(3回試行、指数バックオフ)
- **MapKitPlaceLookupService.swift**: MapKitを使用したPOI検索実装
- **PhotoEditService.swift**: 訪問記録の写真管理

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

写真はファイルシステムにファイルパスとして保存され、`ImageStore` (kokokita/Shared/Media/) で管理されます。

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

### Serenaツールの優先使用

**コード探索・編集時はSerenaツールを優先してください:**

1. **会話開始時**
   ```
   mcp__serena__check_onboarding_performed
   mcp__serena__list_memories
   mcp__serena__read_memory (必要なメモリを読み込み)
   ```

2. **コード探索時**
   ```
   mcp__serena__get_symbols_overview (ファイル全体を読む前に)
   mcp__serena__find_symbol (特定のシンボルを探す)
   mcp__serena__find_referencing_symbols (依存関係を調査)
   ```

3. **コード編集時**
   ```
   mcp__serena__replace_symbol_body (シンボル置換)
   mcp__serena__insert_after_symbol (新規追加)
   ```

4. **品質確認時**
   ```
   mcp__serena__think_about_collected_information
   mcp__serena__think_about_task_adherence
   mcp__serena__think_about_whether_you_are_done
   ```

### エージェントシステムの活用

**タスクに応じて適切なエージェントに委譲してください:**

- `/manager`: 複雑なタスクの統括管理
- `/designer`: 新機能の詳細設計
- `/reviewer`: コードレビューと品質チェック
- `/documentor`: ドキュメント作成・更新

### 実装の基本フロー

1. **情報収集** → インターネット検索 + Serenaメモリ読み込み
2. **設計** → 最新のベストプラクティスを確認
3. **実装** → Serenaツールで効率的にコード操作
4. **検証** → インターネットでエラー解決、Serenaで品質確認
5. **ドキュメント** → Serenaメモリに知見を保存

この方針により、常に最新の情報に基づいた高品質な実装が可能になります。
