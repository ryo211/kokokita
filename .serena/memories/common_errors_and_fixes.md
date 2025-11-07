# よくあるエラーと修正方法

このファイルは、プロジェクトでよく発生するエラーパターンとその修正方法を記録します。

## 1. @ViewBuilder重複エラー（頻出⚠️）

### エラーメッセージ
```
Consecutive declarations on a line must be separated by ';'
```

### 発生パターン
Serenaの`replace_symbol_body`ツール使用時に、`@ViewBuilder`属性が重複してしまう。

### 原因
```swift
// ❌ 誤り: @ViewBuilderが2行になっている
@ViewBuilder
private @ViewBuilder
private func actionButton(...) -> some View {
```

### 正しい書き方
```swift
// ✅ 正しい: @ViewBuilderは1回だけ
@ViewBuilder
private func actionButton(...) -> some View {
```

### 修正方法
重複している行を削除する:
```swift
// Before (エラー)
@ViewBuilder
private @ViewBuilder
private func actionButton(

// After (修正後)
@ViewBuilder
private func actionButton(
```

### 予防策
- Serenaで関数を置き換える時は、既存の`@ViewBuilder`を含めて置き換える
- 置き換え後に該当行付近を目視確認する

---

## 2. onChange API非推奨警告（iOS 17+）

### エラーメッセージ
```
'onChange(of:perform:)' was deprecated in iOS 17.0
```

### 修正方法
```swift
// ❌ 旧API
.onChange(of: value) { newValue in
    // 処理
}

// ✅ 新API（iOS 17+）
.onChange(of: value) { oldValue, newValue in
    // 処理
}
```

---

## 3. CLLocationManager.authorizationStatus() 非推奨（iOS 14+）

### エラーメッセージ
```
'authorizationStatus()' was deprecated in iOS 14.0
```

### 修正方法
```swift
// ❌ 旧API（クラスメソッド）
if CLLocationManager.authorizationStatus() == .authorizedWhenInUse {
    // 処理
}

// ✅ 新API（インスタンスプロパティ）
if locationManager.authorizationStatus == .authorizedWhenInUse {
    // 処理
}
```

---

## 4. Core Data型キャストの警告

### エラーメッセージ
```
Cast from 'NSOrderedSet?' to unrelated type '[VisitPhotoEntity]' always fails
```

### 修正方法
```swift
// ❌ 誤り
let photos = entity.photos as? [VisitPhotoEntity]

// ✅ 正しい
let photos = (entity.photos?.array as? [VisitPhotoEntity]) ?? []
```

---

## 5. Switch文の網羅性エラー

### エラーメッセージ
```
Switch must be exhaustive
```

### 原因
enumに新しいケースを追加したが、switch文で処理していない。

### 修正方法
```swift
enum LocationServiceError: LocalizedError {
    case permissionDenied
    case timeout  // ← 新しく追加
    case other(Error)
}

// ❌ 誤り: timeoutケースがない
switch error {
case .permissionDenied:
    alert = "権限がありません"
case .other:
    alert = error.localizedDescription
}

// ✅ 正しい: すべてのケースを処理
switch error {
case .permissionDenied:
    alert = "権限がありません"
case .timeout:
    alert = "タイムアウトしました"
case .other:
    alert = error.localizedDescription
}
```

---

## 6. 変数の不変性警告

### エラーメッセージ
```
Variable 'xxx' was never mutated; consider changing to 'let' constant
```

### 修正方法
```swift
// ❌ 誤り: 変更しない変数をvarで宣言
var url = URL(string: "...")

// ✅ 正しい: letで宣言
let url = URL(string: "...")
```

---

## 7. async操作がない警告

### エラーメッセージ
```
No 'async' operations occur within 'await' expression
```

### 修正方法
```swift
// ❌ 誤り: awaitが不要
await MainActor.run {
    self.value = newValue  // 同期処理のみ
}

// ✅ 正しい: awaitを削除
MainActor.run {
    self.value = newValue
}
```

---

## 8. scrollIndicatorInsets非推奨（iOS 13+）

### エラーメッセージ
```
Getter for 'scrollIndicatorInsets' was deprecated in iOS 13.0
```

### 修正方法
```swift
// ❌ 旧API
.scrollIndicatorInsets(...)

// ✅ 新API
.verticalScrollIndicatorInsets(...)
.horizontalScrollIndicatorInsets(...)
```

---

## エラー対応の基本フロー

1. **エラーメッセージを確認**
2. **このドキュメントで該当パターンを検索**
3. **見つかれば記載の修正方法を適用**
4. **見つからなければ以下を実行**:
   - ネット検索（WebSearch）でベストプラクティスを調査
   - Apple公式ドキュメントを確認
   - コードベース内で同様の実装を検索（Grep）
   - 修正後、このドキュメントに追記

---

## Serena使用時の注意点

### replace_symbol_body使用時
- 既存の属性（@ViewBuilder、@MainActor等）を含めて置き換える
- 置き換え後、属性の重複がないか確認

### find_symbol使用時
- include_body=Trueで本体を取得してから編集
- 部分的な編集には適さない（全体置換用）

### insert_after_symbol / insert_before_symbol使用時
- インデントを正確に合わせる
- 属性やアクセス修飾子の重複に注意

---

## デバッグのヒント

### ビルドエラー時
```bash
# Derived Dataをクリア
rm -rf ~/Library/Developer/Xcode/DerivedData

# Clean Build Folder（Xcode: Cmd+Shift+K）
```

### 実行時エラー時
- `Logger`の出力を確認
- ブレークポイントを設定
- lldbでデバッグ

### Core Dataエラー時
- 必須属性がnilでないか確認
- マイグレーションが必要か確認
- CoreDataStackのログを確認

---

## よくある質問

### Q: @ViewBuilderエラーが何度も発生する
A: Serenaのreplace_symbol_body使用時に属性が重複しやすいため、置き換え前の関数全体（属性含む）を確認してから置き換える。

### Q: iOS 17+の新APIを使うべきか？
A: はい。このプロジェクトの最小サポートバージョンはiOS 17なので、最新APIを使用すべき。

### Q: 非推奨警告は無視してもいい？
A: いいえ。すべて修正すること。将来のiOSバージョンで削除される可能性がある。

---

## 更新履歴

- 2025-11-06: 初版作成（@ViewBuilderエラーパターン追加）
- よくあるエラーパターンを今後も追記予定
