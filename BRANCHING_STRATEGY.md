# ブランチ戦略 - ココキタ

## 概要

このドキュメントは、iOSアプリ「ココキタ」の開発・リリース・保守における Git ブランチ戦略を定義します。

## バージョン管理の基本

### アプリバージョン（CFBundleShortVersionString）
- **形式**: `Major.Minor.Patch` (例: `1.0.0`, `1.1.0`, `2.0.0`)
- **Major**: 大規模な機能追加や破壊的変更
- **Minor**: 新機能追加や大きな改善
- **Patch**: バグフィックスや小さな改善

### ビルドバージョン（CFBundleVersion）
- **形式**: 単調増加する整数 (例: `1`, `2`, `3`, `4`...)
- **ルール**: App Store Connect へ提出するたびに必ずインクリメント
- **リセット不可**: アプリバージョンが上がっても、ビルドバージョンは継続して増加

**例**:
- `1.0.0 (1)` - 初回リリース
- `1.0.0 (2)` - 初回リリースの再提出（修正後）
- `1.0.1 (3)` - ホットフィックス
- `1.1.0 (4)` - 新機能追加バージョン

## ブランチ構造

### メインブランチ

#### `main`
- **役割**: App Store にリリースされているコードの正式な履歴
- **保護**: 直接コミット禁止、マージのみ許可
- **タグ**: リリースごとに `v1.0.0 (1)` 形式でタグ付け
- **特徴**: 常に安定した状態を維持

#### `develop`
- **役割**: 次回リリースに向けた開発の統合ブランチ
- **保護**: feature ブランチからのマージを受け入れ
- **特徴**: TestFlight ビルドの作成元

### サポートブランチ

#### Feature ブランチ (`feature/*`)
- **命名規則**: `feature/機能名` (例: `feature/member-filter`, `feature/photo-share`)
- **起点**: `develop` から分岐
- **マージ先**: `develop` へマージ
- **削除**: マージ後は削除
- **用途**: 新機能の開発

#### Release ブランチ (`release/*`)
- **命名規則**: `release/v1.0.0` (アプリバージョンを使用)
- **起点**: `develop` から分岐（機能が揃った時点）
- **マージ先**: `main` と `develop` の両方
- **削除**: リリース完了後は削除
- **用途**: リリース準備、バージョン番号更新、最終調整、バグフィックス

#### Hotfix ブランチ (`hotfix/*`)
- **命名規則**: `hotfix/v1.0.1` (パッチバージョンを使用)
- **起点**: `main` から分岐（緊急バグ修正時）
- **マージ先**: `main` と `develop` の両方
- **削除**: リリース完了後は削除
- **用途**: リリース済みアプリの緊急バグ修正

## ワークフロー

### 1. 通常の機能開発フロー

```bash
# 1. develop から feature ブランチを作成
git checkout develop
git pull origin develop
git checkout -b feature/new-feature

# 2. 開発作業
# ... コード変更、コミット ...

# 3. develop へマージ
git checkout develop
git pull origin develop
git merge --no-ff feature/new-feature
git push origin develop

# 4. feature ブランチを削除
git branch -d feature/new-feature
```

### 2. リリースフロー

```bash
# 1. develop から release ブランチを作成
git checkout develop
git pull origin develop
git checkout -b release/v1.1.0

# 2. バージョン情報を更新
# - Xcode で CFBundleShortVersionString を 1.1.0 に更新
# - CFBundleVersion をインクリメント（例: 4）
# - CHANGELOG.md を更新
git add .
git commit -m "Bump version to 1.1.0 (4)"

# 3. 最終調整・バグフィックス（必要に応じて）
# ... 修正、コミット ...

# 4. TestFlight でテスト
# Xcode で Archive → Upload to App Store Connect
# TestFlight でテスト

# 5. main へマージ
git checkout main
git pull origin main
git merge --no-ff release/v1.1.0
git tag -a v1.1.0 -m "Release version 1.1.0 (4)"
git push origin main --tags

# 6. develop へマージバック
git checkout develop
git pull origin develop
git merge --no-ff release/v1.1.0
git push origin develop

# 7. release ブランチを削除
git branch -d release/v1.1.0

# 8. App Store Connect でリリース
```

### 3. ホットフィックスフロー

```bash
# 1. main から hotfix ブランチを作成
git checkout main
git pull origin main
git checkout -b hotfix/v1.0.1

# 2. バージョン情報を更新
# - CFBundleShortVersionString を 1.0.1 に更新
# - CFBundleVersion をインクリメント（例: 5）
git add .
git commit -m "Bump version to 1.0.1 (5) for hotfix"

# 3. バグ修正
# ... 修正、コミット ...

# 4. TestFlight でテスト
# Xcode で Archive → Upload

# 5. main へマージ
git checkout main
git merge --no-ff hotfix/v1.0.1
git tag -a v1.0.1 -m "Hotfix version 1.0.1 (5)"
git push origin main --tags

# 6. develop へマージバック
git checkout develop
git merge --no-ff hotfix/v1.0.1
git push origin develop

# 7. hotfix ブランチを削除
git branch -d hotfix/v1.0.1

# 8. App Store Connect でリリース
```

## App Store 審査中のワークフロー

App Store 審査中に新機能開発を継続する場合：

```bash
# 審査中: release/v1.0.0 が main にマージ済み、審査待ち

# develop で次バージョンの開発を継続
git checkout develop
git checkout -b feature/next-feature
# ... 開発継続 ...

# もし審査でリジェクトされた場合:
# 1. release/v1.0.0 ブランチを再作成（タグから復元可能）
git checkout -b release/v1.0.0 v1.0.0

# 2. 修正
# - CFBundleVersion のみインクリメント（例: 1 → 2 → 3）
# - 審査指摘事項を修正

# 3. main と develop へマージ（通常のリリースフローと同様）
```

## ビルド番号管理のベストプラクティス

### 原則
1. **ビルド番号は常にインクリメント**: TestFlight や App Store Connect へアップロードするたびに必ず +1
2. **アプリバージョンとは独立**: アプリバージョンが変わっても、ビルド番号はリセットしない
3. **一意性の保証**: 同じビルド番号を再利用しない

### 実例
```
初回リリース:
- 1.0.0 (1) - 初回提出
- 1.0.0 (2) - Privacy Manifest 修正後の再提出
- 1.0.0 (3) - 位置情報エラー修正後の再提出
- 審査通過 → App Store リリース

ホットフィックス:
- 1.0.1 (4) - 写真削除のクラッシュ修正

次期バージョン:
- 1.1.0 (5) - TestFlight ビルド（開発中）
- 1.1.0 (6) - TestFlight ビルド（バグ修正）
- 1.1.0 (7) - App Store 提出
- 審査通過 → App Store リリース

大型アップデート:
- 2.0.0 (8) - TestFlight ビルド
- 2.0.0 (9) - App Store 提出
```

## コミットメッセージ規約

### フォーマット
```
<type>: <subject>

<body>
```

### Type
- `feat`: 新機能
- `fix`: バグ修正
- `docs`: ドキュメントのみの変更
- `style`: コードの意味に影響しない変更（空白、フォーマットなど）
- `refactor`: バグ修正でも機能追加でもないコード変更
- `test`: テストの追加や修正
- `chore`: ビルドプロセスやツールの変更

### 例
```
feat: メンバーフィルタリング機能を追加

VisitListStore にメンバーIDによるフィルタリング機能を実装。
SearchFilterSheet でメンバー選択UIを追加。

関連ファイル:
- VisitListStore.swift
- SearchFilterSheet.swift
- CoreDataVisitRepository.swift
```

## タグ管理

### 命名規則
```
v<アプリバージョン>
```

### 例
```bash
git tag -a v1.0.0 -m "Release version 1.0.0 (3) - 初回リリース"
git tag -a v1.0.1 -m "Release version 1.0.1 (4) - 写真削除クラッシュ修正"
git tag -a v1.1.0 -m "Release version 1.1.0 (7) - メンバー機能追加"
```

### タグの利用
- **リリース履歴の追跡**: `git tag -l` でリリース一覧を確認
- **特定バージョンへの復元**: `git checkout v1.0.0` で過去バージョンを参照
- **比較**: `git diff v1.0.0 v1.1.0` でバージョン間の差分確認

## 初回セットアップ

現在 `main` ブランチのみ存在する状態から、この戦略を適用する手順：

```bash
# 1. 現在の main に初回リリースタグを付ける（Build 3 リリース時）
git checkout main
git tag -a v1.0.0 -m "Release version 1.0.0 (3) - 初回リリース"
git push origin main --tags

# 2. develop ブランチを作成
git checkout -b develop
git push origin develop

# 3. 今後の開発は develop から feature ブランチを作成
git checkout develop
git checkout -b feature/example-feature
```

## トラブルシューティング

### App Store Connect でビルドが見つからない
- **原因**: ビルド番号の重複、処理中（最大1時間）
- **対処**: CFBundleVersion をインクリメントして再アップロード

### リジェクト後の再提出
- **ビルド番号**: 必ずインクリメント
- **アプリバージョン**: バグ修正のみなら変更不要（同じバージョンで再提出可能）

### 複数の feature を並行開発中にリリース
- **対処**:
  1. リリースに含める feature を develop にマージ
  2. release ブランチを作成
  3. リリースに含めない feature は develop で開発継続
  4. release がリリース後、develop にマージバックして統合

## まとめ

この戦略により以下が実現できます：

1. **安定性**: `main` は常にリリース可能な状態を保持
2. **並行開発**: feature ブランチで複数機能を同時開発
3. **迅速なホットフィックス**: `main` から直接分岐して緊急修正
4. **明確な履歴**: タグとブランチでリリース履歴を追跡
5. **TestFlight 活用**: release ブランチで十分にテスト後リリース

個人開発であっても、この戦略を守ることで App Store 審査やホットフィックスに柔軟に対応できます。
