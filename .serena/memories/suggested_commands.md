# 開発でよく使うコマンド

## ビルドと実行

### Xcodeでプロジェクトを開く
```bash
open kokokita.xcodeproj
```

### コマンドラインからビルド（iOS実機向け）
```bash
xcodebuild -project kokokita.xcodeproj -scheme kokokita -sdk iphoneos build
```

### シミュレータ向けビルド
```bash
xcodebuild -project kokokita.xcodeproj -scheme kokokita -sdk iphonesimulator build
```

### ビルドのクリーン
```bash
xcodebuild clean -project kokokita.xcodeproj -scheme kokokita
```

## Gitコマンド

### 現在の状態確認
```bash
git status
```

### ブランチ確認
```bash
git branch
```

### 変更をステージング
```bash
git add .
```

### コミット（日本語でコミットメッセージを記述）
```bash
git commit -m "実装した機能の説明"
```

### リモートへプッシュ
```bash
git push origin [ブランチ名]
```

### 新しいブランチを作成して切り替え
```bash
git checkout -b feature/[機能名]
```

## ファイル検索

### ファイル名で検索（macOS用）
```bash
# 特定のファイルパターンを検索
find kokokita/ -name "*Store.swift"
find kokokita/ -name "*Service.swift"
find kokokita/ -name "*View.swift"
```

### コード内検索（macOS用）
```bash
# キーワードでコード検索
grep -r "キーワード" kokokita/

# 大文字小文字を区別しない検索
grep -ri "keyword" kokokita/

# クラス定義を検索
grep -r "class.*Store" kokokita/

# 関数定義を検索
grep -r "func.*async" kokokita/
```

## ディレクトリ操作

### ディレクトリ内容を確認
```bash
ls -la kokokita/

# ツリー表示（treeがインストールされている場合）
tree kokokita/ -L 2
```

### 新しいフォルダ構成を作成
```bash
# 新機能用のフォルダを作成
mkdir -p Features/[機能名]/{Models,Logic,Services,Views/Components}
```

## Core Data関連

### Core Dataモデルを開く
```bash
open Kokokita.xcdatamodeld
```

## ログとデバッグ

### シミュレータのログを確認
Xcodeのコンソールで確認、またはシミュレータアプリのログで確認可能

### デバイスログの確認
```bash
# iOSデバイスのログを表示（xcrunを使用）
xcrun simctl spawn booted log stream --predicate 'processImagePath contains "kokokita"'
```

## テスト（今後実装予定）

現在、自動テストはないが、将来的には以下のコマンドでテストを実行予定:

```bash
# ユニットテスト実行
xcodebuild test -project kokokita.xcodeproj -scheme kokokita -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 15'
```

## Xcode関連

### Derived Dataをクリア（ビルド問題の解決時）
```bash
rm -rf ~/Library/Developer/Xcode/DerivedData
```

### Xcodeのキャッシュをクリア
```bash
# Clean Build Folderと同等
# XcodeのUI: Product > Clean Build Folder (Cmd+Shift+K)
```

## Darwin（macOS）固有のコマンド

### プロセス確認
```bash
ps aux | grep kokokita
```

### ファイルシステムの詳細情報
```bash
ls -l@ kokokita/  # 拡張属性を表示
```

### パーミッション確認
```bash
ls -la kokokita/
```

## ドキュメント確認

### ドキュメントを読む
```bash
# プロジェクト概要
cat CLAUDE.md

# アーキテクチャガイド
cat doc/architecture-guide.md

# 実装ガイド
cat doc/implementation-guide.md

# エージェントガイド
cat doc/agent-guide.md
```

## 開発フロー

### 新機能実装の典型的な流れ

1. **ドキュメント確認**
   ```bash
   cat CLAUDE.md
   cat doc/architecture-guide.md
   cat doc/implementation-guide.md
   ```

2. **ブランチ作成**
   ```bash
   git checkout -b feature/新機能名
   ```

3. **フォルダ作成**
   ```bash
   mkdir -p Features/[機能名]/{Models,Logic,Services,Views/Components}
   ```

4. **実装**
   - Xcodeで実装

5. **ビルド確認**
   ```bash
   xcodebuild -project kokokita.xcodeproj -scheme kokokita -sdk iphonesimulator build
   ```

6. **コミット**
   ```bash
   git add .
   git commit -m "新機能: [機能名]の実装"
   ```

7. **プッシュ**
   ```bash
   git push origin feature/新機能名
   ```

## よく使うユーティリティコマンド

### 行数カウント
```bash
# Swiftファイルの行数を数える
find kokokita/ -name "*.swift" | xargs wc -l
```

### ファイル数カウント
```bash
# Swiftファイルの数を数える
find kokokita/ -name "*.swift" | wc -l
```

### TODO/FIXMEコメントの検索
```bash
grep -rn "// TODO" kokokita/
grep -rn "// FIXME" kokokita/
```

## 注意事項

- **Darwin（macOS）環境**: このプロジェクトはmacOS上で開発されているため、Unix系コマンドが利用可能
- **日本語の使用**: コミットメッセージ、コメントは日本語で記述
- **エラー時**: ビルドエラーが発生した場合は、まずDerived Dataのクリアを試す