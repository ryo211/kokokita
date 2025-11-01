# コードベース構造

## プロジェクトルート構造

```
kokokita/
├── kokokita/                    # メインソースコード
├── Kokokita.xcdatamodeld/       # Core Dataモデル
├── kokokita.xcodeproj/          # Xcodeプロジェクトファイル
├── doc/                         # ドキュメント
├── .claude/                     # Claude設定（エージェント）
├── .serena/                     # Serena設定（MCP）
├── memo/                        # メモ
├── .git/                        # Gitリポジトリ
├── .gitignore                   # Git除外設定
└── CLAUDE.md                    # プロジェクト概要（重要）

```

## メインソースコード構造（Phase 8完了後の最新構成）

```
kokokita/
├── App/                         # アプリケーション設定
│   ├── KokokitaApp.swift        # エントリポイント
│   ├── AppDelegate.swift        # アプリデリゲート
│   ├── Config/
│   │   ├── UIConstants.swift    # UI定数
│   │   └── AppConfig.swift      # アプリ設定
│   └── DI/
│       └── DependencyContainer.swift  # DIコンテナ（直接依存）
│
├── Resources/                   # リソース
│   ├── ja.lproj/                # 日本語リソース
│   │   └── Localizable.strings
│   └── en.lproj/                # 英語リソース
│       └── Localizable.strings
│
├── Assets.xcassets/             # アセット（画像、色等）
│   ├── AppIcon.appiconset/
│   ├── kokokita_icon.imageset/
│   └── AccentColor.colorset/
│
├── Features/                    # 機能単位（Feature-based MV + Logic/Effects分離）
│   ├── Home/
│   │   ├── Models/
│   │   │   └── HomeStore.swift           # @Observable（状態管理）
│   │   ├── Logic/                        # 純粋な関数（Functional Core）
│   │   │   ├── VisitFilter.swift         # フィルタリングロジック
│   │   │   ├── VisitSorter.swift         # ソートロジック
│   │   │   ├── VisitGrouper.swift        # 日付グルーピング
│   │   │   └── DateHelper.swift          # 日付計算ユーティリティ
│   │   └── Views/
│   │       ├── HomeView.swift
│   │       ├── HomeMapView.swift
│   │       ├── VisitRow.swift
│   │       └── Filter/
│   │           ├── HomeFilterHeader.swift
│   │           ├── SearchFilterSheet.swift
│   │           └── FlowRow.swift
│   │
│   ├── Create/
│   │   ├── Models/
│   │   │   └── CreateEditStore.swift     # @Observable（状態管理）
│   │   ├── Logic/                        # 純粋な関数（Functional Core）
│   │   │   ├── StringValidator.swift     # 文字列検証
│   │   │   └── LocationValidator.swift   # 位置情報検証
│   │   ├── Effects/                      # 副作用（Imperative Shell）
│   │   │   ├── POIEffects.swift          # POI検索（リトライロジック付き）
│   │   │   └── PhotoEffects.swift        # 写真管理（トランザクション型）
│   │   └── Views/
│   │       ├── CreateScreen.swift
│   │       ├── PromptViews.swift
│   │       ├── PhotoAttachmentSection.swift
│   │       ├── LocationLoadingView.swift
│   │       └── POIListView.swift
│   │
│   ├── Detail/
│   │   └── Views/
│   │       ├── VisitDetailScreen.swift
│   │       ├── VisitDetailContent.swift
│   │       ├── EditView.swift
│   │       └── PhotoReadOnlyGrid.swift
│   │
│   └── Menu/
│       └── Views/
│           ├── MenuHomeView.swift
│           ├── LabelListView.swift
│           ├── GroupListView.swift
│           ├── MemberListView.swift
│           └── ResetAllView.swift
│
├── Shared/                      # 共通コード
│   ├── Models/                  # ドメインモデル（Domain/から移行）
│   │   ├── Visit.swift          # 不変な訪問データ + Integrity
│   │   ├── VisitDetails.swift   # 可変なメタデータ + FacilityInfo
│   │   ├── VisitAggregate.swift # 集約ルート（Visit + VisitDetails）
│   │   ├── Taxonomy.swift       # LabelTag, GroupTag, MemberTag
│   │   └── PlacePOI.swift       # POI検索結果
│   │
│   ├── Services/                # 共通サービス（Infrastructure/を統合）
│   │   ├── Persistence/         # データ永続化（旧Infrastructure/Persistence/）
│   │   │   ├── CoreDataStack.swift
│   │   │   ├── CoreDataVisitRepository.swift
│   │   │   └── CoreDataTaxonomyRepository.swift
│   │   ├── Location/            # 位置情報関連（旧Infrastructure/Location/）
│   │   │   ├── DefaultLocationService.swift
│   │   │   └── MapKitPlaceLookupService.swift
│   │   ├── Security/            # セキュリティ関連（旧Infrastructure/Security/）
│   │   │   └── DefaultIntegrityService.swift
│   │   ├── LocationGeocodingService.swift  # 位置情報+ジオコーディング
│   │   └── RateLimiter.swift    # レート制限
│   │
│   ├── Media/                   # メディア管理
│   │   ├── ImageStore.swift     # 画像ファイル管理
│   │   ├── PhotoPager.swift     # 写真フルスクリーン
│   │   └── PhotoThumb.swift     # 写真サムネイル
│   │
│   ├── UIComponents/            # 共通UIコンポーネント
│   │   └── ActivityView.swift   # 共有UI
│   │
│   └── AppMedia.swift           # メディア定数
│
├── Support/                     # サポートユーティリティ
│   ├── NavigationRouter.swift   # ナビゲーション
│   ├── Logger.swift             # ログユーティリティ
│   ├── Extensions/              # 拡張機能
│   │   ├── DateExtensions.swift
│   │   ├── StringExtensions.swift
│   │   ├── CollectionExtensions.swift
│   │   └── NotificationExtensions.swift
│   ├── Localization/
│   │   └── LocalizedString.swift  # ローカライズ定義（L列挙型）
│   ├── ShareImageRenderer.swift
│   ├── KeyboardAwareTextView.swift
│   ├── KeyboardDismissHelpers.swift
│   └── MKPointOfInterestCategory+JP.swift
│
├── Presentation/                # プレゼンテーション層（共通コンポーネントのみ残存）
│   ├── Map/
│   │   ├── MapPreview.swift
│   │   └── MapSnapshotService.swift
│   └── Views/
│       └── Common/              # 共通コンポーネント
│           ├── RootTabView.swift      # タブナビゲーション
│           ├── AppUIState.swift       # グローバルUI状態
│           ├── VisitEditScreen.swift  # 共通編集画面
│           ├── FacilityInfoButton.swift
│           ├── KokokamoPOISheet.swift
│           └── Components/
│               ├── Chip.swift
│               ├── EditFooterBar.swift
│               ├── KokokitaHeaderLogo.swift
│               ├── CameraPicker.swift
│               ├── LabelPickerSheet.swift
│               ├── GroupPickerSheet.swift
│               ├── MemberPickerSheet.swift
│               ├── LabelCreateSheet.swift
│               ├── GroupCreateSheet.swift
│               ├── MemberCreateSheet.swift
│               ├── AlertMsg.swift
│               ├── BannerAdView.swift
│               └── BigFooterButton.swift
│
├── ContentView.swift            # ルートビュー
├── Info.plist                   # アプリ情報
└── Preview Content/             # プレビュー用
    └── Preview Assets.xcassets/

```

## ドキュメント構造

```
doc/
├── architecture-guide.md        # アーキテクチャガイド（重要）
├── implementation-guide.md      # 実装ガイド（重要）
├── agent-guide.md              # エージェント連携ガイド
├── ADR/                        # Architecture Decision Records
│   ├── README.md
│   ├── template.md
│   ├── 001-フォルダ構成とアーキテクチャの再設計.md
│   ├── 002-MVVM-MV移行評価.md
│   ├── 003-Observable-マクロ移行評価.md
│   └── 004-class最小化と関数型パターンの採用.md
└── design/                     # 設計書
    ├── README.md
    └── template.md
```

## 重要なファイル

### プロジェクト設定
- `CLAUDE.md`: プロジェクト全体の方針（**最重要**）
- `doc/architecture-guide.md`: コーディング規約とベストプラクティス
- `doc/implementation-guide.md`: 実装手順とチェックリスト

### ドメインモデル（Phase 6で分割）
- `Shared/Models/Visit.swift`: 不変な訪問データ + Integrity + LocationSourceFlags
- `Shared/Models/VisitDetails.swift`: 可変なメタデータ + FacilityInfo
- `Shared/Models/VisitAggregate.swift`: 集約ルート（Visit + VisitDetails）
- `Shared/Models/Taxonomy.swift`: LabelTag、GroupTag、MemberTag
- `Shared/Models/PlacePOI.swift`: POI検索結果

### Core Data（Phase 8でShared/Services/Persistence/に統合）
- `Kokokita.xcdatamodeld/`: Core Dataモデル定義
- `Shared/Services/Persistence/CoreDataStack.swift`: Core Data管理
- `Shared/Services/Persistence/CoreDataVisitRepository.swift`: 訪問記録リポジトリ
- `Shared/Services/Persistence/CoreDataTaxonomyRepository.swift`: タクソノミーリポジトリ

### 依存性注入（Phase 7で直接依存に変更）
- `App/DI/DependencyContainer.swift`: DIコンテナ（AppContainer.shared）
- Protocolベース抽象化は廃止、具体実装への直接依存

### ローカライゼーション
- `Support/Localization/LocalizedString.swift`: L列挙型で定義
- `Resources/ja.lproj/Localizable.strings`: 日本語
- `Resources/en.lproj/Localizable.strings`: 英語

### ナビゲーション
- `Presentation/Views/Common/RootTabView.swift`: タブナビゲーション

## ファイル配置のルール

### 機能固有のファイル
```
Features/[機能名]/
├── Models/              # @Observable Store
├── Logic/              # 純粋な関数（Functional Core）
├── Effects/            # 副作用（Imperative Shell）
└── Views/              # UIコンポーネント
```

### 複数の機能で使用する場合
```
Shared/
├── Models/             # ドメインモデル
├── Services/           # 共通インフラサービス
├── Media/              # メディア管理
└── UIComponents/       # 共通UIコンポーネント
```

### UI定数と設定
```
App/Config/
├── AppConfig.swift      # アプリ全体の設定
└── UIConstants.swift    # UI定数
```

## Xcodeプロジェクト構成

- **Target**: kokokita
- **Scheme**: kokokita
- **Deployment Target**: iOS 17+
- **Swift Version**: 最新
- **Project Format**: Xcode 15+ (PBXFileSystemSynchronizedRootGroup)
  - kokokita/ フォルダ内のファイルは自動的にビルドに含まれる
  - 手動での"Add to target"は不要

## Core Dataエンティティ

- VisitEntity: 不変な訪問データ
- VisitDetailsEntity: 可変なメタデータ
- VisitPhotoEntity: 写真ファイルパス
- LabelEntity, GroupEntity, MemberEntity: タクソノミー

## アーキテクチャパターン

### MVパターン（iOS 17+ @Observable）+ Logic/Effects分離
- **Store**: @Observableで状態管理（旧ViewModel）
- **View**: SwiftUI View
- **Logic**: 純粋な関数（Functional Core）
- **Effects**: 機能固有の副作用（Imperative Shell）
- **Services**: 共通インフラの副作用（Shared/Services/）

### 命名規則
- Store: `[機能名]Store.swift`（例：HomeStore.swift）
- View: `[機能名]View.swift`
- Logic: `[処理名].swift`（例：VisitFilter.swift）
- Effects: `[対象]Effects.swift`（例：POIEffects.swift）
- Services: `[機能名]Service.swift`（例：DefaultLocationService.swift）

## アーキテクチャ進化の歴史

### Phase 1-3（前セッション完了）
- MVVM → MV移行
- ViewModel → Store リネーム
- Features/構造への移行
- @Observable導入

### Phase 4: Logic層の分離（完了）
- HomeStoreから純粋関数を抽出:
  - `Features/Home/Logic/VisitFilter.swift`
  - `Features/Home/Logic/VisitSorter.swift`
  - `Features/Home/Logic/VisitGrouper.swift`
  - `Features/Home/Logic/DateHelper.swift`
- CreateEditStoreから純粋関数を抽出:
  - `Features/Create/Logic/StringValidator.swift`
  - `Features/Create/Logic/LocationValidator.swift`

### Phase 5: Services → Effects リネーム（完了）
- 機能固有のServiceをEffectsに改名:
  - `POICoordinatorService.swift` → `Features/Create/Effects/POIEffects.swift`
  - `PhotoEditService.swift` → `Features/Create/Effects/PhotoEffects.swift`
- TCAパターンとの整合性向上

### Phase 6: Domain層の削除とモデル分割（完了）
- `Domain/Models.swift` を5つのファイルに分割してShared/Models/に配置:
  - `Visit.swift`（不変な訪問データ + LocationSourceFlags）
  - `VisitDetails.swift`（可変メタデータ + FacilityInfo）
  - `VisitAggregate.swift`（集約ルート）
  - `Taxonomy.swift`（タグ類）
  - `PlacePOI.swift`（POI検索結果）
- `Domain/`ディレクトリ削除（Phase 7で完全削除）

### Phase 7: Protocol削除と直接依存（完了）
- すべてのProtocolベースDIを削除:
  - `VisitRepository` → `CoreDataVisitRepository`
  - `TaxonomyRepository` → `CoreDataTaxonomyRepository`
  - `LocationService` → `DefaultLocationService`
  - `PlaceLookupService` → `MapKitPlaceLookupService`
  - `IntegrityService` → `DefaultIntegrityService`
- `Domain/Protocols.swift` 削除
- `Domain/`ディレクトリ完全削除
- Storeのinitでデフォルト引数を使用してDI実現

### Phase 8: Infrastructure統合（完了）
- Infrastructure/をShared/Services/に統合:
  - `Infrastructure/Persistence/` → `Shared/Services/Persistence/`
  - `Infrastructure/Location/` → `Shared/Services/Location/`
  - `Infrastructure/Security/` → `Shared/Services/Security/`
- `Infrastructure/`ディレクトリ削除
- 3層アーキテクチャから実用的な2層構成へ

## 現在の状態（Phase 8完了）

✅ **完全に新構成に移行完了**

**新構成（現在）**:
- `Features/[機能名]/`: 機能ごとにコロケーション（Models/Logic/Effects/Views）
- `Shared/Models/`: 分割された明確なドメインモデル
- `Shared/Services/`: インフラ層を統合した共通サービス
  - Persistence/、Location/、Security/のサブディレクトリで整理
- Store使用（ViewModelなし）
- @Observableマクロ（ObservableObjectなし）
- 直接依存（Protocolなし）
- Logic/Effects分離（Functional Core, Imperative Shell）

**削除された旧構成**:
- ❌ `Domain/`（Phase 6-7で削除）
- ❌ `Infrastructure/`（Phase 8で削除）
- ❌ `Features/Create/Services/`（Phase 5でEffects/に統合）
- ❌ Protocolベース抽象化（Phase 7で削除）
- ❌ ObservableObject（Phase 1-3で@Observableに置換）

## 注意点

### コンパイラエラー対策
- SwiftUIのbodyプロパティが複雑すぎる場合は、ヘルパープロパティやViewBuilderメソッドに分割する
- @Observableオブジェクトには`$`バインディングが使えるのは`@Bindable`または`@State`のプロパティのみ
- 計算プロパティ（`var vm: Store { store }`）には`$`バインディングは使えない

### ファイル配置
- 機能固有のファイル → `Features/[機能名]/`（Models、Logic、Effects、Viewsに分類）
- 複数機能で共有 → `Shared/`（Models、Services、Media、UIComponentsに分類）
- 汎用ユーティリティ → `Support/`
