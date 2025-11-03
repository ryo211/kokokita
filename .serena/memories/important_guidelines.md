# 重要なガイドラインと注意事項

## 必ず守るべきルール

### 1. 言語使用
- **コード（変数、関数、クラス名）**: 英語
- **コメント**: 日本語
- **ログメッセージ**: 日本語
- **エラーメッセージ**: 日本語
- **コミットメッセージ**: 日本語

### 2. アーキテクチャパターン
- **@Observableマクロを使用**（iOS 17+）
- **ObservableObjectと@Publishedは使わない**（旧パターン）
- **ViewModelという名前は使わない** → Storeを使う
- **@StateObjectは使わない** → @Stateを使う

### 3. フォルダ構成
- **新規機能は必ずFeature-based構成で実装**
- 機能単位でコロケーション（関連ファイルを近くに配置）
- 純粋な関数とServiceを分離（副作用の有無で区別）

### 4. 各層の責務を厳守

| 層 | 責務 | 状態 | 副作用 |
|----|------|------|--------|
| **View** | UI表示とイベント受付 | @State（Storeのみ） | なし |
| **Store** | 状態管理、Serviceとの結合 | あり（@Observable） | なし |
| **Service** | 副作用のある処理 | なし（ステートレス） | あり |
| **Logic** | 純粋な関数 | なし | なし |
| **Model** | データ構造とドメインロジック | データのみ | なし |

### 5. セキュリティ
- **位置情報偽装を検出**: `isSimulatedBySoftware`、`isProducedByAccessory`をチェック
- **改ざん検出**: P256 ECDSA署名を必ず使用
- **機密情報**: Keychainに保存（ハードコーディング禁止）
- **入力値バリデーション**: 必ず実装

## やってはいけないこと

### ❌ 旧パターンの使用
```swift
// ❌ 絶対に使わない
class HomeViewModel: ObservableObject {
    @Published var visits: [Visit] = []
}

struct HomeView: View {
    @StateObject private var viewModel: HomeViewModel
}
```

### ❌ Viewにビジネスロジックを書く
```swift
// ❌ 悪い例
struct HomeView: View {
    var body: some View {
        List {
            ForEach(visits.filter { $0.timestamp >= Date() }) { visit in
                // フィルタリングはLogicまたはStoreで行うべき
            }
        }
    }
}
```

### ❌ Storeに副作用を直接書く
```swift
// ❌ 悪い例
@Observable
final class HomeStore {
    func load() async {
        // DB操作を直接書かない
        let request = VisitEntity.fetchRequest()
        let results = try context.fetch(request)
        
        // Serviceに委譲すべき
    }
}
```

### ❌ Serviceに状態を持たせる
```swift
// ❌ 悪い例
final class VisitService {
    var cachedVisits: [Visit] = []  // 状態を持たせない
    
    func fetchAll() async throws -> [Visit] {
        // ステートレスであるべき
    }
}
```

### ❌ Logicに副作用を含める
```swift
// ❌ 悪い例
struct VisitFilter {
    static func filterRecent(visits: [Visit]) -> [Visit] {
        Logger.info("フィルタリング開始")  // ログ出力 = 副作用
        // 純粋な関数であるべき
    }
}
```

## 正しい実装例

### ✅ @Observableを使用したStore
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
        errorMessage = nil

        do {
            visits = try await visitService.fetchAll()
        } catch {
            Logger.error("訪問記録の読み込みに失敗", error: error)
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}
```

### ✅ Viewの正しい実装
```swift
struct HomeView: View {
    @State private var store = HomeStore()

    var body: some View {
        List(store.visits) { visit in
            VisitRow(visit: visit)
        }
        .navigationTitle("訪問記録")
        .task { await store.load() }
    }
}
```

### ✅ Serviceの正しい実装
```swift
final class VisitService {
    static let shared = VisitService()

    private let repository: VisitRepository

    init(repository: VisitRepository = CoreDataVisitRepository.shared) {
        self.repository = repository
    }

    func fetchAll() async throws -> [Visit] {
        try await repository.fetchAll()  // 副作用をRepositoryに委譲
    }
}
```

### ✅ Logicの正しい実装
```swift
struct VisitFilter {
    // 純粋な関数: 副作用なし
    static func filterByDateRange(
        visits: [Visit],
        from: Date,
        to: Date
    ) -> [Visit] {
        visits.filter { $0.timestamp >= from && $0.timestamp <= to }
    }
}
```

## 特に重要な設計判断

### iOS 17+の@Observableマクロを採用
**理由**: 
- Combineへの依存を削減
- ボイラープレートコードの削減
- パフォーマンス向上
- SwiftUIとの統合が自然

**参照**: `doc/ADR/003-Observable-マクロ移行評価.md`

### Feature-based MV アーキテクチャを採用
**理由**:
- コロケーションによる開発効率向上
- ViewModelレイヤーの削除による複雑性の低減
- 副作用の明確な分離
- テスト容易性の向上

**参照**: `doc/ADR/001-フォルダ構成とアーキテクチャの再設計.md`

### 位置情報偽装検出の徹底
**理由**:
- アプリの信頼性確保
- 不正利用の防止
- 実際に訪問したことの証明

**実装**: `CreateEditViewModel.createNew()`で検証

### Core Dataで永続化
**理由**:
- オフラインファースト
- 複雑なクエリのサポート
- iOSとの統合が良好

## エラーハンドリングの原則

### 1. すべての副作用でエラーハンドリング
```swift
do {
    try await service.save(visit)
} catch {
    Logger.error("保存失敗", error: error)
    errorMessage = error.localizedDescription
}
```

### 2. ユーザーに分かりやすいメッセージ
```swift
enum LocationServiceError: LocalizedError {
    case permissionDenied
    
    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "位置情報の権限がありません"  // 日本語で明確に
        }
    }
}
```

### 3. ログ出力を必ず行う
```swift
Logger.error("API呼び出し失敗", error: error)
```

## パフォーマンスの原則

### 1. Core Dataクエリの最適化
- 述語（Predicate）でフィルタリング
- 必要な属性のみフェッチ
- バッチ操作を活用

### 2. 画像の適切な処理
- リサイズして保存
- 最大4枚まで（`AppConfig.maxPhotosPerVisit`）
- ファイルパスのみCore Dataに保存

### 3. 不要な再レンダリングを避ける
- @Observableで最小限の更新
- LazyVStack/LazyHStack使用

## ドキュメント参照の優先順位

実装時は以下の順序でドキュメントを参照:

1. **CLAUDE.md**: プロジェクト概要を理解
2. **doc/architecture-guide.md**: ベストプラクティスを確認
3. **doc/implementation-guide.md**: 実装手順を確認
4. **doc/ADR/**: 技術的決定の背景を理解
5. **doc/design/**: 該当する設計書があれば参照

## 移行中の注意点

### 旧構成と新構成の混在
現在、旧構成（MVVM）から新構成（Feature-based MV）への移行中:

- **新機能**: 必ず新構成で実装
- **既存機能**: 必要に応じて移行
- **命名**: ViewModelではなくStore使用
- **状態管理**: @Observableマクロ使用

### 段階的な移行
一度に全部移行せず、段階的に移行することでリスクを軽減