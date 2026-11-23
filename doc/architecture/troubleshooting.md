# トラブルシューティング（よくあるビルドエラーと Xcode プロジェクトの扱い）

> ステータス: 実装済（随時追記）
> 最終更新: 2026-11-24
> 対象バージョン: v3.x〜

旧 `.serena/memories/` から、ここにしかなかった知見を移したもの。新しいパターンを見つけたら追記する。

---

## 1. Xcode プロジェクトの形式（ファイル追加時の注意）

このプロジェクトは **Xcode 15+ のフォルダ同期形式**（`objectVersion = 77`、`PBXFileSystemSynchronizedRootGroup`）を使っている。

- `kokokita/` フォルダ内に `.swift` ファイルを置けば **自動でビルド対象になる**。Xcode で「Add to target」する必要はない
- 削除・移動もフォルダ操作だけで反映される。`project.pbxproj` を手で編集しない
- ビルド対象から外したいファイルは `PBXFileSystemSynchronizedBuildFileExceptionSet`（Xcode のターゲット設定）で除外する

```bash
# 形式の確認（出力があればフォルダ同期形式）
grep "PBXFileSystemSynchronizedRootGroup" kokokita.xcodeproj/project.pbxproj
```

**ファイルが認識されない／二重定義エラーになる場合**
1. `kokokita/` 配下に置いているか確認する
2. 同名ファイルが別の場所に重複していないか確認する（`find kokokita -name "Xxx.swift"`）
3. DerivedData を消してクリーンビルドする（`rm -rf ~/Library/Developer/Xcode/DerivedData`、Xcode で Cmd+Shift+K）

---

## 2. よくあるビルドエラー・警告

### `@ViewBuilder` の重複
```
Consecutive declarations on a line must be separated by ';'
```
関数をツールで丸ごと置き換えたときに、属性が二重になって起きやすい。置き換えるときは `@ViewBuilder` や `@MainActor` などの属性も含めて置き換え、置き換え後に該当行を確認する。

```swift
// ❌
@ViewBuilder
private @ViewBuilder
private func actionButton() -> some View {

// ✅
@ViewBuilder
private func actionButton() -> some View {
```

### `onChange(of:perform:)` が非推奨（iOS 17）
```swift
// ❌ .onChange(of: value) { newValue in ... }
// ✅
.onChange(of: value) { oldValue, newValue in ... }
```

### `CLLocationManager.authorizationStatus()` が非推奨
```swift
// ❌ CLLocationManager.authorizationStatus()
// ✅ インスタンスのプロパティを使う
locationManager.authorizationStatus
```

### Core Data の順序付き関係のキャストが常に失敗する
```
Cast from 'NSOrderedSet?' to unrelated type '[VisitPhotoEntity]' always fails
```
```swift
// ❌ entity.photos as? [VisitPhotoEntity]
// ✅
let photos = (entity.photos?.array as? [VisitPhotoEntity]) ?? []
```

### `Switch must be exhaustive`
enum にケースを追加したら、その enum を `switch` しているすべての箇所に分岐を足す（ユーザーに見えるエラー文言は `L` 経由でローカライズする）。

### `scrollIndicatorInsets` が非推奨
`verticalScrollIndicatorInsets` / `horizontalScrollIndicatorInsets` を使う。

---

## 3. 方針

- 最小サポートは iOS 17。非推奨の警告は放置せず、新しい API に直す
- 見つからないエラーは Apple 公式ドキュメントとコードベース内の同様の実装を確認し、解決したらこのファイルに追記する
- Core Data のエラーは [coredata-error-handling.md](coredata-error-handling.md) を参照
