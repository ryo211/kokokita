# Xcodeプロジェクト管理の知見

## プロジェクト形式の違い

### Xcode 15+の新しいプロジェクト形式

このプロジェクト（kokokita）は**Xcode 15+の新しいプロジェクト形式**を使用しています。

#### 特徴

- `objectVersion = 77` （Xcode 15以降）
- `PBXFileSystemSynchronizedRootGroup`を使用したフォルダ同期方式
- 個別の`.swift`ファイルを`project.pbxproj`に列挙しない
- **フォルダ内のファイルは自動的にビルド対象に含まれる**

#### project.pbxprojの例

```xml
/* Begin PBXFileSystemSynchronizedRootGroup section */
    45B214B92E7EDB560004B944 /* kokokita */ = {
        isa = PBXFileSystemSynchronizedRootGroup;
        exceptions = (
            45DF36992E954EAF00B6526D /* Exceptions for "kokokita" folder in "kokokita" target */,
        );
        path = kokokita;
        sourceTree = "<group>";
    };
/* End PBXFileSystemSynchronizedRootGroup section */
```

### 旧形式（Xcode 14以前）

- `objectVersion = 56`以下
- 個別ファイルを`PBXFileReference`セクションに列挙
- `PBXBuildFile`セクションでビルド対象を明示
- 新しいファイルを追加するたびに`project.pbxproj`を更新する必要がある

## ファイル追加の確認方法

### 新形式（このプロジェクト）

```bash
# フォルダ同期方式を確認
grep "PBXFileSystemSynchronizedRootGroup" kokokita.xcodeproj/project.pbxproj

# 出力があれば新形式 → フォルダ内のファイルは自動認識
```

**結論**: `kokokita/`フォルダ内に`.swift`ファイルを配置すれば、**自動的にビルド対象に含まれる**。

### 旧形式の場合

```bash
# 特定のファイルが登録されているか確認
grep "RateLimiter.swift" kokokita.xcodeproj/project.pbxproj

# 出力があれば登録済み
```

## 実践例: RateLimiter.swiftの追加

### 状況
- `kokokita/Shared/Services/RateLimiter.swift`を新規作成
- Xcodeプロジェクトに追加されているか確認したい

### 確認手順

```bash
# 1. ファイルの存在確認
ls -la kokokita/Shared/Services/RateLimiter.swift
# ✅ 出力: -rw-r--r--@ 1 suepie  staff  1321 Oct 31 09:59

# 2. プロジェクト形式の確認
grep "objectVersion" kokokita.xcodeproj/project.pbxproj
# ✅ 出力: objectVersion = 77;

# 3. フォルダ同期方式の確認
grep "PBXFileSystemSynchronizedRootGroup" kokokita.xcodeproj/project.pbxproj
# ✅ 出力あり → 新形式を使用

# 4. 同期対象フォルダの確認
grep -A 5 "PBXFileSystemSynchronizedRootGroup" kokokita.xcodeproj/project.pbxproj
# ✅ path = kokokita; → kokokita/フォルダ全体が同期対象
```

### 結論

✅ `kokokita/Shared/Services/RateLimiter.swift`は自動的にビルド対象に含まれる。
❌ 個別にXcodeで「Add to target」する必要はない。

## 重要な注意点

### ファイルシステム上の存在 ≠ Xcodeプロジェクトへの登録（旧形式の場合）

旧形式では、ファイルが存在してもプロジェクトに登録されていなければビルドされない。

### 新形式では自動認識

新形式では、**同期対象フォルダ内のファイルは自動的にビルド対象**となる。

- ✅ ファイルを追加 → 自動認識
- ✅ ファイルを削除 → 自動除外
- ✅ ファイルを移動 → 自動更新

### 例外設定

`PBXFileSystemSynchronizedBuildFileExceptionSet`で特定のファイルを除外可能。

```xml
exceptions = (
    45DF36992E954EAF00B6526D /* Exceptions for "kokokita" folder in "kokokita" target */,
);
```

## トラブルシューティング

### ファイルが認識されない場合

#### 1. フォルダ位置を確認
```bash
# 同期対象フォルダ内にあるか確認
ls -la kokokita/YourFile.swift
```

#### 2. Xcodeをクリーン
```bash
# Derived Dataをクリア
rm -rf ~/Library/Developer/Xcode/DerivedData

# Xcode Clean Build Folder (Cmd+Shift+K)
```

#### 3. Xcodeを再起動

#### 4. プロジェクトファイルを確認
```bash
# 同期対象フォルダを確認
grep -A 5 "PBXFileSystemSynchronizedRootGroup" kokokita.xcodeproj/project.pbxproj
```

### 重複ファイルの削除

誤って複数箇所にファイルを作成した場合：

```bash
# 重複を確認
find kokokita -name "RateLimiter.swift" -type f

# 出力例:
# kokokita/Shared/Services/RateLimiter.swift  ← 正しい場所
# kokokita/Services/RateLimiter.swift         ← 重複（削除対象）

# 内容が同一か確認
diff kokokita/Shared/Services/RateLimiter.swift kokokita/Services/RateLimiter.swift

# 重複を削除
rm kokokita/Services/RateLimiter.swift
```

## まとめ

- **このプロジェクトはXcode 15+の新形式**を使用
- **`kokokita/`フォルダ内のファイルは自動的にビルド対象**
- **個別にXcodeでファイルを追加する必要はない**
- ファイルを配置するだけでビルドに含まれる
