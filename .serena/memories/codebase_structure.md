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

## メインソースコード構造（最新の構成 - Shared/Features導入後）

```
kokokita/
├── App/                         # アプリケーション設定
│   ├── KokokitaApp.swift        # エントリポイント
│   ├── AppDelegate.swift        # アプリデリゲート
│   ├── RootTabView.swift        # タブナビゲーション
│   ├── AppUIState.swift         # グローバルUI状態
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
├── Features/                    # アプリ機能（Feature-based MV + Logic/Effects分離）
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
│   ├── Features/                # 共有機能（Feature-based）
│   │   ├── Map/                 # 地図機能
│   │   │   ├── Views/
│   │   │   │   ├── MapPreview.swift      # 地図プレビューコンポーネント
│   │   │   │   └── CoordinateBadge.swift # 座標バッジコンポーネント
│   │   │   └── Logic/
│   │   │       └── MapURLBuilder.swift   # 地図アプリURL生成（純粋関数）
│   │   │
│   │   ├── Taxonomy/            # タクソノミー機能（Label/Group/Member）
│   │   │   ├── Models/
│   │   │   │   └── Taxonomy.swift        # LabelTag, GroupTag, MemberTag
│   │   │   ├── Services/
│   │   │   │   └── CoreDataTaxonomyRepository.swift
│   │   │   └── Views/
│   │   │       ├── Pickers/
│   │   │       │   ├── LabelPickerSheet.swift
│   │   │       │   ├── GroupPickerSheet.swift
│   │   │       │   └── MemberPickerSheet.swift
│   │   │       └── Forms/
│   │   │           ├── LabelCreateSheet.swift
│   │   │           ├── GroupCreateSheet.swift
│   │   │           └── MemberCreateSheet.swift
│   │   │
│   │   └── Visit/               # 訪問記録機能
│   │       ├── Models/
│   │       │   ├── Visit.swift           # 不変な訪問データ + Integrity
│   │       │   ├── VisitDetails.swift    # 可変なメタデータ + FacilityInfo
│   │       │   ├── VisitAggregate.swift  # 集約ルート（Visit + VisitDetails）
│   │       │   └── PlacePOI.swift        # POI検索結果
│   │       ├── Services/
│   │       │   └── CoreDataVisitRepository.swift
│   │       └── Views/
│   │           └── VisitEditScreen.swift # 共通編集画面
│   │
│   ├── Infrastructure/          # 共有インフラ（技術層）
│   │   ├── Persistence/
│   │   │   └── CoreDataStack.swift       # Core Data管理
│   │   ├── Location/
│   │   │   ├── DefaultLocationService.swift
│   │   │   ├── MapKitPlaceLookupService.swift
│   │   │   └── LocationGeocodingService.swift
│   │   ├── Security/
│   │   │   └── DefaultIntegrityService.swift
│   │   ├── Map/
│   │   │   └── MapSnapshotService.swift  # 地図スナップショット生成
│   │   └── RateLimiter.swift
│   │
│   ├── UIComponents/            # 汎用UIコンポーネント
│   │   ├── Chip.swift
│   │   ├── EditFooterBar.swift
│   │   ├── KokokitaHeaderLogo.swift
│   │   ├── CameraPicker.swift
│   │   ├── AlertMsg.swift
│   │   ├── BannerAdView.swift
│   │   ├── BigFooterButton.swift
│   │   ├── FacilityInfoButton.swift
│   │   └── KokokamoPOISheet.swift
│   │
│   ├── UI/                      # UIユーティリティ
│   │   ├── Components/
│   │   │   └── ActivityView.swift
│   │   ├── Keyboard/
│   │   │   ├── KeyboardAwareTextView.swift
│   │   │   └── KeyboardDismissHelpers.swift
│   │   └── Media/
│   │       ├── PhotoPager.swift
│   │       ├── PhotoThumb.swift
│   │       └── ImageStore.swift
│   │
│   ├── Config/
│   │   ├── AppMedia.swift
│   │   └── Localization/
│   │       └── LocalizedString.swift
│   │
│   ├── DI/
│   │   └── DependencyContainer.swift
│   │
│   └── Utilities/
│       ├── NavigationRouter.swift
│       ├── Logger.swift
│       ├── ShareImageRenderer.swift
│       ├── MKPointOfInterestCategory+JP.swift
│       └── Extensions/
│           ├── DateExtensions.swift
│           ├── StringExtensions.swift
│           ├── CollectionExtensions.swift
│           └── NotificationExtensions.swift
│
├── Support/                     # サポートユーティリティ
│   （現在は空またはShared/に統合済み）
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

### ドメインモデル（Shared/Features/配下に整理）
- `Shared/Features/Visit/Models/Visit.swift`: 不変な訪問データ + Integrity + LocationSourceFlags
- `Shared/Features/Visit/Models/VisitDetails.swift`: 可変なメタデータ + FacilityInfo
- `Shared/Features/Visit/Models/VisitAggregate.swift`: 集約ルート（Visit + VisitDetails）
- `Shared/Features/Taxonomy/Models/Taxonomy.swift`: LabelTag、GroupTag、MemberTag
- `Shared/Features/Visit/Models/PlacePOI.swift`: POI検索結果

### Core Data（Shared/Infrastructure/Persistence/に統合）
- `Kokokita.xcdatamodeld/`: Core Dataモデル定義
- `Shared/Infrastructure/Persistence/CoreDataStack.swift`: Core Data管理
- `Shared/Features/Visit/Services/CoreDataVisitRepository.swift`: 訪問記録リポジトリ
- `Shared/Features/Taxonomy/Services/CoreDataTaxonomyRepository.swift`: タクソノミーリポジトリ

### 依存性注入（直接依存）
- `Shared/DI/DependencyContainer.swift`: DIコンテナ（AppContainer.shared）
- Protocolベース抽象化は廃止、具体実装への直接依存

### ローカライゼーション
- `Shared/Config/Localization/LocalizedString.swift`: L列挙型で定義
- `Resources/ja.lproj/Localizable.strings`: 日本語
- `Resources/en.lproj/Localizable.strings`: 英語

### ナビゲーション
- `App/RootTabView.swift`: タブナビゲーション

## ファイル配置のルール

### アプリ機能
```
Features/[機能名]/
├── Models/              # @Observable Store
├── Logic/              # 純粋な関数（Functional Core）
├── Effects/            # 副作用（Imperative Shell）
└── Views/              # UIコンポーネント
```

### 共有機能（Feature-based）
```
Shared/Features/[機能名]/
├── Models/             # ドメインモデル
├── Services/           # 機能固有のサービス
├── Logic/              # 純粋な関数
└── Views/              # UIコンポーネント
```

### 共有インフラ（技術層）
```
Shared/Infrastructure/
├── Persistence/        # Core Data
├── Location/           # 位置情報
├── Security/           # セキュリティ
└── Map/                # 地図関連サービス
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
- **Infrastructure**: 共通インフラの副作用（Shared/Infrastructure/）

### 命名規則
- Store: `[機能名]Store.swift`（例：HomeStore.swift）
- View: `[機能名]View.swift`
- Logic: `[処理名].swift`（例：VisitFilter.swift、MapURLBuilder.swift）
- Effects: `[対象]Effects.swift`（例：POIEffects.swift）
- Services: `[機能名]Service.swift`（例：DefaultLocationService.swift）

## アーキテクチャ進化の歴史

### Phase 1-3（前セッション完了）
- MVVM → MV移行
- ViewModel → Store リネーム
- Features/構造への移行
- @Observable導入

### Phase 4: Logic層の分離（完了）
- HomeStoreから純粋関数を抽出
- CreateEditStoreから純粋関数を抽出

### Phase 5: Services → Effects リネーム（完了）
- 機能固有のServiceをEffectsに改名

### Phase 6: Domain層の削除とモデル分割（完了）
- Domain/Models.swift を5つのファイルに分割してShared/Models/に配置

### Phase 7: Protocol削除と直接依存（完了）
- すべてのProtocolベースDIを削除
- Storeのinitでデフォルト引数を使用してDI実現

### Phase 8: Infrastructure統合（完了）
- Infrastructure/をShared/Services/に統合

### Phase 9: Presentation統合（完了）
- Presentation/フォルダを削除
- アプリレベルコンポーネントをApp/に移動
- 共通UIコンポーネントをShared/UIComponents/に移動
- Map関連をShared/Map/に移動（後にShared/Features/Map/に再構成）

### Phase 10: Shared/Features構造導入（完了）
- **Shared/Features/Map/** 作成
  - Views/: MapPreview、CoordinateBadge
  - Logic/: MapURLBuilder（純粋関数）
- **Shared/Features/Taxonomy/** 作成
  - Models/: Taxonomy.swift
  - Services/: CoreDataTaxonomyRepository
  - Views/Pickers/: Label/Group/MemberPickerSheet
  - Views/Forms/: Label/Group/MemberCreateSheet
- **Shared/Features/Visit/** 作成
  - Models/: Visit、VisitDetails、VisitAggregate、PlacePOI
  - Services/: CoreDataVisitRepository
  - Views/: VisitEditScreen
- **Shared/Infrastructure/** 再編成
  - Persistence/、Location/、Security/、Map/に整理
  - Services/ディレクトリ削除

## 現在の状態（Phase 10完了）

✅ **完全に新構成に移行完了 + Shared/Features導入**

**新構成（現在）**:
- `Features/[機能名]/`: アプリ機能（Models/Logic/Effects/Views）
- `Shared/Features/[機能名]/`: 共有機能（Models/Services/Logic/Views）
- `Shared/Infrastructure/`: 共有インフラ（Persistence/、Location/、Security/、Map/）
- `Shared/UIComponents/`: 汎用UIコンポーネント（機能に属さない）
- Store使用（ViewModelなし）
- @Observableマクロ（ObservableObjectなし）
- 直接依存（Protocolなし）
- Logic/Effects分離（Functional Core, Imperative Shell）
- Feature-based構造の一貫性（Features/とShared/Features/で同じ構造）

**削除された旧構成**:
- ❌ `Domain/`（Phase 6-7で削除）
- ❌ `Infrastructure/`（Phase 8で削除）
- ❌ `Presentation/`（Phase 9で削除）
- ❌ `Shared/Models/`（Phase 10でShared/Features/*/Models/に分散）
- ❌ `Shared/Services/`（Phase 10でShared/Infrastructure/に改名）
- ❌ `Shared/Map/`（Phase 10でShared/Features/Map/に再構成）
- ❌ `Features/Create/Services/`（Phase 5でEffects/に統合）
- ❌ Protocolベース抽象化（Phase 7で削除）
- ❌ ObservableObject（Phase 1-3で@Observableに置換）

## 注意点

### コンパイラエラー対策
- SwiftUIのbodyプロパティが複雑すぎる場合は、ヘルパープロパティやViewBuilderメソッドに分割する
- @Observableオブジェクトには`$`バインディングが使えるのは`@Bindable`または`@State`のプロパティのみ
- 計算プロパティ（`var vm: Store { store }`）には`$`バインディングは使えない

### ファイル配置の判断基準
- **アプリ機能**: `Features/[機能名]/`（Models、Logic、Effects、Viewsに分類）
- **共有機能**: `Shared/Features/[機能名]/`（Models、Services、Logic、Viewsに分類）
- **共有インフラ**: `Shared/Infrastructure/`（Persistence、Location、Security、Map等）
- **汎用UI**: `Shared/UIComponents/`（機能に属さない共通コンポーネント）
- **サポート**: `Support/`（汎用ユーティリティ）
