# アーキテクチャと設計パターン

## Feature-based MV アーキテクチャ

### 基本原則
- **コロケーション最優先**: 機能に関連する全てのファイルを1つのフォルダにまとめる
- **MVパターン**: ViewModelを排除し、@Observable Storeで状態管理
- **純粋な関数とServiceを分離**: 副作用の有無で明確に区別
- **iOS 17+をターゲット**: @Observableマクロを活用

### フォルダ構成

```
kokokita/
├── Features/                      # 機能単位（Feature-based）
│   ├── Home/                      # ホーム画面機能
│   │   ├── Models/                # @Observable Store
│   │   ├── Logic/                 # 純粋な関数
│   │   ├── Services/              # 副作用（DB操作等）
│   │   └── Views/                 # UIコンポーネント
│   ├── Create/                    # 訪問作成機能
│   ├── Detail/                    # 訪問詳細機能
│   └── Menu/                      # メニュー機能
│
├── Shared/                        # 複数機能で使用する共通コード
│   ├── Models/                    # 共通のドメインモデル
│   ├── Logic/                     # 共通の純粋な関数
│   ├── Services/                  # 共通Service
│   └── UIComponents/              # 共通UIコンポーネント
│
├── App/                           # アプリケーション設定
│   ├── KokokitaApp.swift
│   ├── AppDelegate.swift
│   ├── Config/
│   └── DI/
│
└── Resources/                     # リソース
    └── Localization/
```

### 各層の責務

#### Model（モデル）
- **配置**: `Shared/Models/` または `Features/[機能名]/Models/[データ名].swift`
- **責務**: データ構造の定義とドメインロジック
- **特徴**: 不変（immutable）を推奨、structを優先
- **例**: Visit、Location、Taxonomy

#### View（ビュー）
- **配置**: `Features/[機能名]/Views/`
- **責務**: UI表示とユーザーイベントの受付
- **特徴**: ビジネスロジックを含まない、Storeのメソッド呼び出しのみ
- **使用方法**: `@State private var store = [機能名]Store()`

#### Store（状態管理）
- **配置**: `Features/[機能名]/Models/[機能名]Store.swift`
- **責務**: 状態管理とServiceとの結合
- **特徴**: 
  - @Observableマクロを使用（ObservableObjectは使わない）
  - 通常のプロパティ（@Publishedは不要）
  - 自身は副作用を持たない（Serviceに委譲）
- **命名**: `[機能名]Store.swift`（ViewModelは使わない）

#### Service（副作用のある処理）
- **配置**: `Features/[機能名]/Services/` または `Shared/Services/`
- **責務**: 副作用のある処理（DB、API、位置情報、ファイルI/O）
- **特徴**: ステートレス（状態を持たない）、UIに依存しない
- **例**: VisitService、LocationService、POIService

#### Logic（純粋な関数）
- **配置**: `Features/[機能名]/Logic/` または `Shared/Logic/`
- **責務**: 純粋な関数（計算、変換、フォーマット、バリデーション）
- **特徴**: 副作用なし、同じ入力で常に同じ出力、テスト容易
- **例**: VisitFilter、DistanceCalculator、CoordinateValidator

#### Repository（データアクセス層）
- **配置**: `Shared/Services/Persistence/`
- **責務**: データの永続化と取得（Core Data）
- **特徴**: データソースの詳細を隠蔽、CRUD操作を提供
- **例**: CoreDataVisitRepository、CoreDataTaxonomyRepository

### 依存性注入（DI）
- Storeは依存するServiceをコンストラクタで受け取る
- デフォルト引数で`.shared`インスタンスを提供
- DependencyContainer（AppContainer.shared）で集中管理

### 状態の単一方向フロー
```
User Action → View → Store → Service → Repository
     ↑                 ↓
     └─── UI Update ←──┘
          (@Observable自動通知)
```

## 重要な設計パターン

### 改ざん検出システム
- P256 ECDSA署名をDER形式(base64)で保存
- ペイロード: id、timestampUTC、lat、lon、acc、isSimulated等
- 公開鍵を訪問記録と共に保存
- 秘密鍵はKeychainに保存（タグ: `jp.kokokita.signingkey.soft`）

### 位置情報偽装検出
- `CLLocation.sourceInformation`から検出
- `isSimulatedBySoftware`、`isProducedByAccessory`をチェック
- シミュレート位置情報の場合は訪問記録作成を拒否

### POI統合（ココカモ）
- 検索半径: 100m（AppConfig.poiSearchRadius）
- リトライロジック: 3回試行、指数バックオフ
- MapKitのMKLocalSearchを使用
- レート制限と一時的なエラーを処理

### 写真管理
- ファイルパスはCore Dataに保存
- 実際の画像はDocumentsディレクトリに保存
- ImageStoreで管理（保存/削除）
- トランザクション型編集（discardEditingIfNeeded）

## 命名規約

### Swift命名規約
- クラス・構造体・列挙型: UpperCamelCase
- 関数・変数: lowerCamelCase
- Bool型: is、has、should、can で始める

### MVパターンでの命名
- Store: `[機能名]Store.swift`（例: HomeStore.swift）
- View: `[機能名]View.swift`（例: HomeView.swift）
- Service: `[機能名]Service.swift`（例: VisitService.swift）
- Logic: `[処理名].swift`（例: VisitFilter.swift）

## 移行状況

### 現在の状態
プロジェクトは旧MVVM構成から新Feature-based MV構成への移行中:

**旧構成（現在）**:
- `kokokita/Presentation/ViewModels/`: ViewModelが存在
- `kokokita/Domain/`: ドメインモデル
- `kokokita/Infrastructure/`: Repository実装
- `kokokita/Services/`: 各種サービス

**新構成（目標）**:
- `Features/[機能名]/`: 機能ごとにコロケーション
- `Shared/`: 共通コード
- ViewModelではなくStore使用
- @ObservableマクロでObservableObject置換

### 移行方針
- 新規機能は新構成で実装
- 既存機能は必要に応じて移行
- 一度に全部移行しない（段階的移行）