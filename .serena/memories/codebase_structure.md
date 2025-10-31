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

## メインソースコード構造（最新の構成）

```
kokokita/
├── App/                         # アプリケーション設定
│   ├── KokokitaApp.swift        # エントリポイント
│   └── AppDelegate.swift        # アプリデリゲート
│
├── Config/                      # 設定
│   ├── UIConstants.swift        # UI定数
│   └── AppConfig.swift          # アプリ設定
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
├── Features/                    # 機能単位（Feature-based MV）
│   ├── Home/
│   │   ├── Models/
│   │   │   └── HomeStore.swift  # @Observable（状態管理）
│   │   └── Views/
│   │       ├── HomeView.swift
│   │       ├── HomeMapView.swift
│   │       ├── VisitRow.swift
│   │       └── Filter/
│   │           ├── HomeFilterHeader.swift
│   │           ├── SearchFilterSheet.swift
│   │           └── FlowRow.swift
│   ├── Create/
│   │   ├── Models/
│   │   │   └── CreateEditStore.swift
│   │   └── Views/
│   │       ├── CreateView.swift
│   │       ├── PromptViews.swift
│   │       ├── PhotoAttachmentSection.swift
│   │       └── LocationLoadingView.swift
│   ├── Detail/
│   │   └── Views/
│   │       ├── VisitDetailScreen.swift
│   │       ├── VisitDetailContent.swift
│   │       ├── EditView.swift
│   │       └── PhotoReadOnlyGrid.swift
│   └── Menu/
│       └── Views/
│           ├── MenuHomeView.swift
│           ├── LabelListView.swift
│           ├── GroupListView.swift
│           ├── MemberListView.swift
│           └── ResetAllView.swift
│
├── Shared/                      # 共通コード（Share/から統合）
│   ├── AppMedia.swift
│   ├── Media/
│   │   ├── ImageStore.swift     # 画像ファイル管理
│   │   ├── PhotoPager.swift
│   │   └── PhotoThumb.swift
│   ├── Services/
│   │   └── RateLimiter.swift    # レート制限
│   └── Components/
│       └── ActivityView.swift   # 共有UI
│
├── Support/                     # サポートユーティリティ
│   ├── DependencyContainer.swift  # DIコンテナ
│   ├── NavigationRouter.swift     # ナビゲーション
│   ├── Logger.swift               # ログユーティリティ
│   ├── Extensions/                # 拡張機能
│   │   ├── DateExtensions.swift
│   │   ├── StringExtensions.swift
│   │   ├── CollectionExtensions.swift
│   │   └── NotificationExtensions.swift
│   ├── Localization/
│   │   └── LocalizedString.swift  # ローカライズ定義
│   ├── ShareImageRenderer.swift
│   ├── KeyboardAwareTextView.swift
│   ├── KeyboardDismissHelpers.swift
│   └── MKPointOfInterestCategory+JP.swift
│
├── Infrastructure/              # インフラ層（Repository実装）
│   ├── CoreDataStack.swift      # Core Data管理
│   ├── CoreDataVisitRepository.swift
│   └── DefaultIntegrityService.swift  # 改ざん検出
│
├── Domain/                      # ドメイン層
│   ├── Models.swift             # ドメインモデル
│   └── Protocols.swift          # プロトコル定義
│
├── Presentation/                # プレゼンテーション層
│   ├── Map/
│   │   ├── MapPreview.swift
│   │   └── MapSnapshotService.swift
│   └── Views/
│       └── Common/              # 共通コンポーネント
│           ├── RootTabView.swift      # タブナビゲーション
│           ├── AppUIState.swift       # グローバルUI状態
│           ├── VisitEditScreen.swift
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
├── Services/                    # サービス層
│   ├── DefaultLocationService.swift    # 位置情報取得
│   ├── LocationGeocodingService.swift  # ジオコーディング
│   ├── POICoordinatorService.swift     # POI検索
│   ├── MapKitPlaceLookupService.swift  # MapKit POI
│   └── PhotoEditService.swift          # 写真管理
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

### ドメインモデル
- `Domain/Models.swift`: Visit、VisitDetails、Taxonomy等
- `Domain/Protocols.swift`: リポジトリとサービスのプロトコル

### Core Data
- `Kokokita.xcdatamodeld/`: Core Dataモデル定義
- `Infrastructure/CoreDataStack.swift`: Core Data管理

### 依存性注入
- `Support/DependencyContainer.swift`: DIコンテナ（AppContainer.shared）

### ローカライゼーション
- `Support/Localization/LocalizedString.swift`: L列挙型で定義
- `Resources/ja.lproj/Localizable.strings`: 日本語
- `Resources/en.lproj/Localizable.strings`: 英語

### ナビゲーション
- `Presentation/Views/Common/RootTabView.swift`: タブナビゲーション

## ファイル配置のルール

### 1つの機能でのみ使用する場合
```
Features/[機能名]/
```

### 複数の機能で使用する場合
```
Shared/
```

### UI定数と設定
```
Config/
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

### MVパターン（iOS 17+ @Observable）
- **Store**: @Observableで状態管理（旧ViewModel）
- **View**: SwiftUI View
- **Service**: 副作用のある処理（struct推奨）
- **Logic**: 純粋な関数

### 命名規則
- Store: `[機能名]Store.swift`（例：HomeStore.swift）
- View: `[機能名]View.swift`
- Service: `[機能名]Service.swift`
- Logic: `[処理名].swift`

## 最近の変更（Phase 3完了）

### Features/構造への移行
- Home機能: `HomeViewModel` → `HomeStore`に変更、Features/Home/に移行
- Create機能: `CreateEditViewModel` → `CreateEditStore`に変更、Features/Create/に移行
- Detail機能: Features/Detail/に移行
- Menu機能: Features/Menu/に移行
- Presentation/ViewModels/ディレクトリは削除（空になったため）

### Share/とShared/の統合
- `Share/`を`Shared/`に統合
- `Features/Detail/Views/Share/ActivityView.swift`を`Shared/Components/`に移動
- メディア関連ファイル（ImageStore、PhotoPager、PhotoThumb）を`Shared/Media/`に配置

## 注意点

### コンパイラエラー対策
- SwiftUIのbodyプロパティが複雑すぎる場合は、ヘルパープロパティやViewBuilderメソッドに分割する
- @Observableオブジェクトには`$`バインディングが使えるのは`@Bindable`または`@State`のプロパティのみ
- 計算プロパティ（`var vm: Store { store }`）には`$`バインディングは使えない

### ファイル配置
- 機能固有のファイル → `Features/[機能名]/`
- 複数機能で共有 → `Shared/`
- 汎用ユーティリティ → `Support/`