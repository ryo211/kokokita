# アーキテクチャと設計パターン

## Screen-based MV アーキテクチャ

### 基本原則
- **Screen-based構成**: 画面単位でFeatureを分割
- **MVパターン**: ViewModelを排除し、@Observable Storeで状態管理
- **純粋な関数とEffectsを分離**: 副作用の有無で明確に区別（TCAパターン）
- **直接依存**: プロトコルを使わず具体実装に直接依存
- **iOS 17+をターゲット**: @Observableマクロを活用
- **Models vs Stores**: データ構造はModels/、状態管理はStores/に明確に分離

### フォルダ構成

```
kokokita/
├── Features/                      # 画面単位（Screen-based）
│   ├── VisitListScreen/           # 訪問記録一覧画面
│   │   ├── Stores/                # @Observable Store（状態管理）
│   │   │   └── VisitListStore.swift
│   │   ├── Logic/                 # 純粋な関数（ビジネスロジック）
│   │   │   ├── VisitFilter.swift
│   │   │   ├── VisitSorter.swift
│   │   │   ├── VisitGrouper.swift
│   │   │   └── DateHelper.swift
│   │   └── Views/                 # UIコンポーネント
│   │       ├── VisitListScreen.swift
│   │       ├── VisitMapView.swift
│   │       └── Filter/
│   │           └── SearchFilterSheet.swift
│   │
│   ├── VisitFormScreen/           # 訪問作成画面
│   │   ├── Stores/
│   │   │   └── VisitFormStore.swift
│   │   ├── Logic/                 # 純粋な関数
│   │   │   ├── StringValidator.swift
│   │   │   └── LocationValidator.swift
│   │   ├── Effects/               # 副作用（DB、API、ファイルI/O）
│   │   │   ├── POIEffects.swift
│   │   │   └── PhotoEffects.swift
│   │   └── Views/
│   │       ├── VisitFormScreen.swift
│   │       └── PhotoAttachmentSection.swift
│   │
│   ├── VisitDetailScreen/         # 訪問詳細画面
│   │   ├── Stores/                # （現在は空）
│   │   └── Views/
│   │       └── VisitDetailScreen.swift
│   │
│   ├── LabelManagementScreen/     # ラベル管理画面
│   │   ├── Stores/
│   │   │   └── LabelListStore.swift
│   │   ├── Logic/
│   │   │   └── LabelValidator.swift
│   │   └── Views/
│   │       ├── LabelListScreen.swift
│   │       └── LabelDetailView.swift
│   │
│   ├── GroupManagementScreen/     # グループ管理画面
│   │   ├── Stores/
│   │   │   └── GroupListStore.swift
│   │   ├── Logic/
│   │   │   └── GroupValidator.swift
│   │   └── Views/
│   │       ├── GroupListScreen.swift
│   │       └── GroupDetailView.swift
│   │
│   ├── MemberManagementScreen/    # メンバー管理画面
│   │   ├── Stores/
│   │   │   └── MemberListStore.swift
│   │   ├── Logic/
│   │   │   └── MemberValidator.swift
│   │   └── Views/
│   │       ├── MemberListScreen.swift
│   │       └── MemberDetailView.swift
│   │
│   └── SettingsScreen/            # 設定画面
│       └── Views/
│           ├── SettingsHomeScreen.swift
│           └── ResetAllScreen.swift
│
├── Shared/                        # 複数機能で使用する共通コード
│   ├── Features/                  # 共有機能（Feature-based）
│   │   ├── Visit/
│   │   │   ├── Models/            # ドメインモデル（データ構造）
│   │   │   │   ├── Visit.swift            # 不変な訪問データ + Integrity
│   │   │   │   ├── VisitDetails.swift     # 可変なメタデータ + FacilityInfo
│   │   │   │   ├── VisitAggregate.swift   # 集約ルート
│   │   │   │   └── PlacePOI.swift         # POI検索結果
│   │   │   ├── Services/
│   │   │   │   └── CoreDataVisitRepository.swift
│   │   │   └── Views/
│   │   │       └── VisitEditScreen.swift
│   │   │
│   │   ├── Taxonomy/
│   │   │   ├── Models/
│   │   │   │   └── Taxonomy.swift         # LabelTag, GroupTag, MemberTag
│   │   │   ├── Services/
│   │   │   │   └── CoreDataTaxonomyRepository.swift
│   │   │   └── Views/
│   │   │       └── Pickers/
│   │   │
│   │   └── Map/
│   │       ├── Views/
│   │       │   └── MapPreview.swift
│   │       └── Logic/
│   │           └── MapURLBuilder.swift
│   │
│   ├── Infrastructure/            # 共通インフラ（技術層）
│   │   ├── Persistence/           # データ永続化
│   │   │   └── CoreDataStack.swift
│   │   ├── Location/              # 位置情報関連
│   │   │   ├── DefaultLocationService.swift
│   │   │   └── MapKitPlaceLookupService.swift
│   │   └── Security/              # セキュリティ関連
│   │       └── DefaultIntegrityService.swift
│   │
│   ├── Components/                # 共通UIコンポーネント
│   │   ├── PhotoThumb.swift
│   │   └── PhotoPager.swift
│   │
│   └── Utilities/                 # ユーティリティ
│       ├── DependencyContainer.swift
│       └── Extensions/
│
├── App/                           # アプリケーション設定
│   ├── KokokitaApp.swift
│   ├── AppDelegate.swift
│   ├── RootTabView.swift
│   └── Config/
│       └── AppConfig.swift
│
└── Resources/                     # リソース
    └── Localization/
```

### 各層の責務

#### Model（モデル）- データ構造
- **配置**: `Shared/Features/[機能名]/Models/` 
- **責務**: データ構造の定義
- **特徴**: 不変（immutable）を推奨、structを優先
- **型**: `struct`
- **例**: Visit（改ざん防止署名付き不変データ）、VisitDetails（可変メタデータ）、Taxonomy（タグ）

**重要**: `Stores/`ディレクトリには配置しない

#### Store（状態管理）
- **配置**: `Features/[Screen名]/Stores/[機能名]Store.swift`
- **責務**: 状態管理とLogic/Effectsとの結合（オーケストレーション）
- **型**: `@Observable class`
- **特徴**: 
  - @Observableマクロを使用（ObservableObjectは使わない）
  - 通常のプロパティ（@Publishedは不要）
  - 自身は副作用を持たない（Effectsに委譲）
  - Logicの純粋関数を呼び出してビジネスロジック実行
- **命名**: `[機能名]Store.swift`（ViewModelは使わない）
- **依存**: デフォルト引数でAppContainer.sharedから注入

**重要**: `Models/`ディレクトリには配置しない（状態管理はStores/）

#### View（ビュー）
- **配置**: `Features/[Screen名]/Views/`
- **責務**: UI表示とユーザーイベントの受付
- **特徴**: ビジネスロジックを含まない、Storeのメソッド呼び出しのみ
- **使用方法**: `@State private var store = [機能名]Store()`

#### Logic（純粋な関数）
- **配置**: `Features/[Screen名]/Logic/`
- **責務**: 純粋なビジネスロジック（計算、変換、フォーマット、バリデーション、フィルタリング、ソート）
- **特徴**: 
  - 副作用なし、同じ入力で常に同じ出力
  - structで実装
  - テスト容易
  - Functional Core（関数型コア）を構成
- **例**: 
  - VisitListScreen: VisitFilter、VisitSorter、VisitGrouper、DateHelper
  - VisitFormScreen: StringValidator、LocationValidator
  - *ManagementScreen: *Validator

#### Effects（副作用のある処理）
- **配置**: `Features/[Screen名]/Effects/`
- **責務**: 機能固有の副作用（POI検索、写真管理など）
- **特徴**: 
  - @Observableマクロを使用（状態を持つ場合）
  - Imperative Shell（命令型シェル）を構成
  - UIロジックに密接に関連
- **例**: POIEffects（POI検索とリトライ）、PhotoEffects（写真追加/削除/トランザクション）

#### Infrastructure（共通インフラ層）
- **配置**: `Shared/Infrastructure/`
- **責務**: 複数機能で共有される副作用（DB、位置情報、セキュリティ）
- **サブディレクトリ**:
  - `Persistence/`: Core Data関連（Stack、Repository）
  - `Location/`: 位置情報とPOI検索
  - `Security/`: 暗号署名と検証
- **特徴**: ステートレスまたは最小限の状態、UIに依存しない
- **例**: CoreDataStack、DefaultLocationService、DefaultIntegrityService

### Models/ vs Stores/ の使い分け

| ディレクトリ | 用途 | 型 | 例 | 配置場所 |
|------------|------|-----|-----|----------|
| **Models/** | データ構造 | `struct` | Visit, VisitDetails, LabelTag | `Shared/Features/*/Models/` |
| **Stores/** | 状態管理 | `@Observable class` | VisitListStore, GroupListStore | `Features/*/Stores/` |

**理由**:
- 状態管理（Store）とデータ構造（Model）の明確な分離
- 業界標準（TCA、Redux）と一致
- ViewModelという用語を避ける（MVパターン）
- 混同を防ぐ

### 依存性注入（DI）
- **方針**: Protocol-based DIを廃止し、具体実装への直接依存
- **理由**: 
  - 実装が1つしかないProtocolは不要な抽象化
  - 型安全性とコード追跡性の向上
  - ボイラープレートコード削減
- **実装**: 
  - Storeのinitでデフォルト引数を使用
  - テスト時は引数で注入可能
  - `AppContainer.shared`で集中管理

**例**:
```swift
@Observable
final class VisitListStore {
    private let repo: CoreDataVisitRepository
    
    init(repo: CoreDataVisitRepository = AppContainer.shared.repo) {
        self.repo = repo
    }
}
```

### 状態の単一方向フロー
```
User Action → View → Store → Logic (純粋関数)
                       ↓
                    Effects → Infrastructure → Repository
                       ↓
     ← UI Update ←─────┘
     (@Observable自動通知)
```

## 重要な設計パターン

### Functional Core, Imperative Shell
- **Functional Core**: Logic/で純粋関数として実装
- **Imperative Shell**: Effects/とInfrastructure/で副作用を実装
- **参考**: The Composable Architecture (TCA) パターン

### Storeの役割（2025年版）

**Store = State（状態） + Orchestration（オーケストレーション）**

#### ✅ Storeが持つべきもの
- 状態管理: `items`, `loading`, `alert`
- 依存性管理: Repository注入
- オーケストレーション: 純粋関数とEffectsを組み合わせてワークフローを制御

#### ❌ Storeが持つべきでないもの
- 複雑なビジネスロジック → Logic層に分離
- 副作用の実装 → Effects/Infrastructureに委譲

#### 簡易なヘルパーはStoreに残してOK
- 1-2行の簡単なソート・フィルタリング
- 単純な計算処理

過度な分離は避け、実用性を優先する。

### 改ざん検出システム
- P256 ECDSA署名をDER形式(base64)で保存
- ペイロード: id、timestampUTC、lat、lon、acc、isSimulated等
- 公開鍵を訪問記録と共に保存（Visit.Integrity）
- 秘密鍵はKeychainに保存（タグ: `jp.kokokita.signingkey.soft`）
- DefaultIntegrityServiceで署名/検証

### 位置情報偽装検出
- `CLLocation.sourceInformation`から検出
- `isSimulatedBySoftware`、`isProducedByAccessory`をチェック
- LocationValidatorで検証ロジックを分離
- シミュレート位置情報の場合は訪問記録作成を拒否（VisitFormStore）

### POI統合（ココカモ）
- 検索半径: 100m（AppConfig.poiSearchRadius）
- リトライロジック: 3回試行、指数バックオフ（POIEffects）
- MapKitPlaceLookupServiceでMKLocalSearchを使用
- レート制限と一時的なエラーを処理

### 写真管理（トランザクション型）
- ファイルパスはCore Dataに保存（VisitDetails.photoPaths）
- 実際の画像はDocumentsディレクトリに保存
- ImageStoreで管理（保存/削除）
- PhotoEffectsでトランザクション型編集:
  - `photoPathsEditing`: 編集中のパス
  - `pendingAdds`: セッション中に追加された画像（キャンセル時に削除）
  - `pendingDeletes`: 削除予約された既存画像（保存時に削除確定）
  - `commitEdits()`: 編集確定
  - `discardEditingIfNeeded()`: 変更破棄

## 命名規約

### Swift命名規約
- クラス・構造体・列挙型: UpperCamelCase
- 関数・変数: lowerCamelCase
- Bool型: is、has、should、can で始める

### MVパターンでの命名
- Store: `[機能名]Store.swift`（例: VisitListStore.swift、GroupListStore.swift）
- View: `[画面名]Screen.swift` または `[コンポーネント名]View.swift`
- Logic: `[処理名].swift`（例: VisitFilter.swift、GroupValidator.swift）
- Effects: `[対象]Effects.swift`（例: POIEffects.swift、PhotoEffects.swift）
- Services: `[機能名]Service.swift`（例: DefaultLocationService.swift）

### ディレクトリ命名
- **Stores/**: 状態管理クラス（@Observable）
- **Models/**: データ構造（struct）
- **Views/**: UIコンポーネント
- **Logic/**: 純粋関数
- **Effects/**: 副作用

## アーキテクチャ進化の歴史

### Phase 1-10（過去）
- MVVM → MV移行
- @Observable導入
- Logic/Effects分離
- Protocol削除と直接依存
- Infrastructure統合

### Phase 11: Screen-based リネーム（完了）
- Home → VisitListScreen
- Create → VisitFormScreen
- Detail → VisitDetailScreen
- Menu → 各種ManagementScreen + SettingsScreen
- 画面単位でFeatureを分割

### Phase 12: Models → Stores リネーム（完了）
- **動機**: 状態管理（Store）とデータ構造（Model）の混同を避ける
- **変更内容**: 全機能の`Models/`ディレクトリを`Stores/`にリネーム
- **理由**:
  - Storeは@Observableクラスで状態管理を行う
  - Modelはstructでデータ構造を定義する
  - 業界標準（TCA、Redux）で"Store"が状態管理に使われる
  - MVパターンの命名規約と一致
- **影響範囲**: Features/配下の全7機能
  - GroupManagementScreen/Stores/
  - LabelManagementScreen/Stores/
  - MemberManagementScreen/Stores/
  - VisitListScreen/Stores/
  - VisitFormScreen/Stores/
  - VisitDetailScreen/Stores/（空）
  - SettingsScreen/（Storesなし）

## 現在の状態（Phase 12完了）

✅ **Screen-based + Stores命名に移行完了**

**新構成（現在）**:
- `Features/[Screen名]/Stores/`: 状態管理（Models/から変更）
- `Features/[Screen名]/Logic/`: 純粋関数
- `Features/[Screen名]/Effects/`: 副作用
- `Features/[Screen名]/Views/`: UI
- `Shared/Features/[機能名]/Models/`: ドメインモデル（データ構造）
- `Shared/Infrastructure/`: 共通インフラ
- Store使用（ViewModelなし）
- @Observableマクロ（ObservableObjectなし）
- 直接依存（Protocolなし）
- Logic/Effects分離（Functional Core, Imperative Shell）

**削除された旧構成**:
- ❌ `Features/*/Models/`（Stores/にリネーム）
- ❌ `Domain/`、`Infrastructure/`（Shared/に統合）
- ❌ `Presentation/`（App/とShared/に分散）
- ❌ Protocolベース抽象化
- ❌ ObservableObject
