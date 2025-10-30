# MVVM から Feature-based MV への移行ガイド

> **重要**: このドキュメントは既存のMVVMアーキテクチャから新しいFeature-based MVアーキテクチャへの移行専用ガイドです。

最終更新: 2025-10-30

## 目次

- [移行の背景と方針](#移行の背景と方針)
- [移行前の準備](#移行前の準備)
- [移行フェーズ](#移行フェーズ)
  - [Phase 1: 新しいフォルダ構造を作成](#phase-1-新しいフォルダ構造を作成)
  - [Phase 2: Shared/の整理と移行](#phase-2-sharedの整理と移行)
  - [Phase 3: Features/への移行](#phase-3-featuresへの移行)
  - [Phase 4: ViewModelからStoreへの変換](#phase-4-viewmodelからstoreへの変換)
  - [Phase 5: 純粋な関数の切り出し](#phase-5-純粋な関数の切り出し)
- [移行チェックリスト](#移行チェックリスト)
- [トラブルシューティング](#トラブルシューティング)

---

## 移行の背景と方針

### なぜ移行するのか

- **iOS 17+の@Observableマクロ活用**: ボイラープレートコードの削減
- **Feature-based構成**: 機能単位でコードをコロケーション（関連コードを近くに配置）
- **純粋な関数とServiceの明確な分離**: テスタビリティとメンテナンス性の向上
- **MVVMからMVへ**: ViewModelを排除しシンプルなアーキテクチャへ

### 移行の基本方針

1. **段階的移行**: 一度に全部移行せず、フェーズごとに進める
2. **新規機能は新構成で**: 新しい機能は必ずFeature-based MVで実装
3. **既存機能は必要に応じて**: 影響の少ないものから順次移行
4. **リスク軽減**: 小さな単位で移行し、都度ビルド確認とコミット

---

## 移行前の準備

### 1. 関連ドキュメントの確認

移行前に以下を必ず読む:

- [ ] `doc/ADR/001-フォルダ構成とアーキテクチャの再設計.md` - 設計判断の背景
- [ ] `doc/architecture-guide.md` - 新アーキテクチャの原則とベストプラクティス
- [ ] `doc/implementation-guide.md` - 実装手順

### 2. バックアップの作成

```bash
# ブランチを作成
git checkout -b refactor/migration-to-mv

# 現在の状態をコミット
git add .
git commit -m "移行前の状態を保存"
```

### 3. 依存関係の把握

```bash
# ViewModelの使用箇所を確認
grep -r "ViewModel" kokokita/ --include="*.swift"

# ObservableObjectの使用箇所を確認
grep -r "ObservableObject" kokokita/ --include="*.swift"

# @Publishedの使用箇所を確認
grep -r "@Published" kokokita/ --include="*.swift"
```

---

## 移行フェーズ

### Phase 1: 新しいフォルダ構造を作成

#### 1.1 Feature-based構成のフォルダを作成

```bash
# Featuresフォルダ（機能単位）
mkdir -p Features/{Home,Create,Detail,Menu}/{Models,Logic,Services,Views/Components}

# Sharedフォルダ（共通コード）
mkdir -p Shared/{Models,Logic,Services,UIComponents}
mkdir -p Shared/Logic/{Calculations,Formatting,Validation}
mkdir -p Shared/Services/{Persistence,Security}
mkdir -p Shared/UIComponents/{Buttons,Forms,Media}

# Appフォルダ（アプリケーション設定）
mkdir -p App/{Config,DI}

# Utilitiesフォルダ（汎用ユーティリティ）
mkdir -p Utilities/{Extensions,Helpers,Protocols}

# Resourcesフォルダ（リソース）
mkdir -p Resources/Localization
```

#### 1.2 Xcodeプロジェクトにフォルダを追加

Xcodeで:
1. 作成したフォルダをプロジェクトナビゲータにドラッグ
2. "Create folder references"を選択
3. ターゲットに追加

---

### Phase 2: Shared/の整理と移行

> **優先度: 高** - 共通コードを先に整理することで、後の移行がスムーズになります

#### 2.1 共通モデルの移行

**現在の場所** → **移行先**:

| 現在 | 移行先 | 作業 |
|------|--------|------|
| `Domain/Models.swift` | `Shared/Models/` | ファイルを分割して移動 |
| `Visit` | `Shared/Models/Visit.swift` | 抽出 |
| `VisitDetails` | `Shared/Models/VisitDetails.swift` | 抽出 |
| `VisitAggregate` | `Shared/Models/VisitAggregate.swift` | 抽出 |
| `LabelTag`, `GroupTag`, `MemberTag` | `Shared/Models/Taxonomy.swift` | 抽出してまとめる |
| `Location` | `Shared/Models/Location.swift` | 抽出 |

**手順**:

```bash
# 1. 新しいファイルを作成し、該当するモデルを移動
# 2. 元のファイルから削除
# 3. import文を更新
# 4. ビルド確認
# 5. コミット
```

**例**:

```swift
// Shared/Models/Visit.swift
import Foundation

/// 訪問記録の不変部分（改ざん検出データ）
struct Visit: Identifiable, Codable, Equatable {
    let id: UUID
    let timestampUTC: Date
    let lat: Double
    let lon: Double
    let acc: Double
    let isSimulatedBySoftware: Bool
    let isProducedByAccessory: Bool
    let signature: String
    let publicKeyPEM: String
}
```

#### 2.2 共通Serviceの移行

| 現在 | 移行先 |
|------|--------|
| `Infrastructure/CoreDataVisitRepository.swift` | `Shared/Services/Persistence/VisitRepository.swift` |
| `Infrastructure/CoreDataTaxonomyRepository.swift` | `Shared/Services/Persistence/TaxonomyRepository.swift` |
| `Infrastructure/CoreDataStack.swift` | `Shared/Services/Persistence/CoreDataStack.swift` |
| `Infrastructure/DefaultIntegrityService.swift` | `Shared/Services/Security/IntegrityService.swift` |

**手順**:

```bash
# 例: VisitRepositoryの移行
git mv Infrastructure/CoreDataVisitRepository.swift Shared/Services/Persistence/VisitRepository.swift

# Xcodeでファイル参照を更新
# 1. Xcodeで古い参照を削除
# 2. 新しい場所から追加

# ビルド確認
xcodebuild -project kokokita.xcodeproj -scheme kokokita -sdk iphonesimulator build

# コミット
git add .
git commit -m "Shared/Services/Persistence/にVisitRepositoryを移行"
```

---

### Phase 3: Features/への移行

> **優先度: 中〜高** - 新規機能から順に移行

#### 3.1 新規機能の実装ルール

**新機能は必ずFeatures/で実装**:

```
Features/
└── [新機能名]/
    ├── Models/
    │   └── [機能名]Store.swift     # @Observable
    ├── Logic/
    │   └── [処理名].swift          # 純粋な関数
    ├── Services/
    │   └── [機能名]Service.swift   # 副作用
    └── Views/
        ├── [機能名]View.swift
        └── Components/
```

#### 3.2 既存機能の移行（例: Menu機能）

**移行手順**:

```bash
# 1. フォルダ作成
mkdir -p Features/Menu/{Models,Views}

# 2. ViewModelをStoreに変換して移動
# Presentation/ViewModels/MenuViewModel.swift → Features/Menu/Models/MenuStore.swift

# 3. Viewを移動
git mv Presentation/Views/Menu/MenuView.swift Features/Menu/Views/

# 4. import文を更新
# 5. ビルド確認
# 6. コミット
git add .
git commit -m "Menu機能をFeatures/Menuに移行"
```

**移行優先順位**（影響の少ない順）:

1. **Menu機能** - 依存が少ない
2. **Detail機能** - 比較的独立
3. **Create機能** - 複数のServiceに依存
4. **Home機能** - 多くの機能と連携

---

### Phase 4: ViewModelからStoreへの変換

> **重要**: MVVMパターンからMVパターンへの中心的な変更

#### 4.1 変換対比表

| 項目 | MVVM（旧） | MV（新） |
|------|-----------|---------|
| 状態管理 | `ViewModel (ObservableObject)` | `Store (@Observable)` |
| プロパティ宣言 | `@Published var items: [Item]` | `var items: [Item]` |
| Viewでの保持 | `@StateObject private var viewModel` | `@State private var store` |
| ボイラープレート | Combine、@Published | 最小限 |
| 複雑性 | 中〜高 | 低 |
| iOS要件 | iOS 13+ | iOS 17+ |

#### 4.2 ViewModelからStoreへの変換手順

**Before (旧MVVM)**:

```swift
// Presentation/ViewModels/HomeViewModel.swift
import Foundation
import Combine

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var visits: [Visit] = []
    @Published var isLoading = false

    private let repository: VisitRepository
    private var cancellables = Set<AnyCancellable>()

    init(repository: VisitRepository) {
        self.repository = repository
    }

    func load() {
        isLoading = true
        repository.fetchAll()
            .sink(
                receiveCompletion: { _ in
                    self.isLoading = false
                },
                receiveValue: { visits in
                    self.visits = visits
                }
            )
            .store(in: &cancellables)
    }
}
```

**After (Feature-based MV)**:

```swift
// Features/Home/Models/HomeStore.swift
import Foundation
import Observation

@Observable
final class HomeStore {
    // MARK: - State
    var visits: [Visit] = []
    var isLoading = false
    var errorMessage: String?

    // MARK: - Dependencies
    private let visitService: VisitService

    // MARK: - Initialization
    init(visitService: VisitService = .shared) {
        self.visitService = visitService
    }

    // MARK: - Actions
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

**変換チェックリスト**:

- [ ] `ObservableObject` → `@Observable`
- [ ] `@Published` を削除（通常のプロパティに）
- [ ] `@MainActor` を削除（@Observableが自動対応）
- [ ] Combineの`import`を削除
- [ ] `import Observation` を追加
- [ ] `cancellables`を削除
- [ ] ViewModelという名前 → Store
- [ ] Combine処理 → async/await

#### 4.3 Viewの変換

**Before**:

```swift
struct HomeView: View {
    @StateObject private var viewModel: HomeViewModel

    var body: some View {
        List(viewModel.visits) { visit in
            VisitRow(visit: visit)
        }
        .onAppear {
            viewModel.load()
        }
    }
}
```

**After**:

```swift
struct HomeView: View {
    @State private var store = HomeStore()

    var body: some View {
        List(store.visits) { visit in
            VisitRow(visit: visit)
        }
        .task {
            await store.load()
        }
    }
}
```

**変換チェックリスト**:

- [ ] `@StateObject` → `@State`
- [ ] `viewModel` → `store`
- [ ] `.onAppear` → `.task`（async処理の場合）
- [ ] 初期化方法の変更（`@State private var store = HomeStore()`）

---

### Phase 5: 純粋な関数の切り出し

> **目的**: 副作用のないロジックをLogic/に切り出し、テスタビリティを向上

#### 5.1 切り出し候補の特定

Serviceに混在している純粋なロジックを確認:

```bash
# Serviceファイルを確認
grep -r "func.*->.*{" Features/*/Services/
grep -r "func.*->.*{" Shared/Services/
```

**純粋な関数の特徴**:

- 副作用なし（DB、API、ファイルI/O等を呼ばない）
- 同じ入力 → 常に同じ出力
- 外部状態に依存しない
- 計算、フィルタリング、フォーマット、バリデーション等

#### 5.2 切り出し例

**Before**:

```swift
// Services/VisitService.swift
class VisitService {
    func fetchFiltered(from: Date, to: Date) async throws -> [Visit] {
        let visits = try await repository.fetchAll()
        // ↓ これは純粋な関数として切り出すべき
        return visits.filter { $0.timestamp >= from && $0.timestamp <= to }
    }

    func formatDate(_ date: Date) -> String {
        // ↓ これも純粋な関数
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}
```

**After**:

```swift
// Features/Home/Logic/VisitFilter.swift（または Shared/Logic/）
struct VisitFilter {
    /// 日付範囲でフィルタリング（純粋な関数）
    static func filterByDateRange(
        visits: [Visit],
        from: Date,
        to: Date
    ) -> [Visit] {
        visits.filter { $0.timestamp >= from && $0.timestamp <= to }
    }
}

// Shared/Logic/Formatting/DateFormatHelper.swift
struct DateFormatHelper {
    /// 日付をフォーマット（純粋な関数）
    static func formatVisitDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: date)
    }
}

// Features/Home/Services/VisitService.swift
class VisitService {
    func fetchFiltered(from: Date, to: Date) async throws -> [Visit] {
        let visits = try await repository.fetchAll()  // 副作用
        return VisitFilter.filterByDateRange(
            visits: visits,
            from: from,
            to: to
        )  // 純粋な関数を呼び出し
    }
}
```

#### 5.3 Logic配置の判断基準

**機能固有のLogic**:
```
Features/[機能名]/Logic/
```

**複数機能で使用するLogic**:
```
Shared/Logic/
├── Calculations/      # 計算系
├── Formatting/        # フォーマット系
└── Validation/        # バリデーション系
```

---

## 移行チェックリスト

### Phase完了時の確認

各Phase完了時に確認:

- [ ] すべてのファイルが正しい場所に配置されている
- [ ] ビルドが通る
- [ ] 既存機能が動作する
- [ ] import文が正しい
- [ ] Xcodeプロジェクトファイルが更新されている
- [ ] 移行内容をコミット

### アーキテクチャ確認

- [ ] ViewModelではなくStoreを使用している
- [ ] @Observableマクロを使用している（@Publishedではない）
- [ ] 純粋な関数とServiceが分離されている
- [ ] Feature単位でコロケーションされている

### コード品質確認

- [ ] 命名規約に従っている（Store、Service、Logic）
- [ ] 依存性注入が適切に行われている
- [ ] エラーハンドリングが実装されている
- [ ] ログが適切に出力されている

---

## トラブルシューティング

### ビルドエラー

#### "No such module 'Observation'"

**原因**: iOS 17+が必要

**解決策**:
```swift
// プロジェクト設定で確認
// Deployment Target: iOS 17.0以上
```

#### "Property wrapper cannot be applied to a computed property"

**原因**: @Observableと@Publishedを併用している

**解決策**:
```swift
// ❌ 間違い
@Observable
class Store {
    @Published var items: [Item] = []  // エラー
}

// ✅ 正しい
@Observable
class Store {
    var items: [Item] = []  // @Publishedは不要
}
```

#### "Cannot find type 'XXX' in scope"

**原因**: import文が不足、またはファイルがターゲットに含まれていない

**解決策**:
1. 必要なimport文を追加
2. Xcodeでファイルがターゲットに含まれているか確認

### 実行時エラー

#### Storeの変更がViewに反映されない

**原因**: @Stateではなく@StateObjectを使用している

**解決策**:
```swift
// ❌ 間違い（旧パターン）
@StateObject private var viewModel: HomeViewModel

// ✅ 正しい（新パターン）
@State private var store = HomeStore()
```

#### "Stored properties cannot be marked potentially isolated"

**原因**: @MainActorと@Observableの競合

**解決策**:
```swift
// ❌ 間違い
@MainActor
@Observable
class Store { }

// ✅ 正しい（@MainActorは不要）
@Observable
class Store { }
```

### Xcodeプロジェクト関連

#### ファイルが見つからない（グレーアウト）

**原因**: ファイルを移動したがXcodeの参照が更新されていない

**解決策**:
1. Xcodeで該当ファイルを削除（参照のみ）
2. 新しい場所からファイルを追加
3. "Add to targets"でターゲットを選択

#### ビルドは通るが参照エラー

**原因**: ビルドキャッシュが古い

**解決策**:
```bash
# Xcodeの「Clean Build Folder」を実行
# Cmd+Shift+K

# または派生データを削除
rm -rf ~/Library/Developer/Xcode/DerivedData
```

---

## 移行時の注意点

### 小さな単位で移行

- 1ファイルまたは1機能ずつ移行
- 移行したら必ずビルド確認
- git commitを細かく実施

### インポート文の更新

移動後、全ファイルで参照を検索:

```bash
# 例: HomeStoreを移動した場合
grep -r "HomeStore" kokokita/ --include="*.swift"

# 例: VisitRepositoryを移動した場合
grep -r "VisitRepository" kokokita/ --include="*.swift"
```

### 並行開発への配慮

チーム開発の場合:

- 移行計画を共有
- 大きな変更は専用ブランチで
- 定期的にmainブランチをマージ
- コンフリクトを最小化

---

## 参考資料

- [ADR-001: フォルダ構成とアーキテクチャの再設計](../ADR/001-フォルダ構成とアーキテクチャの再設計.md)
- [アーキテクチャガイド](../architecture-guide.md)
- [実装ガイド](../implementation-guide.md)
- [Apple Developer Documentation: Observation](https://developer.apple.com/documentation/observation)
- [Apple Developer Documentation: Managing model data in your app](https://developer.apple.com/documentation/swiftui/managing-model-data-in-your-app)

---

## 更新履歴

- 2025-10-30: 初版作成 - MVVM→MV移行ガイド
