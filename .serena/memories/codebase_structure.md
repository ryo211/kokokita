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

## メインソースコード構造（現在の構成）

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
│   ├── CoreDataTaxonomyRepository.swift
│   └── DefaultIntegrityService.swift  # 改ざん検出
│
├── Domain/                      # ドメイン層
│   ├── Models.swift             # ドメインモデル
│   └── Protocols.swift          # プロトコル定義
│
├── Presentation/                # プレゼンテーション層
│   ├── ViewModels/              # ViewModel（将来的にStoreに移行）
│   │   ├── HomeViewModel.swift
│   │   └── CreateEditViewModel.swift
│   ├── Map/
│   │   ├── MapPreview.swift
│   │   └── MapSnapshotService.swift
│   └── Views/                   # SwiftUI View
│       ├── Home/
│       │   ├── HomeView.swift
│       │   ├── VisitRow.swift
│       │   └── Filter/
│       │       ├── HomeFilterHeader.swift
│       │       ├── SearchFilterSheet.swift
│       │       └── FlowRow.swift
│       ├── Create/
│       │   ├── CreateView.swift
│       │   ├── PromptViews.swift
│       │   └── PhotoAttachmentSection.swift
│       ├── Detail/
│       │   ├── VisitDetailScreen.swift
│       │   ├── VisitDetailContent.swift
│       │   ├── EditView.swift
│       │   ├── PhotoReadOnlyGrid.swift
│       │   └── Share/
│       │       └── ActivityView.swift
│       ├── Menu/
│       │   ├── MenuHomeView.swift
│       │   ├── LabelListView.swift
│       │   ├── GroupListView.swift
│       │   ├── MemberListView.swift
│       │   └── ResetAllView.swift
│       └── Common/
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
├── Share/                       # 共有コンポーネント
│   ├── AppMedia.swift
│   └── Media/
│       ├── ImageStore.swift     # 画像ファイル管理
│       ├── PhotoPager.swift
│       └── PhotoThumb.swift
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
│   └── 003-Observable-マクロ移行評価.md
└── design/                     # 設計書
    ├── README.md
    └── template.md
```

## 目指している構造（Feature-based MV）

将来的には以下の構造に移行予定:

```
kokokita/
├── Features/                    # 機能単位（Feature-based）
│   ├── Home/
│   │   ├── Models/              # HomeStore.swift
│   │   ├── Logic/               # 純粋な関数
│   │   ├── Services/            # 副作用
│   │   └── Views/               # UI
│   │       └── Components/
│   ├── Create/
│   ├── Detail/
│   └── Menu/
│
├── Shared/                      # 共通コード
│   ├── Models/                  # ドメインモデル
│   ├── Logic/                   # 共通Logic
│   ├── Services/                # 共通Service
│   │   ├── Persistence/         # Repository
│   │   └── Security/            # セキュリティ
│   └── UIComponents/            # 共通UI
│
├── App/                         # アプリ設定
│   ├── Config/
│   └── DI/
│
├── Resources/                   # リソース
│   └── Localization/
│
└── Utilities/                   # 汎用ユーティリティ
    ├── Extensions/
    ├── Helpers/
    └── Protocols/
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
（移行後）

現在は機能ごとに`Presentation/Views/[機能名]/`

### 複数の機能で使用する場合
```
Shared/
```
（移行後）

現在は`Support/`、`Domain/`、`Services/`等に分散

### UI定数と設定
```
App/Config/
├── AppConfig.swift      # アプリ全体の設定
└── UIConstants.swift    # UI定数
```

現在は`Config/`

## Xcodeプロジェクト構成

- **Target**: kokokita
- **Scheme**: kokokita
- **Deployment Target**: iOS 17+
- **Swift Version**: 最新

## Core Dataエンティティ

- VisitEntity: 不変な訪問データ
- VisitDetailsEntity: 可変なメタデータ
- VisitPhotoEntity: 写真ファイルパス
- LabelEntity, GroupEntity, MemberEntity: タクソノミー

## 注意点

### 移行中の構造
現在、旧構造（Domain/、Presentation/、Infrastructure/）から新構造（Features/、Shared/）への移行中。新規機能は新構造で実装すること。

### ファイル命名
- Store: `[機能名]Store.swift`（ViewModelは使わない）
- View: `[機能名]View.swift`
- Service: `[機能名]Service.swift`
- Logic: `[処理名].swift`