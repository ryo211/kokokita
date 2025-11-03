# タスク完了時のチェックリスト

## 実装完了時に必ず確認すること

### 1. コード品質

- [ ] ベストプラクティスに準拠している（`doc/architecture-guide.md`参照）
- [ ] UIとロジックが分離されている
- [ ] 適切なフォルダに配置されている（Feature-based MV）
- [ ] 命名規約に従っている（Store、Service、Logic）
- [ ] コメントが適切に書かれている（日本語）
- [ ] 冗長なコードがない

### 2. アーキテクチャ（Feature-based MV）

- [ ] 機能単位でコロケーションされている
- [ ] Viewは表示のみ
- [ ] Storeは状態管理とServiceとの結合のみ
- [ ] Serviceは副作用のみ（ステートレス）
- [ ] Logicは純粋な関数のみ（副作用なし）
- [ ] @Observableマクロを使用（ObservableObjectではない）
- [ ] @State でStoreを保持（@StateObjectではない）

### 3. エラーハンドリング

- [ ] エラーケースが適切に処理されている
- [ ] ユーザーに分かりやすいエラーメッセージ（日本語）
- [ ] ログが適切に出力されている（Logger使用）

### 4. パフォーマンス

- [ ] 不要な再レンダリングがない
- [ ] Core Dataクエリが最適化されている
- [ ] メモリリークがない（循環参照チェック）
- [ ] 画像が適切にリサイズされている

### 5. セキュリティ

- [ ] 機密情報がハードコーディングされていない
- [ ] ユーザーデータが適切に扱われている
- [ ] 入力値のバリデーションがある
- [ ] 位置情報の偽装検出が実装されている（該当機能の場合）

### 6. ビルドとテスト

- [ ] ビルドが通る
  ```bash
  xcodebuild -project kokokita.xcodeproj -scheme kokokita -sdk iphonesimulator build
  ```
- [ ] 画面が表示される
- [ ] データの取得・保存・更新・削除が動作する
- [ ] エラーケースが適切に処理される
- [ ] ローディング状態が表示される
- [ ] 既存機能が壊れていない

### 7. ローカライゼーション

- [ ] 表示文字列がローカライズされている（日本語・英語）
- [ ] `LocalizedString.swift`に追加されている
- [ ] `ja.lproj/Localizable.strings`に追加されている
- [ ] `en.lproj/Localizable.strings`に追加されている

### 8. ドキュメント

- [ ] 必要に応じて設計書を作成/更新（`doc/design/`）
- [ ] 重要な決定はADRに記録（`doc/ADR/`）
- [ ] コメントで「なぜ」が説明されている
- [ ] `CLAUDE.md`の更新が必要か確認

### 9. Git

- [ ] 適切なブランチで作業している
- [ ] コミットメッセージが明確（日本語）
- [ ] 不要なファイルがコミットされていない
- [ ] `.gitignore`が適切に設定されている

## 実行コマンド

### ビルド確認
```bash
# シミュレータ向けビルド
xcodebuild -project kokokita.xcodeproj -scheme kokokita -sdk iphonesimulator build
```

### コード検索（実装漏れチェック）
```bash
# TODO/FIXME コメント確認
grep -rn "// TODO" kokokita/
grep -rn "// FIXME" kokokita/

# 旧パターン（ObservableObject）が残っていないか確認
grep -r "ObservableObject" kokokita/
grep -r "@Published" kokokita/
grep -r "@StateObject" kokokita/

# ViewModelという名前が残っていないか確認
grep -r "ViewModel" kokokita/
```

### Core Data確認
```bash
# Core Dataモデルを開いて確認
open Kokokita.xcdatamodeld
```

## 変更内容のコミット

### コミット前確認
```bash
# 変更内容を確認
git status
git diff

# ステージング
git add .

# コミット（日本語で明確なメッセージ）
git commit -m "実装した機能の説明"
```

### コミットメッセージ例
```
新機能: 統計画面の実装

- Features/Statistics/ を追加
- StatisticsStore、StatisticsService、StatisticsView を実装
- @Observableマクロを使用した状態管理
- 月別訪問数の集計機能を追加
```

## リファクタリング時の追加チェック

- [ ] 既存のテストが通る（テストがある場合）
- [ ] 依存している箇所を全て確認
- [ ] APIの互換性が保たれている
- [ ] 移行パスが明確

## トラブルシューティング

### ビルドエラー時
1. Derived Dataをクリア
   ```bash
   rm -rf ~/Library/Developer/Xcode/DerivedData
   ```
2. Clean Build Folder（Xcode: Cmd+Shift+K）
3. Xcodeを再起動

### Core Dataエラー時
- 必須属性がnilになっていないか確認
- マイグレーションが必要か確認
- `CoreDataStack`のログを確認

## ドキュメント更新が必要な場合

以下の変更を行った場合は、対応するドキュメントを更新:

- 新機能追加 → `CLAUDE.md`、`doc/design/[機能名].md`
- アーキテクチャ変更 → `doc/architecture-guide.md`、ADR作成
- 設定変更 → `CLAUDE.md`、`doc/architecture-guide.md`
- ビルド手順変更 → `CLAUDE.md`、このファイル

## 完了報告テンプレート

タスク完了時は以下のような報告を行う:

```
## 完了報告

### 実装内容
- [実装した内容を箇条書き]

### 変更ファイル
- Features/[機能名]/Models/[Store].swift（新規）
- Features/[機能名]/Views/[View].swift（新規）
- [その他の変更ファイル]

### ビルド確認
✅ ビルド成功

### 動作確認
✅ [確認した項目]

### チェックリスト
✅ コード品質
✅ アーキテクチャ準拠
✅ エラーハンドリング
✅ パフォーマンス
✅ セキュリティ
✅ ドキュメント更新
```