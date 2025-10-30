# 実装ガイド

> **重要**: このガイドは実装時の具体的な手順とチェックリストです。

## このドキュメントについて

このドキュメントは**「どうやって実装するか」**の具体的な手順を説明します。

### 実装前に必ず読むこと

**[アーキテクチャガイド](./architecture-guide.md) を先に読んで設計原則を理解してください。**

- アーキテクチャガイド: 「なぜこの設計なのか」「何を守るべきか」を理解
- 実装ガイド（本ドキュメント）: 「どうやって実装するか」の手順を確認

### 関連ドキュメント

- **設計原則とベストプラクティス** → [アーキテクチャガイド](./architecture-guide.md)
- **既存コードの移行** → [MVVM→MV移行ガイド](./migration/mvvm-to-mv-migration-guide.md)
- **設計判断の背景** → [ADR-001: フォルダ構成とアーキテクチャの再設計](./ADR/001-フォルダ構成とアーキテクチャの再設計.md)

最終更新: 2025-10-30

---

## 実装前の準備

### 1. ドキュメント確認

実装を始める前に以下を必ず読む：

- [ ] [アーキテクチャガイド](./architecture-guide.md) - **必読**: 設計原則とベストプラクティスを理解
- [ ] `CLAUDE.md` - プロジェクト概要を理解
- [ ] [ADR-001: フォルダ構成とアーキテクチャの再設計](./ADR/001-フォルダ構成とアーキテクチャの再設計.md) - Feature-based MVアーキテクチャの設計判断を理解
- [ ] `doc/design/[機能名].md` - 該当する設計書があれば読む

### 2. 既存コードの調査

類似機能や参考になるコードを探す：

```bash
# 類似機能を検索
grep -r "キーワード" kokokita/

# 関連ファイルを特定
find kokokita/ -name "*Store.swift"
find kokokita/ -name "*Service.swift"
```

### 3. 影響範囲の把握

変更が他の部分に影響しないか確認：

- [ ] 同じモデルを使用している箇所はないか
- [ ] 同じサービスを使用している箇所はないか
- [ ] UIの変更が他の画面に影響しないか

---

## 新機能実装の手順

### Step 1: 設計の明確化

#### 1.1 要件の整理

- ユーザーストーリーを書く
- 入力と出力を明確にする
- エッジケースをリストアップ

#### 1.2 設計書の作成（推奨）

複雑な機能の場合は`doc/design/[機能名].md`を作成：

```bash
cp doc/design/template.md doc/design/新機能名.md
```

必要な部分だけ埋める（全部埋める必要はない）

### Step 2: フォルダ構成の決定

#### 2.1 機能の配置先を決める

**1つの機能でのみ使用する場合**:
```
Features/[機能名]/
```

**複数の機能で使用する場合**:
```
Shared/
```

#### 2.2 フォルダを作成

```bash
# 新機能（例: Statistics）
mkdir -p Features/Statistics/{Models,Logic,Services,Views/Components}
```

### Step 3: データモデルの定義

#### 3.1 Domain Modelの作成または確認

**共通モデル**は`Shared/Models/`に配置：

```swift
// Shared/Models/Visit.swift
struct Visit: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var timestamp: Date
    // 必要なプロパティ
}
```

**機能固有モデル**は`Features/[機能名]/Models/`に配置

**チェックポイント**:
- [ ] `Identifiable`, `Codable`, `Equatable`を適切に実装
- [ ] 不変部分と可変部分を分離
- [ ] オプショナルは最小限に

#### 3.2 Core Data Entity（必要な場合）

Core Dataで永続化する場合は`Kokokita.xcdatamodeld`にエンティティを追加

### Step 4: Repositoryの実装（必要な場合）

#### 4.1 プロトコル定義

`Shared/Models/`またはプロトコル専用ファイルに追加：

```swift
protocol VisitRepository {
    func create(_ item: Visit) async throws
    func fetchAll() async throws -> [Visit]
    func update(_ item: Visit) async throws
    func delete(id: UUID) async throws
}
```

#### 4.2 Repository実装

`Shared/Services/Persistence/`に作成：

```swift
// Shared/Services/Persistence/CoreDataVisitRepository.swift
final class CoreDataVisitRepository: VisitRepository {
    private let ctx: NSManagedObjectContext

    init(context: NSManagedObjectContext = CoreDataStack.shared.context) {
        self.ctx = context
    }

    // プロトコルメソッドの実装
}
```

**チェックポイント**:
- [ ] プロトコルに準拠
- [ ] エラーハンドリング実装
- [ ] 必須フィールドのバリデーション
- [ ] async/awaitを使用

### Step 5: Logicの実装（純粋な関数）

副作用のない計算やフォーマットは`Logic/`に配置：

```swift
// Features/Statistics/Logic/VisitStatisticsCalculator.swift
struct VisitStatisticsCalculator {
    /// 訪問数を集計する（純粋な関数）
    static func countByMonth(visits: [Visit]) -> [String: Int] {
        // 副作用なし、同じ入力 → 同じ出力
        var result: [String: Int] = [:]
        // 計算ロジック
        return result
    }
}
```

**チェックポイント**:
- [ ] 副作用がない（DB、API、ログ等を呼ばない）
- [ ] 同じ入力で常に同じ出力
- [ ] テスト容易
- [ ] static funcとして実装

### Step 6: Serviceの実装（副作用のある処理）

副作用のある処理は`Services/`に配置：

```swift
// Features/Statistics/Services/StatisticsService.swift
final class StatisticsService {
    static let shared = StatisticsService()

    private let visitRepository: VisitRepository

    init(visitRepository: VisitRepository = CoreDataVisitRepository()) {
        self.visitRepository = visitRepository
    }

    /// 統計データを取得（副作用あり: DB操作）
    func fetchStatistics() async throws -> [Visit] {
        try await visitRepository.fetchAll()  // DB操作 = 副作用
    }
}
```

**チェックポイント**:
- [ ] ステートレス（状態を持たない）
- [ ] 単一責任原則に従っている
- [ ] UIに依存していない
- [ ] テスト可能な設計（DI可能）

### Step 7: Storeの実装（@Observable）

#### 7.1 Storeの作成

`Features/[機能名]/Models/`に配置：

```swift
// Features/Statistics/Models/StatisticsStore.swift
import Foundation
import Observation

@Observable
final class StatisticsStore {
    // MARK: - State
    var visits: [Visit] = []
    var statistics: [String: Int] = [:]
    var isLoading = false
    var errorMessage: String?

    // MARK: - Dependencies
    private let statisticsService: StatisticsService

    // MARK: - Initialization
    init(statisticsService: StatisticsService = .shared) {
        self.statisticsService = statisticsService
    }

    // MARK: - Actions
    func load() async {
        isLoading = true
        errorMessage = nil

        do {
            // Serviceから副作用のある処理を実行
            visits = try await statisticsService.fetchStatistics()

            // Logicで純粋な計算を実行
            statistics = VisitStatisticsCalculator.countByMonth(visits: visits)
        } catch {
            Logger.error("統計データ読み込み失敗", error: error)
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}
```

**チェックポイント**:
- [ ] `@Observable`マクロを付与
- [ ] 通常のプロパティ（`@Published`は不要）
- [ ] 依存性注入でServiceを受け取る
- [ ] ビジネスロジックはServiceとLogicに委譲
- [ ] エラーハンドリング実装
- [ ] async/awaitを使用

### Step 8: Viewの実装

#### 8.1 Viewファイルの作成

`Features/[機能名]/Views/`に配置：

```swift
// Features/Statistics/Views/StatisticsView.swift
import SwiftUI

struct StatisticsView: View {
    @State private var store = StatisticsStore()

    var body: some View {
        NavigationStack {
            Group {
                if store.isLoading {
                    ProgressView("読み込み中...")
                } else {
                    List {
                        ForEach(store.statistics.sorted(by: { $0.key < $1.key }), id: \.key) { month, count in
                            HStack {
                                Text(month)
                                Spacer()
                                Text("\(count)件")
                            }
                        }
                    }
                }
            }
            .navigationTitle("統計")
            .task {
                await store.load()
            }
            .alert("エラー",
                   isPresented: .constant(store.errorMessage != nil),
                   presenting: store.errorMessage) { _ in
                Button("OK") {
                    store.errorMessage = nil
                }
            } message: { message in
                Text(message)
            }
        }
    }
}
```

**チェックポイント**:
- [ ] `@State`でStoreを保持（`@StateObject`ではない）
- [ ] ビジネスロジックを書いていない
- [ ] Storeのメソッド呼び出しのみ
- [ ] 適切なライフサイクルフック（`.task`等）
- [ ] エラー表示の実装

#### 8.2 コンポーネントの作成

機能専用のコンポーネントは`Components/`に配置：

```swift
// Features/Statistics/Views/Components/ChartView.swift
import SwiftUI

struct ChartView: View {
    let data: [String: Int]

    var body: some View {
        // チャート表示
    }
}
```

共通コンポーネントは`Shared/UIComponents/`に配置

### Step 9: 動作確認

- [ ] ビルドが通る
- [ ] 画面が表示される
- [ ] データの取得・保存・更新・削除が動作する
- [ ] エラーケースが適切に処理される
- [ ] ローディング状態が表示される

---

## 既存機能の変更手順

### Step 1: 変更の影響範囲を調査

#### 1.1 依存関係の確認

変更するファイルを使用している箇所を検索：

```bash
# クラス名や関数名で検索
grep -r "ClassName" kokokita/
```

#### 1.2 テスト実行（ある場合）

変更前にテストが通ることを確認

### Step 2: 変更の実装

変更箇所に応じて実装：

- Model変更 → Repository → Service → Store → View の順
- UI変更 → View → Store の順

### Step 3: 設計書の更新

該当する設計書があれば更新：

```markdown
## 変更履歴

- 2025-10-25: [変更内容] - [理由]
```

### Step 4: 動作確認

- [ ] 変更箇所が動作する
- [ ] 既存機能が壊れていない
- [ ] エッジケースも動作する

---

## タスク別ガイド

### 新しい画面の追加

1. **フォルダを作成**
   ```bash
   mkdir -p Features/Settings/{Models,Views/Components}
   ```

2. **Storeを作成**: `Features/Settings/Models/SettingsStore.swift`

3. **Viewを作成**: `Features/Settings/Views/SettingsView.swift`

4. **ナビゲーションに追加**: `RootTabView`または既存画面から遷移

**ファイル構成例**:
```
Features/
└── Settings/
    ├── Models/
    │   └── SettingsStore.swift
    └── Views/
        ├── SettingsView.swift
        └── Components/
            ├── SettingsRow.swift
            └── AboutSection.swift
```

### 新しいドメインモデルの追加

1. **`Shared/Models/`にモデル定義**
2. **必要に応じてCore Dataエンティティ追加**
3. **Repositoryプロトコル定義**
4. **Repository実装**: `Shared/Services/Persistence/`
5. **DIコンテナに登録**（必要なら）

### 新しいServiceの追加

#### 機能固有のService

```bash
# 機能固有のServiceは機能フォルダ内に
mkdir -p Features/[機能名]/Services
```

```swift
// Features/Statistics/Services/StatisticsService.swift
final class StatisticsService {
    static let shared = StatisticsService()
    // 実装
}
```

#### 共通Service

```bash
# 共通Serviceは Shared/Services/
mkdir -p Shared/Services/[カテゴリ名]
```

```swift
// Shared/Services/Analytics/AnalyticsService.swift
final class AnalyticsService {
    static let shared = AnalyticsService()
    // 実装
}
```

### 新しい純粋な関数（Logic）の追加

#### 機能固有のLogic

```swift
// Features/Home/Logic/VisitFilter.swift
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

#### 共通Logic

```swift
// Shared/Logic/Calculations/DistanceCalculator.swift
struct DistanceCalculator {
    static func distance(from: CLLocation, to: CLLocation) -> Double {
        from.distance(from: to)
    }
}
```

### UIコンポーネントの追加

#### 機能専用コンポーネント

```
Features/[機能名]/Views/Components/
```

#### 共通コンポーネント

```
Shared/UIComponents/
├── Buttons/
├── Forms/
└── Media/
```

### Core Dataモデルの変更

1. **バックアップを取る**（重要）
2. **`.xcdatamodeld`にバージョン追加**
3. **マイグレーション設定**（軽量マイグレーションが推奨）
4. **Repositoryの実装を更新**
5. **動作確認**（データ移行を含む）

### ローカライゼーションの追加

1. **`Resources/Localization/LocalizedString.swift`にキー追加**:
   ```swift
   enum L {
       enum Statistics {
           static let title = localized("statistics.title")
       }
   }
   ```

2. **リソースファイルに翻訳追加**:
   - `Resources/ja.lproj/Localizable.strings`
   - `Resources/en.lproj/Localizable.strings`

3. **Viewで使用**:
   ```swift
   Text(L.Statistics.title)
   ```

---

## 実装チェックリスト

### コード品質

- [ ] ベストプラクティスに準拠している
- [ ] UIとロジックが分離されている
- [ ] 適切なフォルダに配置されている（Feature-based）
- [ ] 命名規約に従っている（Store、Service、Logic）
- [ ] コメントが適切に書かれている
- [ ] 冗長なコードがない

### アーキテクチャ（Feature-based MV）

- [ ] 機能単位でコロケーションされている
- [ ] Viewは表示のみ
- [ ] Storeは状態管理とServiceとの結合のみ
- [ ] Serviceは副作用のみ（ステートレス）
- [ ] Logicは純粋な関数のみ（副作用なし）
- [ ] @Observableマクロを使用（ObservableObjectではない）

### エラーハンドリング

- [ ] エラーケースが適切に処理されている
- [ ] ユーザーに分かりやすいエラーメッセージ
- [ ] ログが適切に出力されている

### パフォーマンス

- [ ] 不要な再レンダリングがない
- [ ] Core Dataクエリが最適化されている
- [ ] メモリリークがない（循環参照チェック）

### セキュリティ

- [ ] 機密情報がハードコーディングされていない
- [ ] ユーザーデータが適切に扱われている
- [ ] 入力値のバリデーションがある

### ドキュメント

- [ ] 必要に応じて設計書を作成/更新
- [ ] 重要な決定はADRに記録
- [ ] コメントで「なぜ」が説明されている

---

## トラブルシューティング

### ビルドエラー

#### "Type does not conform to protocol"
→ プロトコルの必須メソッドを実装しているか確認

#### "Cannot find type 'XXX' in scope"
→ importが足りないか、ファイルがターゲットに含まれているか確認

#### "Property wrapper cannot be applied to a computed property"
→ @Observableを使用している場合、@Publishedは不要。通常のプロパティに変更

### 実行時エラー

#### Core Dataの保存エラー
→ 必須属性がnilになっていないか確認
→ `preflightValidate`メソッドでログ確認

#### StoreがViewに反映されない
→ `@State`を使用しているか確認（`@StateObject`ではない）
→ `@Observable`マクロを付けているか確認
→ `import Observation`を忘れていないか確認

### パフォーマンス問題

#### リストのスクロールが重い
→ `LazyVStack`を使用しているか
→ 画像のリサイズを行っているか

#### データ取得が遅い
→ Core Dataの述語フィルタを使用しているか
→ 不要な属性まで取得していないか

---

## 関連ドキュメント

- [アーキテクチャガイド](./architecture-guide.md) - 設計原則とベストプラクティス
- [MVVM→MV移行ガイド](./migration/mvvm-to-mv-migration-guide.md) - 既存コードの移行手順
- [ADR-001: フォルダ構成とアーキテクチャの再設計](./ADR/001-フォルダ構成とアーキテクチャの再設計.md) - 設計判断の背景

---

## 開発効率化のヒント

### Xcodeスニペット

よく使うコードをスニペット登録：

- Store template (@Observable)
- View template
- Service template
- Logic template

### ビルド時間の短縮

- 増分ビルドを活用
- 不要なimportを削除
- コンパイル時間の長いファイルを特定して最適化

### デバッグ効率化

- `Logger`を積極的に使用
- ブレークポイントの活用
- Xcodeのメモリグラフで循環参照をチェック
