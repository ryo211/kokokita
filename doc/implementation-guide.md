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

### 2. 既存コードの調査と影響範囲の把握

```bash
grep -r "キーワード" kokokita/        # 類似機能検索
find kokokita/ -name "*Store.swift"  # 関連ファイル特定
```

- [ ] 同じモデル/サービスを使用している箇所を確認
- [ ] UI変更の影響範囲を確認

---

## 新機能実装の手順

### Step 1: 設計の明確化

- ユーザーストーリー、入力/出力、エッジケースを整理
- 複雑な機能は設計書作成（`doc/design/[機能名].md`）

### Step 2: フォルダ構成の決定

- 1機能のみ: `Features/[機能名]/` | 複数機能: `Shared/`

```bash
mkdir -p Features/Statistics/{Models,Logic,Services,Views/Components}
```

### Step 3: データモデルの定義

```swift
// Shared/Models/ または Features/[機能名]/Models/
struct Visit: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
}
```

**チェック**: `Identifiable`/`Codable`/`Equatable`実装、不変/可変分離、オプショナル最小限
**Core Data**: 永続化する場合は`.xcdatamodeld`にエンティティ追加

### Step 4: Repositoryの実装（必要な場合）

```swift
// Protocol: Shared/Models/
protocol VisitRepository {
    func fetchAll() async throws -> [Visit]
}

// Implementation: Shared/Services/Persistence/
final class CoreDataVisitRepository: VisitRepository {
    func fetchAll() async throws -> [Visit] { /* 実装 */ }
}
```

**チェック**: プロトコル準拠、エラーハンドリング、async/await使用

### Step 5: Logicの実装（純粋な関数）

```swift
// Features/[機能]/Logic/ または Shared/Logic/
struct VisitFilter {
    static func filterByDate(visits: [Visit], from: Date) -> [Visit] {
        visits.filter { $0.timestamp >= from }
    }
}
```

**チェック**: 副作用なし、同じ入力→同じ出力、static func

### Step 6: Serviceの実装（副作用のある処理）

```swift
// Features/[機能]/Services/ または Shared/Services/
final class VisitService {
    static let shared = VisitService()
    private let repository: VisitRepository

    func fetchAll() async throws -> [Visit] {
        try await repository.fetchAll()  // DB = 副作用
    }
}
```

**チェック**: ステートレス、単一責任、UIに非依存、DI可能

### Step 7: Storeの実装（@Observable）

```swift
// Features/[機能名]/Models/[機能名]Store.swift
@Observable
final class HomeStore {
    var visits: [Visit] = []
    var isLoading = false
    private let service: VisitService

    init(service: VisitService = .shared) {
        self.service = service
    }

    func load() async {
        isLoading = true
        do {
            visits = try await service.fetchAll()
        } catch {
            Logger.error("読み込み失敗", error: error)
        }
        isLoading = false
    }
}
```

**チェック**: `@Observable`付与、通常プロパティ（`@Published`不要）、DI、async/await

### Step 8: Viewの実装

```swift
// Features/[機能名]/Views/[機能名]View.swift
struct HomeView: View {
    @State private var store = HomeStore()

    var body: some View {
        NavigationStack {
            if store.isLoading {
                ProgressView()
            } else {
                List(store.visits) { visit in
                    VisitRow(visit: visit)
                }
            }
        }
        .task { await store.load() }
    }
}
```

**チェック**: `@State`で保持（`@StateObject`×）、ビジネスロジック含まず、`.task`でロード

**コンポーネント**: 機能専用は`Components/`、共通は`Shared/UIComponents/`

### Step 9: 動作確認

- [ ] ビルドが通る
- [ ] 画面が表示される
- [ ] データの取得・保存・更新・削除が動作する
- [ ] エラーケースが適切に処理される
- [ ] ローディング状態が表示される

---

## 既存機能の変更手順

1. **影響範囲調査**: `grep -r "ClassName" kokokita/` で依存箇所確認
2. **実装**: Model → Repository → Service → Store → View の順
3. **設計書更新**: 変更内容と理由を記録
4. **動作確認**: 変更箇所・既存機能・エッジケース

---

## タスク別ガイド

### 新しい画面
```bash
mkdir -p Features/Settings/{Models,Views/Components}
# Store作成 → View作成 → ナビゲーション追加
```

### 新しいモデル
`Shared/Models/`に定義 → Core Dataエンティティ追加 → Repository実装

### 新しいService/Logic
- 機能固有: `Features/[機能]/Services/` または `Logic/`
- 共通: `Shared/Services/` または `Shared/Logic/`

### UIコンポーネント
機能専用: `Features/[機能]/Views/Components/` | 共通: `Shared/UIComponents/`

### Core Data変更
バックアップ → バージョン追加 → 軽量マイグレーション → Repository更新

### ローカライゼーション
`LocalizedString.swift`にキー追加 → リソースファイル追加 → View使用

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
- **"Type does not conform to protocol"**: 必須メソッド実装確認
- **"Cannot find type"**: import確認、ターゲット含有確認
- **"Property wrapper cannot be applied"**: @Observable使用時は@Published不要

### 実行時エラー
- **Core Data保存失敗**: 必須属性nil確認
- **Store反映されない**: `@State`使用確認、`@Observable`/`import Observation`確認

### パフォーマンス
- **スクロール重い**: `LazyVStack`使用、画像リサイズ
- **データ取得遅い**: Core Data述語フィルタ使用

---

## 関連ドキュメント

- [アーキテクチャガイド](./architecture-guide.md) - 設計原則とベストプラクティス
- [MVVM→MV移行ガイド](./migration/mvvm-to-mv-migration-guide.md) - 既存コードの移行手順
- [ADR-001: フォルダ構成とアーキテクチャの再設計](./ADR/001-フォルダ構成とアーキテクチャの再設計.md) - 設計判断の背景

---

## 開発効率化のヒント

- **Xcodeスニペット**: Store/View/Service/Logicテンプレート登録
- **ビルド高速化**: 増分ビルド活用、不要import削除
- **デバッグ**: `Logger`使用、ブレークポイント、メモリグラフで循環参照チェック
