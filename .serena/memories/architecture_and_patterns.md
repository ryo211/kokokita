# アーキテクチャと設計パターン

## Feature-based MV アーキテクチャ

### 基本原則
- **コロケーション最優先**: 機能に関連する全てのファイルを1つのフォルダにまとめる
- **MVパターン**: ViewModelを排除し、@Observable Storeで状態管理
- **純粋な関数とEffectsを分離**: 副作用の有無で明確に区別（TCAパターン）
- **直接依存**: プロトコルを使わず具体実装に直接依存
- **iOS 17+をターゲット**: @Observableマクロを活用

### フォルダ構成

```
kokokita/
├── Features/                      # 機能単位（Feature-based）
│   ├── Home/                      # ホーム画面機能
│   │   ├── Models/                # @Observable Store
│   │   │   └── HomeStore.swift
│   │   ├── Logic/                 # 純粋な関数（ビジネスロジック）
│   │   │   ├── VisitFilter.swift
│   │   │   ├── VisitSorter.swift
│   │   │   ├── VisitGrouper.swift
│   │   │   └── DateHelper.swift
│   │   └── Views/                 # UIコンポーネント
│   │       ├── HomeView.swift
│   │       └── SearchFilterSheet.swift
│   │
│   ├── Create/                    # 訪問作成機能
│   │   ├── Models/
│   │   │   └── CreateEditStore.swift
│   │   ├── Logic/                 # 純粋な関数
│   │   │   ├── StringValidator.swift
│   │   │   └── LocationValidator.swift
│   │   ├── Effects/               # 副作用（DB、API、ファイルI/O）
│   │   │   ├── POIEffects.swift
│   │   │   └── PhotoEffects.swift
│   │   └── Views/
│   │       ├── CreateScreen.swift
│   │       ├── PhotoAttachmentSection.swift
│   │       └── POIListView.swift
│   │
│   ├── Detail/                    # 訪問詳細機能
│   │   └── Views/
│   │       └── VisitDetailView.swift
│   │
│   └── Menu/                      # メニュー機能
│       └── Views/
│           └── MenuView.swift
│
├── Shared/                        # 複数機能で使用する共通コード
│   ├── Models/                    # 共通のドメインモデル
│   │   ├── Visit.swift            # 不変な訪問データ + Integrity
│   │   ├── VisitDetails.swift     # 可変なメタデータ + FacilityInfo
│   │   ├── VisitAggregate.swift   # Visit + VisitDetails の集約ルート
│   │   ├── Taxonomy.swift         # LabelTag, GroupTag, MemberTag
│   │   └── PlacePOI.swift         # POI検索結果
│   │
│   ├── Services/                  # 共通Service（インフラ層を統合）
│   │   ├── Persistence/           # データ永続化
│   │   │   ├── CoreDataStack.swift
│   │   │   ├── CoreDataVisitRepository.swift
│   │   │   └── CoreDataTaxonomyRepository.swift
│   │   ├── Location/              # 位置情報関連
│   │   │   ├── DefaultLocationService.swift
│   │   │   └── MapKitPlaceLookupService.swift
│   │   ├── Security/              # セキュリティ関連
│   │   │   └── DefaultIntegrityService.swift
│   │   └── LocationGeocodingService.swift
│   │
│   ├── UIComponents/              # 共通UIコンポーネント
│   │   ├── PhotoThumb.swift
│   │   └── PhotoPager.swift
│   │
│   └── Media/                     # メディア管理
│       └── ImageStore.swift
│
├── App/                           # アプリケーション設定
│   ├── KokokitaApp.swift
│   ├── AppDelegate.swift
│   ├── Config/
│   │   └── AppConfig.swift
│   └── DI/
│       └── DependencyContainer.swift
│
└── Resources/                     # リソース
    └── Localization/
```

### 各層の責務

#### Model（モデル）
- **配置**: `Shared/Models/` 
- **責務**: データ構造の定義
- **特徴**: 不変（immutable）を推奨、structを優先
- **例**: Visit（改ざん防止署名付き不変データ）、VisitDetails（可変メタデータ）、VisitAggregate（集約ルート）、Taxonomy（タグ）

#### View（ビュー）
- **配置**: `Features/[機能名]/Views/`
- **責務**: UI表示とユーザーイベントの受付
- **特徴**: ビジネスロジックを含まない、Storeのメソッド呼び出しのみ
- **使用方法**: `@State private var store = [機能名]Store()`

#### Store（状態管理）
- **配置**: `Features/[機能名]/Models/[機能名]Store.swift`
- **責務**: 状態管理とLogic/Effectsとの結合
- **特徴**: 
  - @Observableマクロを使用（ObservableObjectは使わない）
  - 通常のプロパティ（@Publishedは不要）
  - 自身は副作用を持たない（Effectsに委譲）
  - Logicの純粋関数を呼び出してビジネスロジック実行
- **命名**: `[機能名]Store.swift`（ViewModelは使わない）
- **依存**: デフォルト引数でAppContainer.sharedから注入

#### Logic（純粋な関数）
- **配置**: `Features/[機能名]/Logic/`
- **責務**: 純粋なビジネスロジック（計算、変換、フォーマット、バリデーション、フィルタリング、ソート）
- **特徴**: 
  - 副作用なし、同じ入力で常に同じ出力
  - structで実装
  - テスト容易
  - Functional Core（関数型コア）を構成
- **例**: 
  - Home機能: VisitFilter、VisitSorter、VisitGrouper、DateHelper
  - Create機能: StringValidator、LocationValidator

#### Effects（副作用のある処理）
- **配置**: `Features/[機能名]/Effects/`
- **責務**: 機能固有の副作用（POI検索、写真管理など）
- **特徴**: 
  - @Observableマクロを使用（状態を持つ場合）
  - Imperative Shell（命令型シェル）を構成
  - UIロジックに密接に関連
- **例**: POIEffects（POI検索とリトライ）、PhotoEffects（写真追加/削除/トランザクション）

#### Services（共通インフラ層）
- **配置**: `Shared/Services/`
- **責務**: 複数機能で共有される副作用（DB、位置情報、セキュリティ）
- **サブディレクトリ**:
  - `Persistence/`: Core Data関連（Stack、Repository）
  - `Location/`: 位置情報とPOI検索
  - `Security/`: 暗号署名と検証
- **特徴**: ステートレスまたは最小限の状態、UIに依存しない
- **例**: CoreDataVisitRepository、DefaultLocationService、DefaultIntegrityService

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
final class HomeStore {
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
                    Effects → Services → Repository
                       ↓
     ← UI Update ←─────┘
     (@Observable自動通知)
```

## 重要な設計パターン

### Functional Core, Imperative Shell
- **Functional Core**: Logic/で純粋関数として実装
- **Imperative Shell**: Effects/とServices/で副作用を実装
- **参考**: The Composable Architecture (TCA) パターン

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
- シミュレート位置情報の場合は訪問記録作成を拒否（CreateEditStore）

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
- Store: `[機能名]Store.swift`（例: HomeStore.swift）
- View: `[機能名]View.swift`（例: HomeView.swift）
- Logic: `[処理名].swift`（例: VisitFilter.swift）
- Effects: `[対象]Effects.swift`（例: POIEffects.swift、PhotoEffects.swift）
- Services: `[機能名]Service.swift`（例: DefaultLocationService.swift）

## アーキテクチャ進化の歴史

### Phase 1-3（前セッションで完了）
- MVVM → MV移行
- @Observable導入
- Feature-based構成へ

### Phase 4: Logic層の分離（完了）
- HomeStoreから純粋関数を抽出:
  - VisitFilter（フィルタリング）
  - VisitSorter（ソート）
  - VisitGrouper（日付グルーピング）
  - DateHelper（日付計算）
- CreateEditStoreから純粋関数を抽出:
  - StringValidator（文字列検証）
  - LocationValidator（位置情報検証）

### Phase 5: Services → Effects リネーム（完了）
- 機能固有のServiceをEffectsに改名:
  - POICoordinatorService → POIEffects
  - PhotoEditService → PhotoEffects
- TCAパターンとの整合性向上

### Phase 6: Domain層の削除とモデル分割（完了）
- Domain/Models.swift を5つのファイルに分割:
  - Visit.swift（不変な訪問データ + LocationSourceFlags）
  - VisitDetails.swift（可変メタデータ + FacilityInfo）
  - VisitAggregate.swift（集約ルート）
  - Taxonomy.swift（タグ類）
  - PlacePOI.swift（POI検索結果）
- Shared/Models/に配置

### Phase 7: Protocol削除と直接依存（完了）
- すべてのProtocolベースDIを削除:
  - VisitRepository → CoreDataVisitRepository
  - TaxonomyRepository → CoreDataTaxonomyRepository
  - LocationService → DefaultLocationService
  - PlaceLookupService → MapKitPlaceLookupService
  - IntegrityService → DefaultIntegrityService
- Domain/Protocols.swift 削除
- Domain/ディレクトリ削除
- デフォルト引数でDI実現

### Phase 8: Infrastructure統合（完了）
- Infrastructure/をShared/Services/に統合:
  - Infrastructure/Persistence/ → Shared/Services/Persistence/
  - Infrastructure/Location/ → Shared/Services/Location/
  - Infrastructure/Security/ → Shared/Services/Security/
- Infrastructure/ディレクトリ削除
- 3層アーキテクチャから実用的な2層構成へ

## 現在の状態

✅ **完全に新構成に移行完了**

**新構成**:
- `Features/[機能名]/`: 機能ごとにコロケーション（Models/Logic/Effects/Views）
- `Shared/Models/`: 分割された明確なドメインモデル
- `Shared/Services/`: インフラ層を統合した共通サービス
- Store使用（ViewModelなし）
- @Observableマクロ（ObservableObjectなし）
- 直接依存（Protocolなし）
- Logic/Effects分離（Functional Core, Imperative Shell）

**削除された旧構成**:
- ❌ Domain/（削除済み）
- ❌ Infrastructure/（削除済み）
- ❌ Protocolベース抽象化（削除済み）
- ❌ ObservableObject（@Observableに置換済み）
