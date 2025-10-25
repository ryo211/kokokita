# 実装ガイド

> **重要**: このガイドは実装時の具体的な手順とチェックリストです。実装前に必ず確認してください。

最終更新: 2025-10-24

## 目次

1. [実装前の準備](#実装前の準備)
2. [新機能実装の手順](#新機能実装の手順)
3. [既存機能の変更手順](#既存機能の変更手順)
4. [タスク別ガイド](#タスク別ガイド)
5. [実装チェックリスト](#実装チェックリスト)
6. [トラブルシューティング](#トラブルシューティング)

---

## 実装前の準備

### 1. ドキュメント確認

実装を始める前に以下を必ず読む：

- [ ] `CLAUDE.md` - プロジェクト概要を理解
- [ ] `doc/best-practices.md` - ベストプラクティスを確認
- [ ] `doc/design/[機能名].md` - 該当する設計書があれば読む
- [ ] 関連する`doc/ADR/` - 技術的決定を確認

### 2. 既存コードの調査

類似機能や参考になるコードを探す：

```bash
# 類似機能を検索
grep -r "キーワード" kokokita/

# 関連ファイルを特定
find kokokita/ -name "*ViewModel.swift"
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

### Step 2: データモデルの定義

#### 2.1 Domain Modelの作成

`kokokita/Domain/Models.swift`に追加：

```swift
// ドメインモデル
struct NewFeature: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    // 必要なプロパティ
}
```

**チェックポイント**:
- [ ] `Identifiable`, `Codable`, `Equatable`を適切に実装
- [ ] 不変部分と可変部分を分離
- [ ] オプショナルは最小限に

#### 2.2 Core Data Entity（必要な場合）

Core Dataで永続化する場合は`Kokokita.xcdatamodeld`にエンティティを追加

### Step 3: Repositoryの実装

#### 3.1 プロトコル定義

`kokokita/Domain/Protocols.swift`に追加：

```swift
protocol NewFeatureRepository {
    func create(_ item: NewFeature) throws
    func fetchAll() throws -> [NewFeature]
    func update(_ item: NewFeature) throws
    func delete(id: UUID) throws
}
```

#### 3.2 Repository実装

`kokokita/Infrastructure/CoreDataNewFeatureRepository.swift`を作成：

```swift
final class CoreDataNewFeatureRepository: NewFeatureRepository {
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

### Step 4: Serviceの実装（必要な場合）

ビジネスロジックがある場合は`kokokita/Services/`に作成：

```swift
final class NewFeatureService {
    // ビジネスロジック
    func processData() {
        // ...
    }
}
```

**チェックポイント**:
- [ ] 単一責任原則に従っている
- [ ] UIに依存していない
- [ ] テスト可能な設計

### Step 5: ViewModelの実装

#### 5.1 ViewModelの作成

`kokokita/Presentation/ViewModels/NewFeatureViewModel.swift`を作成：

```swift
@MainActor
final class NewFeatureViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var items: [NewFeature] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    // MARK: - Dependencies
    private let repository: NewFeatureRepository

    // MARK: - Initialization
    init(repository: NewFeatureRepository) {
        self.repository = repository
    }

    // MARK: - Public Methods
    func loadData() {
        isLoading = true
        do {
            items = try repository.fetchAll()
        } catch {
            Logger.error("データ読み込み失敗", error: error)
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
```

**チェックポイント**:
- [ ] `@MainActor`を付与
- [ ] `ObservableObject`に準拠
- [ ] 依存性注入でRepositoryを受け取る
- [ ] `@Published`で状態を公開
- [ ] ビジネスロジックはRepositoryに委譲
- [ ] エラーハンドリング実装

### Step 6: Viewの実装

#### 6.1 Viewファイルの作成

`kokokita/Presentation/Views/NewFeature/NewFeatureView.swift`を作成：

```swift
struct NewFeatureView: View {
    @StateObject private var viewModel: NewFeatureViewModel

    init() {
        // 依存性注入
        _viewModel = StateObject(wrappedValue: NewFeatureViewModel(
            repository: AppContainer.shared.repo
        ))
    }

    var body: some View {
        List(viewModel.items) { item in
            Text(item.name)
        }
        .onAppear {
            viewModel.loadData()
        }
    }
}
```

**チェックポイント**:
- [ ] `@StateObject`でViewModelを保持
- [ ] ビジネスロジックを書いていない
- [ ] ViewModelのメソッド呼び出しのみ
- [ ] 適切なライフサイクルフック（`onAppear`等）

#### 6.2 共通コンポーネントの活用

既存の共通コンポーネントを再利用：

```swift
// 既存コンポーネント例
BigFooterButton("保存", action: { viewModel.save() })
AlertMsg(message: viewModel.errorMessage)
```

### Step 7: DI Containerへの登録

`kokokita/Support/DependencyContainer.swift`にサービスを追加（必要な場合）：

```swift
final class AppContainer {
    static let shared = AppContainer()

    let newFeatureService = NewFeatureService()
    // ...
}
```

### Step 8: 動作確認

- [ ] ビルドが通る
- [ ] 画面が表示される
- [ ] データの取得・保存・更新・削除が動作する
- [ ] エラーケースが適切に処理される

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

- Model変更 → Repository → ViewModel → View の順
- UI変更 → View → ViewModel の順

### Step 3: 設計書の更新

該当する設計書があれば更新：

```markdown
## 変更履歴

- 2025-10-24: [変更内容] - [理由]
```

### Step 4: 動作確認

- [ ] 変更箇所が動作する
- [ ] 既存機能が壊れていない
- [ ] エッジケースも動作する

---

## タスク別ガイド

### 新しい画面の追加

1. **設計書を作成**（推奨）
2. **ViewModelを作成**: `Presentation/ViewModels/`
3. **Viewを作成**: `Presentation/Views/[機能名]/`
4. **ナビゲーションに追加**: `RootTabView`または既存画面から遷移

**ファイル構成例**:
```
Presentation/
├── ViewModels/
│   └── SettingsViewModel.swift
└── Views/
    └── Settings/
        ├── SettingsView.swift
        ├── SettingsRow.swift
        └── AboutSection.swift
```

### 新しいドメインモデルの追加

1. **`Domain/Models.swift`にモデル定義**
2. **必要に応じてCore Dataエンティティ追加**
3. **Repositoryプロトコル定義**: `Domain/Protocols.swift`
4. **Repository実装**: `Infrastructure/CoreData[Name]Repository.swift`
5. **DIコンテナに登録**（必要なら）

### 新しいサービスの追加

1. **プロトコル定義**: `Domain/Protocols.swift`
2. **実装クラス作成**: `Services/[Name]Service.swift`
3. **DIコンテナに登録**: `Support/DependencyContainer.swift`
4. **ViewModelで使用**

### UIコンポーネントの追加

1. **共通コンポーネント**: `Presentation/Views/Common/Components/`
2. **機能固有コンポーネント**: `Presentation/Views/[機能名]/`
3. **再利用性を考慮して設計**

### Core Dataモデルの変更

1. **バックアップを取る**（重要）
2. **`.xcdatamodeld`にバージョン追加**
3. **マイグレーション設定**（軽量マイグレーションが推奨）
4. **Repositoryの実装を更新**
5. **動作確認**（データ移行を含む）

### ローカライゼーションの追加

1. **`Support/Localization/LocalizedString.swift`にキー追加**:
   ```swift
   enum L {
       enum NewFeature {
           static let title = localized("newFeature.title")
       }
   }
   ```

2. **リソースファイルに翻訳追加**:
   - `Resources/ja.lproj/Localizable.strings`
   - `Resources/en.lproj/Localizable.strings`

3. **Viewで使用**:
   ```swift
   Text(L.NewFeature.title)
   ```

---

## 実装チェックリスト

### コード品質

- [ ] ベストプラクティスに準拠している
- [ ] UIとロジックが分離されている
- [ ] 適切なフォルダに配置されている
- [ ] 命名規約に従っている
- [ ] コメントが適切に書かれている
- [ ] 冗長なコードがない

### アーキテクチャ

- [ ] 層の責務が適切に分離されている
- [ ] 依存の方向が正しい（上位→下位）
- [ ] プロトコルを介して依存している
- [ ] 単一責任原則に従っている

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

### 実行時エラー

#### Core Dataの保存エラー
→ 必須属性がnilになっていないか確認
→ `preflightValidate`メソッドでログ確認

#### ViewModelがViewに反映されない
→ `@Published`を付けているか確認
→ `@MainActor`を付けているか確認

### パフォーマンス問題

#### リストのスクロールが重い
→ `LazyVStack`を使用しているか
→ 画像のリサイズを行っているか

#### データ取得が遅い
→ Core Dataの述語フィルタを使用しているか
→ 不要な属性まで取得していないか

---

## 開発効率化のヒント

### Xcodeスニペット

よく使うコードをスニペット登録：

- ViewModel template
- View template
- Repository template

### ビルド時間の短縮

- 増分ビルドを活用
- 不要なimportを削除
- コンパイル時間の長いファイルを特定して最適化

### デバッグ効率化

- `Logger`を積極的に使用
- ブレークポイントの活用
- Xcodeのメモリグラフで循環参照をチェック

---

## フォルダ構成の移行

> **重要**: 詳細な設計判断は `doc/ADR/001-フォルダ構成とアーキテクチャの再設計.md` を参照してください。

### 移行の方針

新しいフォルダ構成への移行は**段階的**に行います：

1. **新規機能は新構成で実装**
2. **既存機能は必要に応じて移行**
3. **一度に全部移行しない**（リスク軽減）

### Phase 1: 新しいフォルダ構造を作成

```bash
# 新しいフォルダを作成
mkdir -p kokokita/Domain/{Models,Logic,Services,Protocols}
mkdir -p kokokita/Domain/Logic/{Calculations,Formatting,Validation,Filtering}
mkdir -p kokokita/Domain/Services/{Location,POI,Photo,Visit}
mkdir -p kokokita/Screens/{Home,Create,Detail,Menu}/Components
mkdir -p kokokita/UIComponents/{Buttons,Forms,Media,Navigation}
mkdir -p kokokita/App/{Config,DI}
mkdir -p kokokita/Utilities/{Extensions,Helpers,Protocols}
mkdir -p kokokita/Resources/Localization
```

### Phase 2: Services の整理と移行（優先度：高）

現在の`Services/`フォルダを`Domain/Services/`に機能別で再編成：

#### 移行対象ファイル

| 現在の場所 | 移行先 | 作業 |
|-----------|--------|------|
| `Services/DefaultLocationService.swift` | `Domain/Services/Location/LocationService.swift` | 移動 + 名前変更 |
| `Services/LocationGeocodingService.swift` | `Domain/Services/Location/` | 移動 |
| `Services/MapKitPlaceLookupService.swift` | `Domain/Services/POI/POIService.swift` | 移動 + 名前変更 |
| `Services/POICoordinatorService.swift` | `Domain/Services/POI/` | 移動 |
| `Services/PhotoEditService.swift` | `Domain/Services/Photo/` | 移動 |
| `Infrastructure/CoreDataVisitRepository.swift` | `Domain/Services/Visit/` ※ | 移動検討 |

※ Repositoryは技術的実装なのでInfrastructureに残すか、Services/に移すか検討

#### 移行手順

```bash
# 例: LocationServiceの移行
git mv Services/DefaultLocationService.swift Domain/Services/Location/LocationService.swift
```

移行後、import文やファイルパスの参照を更新：
```bash
# 全ファイルで参照を検索
grep -r "DefaultLocationService" kokokita/
```

### Phase 3: Presentation の移行（優先度：中）

`Presentation/`を`Screens/`に再編成：

#### 移行対象

| 現在の場所 | 移行先 |
|-----------|--------|
| `Presentation/ViewModels/HomeViewModel.swift` | `Screens/Home/HomeViewModel.swift` |
| `Presentation/Views/Home/HomeView.swift` | `Screens/Home/HomeView.swift` |
| `Presentation/Views/Home/VisitRow.swift` | `Screens/Home/Components/VisitRow.swift` |
| `Presentation/ViewModels/CreateEditViewModel.swift` | `Screens/Create/CreateEditViewModel.swift` |
| `Presentation/Views/Create/CreateView.swift` | `Screens/Create/CreateView.swift` |

#### 移行手順

1. **Screens/Home/を作成**
2. **ViewModelとViewを移動**
   ```bash
   git mv Presentation/ViewModels/HomeViewModel.swift Screens/Home/
   git mv Presentation/Views/Home/HomeView.swift Screens/Home/
   ```
3. **コンポーネントをComponents/に**
   ```bash
   mkdir Screens/Home/Components
   git mv Presentation/Views/Home/VisitRow.swift Screens/Home/Components/
   ```
4. **import文とパスを更新**

### Phase 4: Support/Utilities の整理（優先度：低）

`Support/`を`Utilities/`に整理：

| 現在の場所 | 移行先 |
|-----------|--------|
| `Support/Extensions/` | `Utilities/Extensions/` |
| `Support/Logger.swift` | `Utilities/Helpers/Logger.swift` |
| `Support/KeyboardHelpers.swift` | `Utilities/Helpers/` |
| `Support/Localization/` | `Resources/Localization/` |
| `Support/DependencyContainer.swift` | `App/DI/DependencyContainer.swift` |
| `Config/` | `App/Config/` |

### Phase 5: 純粋な関数の切り出し（優先度：中）

Serviceに混在している純粋なロジックを`Domain/Logic/`に切り出す：

#### 切り出し候補の特定

以下のようなコードを探す：
```swift
// ❌ Service内に純粋なロジックが混在
class VisitService {
    func fetchFiltered(from: Date, to: Date) -> [Visit] {
        let visits = repository.fetchAll()
        // ↓ これは純粋な関数として切り出すべき
        return visits.filter { $0.timestamp >= from && $0.timestamp <= to }
    }
}
```

#### 切り出し後

```swift
// ✅ Domain/Logic/Filtering/VisitFilter.swift
struct VisitFilter {
    static func filterByDateRange(visits: [Visit], from: Date, to: Date) -> [Visit] {
        visits.filter { $0.timestamp >= from && $0.timestamp <= to }
    }
}

// ✅ Domain/Services/Visit/VisitService.swift
class VisitService {
    func fetchFiltered(from: Date, to: Date) -> [Visit] {
        let visits = repository.fetchAll()  // 副作用
        return VisitFilter.filterByDateRange(visits: visits, from: from, to: to)  // 純粋
    }
}
```

### 移行時の注意点

#### ビルドエラーを避ける

- 移行は小さな単位で行う
- 1ファイル移行したら必ずビルド確認
- git commitを細かく実施

#### インポート文の更新

移動後、全ファイルで参照を検索：
```bash
# 例: HomeViewModelを移動した場合
grep -r "import.*HomeViewModel" kokokita/
grep -r "HomeViewModel" kokokita/ | grep -v ".swift:"
```

#### Xcode プロジェクトファイルの更新

ファイルを移動したら、Xcodeプロジェクトで：
1. 古いファイルを削除（参照のみ）
2. 新しい場所からファイルを追加

または、プロジェクトファイルを直接編集（上級者向け）

### 移行チェックリスト

各Phase完了時に確認：

- [ ] すべてのファイルが正しい場所に配置されている
- [ ] ビルドが通る
- [ ] 既存機能が動作する
- [ ] import文が正しい
- [ ] Xcodeプロジェクトファイルが更新されている
- [ ] 移行内容をコミット

### トラブルシューティング

#### "No such module" エラー

→ import文を確認。相対パスから絶対パスに変更する必要がある場合も

#### ファイルが見つからない

→ Xcodeで該当ファイルを削除し、新しい場所から再追加

#### ビルドは通るが参照エラー

→ Xcodeの「Clean Build Folder」を実行（Cmd+Shift+K）

---

## 更新履歴

- 2025-10-24: フォルダ構成の移行手順を追加
- 初版作成

このドキュメントは継続的に更新されます。実装で得た知見は積極的に追加してください。
