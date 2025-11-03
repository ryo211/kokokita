# コーディングスタイルと規約

## 言語使用

- **コード（変数、関数、クラス名）**: 英語
- **コメント**: 日本語
- **ログメッセージ**: 日本語
- **エラーメッセージ**: 日本語（可能な限り）
- **ユーザー向けメッセージ**: 日本語（ローカライズ）

## Swift命名規約

### クラス・構造体・列挙型
- **UpperCamelCase**を使用
- 名詞または名詞句

```swift
class HomeStore { }
struct VisitAggregate { }
enum ViewState { }
```

### 関数・変数
- **lowerCamelCase**を使用
- 動詞または動詞句（関数）、名詞（変数）

```swift
func fetchVisits() { }
func load() { }
var visits: [Visit] = []
var isLoading: Bool = false
```

### Bool型の命名
- `is`, `has`, `should`, `can` で始める

```swift
var isLoading: Bool
var hasPhotos: Bool
var shouldRefresh: Bool
var canDelete: Bool
```

### プロトコル
- 能力を表す場合は `-able`, `-ing` を付ける
- それ以外は名詞

```swift
protocol VisitRepository { }
protocol Codable { }
```

## MVパターンでの命名

### Store: `[機能名]Store.swift`
```swift
// ✅ 良い
HomeStore.swift
CreateStore.swift
DetailStore.swift

// ❌ 悪い（ViewModelという名前は使わない）
HomeViewModel.swift
```

### View: `[機能名]View.swift`
```swift
HomeView.swift
CreateView.swift
```

### Service: `[機能名]Service.swift`
```swift
VisitService.swift
LocationService.swift
```

### Logic: `[処理名].swift`
```swift
VisitFilter.swift
DistanceCalculator.swift
CoordinateValidator.swift
```

## コードスタイル

### @Observableマクロの使用（iOS 17+）

**良い例（新パターン）**:
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
```

**悪い例（旧パターン）**:
```swift
// ❌ ObservableObject と @Published（旧MVVM）
class HomeViewModel: ObservableObject {
    @Published var visits: [Visit] = []
    @Published var isLoading = false
}
```

### Viewでの使用

**良い例**:
```swift
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

**悪い例**:
```swift
// ❌ @StateObject（旧パターン）
struct HomeView: View {
    @StateObject private var viewModel: HomeViewModel
}
```

## コメント規約

### 日本語コメントの使用
コメントは必ず日本語で記述:

```swift
// 訪問記録を取得する
func fetchVisits() async throws -> [Visit] {
    // Core Dataから全訪問記録を取得
    let entities = try await repository.fetchAll()
    
    // ドメインモデルに変換
    return entities.map { $0.toDomain() }
}
```

### MARKコメント
コードセクションを明確にするため、MARKコメントを活用:

```swift
@Observable
final class HomeStore {
    // MARK: - State
    var visits: [Visit] = []
    var isLoading = false

    // MARK: - Dependencies
    private let visitService: VisitService

    // MARK: - Initialization
    init(visitService: VisitService = .shared) {
        self.visitService = visitService
    }

    // MARK: - Actions
    func load() async {
        // 実装
    }
}
```

## エラーハンドリング

### エラー型の定義
```swift
enum LocationServiceError: LocalizedError {
    case permissionDenied
    case simulatedLocation
    case other(Error)

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "位置情報の権限がありません"
        case .simulatedLocation:
            return "偽装された位置情報は使用できません"
        case .other(let error):
            return error.localizedDescription
        }
    }
}
```

### エラーログ
```swift
do {
    try await visitService.save(visit)
} catch {
    Logger.error("訪問の保存に失敗しました", error: error)
    errorMessage = error.localizedDescription
}
```

## Logger の活用

カスタムLoggerユーティリティ（`kokokita/Support/Logger.swift`）を使用:

```swift
Logger.info("位置情報取得を開始")
Logger.success("データ保存完了")
Logger.warning("キャッシュが見つかりません")
Logger.error("API呼び出し失敗", error: error)
```

## ファイル配置規約

### 機能固有のコード
```
Features/[機能名]/
├── Models/      # Store
├── Logic/       # 純粋な関数
├── Services/    # 副作用
└── Views/       # UI
```

### 共通コード
```
Shared/
├── Models/           # ドメインモデル
├── Logic/            # 共通Logic
├── Services/         # 共通Service
└── UIComponents/     # 共通UI
```

### 拡張機能
型ごとに整理された拡張機能は以下に配置:
```
kokokita/Support/Extensions/
├── DateExtensions.swift
├── StringExtensions.swift
└── CollectionExtensions.swift
```

### UI定数
```
kokokita/Config/UIConstants.swift
```

## 具体的で明確な命名

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

## 型安全性

### オプショナルは最小限に
```swift
// ✅ 良い
struct Visit {
    let id: UUID
    let timestamp: Date
}

// ❌ 悪い
struct Visit {
    var id: UUID?  // IDは必須のはず
    var timestamp: Date?
}
```

### 適切なアクセス修飾子
```swift
@Observable
final class HomeStore {
    // パブリック: Viewからアクセス
    var visits: [Visit] = []
    
    // プライベート: 内部実装
    private let visitService: VisitService
}
```