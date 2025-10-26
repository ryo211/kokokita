# ベストプラクティス

> **重要**: このドキュメントはプロジェクトの重要な指針です。すべてのコード変更時に参照してください。

最終更新: 2025-10-25

## 目次

1. [アーキテクチャ原則](#アーキテクチャ原則)
2. [UIとロジックの分離](#uiとロジックの分離)
3. [フォルダ構成とコロケーション](#フォルダ構成とコロケーション)
4. [命名規約](#命名規約)
5. [コーディングスタイル](#コーディングスタイル)
6. [状態管理](#状態管理)
7. [パフォーマンス](#パフォーマンス)
8. [エラーハンドリング](#エラーハンドリング)
9. [テストとデバッグ](#テストとデバッグ)
10. [セキュリティ](#セキュリティ)

---

## アーキテクチャ原則

### Feature-based MV アーキテクチャ

> **参照**: 詳細な設計判断は`doc/ADR/001-フォルダ構成とアーキテクチャの再設計.md`を参照してください。

プロジェクトは**Feature-based MV**パターンを採用しています（2025年のSwiftベストプラクティスに準拠）：

```
┌─────────────────────────────────────┐
│  Features/                          │  ← 機能単位でコロケーション
│  ├── [機能名]/                      │
│  │   ├── Models/    (Store)         │  ← @Observable 状態管理
│  │   ├── Views/                     │  ← SwiftUI View
│  │   ├── Logic/     (純粋な関数)    │  ← 副作用なし
│  │   └── Services/  (副作用)        │  ← DB、API、I/O
├─────────────────────────────────────┤
│  Shared/                            │  ← 共通コード
│  ├── Models/                        │  ← ドメインモデル
│  ├── Logic/                         │  ← 共通の純粋な関数
│  ├── Services/                      │  ← 共通Service
│  └── UIComponents/                  │  ← 共通UIコンポーネント
└─────────────────────────────────────┘
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

- ✅ **View**: 表示のみ
- ✅ **Store**: 状態管理とServiceとの結合のみ（@Observable）
- ✅ **Service**: 副作用のある処理のみ（ステートレス）
- ✅ **Logic**: 純粋な関数のみ（副作用なし）

---

## UIとロジックの分離

### 厳密な分離の原則

**絶対に守るべきルール**:
1. **Viewにビジネスロジックやデータアクセスロジックを書かない**
2. **StoreにUIコンポーネントを持ち込まない**
3. **Serviceに表示ロジックを書かない**
4. **Logicに副作用を持ち込まない**

### Viewの責務

Viewは**表示のみ**に集中します。

**良い例**:
```swift
struct HomeView: View {
    @State private var store = HomeStore()

    var body: some View {
        List(store.visits) { visit in
            VisitRow(visit: visit)
        }
        .task {
            await store.load()  // ロジックはStoreに委譲
        }
    }
}
```

**悪い例**:
```swift
struct HomeView: View {
    var body: some View {
        // ❌ Viewでデータ取得やビジネスロジック
        let items = try? CoreDataStack.shared.context.fetch(...)
        let filtered = items.filter { /* 複雑なロジック */ }

        List(filtered) { item in
            Text(item.title)
        }
    }
}
```

### Storeの責務

Storeは**状態管理とServiceとの結合**に集中します。

**良い例**:
```swift
import Foundation
import Observation

@Observable
final class HomeStore {
    // 状態
    var visits: [Visit] = []
    var isLoading = false
    var errorMessage: String?

    // 依存するService
    private let visitService: VisitService

    init(visitService: VisitService = .shared) {
        self.visitService = visitService
    }

    // アクション
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
}
```

**悪い例**:
```swift
@Observable
final class HomeStore {
    // ❌ StoreでCore Data操作を直接行う
    func load() {
        let context = CoreDataStack.shared.context
        let request = VisitEntity.fetchRequest()
        let results = try? context.fetch(request)
        // ...
    }
}
```

### Serviceの責務

Serviceは**副作用のある処理**のみを行います（ステートレス）。

**良い例**:
```swift
// Features/Home/Services/VisitService.swift
final class VisitService {
    static let shared = VisitService()

    private let repository: VisitRepository

    init(repository: VisitRepository = .shared) {
        self.repository = repository
    }

    // DB操作 = 副作用
    func fetchAll() async throws -> [Visit] {
        try await repository.fetchAll()
    }

    func delete(_ visit: Visit) async throws {
        try await repository.delete(visit)
    }
}
```

**悪い例**:
```swift
class VisitService {
    // ❌ Serviceに状態を持つ（ステートレスにすべき）
    var cachedVisits: [Visit] = []

    func fetchAll() -> [Visit] {
        if !cachedVisits.isEmpty {
            return cachedVisits
        }
        // ...
    }
}
```

### Logicの責務

Logicは**純粋な関数**のみを含みます（副作用なし）。

**良い例**:
```swift
// Features/Home/Logic/VisitFilter.swift
struct VisitFilter {
    // 副作用なし、同じ入力 → 同じ出力
    static func filterByDateRange(
        visits: [Visit],
        from: Date,
        to: Date
    ) -> [Visit] {
        visits.filter { $0.timestamp >= from && $0.timestamp <= to }
    }
}
```

**悪い例**:
```swift
struct VisitFilter {
    // ❌ 純粋な関数に副作用を持ち込む
    static func filterByDateRange(
        visits: [Visit],
        from: Date,
        to: Date
    ) -> [Visit] {
        Logger.info("フィルタリング開始")  // ❌ 副作用（ログ出力）
        let result = visits.filter { ... }
        UserDefaults.standard.set(result.count, forKey: "count")  // ❌ 副作用（永続化）
        return result
    }
}
```

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

## コーディングスタイル

### インデントと整形

- **インデント**: スペース4つ
- **行の長さ**: 120文字を目安に
- **空行**: 論理的なブロック間に1行

### コメント

#### コメントを書くべき箇所
1. **なぜそうしたか**が明確でない箇所
2. 複雑なロジック
3. 回避策や一時的な処理
4. パブリックAPI

#### コメントを書かなくて良い箇所
- コードを読めば分かる明白な内容
- 関数名で十分説明できている処理

**良い例**:
```swift
// ココカモAPIのレート制限を回避するため、3回リトライする
for attempt in 1...3 {
    // ...
}

// NOTE: iOS 15以前のバグ対応。iOS 16以降では不要な可能性あり
if #available(iOS 16, *) {
    // ...
}
```

**悪い例**:
```swift
// 変数を定義
var visits: [Visit] = []  // ❌ 読めば分かる

// ループする
for visit in visits {     // ❌ 意味がない
    // ...
}
```

### 冗長な記載の削除

#### 型推論を活用

```swift
// ✅ 良い
let visits = [Visit]()
let name = "テスト"

// ❌ 冗長
let visits: [Visit] = [Visit]()
let name: String = "テスト"
```

#### 不要なselfを削除

```swift
@Observable
final class HomeStore {
    var visits: [Visit] = []

    func load() {
        // ✅ selfは不要
        visits = []

        // ❌ 冗長（曖昧でない場合）
        self.visits = []
    }
}
```

#### guard文とearly returnを活用

```swift
// ✅ 良い: early return
func process(value: String?) {
    guard let value = value else { return }
    // メインロジック
}

// ❌ 悪い: ネストが深い
func process(value: String?) {
    if let value = value {
        // メインロジック
    }
}
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

## 移行ガイド

### 旧MVVMから新MVへの移行

| 項目 | MVVM（旧） | MV（新） |
|------|-----------|---------|
| 状態管理 | `ViewModel (ObservableObject)` | `Store (@Observable)` |
| プロパティ宣言 | `@Published var items: [Item]` | `var items: [Item]` |
| Viewでの保持 | `@StateObject private var viewModel` | `@State private var store` |
| ボイラープレート | Combine、@Published | 最小限 |
| 複雑性 | 中〜高 | 低 |
| iOS要件 | iOS 13+ | iOS 17+ |

**移行手順**:
1. ViewModelをStoreにリネーム
2. `ObservableObject` → `@Observable`
3. `@Published` → 通常のプロパティ
4. `@StateObject` → `@State`
5. Combineの削除

---

## 今後の改善

このドキュメントは継続的に更新されます。新しいベストプラクティスが見つかったら追加してください。
