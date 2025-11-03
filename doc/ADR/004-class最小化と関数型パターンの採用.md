# ADR-004: class最小化と関数型パターンの採用

**ステータス**: 提案中

**日付**: 2025-10-28

## 背景と課題

### 何が問題だったか

現在のkokokitaプロジェクトでは、以下のような課題が存在する:

1. **classの過剰使用**: ViewModel、Service、Repository等、多くの層でclassが使用されている
2. **React関数コンポーネント風の開発体験の欠如**: Reactの関数コンポーネントのような、よりシンプルで予測可能な開発スタイルが望まれている
3. **値型の利点が活かされていない**: Swiftの値型（struct）の利点（メモリ安全性、パフォーマンス、不変性）が十分に活用されていない
4. **参照型による複雑性**: classの参照セマンティクスによる予期しない副作用や、メモリ管理の複雑さ

### 制約

- **@Observableマクロの制限**: iOS 17+の`@Observable`マクロは**classのみ対応**（structは不可）
- **Core Dataの制限**: Core DataのNSManagedObjectはclass継承が必須
- **既存コードベース**: 段階的な移行が必要
- **後方互換性**: 既存の機能を壊さずに移行する必要がある

## 検討した選択肢

### 選択肢1: 現状維持（class中心のアーキテクチャ）

- **概要**: 現在のMVVMパターンを維持し、ViewModel、Service、Repositoryすべてでclassを使用
- **メリット**:
  - 既存コードの変更が不要
  - チームの学習コスト不要
  - 参照セマンティクスによる状態共有が容易
- **デメリット**:
  - 参照サイクルによるメモリリークのリスク
  - マルチスレッド環境での安全性が低い
  - パフォーマンスの最適化が困難
  - テストが複雑（状態の共有による副作用）
  - React風の関数的な開発体験が得られない

### 選択肢2: 完全なstruct化（Store/Serviceも含む）

- **概要**: @Observableの制約を無視し、すべてをstructで実装
- **メリット**:
  - 完全な値型セマンティクス
  - 最高のメモリ安全性とパフォーマンス
  - 理論的に最もシンプル
- **デメリット**:
  - ❌ **実装不可能**: @Observableがclassのみ対応のため、状態管理ができない
  - SwiftUIの状態変更追跡が機能しない
  - 現実的な選択肢ではない

### 選択肢3: struct優先・class最小化（ハイブリッドアプローチ）

- **概要**:
  - **デフォルトはstruct**: Model、Logic、Viewは常にstruct
  - **必要最小限のclass**: Store（@Observable必須）とService（必要な場合のみ）
  - **関数型パターンの採用**: 純粋な関数、immutability、値型を優先
- **メリット**:
  - ✅ Swiftの値型の利点を最大限活用
  - ✅ メモリ安全性とパフォーマンスの向上
  - ✅ テスト容易性の大幅改善
  - ✅ React関数コンポーネントに近い開発体験
  - ✅ @Observableの制約を満たしつつ、classを最小化
  - ✅ マルチスレッド環境での安全性向上
  - ✅ コードの予測可能性と保守性の向上
- **デメリット**:
  - 既存コードの段階的な移行が必要
  - チームの学習コスト（関数型パターンの理解）
  - Serviceのstruct化には設計の見直しが必要

### 選択肢4: TCA（The Composable Architecture）の採用

- **概要**: Point-FreeのComposable Architectureフレームワークを導入
- **メリット**:
  - 完全な関数型アーキテクチャ
  - テスト容易性が非常に高い
  - 状態管理が明確
- **デメリット**:
  - 学習コストが非常に高い
  - 既存コードの大規模な書き換えが必要
  - フレームワークへの依存が大きい
  - オーバーエンジニアリングの可能性

## 決定

### 採用した選択肢

**選択肢3: struct優先・class最小化（ハイブリッドアプローチ）**

### なぜこれを選んだか

1. **実現可能性**: @Observableの制約を満たしつつ、最大限struct化できる
2. **段階的移行**: 既存コードを段階的に移行可能
3. **パフォーマンス**: 値型による最適化が可能
4. **開発体験**: React関数コンポーネントに近い、シンプルで予測可能な開発が可能
5. **業界標準**: 2025年のSwift/SwiftUIベストプラクティスに準拠
6. **メモリ安全性**: 参照サイクルのリスクを最小化
7. **バランス**: 理想と現実のバランスが取れている

### 実装方針

#### Phase 1: 新規コードから適用（即座に開始）

```swift
// ✅ Model - 常にstruct
struct Visit: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    var title: String

    // ドメインロジックもここに
    var isHighQuality: Bool {
        accuracy <= 50.0
    }
}

// ✅ Logic - structのstatic funcで純粋な関数
struct VisitFilter {
    static func filterByDateRange(
        visits: [Visit],
        from: Date,
        to: Date
    ) -> [Visit] {
        visits.filter { $0.timestamp >= from && $0.timestamp <= to }
    }
}

// ✅ View - struct（React関数コンポーネント風）
struct HomeView: View {
    @State private var store = HomeStore()

    var body: some View {
        contentView
            .task { await store.load() }
    }

    private var contentView: some View {
        List(store.visits) { visit in
            VisitRow(visit: visit)
        }
    }
}

// ⚠️ Store - classだが最小限（@Observable必須）
@Observable
final class HomeStore {
    var visits: [Visit] = []
    var isLoading = false

    private let visitService: any VisitService

    init(visitService: any VisitService = DefaultVisitService()) {
        self.visitService = visitService
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            visits = try await visitService.fetchAll()
        } catch {
            // エラーハンドリング
        }
    }
}

// ✅ Service - protocol + struct（可能な限り）
protocol VisitService {
    func fetchAll() async throws -> [Visit]
    func save(_ visit: Visit) async throws
}

struct DefaultVisitService: VisitService {
    private let repository: any VisitRepository

    init(repository: any VisitRepository = CoreDataVisitRepository.shared) {
        self.repository = repository
    }

    func fetchAll() async throws -> [Visit] {
        try await repository.fetchAll()
    }

    func save(_ visit: Visit) async throws {
        try await repository.save(visit)
    }
}
```

#### Phase 2: 既存Serviceのstruct化（優先度：中）

現在のService（15ファイル）を評価し、struct化可能なものから移行:

**struct化可能な候補**:
- `MapKitPlaceLookupService`: ステートレス、純粋な副作用のみ
- `LocationGeocodingService`: ステートレス
- `POICoordinatorService`: リトライロジックあるが、struct化可能

**class維持が必要な候補**:
- `PhotoEditService`: トランザクション状態を保持（class維持）
- `DefaultIntegrityService`: Keychain操作、シングルトンパターン（class維持）

#### Phase 3: ViewModelからStoreへの移行（優先度：高）

- `HomeViewModel` → `HomeStore`（@Observable使用）
- `CreateEditViewModel` → `CreateStore`（@Observable使用）

#### Phase 4: ドキュメント更新

- `doc/architecture-guide.md`: struct優先の設計方針を明記
- `doc/implementation-guide.md`: 実装例を更新
- Serenaメモリ更新

## 影響

### プラス面

1. **パフォーマンス向上**
   - structはスタックに確保され、classよりも高速（調査結果より）
   - ARCのオーバーヘッドがない
   - Copy-on-Writeによる効率的なメモリ利用

2. **メモリ安全性**
   - 参照サイクルによるメモリリークのリスクがゼロ（struct部分）
   - マルチスレッド環境での安全性向上（値型のコピーセマンティクス）

3. **テスト容易性**
   - 値型は予測可能（同じ入力→同じ出力）
   - モックやスタブが不要（純粋な関数）
   - 並列テストが安全

4. **開発体験の向上**
   - React関数コンポーネントに近いシンプルな開発
   - コードの予測可能性が高い
   - 副作用が明確に分離される

5. **コード品質**
   - 不変性による予測可能性
   - 関数型パターンによる保守性向上
   - 2025年のSwiftベストプラクティスに準拠

### マイナス面と対策

1. **@Observableがclassのみ対応**
   - **対策**: Storeのみclassを使用、他はすべてstruct
   - **影響**: 最小限（Store以外は完全にstruct化可能）

2. **既存コードの移行コスト**
   - **対策**: 段階的移行（新規コードから適用→既存コードを徐々に移行）
   - **優先度**: 高頻度で変更する部分から移行

3. **学習コスト**
   - **対策**: ドキュメント充実化、実装例の提供
   - **期間**: 1-2週間で習得可能

4. **Serviceのstruct化の複雑さ**
   - **対策**: 状態を持つServiceはclassのまま維持
   - **判断基準**: ステートレスならstruct、ステートフルならclass

### 影響するコンポーネント

| コンポーネント | 影響 | 対応 |
|--------------|------|------|
| **Model** | ✅ 既にstructが多い | そのまま維持 |
| **View** | ✅ 既にstruct | そのまま維持 |
| **ViewModel** | 🔄 classからStoreへ | @Observableに移行 |
| **Service** | 🔄 一部struct化 | ステートレスなものからstruct化 |
| **Logic** | ➕ 新規追加 | structのstatic funcで実装 |
| **Repository** | ⚠️ class維持 | Core Data制約のため維持 |

## 技術詳細

### アーキテクチャ図

```mermaid
graph TB
    subgraph "Value Types (struct)"
        View[View<br/>struct]
        Model[Model<br/>struct]
        Logic[Logic<br/>struct static func]
    end

    subgraph "Reference Types (class - 最小限)"
        Store[Store<br/>@Observable class]
        Service[Service<br/>protocol + struct/class]
        Repository[Repository<br/>class]
    end

    subgraph "External"
        CoreData[(Core Data)]
        API[External API]
    end

    View -->|@State| Store
    Store -->|uses| Service
    Service -->|uses| Repository
    Service -->|uses| Logic
    Store -->|contains| Model
    View -->|displays| Model
    Repository -->|accesses| CoreData
    Service -->|calls| API

    style View fill:#90EE90
    style Model fill:#90EE90
    style Logic fill:#90EE90
    style Store fill:#FFB6C1
    style Service fill:#FFE4B5
    style Repository fill:#FFB6C1
```

### パフォーマンス比較（調査結果より）

| 項目 | struct | class |
|------|--------|-------|
| メモリ確保 | Stack（高速） | Heap（低速） |
| コピーコスト | Copy-on-Write最適化 | 参照カウント管理 |
| マルチスレッド | 安全（コピーセマンティクス） | 注意必要（共有状態） |
| メモリリーク | なし | 参照サイクルのリスク |
| ARC | 不要 | 必要（オーバーヘッド） |

### struct化の判断フローチャート

```mermaid
flowchart TD
    Start([型を定義する])
    --> Q1{@Observableが<br/>必要？}

    Q1 -->|Yes| UseClass[class使用<br/>@Observable付与]
    Q1 -->|No| Q2{状態を<br/>保持する？}

    Q2 -->|Yes| Q3{状態は<br/>ステートフル？}
    Q2 -->|No| UseStruct[struct使用<br/>static funcで実装]

    Q3 -->|Yes| ConsiderClass[class検討<br/>例: トランザクション]
    Q3 -->|No| UseStructWithProtocol[protocol + struct<br/>ステートレス]

    UseClass --> End([完了])
    UseStruct --> End
    ConsiderClass --> End
    UseStructWithProtocol --> End
```

## 参考資料

### 調査したWeb検索結果

1. **SwiftUI Best Practices 2025**
   - structベースのアーキテクチャが推奨
   - MVVM、TCA等のパターンでもstructを優先
   - 参照: 検索「SwiftUI struct based architecture functional programming best practices 2025」

2. **Struct vs Class Performance**
   - structは平均30-50%高速（スタック確保のため）
   - ARCのオーバーヘッドなし
   - Copy-on-Write最適化
   - 参照: 検索「Swift struct vs class performance comparison memory safety 2025」

3. **@Observable制約**
   - classのみ対応（structは不可）
   - 理由: 参照セマンティクスが必要
   - 参照: 検索「SwiftUI @Observable struct class comparison iOS 17 2025」

4. **Functional Programming in Swift**
   - 値型優先の設計
   - 純粋な関数パターン
   - 参照: 検索「Swift functional programming patterns 2025 avoid classes」

### 関連ADR

- ADR-001: フォルダ構成とアーキテクチャの再設計
- ADR-002: MVVM-MV移行評価
- ADR-003: Observable-マクロ移行評価

## メモ

### 実装時の注意点

1. **structのメソッド内での変更**
   ```swift
   // ✅ 良い: 新しいインスタンスを返す（immutable）
   func updated(title: String) -> Visit {
       var visit = self
       visit.title = title
       return visit
   }

   // ❌ 悪い: mutating（できるだけ避ける）
   mutating func update(title: String) {
       self.title = title
   }
   ```

2. **Serviceのstruct化例**
   ```swift
   // ✅ ステートレスなServiceはstruct
   struct MapKitPlaceLookupService: PlaceLookupService {
       func search(coordinate: CLLocationCoordinate2D) async throws -> [POI] {
           // 実装
       }
   }

   // ⚠️ トランザクション状態を持つ場合はclass
   final class PhotoEditService {
       private var editingPhotos: [Photo] = []  // 状態

       func beginEditing() { }
       func discardEditingIfNeeded() { }
   }
   ```

3. **Logicの実装パターン**
   ```swift
   // ✅ structのstatic funcで純粋な関数
   struct VisitFilter {
       static func filterByDateRange(
           visits: [Visit],
           from: Date,
           to: Date
       ) -> [Visit] {
           // 副作用なし、同じ入力→同じ出力
           visits.filter { $0.timestamp >= from && $0.timestamp <= to }
       }
   }
   ```

### React関数コンポーネントとの対応

| React | SwiftUI | 型 |
|-------|---------|-----|
| 関数コンポーネント | View struct | struct |
| useState | @State + Store | class（Store） |
| Props | View引数 | struct |
| useEffect | .task, .onAppear | - |
| カスタムフック | ViewModifier | struct |
| Redux/Context | Store (@Observable) | class |

### 移行優先度

**優先度: 高**
1. 新規機能は必ずstruct優先で実装
2. ViewModelをStoreに移行（@Observable使用）
3. Modelが完全にstruct化されていることを確認

**優先度: 中**
4. ステートレスなServiceをstruct化
5. Logicレイヤーの整備（純粋な関数）

**優先度: 低**
6. 既存の動作するコードの移行（必要に応じて）

---

**次のステップ**: このADRをチームでレビューし、承認されたら段階的に実装を開始する。
