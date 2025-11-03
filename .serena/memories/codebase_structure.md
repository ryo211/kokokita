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

## メインソースコード構造（Screen-based構成）

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
├── Features/                    # アプリ機能（Screen-based MV + Logic/Effects分離）
│   ├── VisitListScreen/         # 訪問記録一覧画面（旧 Home/）
│   │   ├── Stores/              # 状態管理
│   │   │   └── VisitListStore.swift      # @Observable（状態管理）
│   │   ├── Logic/                        # 純粋な関数（Functional Core）
│   │   │   ├── VisitFilter.swift         # フィルタリングロジック
│   │   │   ├── VisitSorter.swift         # ソートロジック
│   │   │   ├── VisitGrouper.swift        # 日付グルーピング
│   │   │   └── DateHelper.swift          # 日付計算ユーティリティ
│   │   └── Views/
│   │       ├── VisitListScreen.swift
│   │       ├── VisitMapView.swift
│   │       ├── VisitRow.swift
│   │       └── Filter/
│   │           ├── HomeFilterHeader.swift
│   │           ├── SearchFilterSheet.swift
│   │           └── FlowRow.swift
│   │
│   ├── VisitFormScreen/         # 訪問記録作成画面（旧 Create/）
│   │   ├── Stores/
│   │   │   └── VisitFormStore.swift      # @Observable（状態管理）
│   │   ├── Logic/                        # 純粋な関数（Functional Core）
│   │   │   ├── StringValidator.swift     # 文字列検証
│   │   │   └── LocationValidator.swift   # 位置情報検証
│   │   ├── Effects/                      # 副作用（Imperative Shell）
│   │   │   ├── POIEffects.swift          # POI検索（リトライロジック付き）
│   │   │   └── PhotoEffects.swift        # 写真管理（トランザクション型）
│   │   └── Views/
│   │       ├── VisitFormScreen.swift
│   │       ├── PromptViews.swift
│   │       ├── PhotoAttachmentSection.swift
│   │       └── LocationLoadingView.swift
│   │
│   ├── VisitDetailScreen/       # 訪問記録詳細画面（旧 Detail/）
│   │   ├── Stores/              # （現在は空）
│   │   └── Views/
│   │       ├── VisitDetailScreen.swift
│   │       ├── VisitDetailContent.swift
│   │       ├── EditView.swift
│   │       └── PhotoReadOnlyGrid.swift
│   │
│   ├── LabelManagementScreen/   # ラベル管理画面（旧 Menu/Label）
│   │   ├── Stores/
│   │   │   └── LabelListStore.swift
│   │   ├── Logic/
│   │   │   └── LabelValidator.swift
│   │   └── Views/
│   │       ├── LabelListScreen.swift
│   │       └── LabelDetailView.swift
│   │
│   ├── GroupManagementScreen/   # グループ管理画面（旧 Menu/Group）
│   │   ├── Stores/
│   │   │   └── GroupListStore.swift
│   │   ├── Logic/
│   │   │   └── GroupValidator.swift
│   │   └── Views/
│   │       ├── GroupListScreen.swift
│   │       └── GroupDetailView.swift
│   │
│   ├── MemberManagementScreen/  # メンバー管理画面（旧 Menu/Member）
│   │   ├── Stores/
│   │   │   └── MemberListStore.swift
│   │   ├── Logic/
│   │   │   └── MemberValidator.swift
│   │   └── Views/
│   │       ├── MemberListScreen.swift
│   │       └── MemberDetailView.swift
│   │
│   └── SettingsScreen/          # 設定画面（旧 Menu/）
│       └── Views/
│           ├── SettingsHomeScreen.swift
│           └── ResetAllScreen.swift
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
│   ├── Components/              # 汎用UIコンポーネント
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
│   ├── Config/
│   │   ├── AppMedia.swift
│   │   └── Localization/
│   │       └── LocalizedString.swift
│   │
│   ├── Media/
│   │   ├── PhotoPager.swift
│   │   ├── PhotoThumb.swift
│   │   └── ImageStore.swift
│   │
│   └── Utilities/
│       ├── NavigationRouter.swift
│       ├── Logger.swift
│       ├── ShareImageRenderer.swift
│       ├── DependencyContainer.swift
│       ├── MKPointOfInterestCategory+JP.swift
│       └── Extensions/
│           ├── DateExtensions.swift
│           ├── StringExtensions.swift
│           ├── CollectionExtensions.swift
│           └── NotificationExtensions.swift
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
- `Shared/Utilities/DependencyContainer.swift`: DIコンテナ（AppContainer.shared）
- Protocolベース抽象化は廃止、具体実装への直接依存

### ローカライゼーション
- `Shared/Config/Localization/LocalizedString.swift`: L列挙型で定義
- `Resources/ja.lproj/Localizable.strings`: 日本語
- `Resources/en.lproj/Localizable.strings`: 英語

### ナビゲーション
- `App/RootTabView.swift`: タブナビゲーション

## ファイル配置のルール

### アプリ機能（Screen-based）
```
Features/[Screen名]/
├── Stores/             # @Observable Store（状態管理）
├── Logic/              # 純粋な関数（Functional Core）
├── Effects/            # 副作用（Imperative Shell）
└── Views/              # UIコンポーネント
```

**重要**: `Models/`ではなく`Stores/`を使用
- **Models**: 純粋なデータ構造（struct、不変オブジェクト）
- **Stores**: 状態管理クラス（@Observable）

### 共有機能（Feature-based）
```
Shared/Features/[機能名]/
├── Models/             # ドメインモデル（データ構造）
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
- Store: `[機能名]Store.swift`（例：VisitListStore.swift、GroupListStore.swift）
- View: `[画面名]Screen.swift` または `[コンポーネント名]View.swift`
- Logic: `[処理名].swift`（例：VisitFilter.swift、MapURLBuilder.swift）
- Effects: `[対象]Effects.swift`（例：POIEffects.swift）
- Services: `[機能名]Service.swift`（例：DefaultLocationService.swift）

### ディレクトリ命名の理由
- **Stores/**（Models/ではない）: 状態管理を明示、データ構造（Model）との混同を避ける
- **Views/**: SwiftUIの標準的な命名
- **Logic/**: 純粋な関数（Functional Core）
- **Effects/**: 副作用（Imperative Shell）

## アーキテクチャ進化の歴史

### Phase 1-10（過去）
- MVVM → MV移行
- @Observable導入
- Logic/Effects分離
- Protocol削除と直接依存
- Shared/Features構造導入

### Phase 11: Screen-based リネーム（完了）
- Home → VisitListScreen
- Create → VisitFormScreen
- Detail → VisitDetailScreen
- Menu → LabelManagementScreen、GroupManagementScreen、MemberManagementScreen、SettingsScreen
- 画面単位でFeatureを分割

### Phase 12: Models → Stores リネーム（完了）
- 全機能の`Models/`ディレクトリを`Stores/`にリネーム
- 状態管理（Store）とデータ構造（Model）の明確な分離
- 業界標準（TCA、Redux）と一致

## 現在の状態（Phase 12完了）

✅ **Screen-based + Stores命名に移行完了**

**新構成（現在）**:
- `Features/[Screen名]/Stores/`: 状態管理（Models/から変更）
- `Features/[Screen名]/Logic/`: 純粋関数
- `Features/[Screen名]/Effects/`: 副作用
- `Features/[Screen名]/Views/`: UI
- `Shared/Features/[機能名]/Models/`: ドメインモデル（データ構造）
- Store使用（ViewModelなし）
- @Observableマクロ
- 直接依存（Protocolなし）

**削除された旧構成**:
- ❌ `Features/*/Models/`（Stores/にリネーム）
- ❌ `Domain/`、`Infrastructure/`、`Presentation/`（過去のPhaseで削除）
- ❌ Protocolベース抽象化
- ❌ ObservableObject

## 注意点

### コンパイラエラー対策
- SwiftUIのbodyプロパティが複雑すぎる場合は、ヘルパープロパティやViewBuilderメソッドに分割する
- @Observableオブジェクトには`$`バインディングが使えるのは`@Bindable`または`@State`のプロパティのみ
- 計算プロパティ（`var vm: Store { store }`）には`$`バインディングは使えない

### ファイル配置の判断基準
- **アプリ画面**: `Features/[Screen名]/`（Stores、Logic、Effects、Viewsに分類）
- **共有機能**: `Shared/Features/[機能名]/`（Models、Services、Logic、Viewsに分類）
- **共有インフラ**: `Shared/Infrastructure/`（Persistence、Location、Security、Map等）
- **汎用UI**: `Shared/Components/`（機能に属さない共通コンポーネント）
