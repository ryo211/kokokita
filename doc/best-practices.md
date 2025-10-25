# ベストプラクティス

> **重要**: このドキュメントはプロジェクトの重要な指針です。すべてのコード変更時に参照してください。

最終更新: 2025-10-24

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

### クリーンアーキテクチャの遵守

プロジェクトは以下の層に分離されています：

```
┌─────────────────────────────────────┐
│  Presentation Layer                 │  ← UI、ViewModel
├─────────────────────────────────────┤
│  Domain Layer                       │  ← ビジネスロジック、Model、Protocol
├─────────────────────────────────────┤
│  Infrastructure Layer               │  ← Repository、外部ライブラリ
└─────────────────────────────────────┘
```

**原則**:
- 上位層は下位層に依存してもよい
- 下位層は上位層に依存してはならない
- 依存性は常にプロトコル（抽象）を介する

**例（良い）**:
```swift
// ViewModel（Presentation層）がプロトコル（Domain層）に依存
class HomeViewModel {
    private let repo: VisitRepository  // プロトコル
}

// Repository（Infrastructure層）がプロトコルを実装
class CoreDataVisitRepository: VisitRepository {
    // 実装
}
```

**例（悪い）**:
```swift
// Domain層がPresentation層に依存している（NG）
struct Visit {
    var viewModel: ViewModel  // ❌ Domain層にViewModelを持ち込まない
}
```

### 単一責任原則（SRP）

各クラス・構造体は**1つの責務**のみを持つ：

- ✅ View: 表示のみ
- ✅ ViewModel: 表示ロジックと状態管理のみ
- ✅ Repository: データ永続化のみ
- ✅ Service: 特定のビジネスロジックのみ

---

## UIとロジックの分離

### 厳密な分離の原則

**絶対に守るべきルール**:
1. **Viewにビジネスロジックやデータアクセスロジックを書かない**
2. **ViewModelにUIコンポーネントを持ち込まない**
3. **Repositoryに表示ロジックを書かない**

### Viewの責務

Viewは**表示のみ**に集中します。

**良い例**:
```swift
struct HomeView: View {
    @StateObject private var viewModel: HomeViewModel

    var body: some View {
        List(viewModel.items) { item in
            VisitRow(visit: item)
        }
        .onAppear {
            viewModel.reload()  // ロジックはViewModelに委譲
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

### ViewModelの責務

ViewModelは**表示ロジックと状態管理**に集中します。

**良い例**:
```swift
@MainActor
final class HomeViewModel: ObservableObject {
    @Published var items: [VisitAggregate] = []
    @Published var isLoading = false

    private let repo: VisitRepository

    func reload() {
        isLoading = true
        do {
            items = try repo.fetchAll(...)
        } catch {
            // エラーハンドリング
        }
        isLoading = false
    }
}
```

**悪い例**:
```swift
class HomeViewModel {
    // ❌ ViewModelでCore Data操作を直接行う
    func reload() {
        let context = CoreDataStack.shared.context
        let request = VisitEntity.fetchRequest()
        let results = try? context.fetch(request)
        // ...
    }
}
```

### 依存性注入（DI）

ViewModelは依存するサービスを**コンストラクタで受け取る**:

```swift
class CreateEditViewModel: ObservableObject {
    private let locationService: LocationService
    private let repository: VisitRepository
    private let integrityService: IntegrityService

    init(
        loc: LocationService,
        repo: VisitRepository,
        integ: IntegrityService
    ) {
        self.locationService = loc
        self.repository = repo
        self.integrityService = integ
    }
}
```

---

## フォルダ構成とコロケーション

> **重要**: フォルダ構成の詳細な設計判断は`doc/ADR/001-フォルダ構成とアーキテクチャの再設計.md`を参照してください。

### 基本原則

1. **機能単位でグループ化**: 関連するファイルは近くに配置
2. **責務で分離**: 層ごとに明確に分ける
3. **深すぎる階層は避ける**: 3階層程度が理想
4. **純粋な関数とServiceを分離**: 副作用の有無で配置場所を変える

### 理想的なフォルダ構成（移行中）

```
kokokita/
├── Domain/                        # ビジネスロジック層
│   ├── Models/                   # データ構造
│   │   ├── Visit.swift
│   │   ├── Taxonomy.swift
│   │   └── Location.swift
│   │
│   ├── Logic/                    # 純粋な関数（副作用なし）
│   │   ├── Calculations/         # 計算ロジック
│   │   ├── Formatting/           # フォーマット
│   │   ├── Validation/           # バリデーション
│   │   └── Filtering/            # フィルタリング
│   │
│   ├── Services/                 # 副作用のある処理
│   │   ├── Location/
│   │   │   ├── LocationService.swift
│   │   │   └── LocationGeocodingService.swift
│   │   ├── POI/
│   │   │   ├── POIService.swift
│   │   │   └── POICoordinatorService.swift
│   │   ├── Photo/
│   │   │   ├── PhotoEditService.swift
│   │   │   └── ImageStore.swift
│   │   └── Visit/
│   │       ├── VisitRepository.swift
│   │       └── TaxonomyRepository.swift
│   │
│   └── Protocols/                # インターフェース定義
│       └── ServiceProtocols.swift
│
├── Infrastructure/               # 技術的実装
│   ├── CoreData/
│   │   ├── CoreDataStack.swift
│   │   └── Repositories/
│   └── Security/
│       └── DefaultIntegrityService.swift
│
├── Screens/                      # 画面単位（UI層）
│   ├── Home/
│   │   ├── HomeViewModel.swift   # 状態管理 + Service結合
│   │   ├── HomeView.swift        # 表示（エントリポイント）
│   │   └── Components/           # この画面専用のコンポーネント
│   │       ├── VisitRow.swift
│   │       └── FilterSheet.swift
│   │
│   ├── Create/
│   │   ├── CreateEditViewModel.swift
│   │   ├── CreateView.swift
│   │   └── Components/
│   │
│   ├── Detail/
│   │   ├── DetailViewModel.swift
│   │   ├── DetailView.swift
│   │   └── Components/
│   │
│   └── Menu/
│       ├── MenuViewModel.swift
│       └── MenuView.swift
│
├── UIComponents/                 # 共通UIコンポーネント
│   ├── Buttons/
│   ├── Forms/
│   ├── Media/
│   └── Navigation/
│       └── RootTabView.swift
│
├── App/                          # アプリケーション設定
│   ├── AppDelegate.swift
│   ├── KokokitaApp.swift
│   ├── Config/
│   │   ├── AppConfig.swift
│   │   └── UIConstants.swift
│   └── DI/
│       └── DependencyContainer.swift
│
├── Resources/                    # リソース
│   └── Localization/
│       ├── LocalizedString.swift
│       ├── ja.lproj/
│       └── en.lproj/
│
└── Utilities/                    # 汎用ユーティリティ
    ├── Extensions/
    ├── Helpers/
    │   ├── Logger.swift
    │   └── KeyboardHelpers.swift
    └── Protocols/
```

### 各層の責務と配置ルール

| 層 | フォルダ | 役割 | 状態 | 副作用 |
|----|---------|------|------|--------|
| **Logic** | `Domain/Logic/` | 純粋な関数（計算、フォーマット） | なし | なし |
| **Service** | `Domain/Services/` | 副作用のある処理（API、DB、I/O） | なし | あり |
| **ViewModel** | `Screens/[機能]/` | 状態管理、Serviceとの結合 | あり | なし |
| **View** | `Screens/[機能]/` | 表示、ユーザーイベント受付（エントリ） | なし | なし |

### 純粋な関数とServiceの区別

**純粋な関数（Domain/Logic/）**:
- 同じ入力 → 常に同じ出力
- 副作用なし
- テスト容易

```swift
// ✅ Logic/Filtering/VisitFilter.swift
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

**Service（Domain/Services/）**:
- 副作用あり（DB、API、位置情報、ファイルI/O）
- 状態は持たない（ステートレス）

```swift
// ✅ Services/Visit/VisitService.swift
class VisitService {
    private let repository: VisitRepository

    func fetchVisits() throws -> [Visit] {
        try repository.fetchAll()  // DB操作 = 副作用
    }
}
```

### 新機能追加時のフォルダ配置

新しい画面を追加する場合：

1. **Screens/[機能名]/を作成**
2. **ViewとViewModelを同じフォルダに配置**
3. **画面専用コンポーネントはComponents/に**
4. **複数画面で使うコンポーネントはUIComponents/に**

**例: 統計機能を追加**
```
Screens/
└── Statistics/
    ├── StatisticsViewModel.swift
    ├── StatisticsView.swift       ← エントリポイント
    └── Components/
        ├── ChartView.swift
        └── SummaryCard.swift
```

**例: 新しいロジックを追加**
```
Domain/
├── Logic/
│   └── Statistics/
│       └── VisitStatisticsCalculator.swift  ← 純粋な計算
└── Services/
    └── Statistics/
        └── StatisticsService.swift          ← データ取得（副作用）
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
class HomeViewModel { }
struct VisitAggregate { }
enum ViewState { }
```

#### 関数・変数
- **lowerCamelCase**を使用
- 動詞または動詞句（関数）、名詞（変数）

```swift
func fetchVisits() { }
func reload() { }
var items: [Item] = []
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
var items: [Item] = []  // ❌ 読めば分かる

// ループする
for item in items {     // ❌ 意味がない
    // ...
}
```

### 冗長な記載の削除

#### 型推論を活用

```swift
// ✅ 良い
let items = [Visit]()
let name = "テスト"

// ❌ 冗長
let items: [Visit] = [Visit]()
let name: String = "テスト"
```

#### 不要なselfを削除

```swift
class ViewModel {
    var items: [Item] = []

    func reload() {
        // ✅ selfは不要
        items = []

        // ❌ 冗長（曖昧でない場合）
        self.items = []
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

### @Published と Combine

ViewModelの状態は`@Published`で公開：

```swift
@MainActor
final class HomeViewModel: ObservableObject {
    @Published var items: [VisitAggregate] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
}
```

### 状態の単一方向フロー

```
User Action → ViewModel → Repository → Domain Model
     ↑                                      ↓
     └──────────── View Update ←───────────┘
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
    try repository.save(item)
} catch {
    Logger.error("アイテムの保存に失敗しました", error: error)
    alert = error.localizedDescription
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

## 今後の改善

このドキュメントは継続的に更新されます。新しいベストプラクティスが見つかったら追加してください。
