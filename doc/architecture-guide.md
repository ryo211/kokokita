# アーキテクチャガイド

> **重要**: このドキュメントはプロジェクトの設計方針とアーキテクチャの指針。Claudeはすべてのコード変更時に参照する。

## このドキュメントの使い方

### 用途別ガイド

- **初めて読む場合**: 全体を通読してアーキテクチャの設計思想と原則を理解する
- **実装中の参照**: 各層の責務、命名規約、ベストプラクティスをクイックリファレンスとして使用
- **コードレビュー時**: チェックリストとして品質確認に使用（コーディングスタイル、アーキテクチャ準拠）
- **設計判断時**: 新機能の設計時に原則に沿っているか確認

### 実装時は実装ガイドも参照

このドキュメントは**「なぜこの設計なのか」「何を守るべきか」**を説明します。

**「どうやって実装するか」**の具体的な手順は [実装ガイド](./implementation-guide.md) を参照してください。

### 関連ドキュメント

- **実装の具体的手順** → [実装ガイド](./implementation-guide.md)
- **既存コードの移行** → [MVVM→MV移行ガイド](./migration/mvvm-to-mv-migration-guide.md)
- **設計判断の背景** → [ADR-001: フォルダ構成とアーキテクチャの再設計](./ADR/001-フォルダ構成とアーキテクチャの再設計.md)

---

## アーキテクチャ原則

### Feature-based MV アーキテクチャ

> **参照**: 詳細な設計判断は`doc/ADR/001-フォルダ構成とアーキテクチャの再設計.md`を参照。

プロジェクトは**Feature-based MV**パターンを採用しています（2025年のSwiftベストプラクティスに準拠）：

```
Features/                        # 機能単位でコロケーション
├── [機能名]/
│   ├── Models/                  # @Observable 状態管理
│   ├── Views/                   # SwiftUI View
│   ├── Logic/                   # 純粋な関数（副作用なし）
│   └── Services/                # 副作用（DB、API、I/O）
│
Shared/                          # 共通コード
├── Models/                      # ドメインモデル
├── Logic/                       # 共通の純粋な関数
├── Services/                    # 共通Service
└── UIComponents/                # 共通UIコンポーネント
```

**原則**:
- **コロケーション最優先**: 機能に関連する全てのファイルを1つのフォルダにまとめる
- **MVパターン**: ViewModelを排除し、@Observable Storeで状態管理
- **純粋な関数とServiceを分離**: 副作用の有無で明確に区別
- **iOS 17+をターゲット**: @Observableマクロを活用

**例（良い）**:
```swift
// Features/Home/Models/HomeStore.swift
@Observable
final class HomeStore {
    var visits: [Visit] = []
    var isLoading = false

    private let visitService: VisitService

    init(visitService: VisitService = .shared) {
        self.visitService = visitService
    }

    func load() async {
        isLoading = true
        visits = try await visitService.fetchAll()
        isLoading = false
    }
}

// Features/Home/Views/HomeView.swift
struct HomeView: View {
    @State private var store = HomeStore()

    var body: some View {
        List(store.visits) { visit in
            VisitRow(visit: visit)
        }
        .task { await store.load() }
    }
}
```

**例（悪い - 旧MVVM）**:
```swift
// ❌ ObservableObject と @Published（旧パターン）
class HomeViewModel: ObservableObject {
    @Published var visits: [Visit] = []
    // ...
}

// ❌ ViewModelという名前（MVでは使わない）
@StateObject private var viewModel: HomeViewModel
```

### 単一責任原則（SRP）

各クラス・構造体は**1つの責務**のみを持つ：

- ✅ **View**: UI表示とユーザーイベントの受付のみ
- ✅ **Store**: 状態管理とServiceとの結合のみ（@Observable）
- ✅ **Service**: 副作用のある処理のみ（DB、API、I/O等）（ステートレス）
- ✅ **Logic**: 純粋な関数のみ（計算、変換、フォーマット）（副作用なし）
- ✅ **Model**: データ構造の定義とドメインロジックのみ（struct/class）

### 各層の詳細な責務

#### Model（モデル）
**責務**: データ構造の定義とドメインロジック

**配置**: `Shared/Models/` または `Features/[機能名]/Models/[データ名].swift`

**特徴**:
- アプリケーションのコアとなるデータ構造を定義
- ドメイン固有のビジネスルール（validation等）を含む
- 永続化の詳細には依存しない（Core Dataエンティティとは別）
- 不変（immutable）を推奨（structを優先）

> **実装方法**: 具体的な実装手順は [実装ガイド - Step 3: データモデルの定義](./implementation-guide.md#step-3-データモデルの定義) を参照

**例**:
```swift
// Shared/Models/Visit.swift
struct Visit: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let location: Location
    let accuracy: Double

    // ドメインロジック: 位置情報の品質チェック
    var isHighQuality: Bool {
        accuracy <= 50.0
    }

    // ドメインロジック: シミュレートされた位置情報かどうか
    var isSimulated: Bool {
        location.isSimulatedBySoftware || location.isProducedByAccessory
    }
}

// Shared/Models/Location.swift
struct Location: Codable {
    let latitude: Double
    let longitude: Double
    let isSimulatedBySoftware: Bool
    let isProducedByAccessory: Bool

    // ドメインロジック: 座標の妥当性チェック
    var isValid: Bool {
        (-90...90).contains(latitude) && (-180...180).contains(longitude)
    }
}
```

**悪い例**:
```swift
// ❌ ModelにUIロジックを含める
struct Visit {
    var displayTitle: String {  // ❌ 表示ロジックはViewで処理
        // ...
    }
}

// ❌ Modelで副作用を持つ処理
struct Visit {
    func save() async throws {  // ❌ 保存処理はServiceで処理
        // ...
    }
}
```

#### View（ビュー）
**責務**: UI表示とユーザーイベントの受付

**配置**: `Features/[機能名]/Views/`

**特徴**:
- SwiftUIのViewプロトコルに準拠
- UIの構造とレイアウトを定義
- Storeから状態を受け取り、表示する
- ユーザーアクションをStoreに伝える
- ビジネスロジックやデータアクセスロジックを含まない

> **実装方法**: 具体的な実装手順は [実装ガイド - Step 8: Viewの実装](./implementation-guide.md#step-8-viewの実装) を参照

**例**:
```swift
// Features/Home/Views/HomeView.swift
struct HomeView: View {
    @State private var store = HomeStore()

    var body: some View {
        List(store.visits) { visit in
            VisitRow(visit: visit)
        }
        .navigationTitle("訪問記録")
        .task { await store.load() }
        .refreshable { await store.refresh() }
    }
}
```

#### Store（状態管理）
**責務**: 状態管理とServiceとの結合

**配置**: `Features/[機能名]/Models/[機能名]Store.swift`

**特徴**:
- @Observableマクロを使用
- UI状態を保持（表示データ、ローディング状態、エラー等）
- Serviceを呼び出してデータを取得・更新
- 自身は副作用を持たない（Serviceに委譲）
- ViewとServiceの橋渡し役

> **実装方法**: 具体的な実装手順は [実装ガイド - Step 7: Storeの実装](./implementation-guide.md#step-7-storeの実装observable) を参照

**例**:
```swift
// Features/Home/Models/HomeStore.swift
import Foundation
import Observation

@Observable
final class HomeStore {
    // 状態
    var visits: [Visit] = []
    var isLoading = false
    var errorMessage: String?
    var selectedFilters: Set<String> = []

    // 依存するService
    private let visitService: VisitService

    init(visitService: VisitService = .shared) {
        self.visitService = visitService
    }

    // アクション: Viewから呼ばれる
    func load() async {
        isLoading = true
        errorMessage = nil

        do {
            visits = try await visitService.fetchAll()
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func delete(_ visit: Visit) async {
        do {
            try await visitService.delete(visit)
            visits.removeAll { $0.id == visit.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
```

#### Service（副作用のある処理）
**責務**: 副作用のある処理（DB、API、位置情報、ファイルI/O等）

**配置**: `Features/[機能名]/Services/` または `Shared/Services/`

**特徴**:
- ステートレス（状態を持たない）
- 外部システムとのやり取りを担当
- Repository、API、位置情報サービス等を内部で使用
- エラーハンドリングを行う
- 複数のRepositoryやAPIを組み合わせることもある

> **実装方法**: 具体的な実装手順は [実装ガイド - Step 6: Serviceの実装](./implementation-guide.md#step-6-serviceの実装副作用のある処理) を参照

**例**:
```swift
// Features/Home/Services/VisitService.swift
final class VisitService {
    static let shared = VisitService()

    private let repository: VisitRepository

    init(repository: VisitRepository = CoreDataVisitRepository.shared) {
        self.repository = repository
    }

    // DB操作 = 副作用
    func fetchAll() async throws -> [Visit] {
        try await repository.fetchAll()
    }

    func delete(_ visit: Visit) async throws {
        try await repository.delete(visit)
    }

    // 複数のリポジトリを組み合わせる例
    func save(_ visit: Visit, photos: [UIImage]) async throws {
        // 写真を保存（ファイルI/O = 副作用）
        let photoPaths = try await savePhotos(photos)

        // 訪問記録を保存（DB操作 = 副作用）
        try await repository.save(visit, photoPaths: photoPaths)
    }
}
```

#### Logic（純粋な関数）
**責務**: 純粋な関数（計算、変換、フォーマット、バリデーション）

**配置**: `Features/[機能名]/Logic/` または `Shared/Logic/`

**特徴**:
- 副作用なし（同じ入力 → 常に同じ出力）
- 外部状態に依存しない
- テストが容易
- 計算、フィルタリング、フォーマット、バリデーション等

> **実装方法**: 具体的な実装手順は [実装ガイド - Step 5: Logicの実装](./implementation-guide.md#step-5-logicの実装純粋な関数) を参照

**例**:
```swift
// Features/Home/Logic/VisitFilter.swift
struct VisitFilter {
    // 純粋な関数: 副作用なし
    static func filterByDateRange(
        visits: [Visit],
        from: Date,
        to: Date
    ) -> [Visit] {
        visits.filter { $0.timestamp >= from && $0.timestamp <= to }
    }

    static func filterByLabels(
        visits: [Visit],
        labelIds: Set<UUID>
    ) -> [Visit] {
        guard !labelIds.isEmpty else { return visits }
        return visits.filter { visit in
            !Set(visit.labels.map(\.id)).isDisjoint(with: labelIds)
        }
    }
}

// Shared/Logic/Formatting/DateFormatter.swift
struct DateFormatHelper {
    // 純粋な関数: 日付をフォーマット
    static func formatVisitDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: date)
    }
}

// Shared/Logic/Validation/CoordinateValidator.swift
struct CoordinateValidator {
    // 純粋な関数: 座標の妥当性チェック
    static func isValid(latitude: Double, longitude: Double) -> Bool {
        (-90...90).contains(latitude) && (-180...180).contains(longitude)
    }
}
```

#### Repository（データアクセス層）
**責務**: データの永続化と取得（Core Data、UserDefaults等）

**配置**: `Shared/Services/Persistence/`

**特徴**:
- データソースの詳細を隠蔽
- Core Dataエンティティとドメインモデルの変換を行う
- CRUD操作を提供
- Serviceから呼ばれる

**例**:
```swift
// Shared/Services/Persistence/VisitRepository.swift
protocol VisitRepository {
    func fetchAll() async throws -> [Visit]
    func fetch(byId id: UUID) async throws -> Visit?
    func save(_ visit: Visit) async throws
    func delete(_ visit: Visit) async throws
}

// Shared/Services/Persistence/CoreDataVisitRepository.swift
final class CoreDataVisitRepository: VisitRepository {
    static let shared = CoreDataVisitRepository()

    private let context: NSManagedObjectContext

    init(context: NSManagedObjectContext = CoreDataStack.shared.context) {
        self.context = context
    }

    func fetchAll() async throws -> [Visit] {
        // Core Dataから取得してドメインモデルに変換
        let request = VisitEntity.fetchRequest()
        let entities = try context.fetch(request)
        return entities.map { $0.toDomain() }
    }

    // ...
}
```

### 厳密な分離の原則

**守るべきルール**:
1. **Viewにビジネスロジックやデータアクセスロジックを書かない**
2. **StoreにUIコンポーネントや直接のデータアクセスを持ち込まない**
3. **Serviceに表示ロジックや状態を持ち込まない**
4. **Logicに副作用を持ち込まない**
5. **Modelに副作用や表示ロジックを持ち込まない**

### 依存性注入（DI）

Storeは依存するServiceを**コンストラクタで受け取る**:

```swift
@Observable
final class CreateStore {
    private let locationService: LocationService
    private let visitService: VisitService
    private let integrityService: IntegrityService

    init(
        locationService: LocationService = .shared,
        visitService: VisitService = .shared,
        integrityService: IntegrityService = .shared
    ) {
        self.locationService = locationService
        self.visitService = visitService
        self.integrityService = integrityService
    }
}
```

---

## フォルダ構成とコロケーション

> **重要**: フォルダ構成の詳細な設計判断は`doc/ADR/001-フォルダ構成とアーキテクチャの再設計.md`を参照してください。

### 基本原則

1. **機能単位でグループ化**: 関連するファイルは近くに配置（コロケーション最優先）
2. **Feature-based構成**: 各機能が独立したフォルダ
3. **深すぎる階層は避ける**: 3階層程度が理想
4. **純粋な関数とServiceを分離**: 副作用の有無で配置場所を変える
5. **共通コードはShared/**: 複数機能で使用するコードはShared/に配置

### フォルダ構成

```
kokokita/
├── Features/                      # 機能単位（Feature-based）
│   ├── Home/                      # ホーム画面機能
│   │   ├── Models/
│   │   │   └── HomeStore.swift   # @Observable（状態管理）
│   │   ├── Logic/
│   │   │   └── VisitFilter.swift # 純粋な関数
│   │   ├── Services/
│   │   │   └── VisitService.swift # 副作用（DB操作等）
│   │   └── Views/
│   │       ├── HomeView.swift    # エントリポイント
│   │       └── Components/       # この機能専用のコンポーネント
│   │           ├── VisitRow.swift
│   │           └── FilterSheet.swift
│   │
│   ├── Create/                    # 訪問作成機能
│   │   ├── Models/
│   │   │   └── CreateStore.swift
│   │   ├── Logic/
│   │   │   ├── CoordinateValidator.swift
│   │   │   └── AddressFormatter.swift
│   │   ├── Services/
│   │   │   ├── LocationService.swift
│   │   │   ├── POIService.swift
│   │   │   └── PhotoService.swift
│   │   └── Views/
│   │       ├── CreateView.swift
│   │       └── Components/
│   │           ├── LocationSection.swift
│   │           ├── POISection.swift
│   │           └── PhotoSection.swift
│   │
│   ├── Detail/                    # 訪問詳細機能
│   │   ├── Models/
│   │   │   └── DetailStore.swift
│   │   ├── Services/
│   │   │   └── DetailService.swift
│   │   └── Views/
│   │       ├── DetailView.swift
│   │       └── Components/
│   │           └── PhotoGrid.swift
│   │
│   └── Menu/                      # メニュー機能
│       ├── Models/
│       │   └── MenuStore.swift
│       └── Views/
│           └── MenuView.swift
│
├── Shared/                        # 複数機能で使用する共通コード
│   ├── Models/                    # 共通のドメインモデル
│   │   ├── Visit.swift
│   │   ├── Taxonomy.swift
│   │   ├── Location.swift
│   │   └── Member.swift
│   │
│   ├── Logic/                     # 共通の純粋な関数
│   │   ├── Calculations/
│   │   │   └── DistanceCalculator.swift
│   │   ├── Formatting/
│   │   │   └── DateFormatter.swift
│   │   └── Validation/
│   │       └── InputValidator.swift
│   │
│   ├── Services/                  # 共通のService
│   │   ├── Persistence/
│   │   │   ├── CoreDataStack.swift
│   │   │   ├── VisitRepository.swift
│   │   │   └── TaxonomyRepository.swift
│   │   └── Security/
│   │       └── IntegrityService.swift
│   │
│   └── UIComponents/              # 共通UIコンポーネント
│       ├── Buttons/
│       │   └── BigFooterButton.swift
│       ├── Forms/
│       │   ├── LabelPicker.swift
│       │   └── GroupPicker.swift
│       └── Media/
│           ├── PhotoPager.swift
│           └── PhotoThumb.swift
│
├── App/                           # アプリケーション設定
│   ├── KokokitaApp.swift
│   ├── AppDelegate.swift
│   ├── Config/
│   │   ├── AppConfig.swift
│   │   └── UIConstants.swift
│   └── DI/
│       └── DependencyContainer.swift
│
├── Resources/                     # リソース
│   └── Localization/
│       ├── LocalizedString.swift
│       ├── ja.lproj/
│       └── en.lproj/
│
└── Utilities/                     # 汎用ユーティリティ
    ├── Extensions/
    │   ├── Date+Extensions.swift
    │   ├── String+Extensions.swift
    │   └── Collection+Extensions.swift
    ├── Helpers/
    │   ├── Logger.swift
    │   ├── KeyboardHelpers.swift
    │   └── NavigationRouter.swift
    └── Protocols/
        └── MKPointOfInterestCategory+JP.swift
```

### 各層の責務と配置ルール

| 層 | フォルダ | 役割 | 状態 | 副作用 |
|----|---------|------|------|--------|
| **Logic** | `Features/[機能]/Logic/` または `Shared/Logic/` | 純粋な関数（計算、フォーマット） | なし | なし |
| **Service** | `Features/[機能]/Services/` または `Shared/Services/` | 副作用のある処理（API、DB、I/O） | なし | あり |
| **Store** | `Features/[機能]/Models/` | 状態管理、Serviceとの結合（@Observable） | あり | なし |
| **View** | `Features/[機能]/Views/` | 表示、ユーザーイベント受付（エントリ） | @State（Storeのみ） | なし |

### 純粋な関数とServiceの区別

**純粋な関数（Logic/）**:
- 同じ入力 → 常に同じ出力
- 副作用なし
- テスト容易
- 配置: `Features/[機能]/Logic/` または `Shared/Logic/`

```swift
// ✅ Features/Home/Logic/VisitFilter.swift
struct VisitFilter {
    static func filterByDateRange(
        visits: [Visit],
        from: Date,
        to: Date
    ) -> [Visit] {
        visits.filter { $0.timestamp >= from && $0.timestamp <= to }
    }
}
```

**Service（Services/）**:
- 副作用あり（DB、API、位置情報、ファイルI/O）
- 状態は持たない（ステートレス）
- 配置: `Features/[機能]/Services/` または `Shared/Services/`

```swift
// ✅ Features/Home/Services/VisitService.swift
final class VisitService {
    static let shared = VisitService()

    private let repository: VisitRepository

    func fetchAll() async throws -> [Visit] {
        try await repository.fetchAll()  // DB操作 = 副作用
    }
}
```

### 配置の判断基準

**1つの機能でのみ使用する場合**:
- `Features/[機能名]/` に配置

**複数の機能で使用する場合**:
- `Shared/` に配置

**例: 新機能追加時のフォルダ配置**

```
# 統計機能を追加
Features/
└── Statistics/
    ├── Models/
    │   └── StatisticsStore.swift
    ├── Logic/
    │   └── VisitStatisticsCalculator.swift  # 純粋な計算
    ├── Services/
    │   └── StatisticsService.swift          # データ取得（副作用）
    └── Views/
        ├── StatisticsView.swift
        └── Components/
            ├── ChartView.swift
            └── SummaryCard.swift
```

---

## 命名規約

### 言語使用

- **コード（変数、関数、クラス名）**: 英語
- **コメント**: 日本語
- **ログメッセージ**: 日本語
- **ユーザー向けメッセージ**: 日本語（ローカライズ）

### Swift命名規約

#### クラス・構造体・列挙型
- **UpperCamelCase**を使用
- 名詞または名詞句

```swift
class HomeStore { }          // ViewModel → Store
struct VisitAggregate { }
enum ViewState { }
```

#### 関数・変数
- **lowerCamelCase**を使用
- 動詞または動詞句（関数）、名詞（変数）

```swift
func fetchVisits() { }
func load() { }
var visits: [Visit] = []
var isLoading: Bool = false
```

#### プロトコル
- 能力を表す場合は `-able`, `-ing` を付ける
- それ以外は名詞

```swift
protocol VisitRepository { }      // サービス的なもの
protocol Codable { }               // 能力
```

#### Bool型の命名
- `is`, `has`, `should`, `can` で始める

```swift
var isLoading: Bool
var hasPhotos: Bool
var shouldRefresh: Bool
var canDelete: Bool
```

### MVパターンでの命名

**Store**: `[機能名]Store.swift`
```swift
// ✅ 良い
HomeStore.swift
CreateStore.swift
DetailStore.swift

// ❌ 悪い（ViewModelという名前は使わない）
HomeViewModel.swift
CreateViewModel.swift
```

**View**: `[機能名]View.swift`
```swift
// ✅ 良い
HomeView.swift
CreateView.swift
```

**Service**: `[機能名]Service.swift`
```swift
// ✅ 良い
VisitService.swift
LocationService.swift
```

**Logic**: `[処理名].swift`
```swift
// ✅ 良い
VisitFilter.swift
DistanceCalculator.swift
CoordinateValidator.swift
```

### 具体的で明確な命名

**良い例**:
```swift
func fetchVisitsByDateRange(from: Date, to: Date)
var selectedLabelIds: Set<UUID>
```

**悪い例**:
```swift
func get()              // ❌ 何を取得するか不明
var data: [Any]        // ❌ 型が曖昧
var temp: String       // ❌ 一時変数でも意味のある名前を
```

---

## 状態管理

### @Observable マクロの使用

iOS 17+では`@Observable`マクロを使用して状態管理を行います（`ObservableObject`や`@Published`は使いません）。

**良い例（iOS 17+）**:
```swift
import Foundation
import Observation

@Observable
final class HomeStore {
    var visits: [Visit] = []
    var isLoading = false
    var errorMessage: String?

    private let visitService: VisitService

    init(visitService: VisitService = .shared) {
        self.visitService = visitService
    }

    func load() async {
        isLoading = true
        visits = try await visitService.fetchAll()
        isLoading = false
    }
}

// Viewでの使用
struct HomeView: View {
    @State private var store = HomeStore()

    var body: some View {
        List(store.visits) { visit in
            VisitRow(visit: visit)
        }
        .task { await store.load() }
    }
}
```

**悪い例（旧パターン）**:
```swift
// ❌ ObservableObject と @Published（旧MVVM）
class HomeViewModel: ObservableObject {
    @Published var visits: [Visit] = []
    @Published var isLoading = false

    // ...
}

// ❌ @StateObject（旧パターン）
struct HomeView: View {
    @StateObject private var viewModel: HomeViewModel
    // ...
}
```

### 状態の単一方向フロー

```
User Action → View → Store → Service → Repository
     ↑                 ↓
     └─── UI Update ←──┘
          (@Observable自動通知)
```

---

## パフォーマンス

### Core Dataの効率的な使用

1. **フェッチ時は必要な属性のみ**
2. **述語（Predicate）でフィルタリング**
3. **バッチ操作を活用**
4. **バックグラウンドコンテキストを使用**（大量データ処理時）

```swift
// ✅ 良い: 述語でフィルタ
let request = VisitEntity.fetchRequest()
request.predicate = NSPredicate(format: "timestampUTC >= %@", date as NSDate)
let results = try context.fetch(request)

// ❌ 悪い: 全取得後にフィルタ
let all = try context.fetch(VisitEntity.fetchRequest())
let filtered = all.filter { $0.timestampUTC >= date }
```

### リスト表示の最適化

- LazyVStack/LazyHStackを使用
- 大量データはページング実装を検討

### メモリ管理

- 大きな画像は適切にリサイズ
- 不要なキャッシュは削除
- weak/unownedで循環参照を防ぐ

---

## エラーハンドリング

### エラー型の定義

```swift
enum LocationServiceError: LocalizedError {
    case permissionDenied
    case other(Error)

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "位置情報の権限がありません"
        case .other(let error):
            return error.localizedDescription
        }
    }
}
```

### エラーのログ記録

```swift
do {
    try await visitService.save(visit)
} catch {
    Logger.error("訪問の保存に失敗しました", error: error)
    errorMessage = error.localizedDescription
}
```

---

## テストとデバッグ

### Logger の活用

```swift
Logger.info("位置情報取得を開始")
Logger.success("データ保存完了")
Logger.warning("キャッシュが見つかりません")
Logger.error("API呼び出し失敗", error: error)
```

### デバッグ時の注意点

- 本番環境では詳細ログを出さない
- センシティブ情報（座標、個人情報）はログに出さない

---

## セキュリティ

### 改ざん検出

- 重要データ（位置情報）は署名付きで保存
- 署名の検証を必ず行う

### 機密情報の管理

- API KeyはKeychainに保存
- ハードコーディング禁止
- Gitにコミットしない

### 位置情報の取り扱い

- 偽装検出（`isSimulatedBySoftware`）
- 精度情報の記録
- ユーザー許可の確認

---

## 関連ドキュメント

- [実装ガイド](./implementation-guide.md) - 具体的な実装手順とタスク別ガイド
- [MVVM→MV移行ガイド](./migration/mvvm-to-mv-migration-guide.md) - 既存コードの移行手順
- [ADR-001: フォルダ構成とアーキテクチャの再設計](./ADR/001-フォルダ構成とアーキテクチャの再設計.md) - 設計判断の背景

---

## 今後の改善

このドキュメントは継続的に更新されます。新しい設計方針やアーキテクチャの改善が見つかったら追加してください。
