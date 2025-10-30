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

> **参照**: 詳細な設計判断は [ADR-001](./ADR/001-フォルダ構成とアーキテクチャの再設計.md) を参照

プロジェクトは**Feature-based MV**パターンを採用（iOS 17+ @Observableマクロ活用）：

```
Features/[機能名]/          Shared/
├── Models/  (@Observable)  ├── Models/  (ドメイン)
├── Views/   (SwiftUI)      ├── Logic/   (共通関数)
├── Logic/   (純粋関数)     ├── Services/ (共通Service)
└── Services/ (副作用)      └── UIComponents/
```

**4つの原則**:
1. **コロケーション**: 関連ファイルを機能単位でまとめる
2. **MVパターン**: @Observable Store（ViewModelは使わない）
3. **副作用の分離**: Logic（純粋）とService（副作用）を明確に区別
4. **iOS 17+**: @Observableマクロで状態管理

**コード例**:
```swift
// ✅ Store
@Observable final class HomeStore {
    var visits: [Visit] = []
    private let service: VisitService
    func load() async { visits = try await service.fetchAll() }
}

// ✅ View
struct HomeView: View {
    @State private var store = HomeStore()
    var body: some View {
        List(store.visits) { /* ... */ }
        .task { await store.load() }
    }
}

// ❌ 旧MVVM（使わない）
class HomeViewModel: ObservableObject { @Published var visits... }
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
**責務**: データ構造とドメインロジック | **配置**: `Shared/Models/` または `Features/[機能名]/Models/`

**特徴**: structで不変、永続化に依存しない、ドメインルール（validation等）を含む

> **実装方法**: [実装ガイド - Step 3](./implementation-guide.md#step-3-データモデルの定義)

```swift
// ✅ 良い例
struct Visit: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    var isHighQuality: Bool { accuracy <= 50.0 }  // ドメインロジック
}

// ❌ 避ける
struct Visit {
    var displayTitle: String { /* UI */ }  // ❌ UIロジック
    func save() async throws { /* DB */ }  // ❌ 副作用
}
```

#### View（ビュー）
**責務**: UI表示とイベント受付 | **配置**: `Features/[機能名]/Views/`

**特徴**: SwiftUI、Storeから状態を受取り表示、ビジネスロジック含まず

> **実装方法**: [実装ガイド - Step 8](./implementation-guide.md#step-8-viewの実装)

```swift
struct HomeView: View {
    @State private var store = HomeStore()
    var body: some View {
        List(store.visits) { visit in VisitRow(visit: visit) }
        .task { await store.load() }
    }
}
```

#### Store（状態管理）
**責務**: 状態管理とService結合 | **配置**: `Features/[機能名]/Models/[機能名]Store.swift`

**特徴**: @Observable、UI状態保持、副作用はServiceに委譲、ViewとServiceの橋渡し

> **実装方法**: [実装ガイド - Step 7](./implementation-guide.md#step-7-storeの実装observable)

```swift
@Observable
final class HomeStore {
    var visits: [Visit] = []
    var isLoading = false
    private let visitService: VisitService

    func load() async {
        isLoading = true
        do {
            visits = try await visitService.fetchAll()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
```

#### Service（副作用のある処理）
**責務**: 副作用（DB/API/I/O） | **配置**: `Features/[機能名]/Services/` または `Shared/Services/`

**特徴**: ステートレス、外部システム連携、エラーハンドリング

> **実装方法**: [実装ガイド - Step 6](./implementation-guide.md#step-6-serviceの実装副作用のある処理)

```swift
final class VisitService {
    static let shared = VisitService()
    private let repository: VisitRepository

    func fetchAll() async throws -> [Visit] {
        try await repository.fetchAll()  // DB操作 = 副作用
    }
}
```

#### Logic（純粋な関数）
**責務**: 純粋関数（計算/変換/フォーマット） | **配置**: `Features/[機能名]/Logic/` または `Shared/Logic/`

**特徴**: 副作用なし、同じ入力→同じ出力、外部状態に非依存、テスト容易

> **実装方法**: [実装ガイド - Step 5](./implementation-guide.md#step-5-logicの実装純粋な関数)

```swift
struct VisitFilter {
    static func filterByDateRange(visits: [Visit], from: Date, to: Date) -> [Visit] {
        visits.filter { $0.timestamp >= from && $0.timestamp <= to }
    }
}
```

#### Repository（データアクセス層）
**責務**: データ永続化/取得 | **配置**: `Shared/Services/Persistence/`

**特徴**: データソース隠蔽、Core Data↔ドメインモデル変換、CRUD提供

```swift
protocol VisitRepository {
    func fetchAll() async throws -> [Visit]
    func save(_ visit: Visit) async throws
}

final class CoreDataVisitRepository: VisitRepository {
    func fetchAll() async throws -> [Visit] {
        let entities = try context.fetch(VisitEntity.fetchRequest())
        return entities.map { $0.toDomain() }
    }
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
├── Features/                    # 機能単位（コロケーション）
│   ├── Home/
│   │   ├── Models/             # HomeStore.swift (@Observable)
│   │   ├── Logic/              # VisitFilter.swift (純粋関数)
│   │   ├── Services/           # VisitService.swift (副作用)
│   │   └── Views/              # HomeView.swift, Components/
│   ├── Create/                 # 同様の構成
│   ├── Detail/
│   └── Menu/
│
├── Shared/                      # 共通コード
│   ├── Models/                 # Visit.swift, Taxonomy.swift...
│   ├── Logic/                  # Calculations/, Formatting/, Validation/
│   ├── Services/               # Persistence/, Security/
│   └── UIComponents/           # Buttons/, Forms/, Media/
│
├── App/                         # アプリ設定
│   ├── KokokitaApp.swift
│   ├── Config/                 # AppConfig, UIConstants
│   └── DI/                     # DependencyContainer
│
├── Resources/                   # リソース
│   └── Localization/
│
└── Utilities/                   # 汎用ユーティリティ
    ├── Extensions/
    ├── Helpers/
    └── Protocols/
```

### 各層の責務と配置ルール

| 層 | フォルダ | 役割 | 状態 | 副作用 |
|----|---------|------|------|--------|
| **Logic** | `Features/[機能]/Logic/` または `Shared/Logic/` | 純粋な関数（計算、フォーマット） | なし | なし |
| **Service** | `Features/[機能]/Services/` または `Shared/Services/` | 副作用のある処理（API、DB、I/O） | なし | あり |
| **Store** | `Features/[機能]/Models/` | 状態管理、Serviceとの結合（@Observable） | あり | なし |
| **View** | `Features/[機能]/Views/` | 表示、ユーザーイベント受付（エントリ） | @State（Storeのみ） | なし |

### 純粋な関数とServiceの区別

| 特徴 | Logic（純粋関数） | Service（副作用） |
|------|-----------------|-----------------|
| 副作用 | なし | あり（DB/API/I/O） |
| 状態 | なし | ステートレス |
| テスト | 容易 | モック必要 |
| 配置 | `Logic/` | `Services/` |

```swift
// Logic: 純粋関数
struct VisitFilter {
    static func filterByDateRange(visits: [Visit], from: Date, to: Date) -> [Visit] {
        visits.filter { $0.timestamp >= from && $0.timestamp <= to }
    }
}

// Service: 副作用
final class VisitService {
    func fetchAll() async throws -> [Visit] {
        try await repository.fetchAll()  // DB = 副作用
    }
}
```

### 配置の判断基準

- **1つの機能のみ**: `Features/[機能名]/`
- **複数機能で共有**: `Shared/`

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

### @Observable マクロ（iOS 17+）

`@Observable`で状態管理（`ObservableObject`/`@Published`は使わない）

```swift
// ✅ 正しい
@Observable final class HomeStore {
    var visits: [Visit] = []
    func load() async { visits = try await service.fetchAll() }
}
struct HomeView: View {
    @State private var store = HomeStore()
}

// ❌ 旧MVVM（使わない）
class HomeViewModel: ObservableObject { @Published var visits... }
@StateObject private var viewModel: HomeViewModel
```

### 状態の単一方向フロー

```
User Action → View → Store → Service → Repository
     ↑                ↓
     └── UI Update ←──┘ (@Observable自動通知)
```

---

## パフォーマンス

- **Core Data**: 述語でフィルタ（全取得後フィルタは×）、バッチ操作活用
- **リスト**: LazyVStack使用、大量データはページング
- **メモリ**: 画像リサイズ、weak/unownedで循環参照防止

```swift
// ✅ 述語でフィルタ
request.predicate = NSPredicate(format: "timestampUTC >= %@", date)
```

---

## エラーハンドリング

```swift
enum ServiceError: LocalizedError {
    case permissionDenied
    var errorDescription: String? { "権限がありません" }
}

do {
    try await service.save(visit)
} catch {
    Logger.error("保存失敗", error: error)
}
```

---

## テストとデバッグ

```swift
Logger.info("処理開始")
Logger.error("失敗", error: error)
```

**注意**: 本番では詳細ログ×、センシティブ情報（座標等）ログ×

---

## セキュリティ

- **改ざん検出**: 重要データは署名付き保存・検証
- **機密情報**: Keychain保存、ハードコード禁止
- **位置情報**: 偽装検出（`isSimulatedBySoftware`）、ユーザー許可確認

---

## 関連ドキュメント

- [実装ガイド](./implementation-guide.md) - 具体的な実装手順とタスク別ガイド
- [MVVM→MV移行ガイド](./migration/mvvm-to-mv-migration-guide.md) - 既存コードの移行手順
- [ADR-001: フォルダ構成とアーキテクチャの再設計](./ADR/001-フォルダ構成とアーキテクチャの再設計.md) - 設計判断の背景

---

## 今後の改善

このドキュメントは継続的に更新されます。新しい設計方針やアーキテクチャの改善が見つかったら追加してください。
