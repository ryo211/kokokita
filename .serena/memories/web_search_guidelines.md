# Web検索ガイドライン

## 基本方針

Claudeは常にインターネット検索を積極的に活用して、最新のベストプラクティスと情報に基づいた開発を行う。

## 必須の検索タイミング

### 1. タスク開始時
- 関連する最新のベストプラクティスを確認
- 技術スタックの最新動向を確認
- コミュニティの推奨事項を確認

### 2. 実装前
- 類似機能の実装例を検索
- 最新のAPI使用方法を確認
- セキュリティのベストプラクティスを確認

### 3. エラー発生時
- エラーメッセージで検索
- 解決策やワークアラウンドを検索
- 既知の問題や制限事項を確認

### 4. 設計判断時
- 複数のアプローチを比較
- パフォーマンスへの影響を調査
- メンテナビリティを評価

### 5. レビュー時
- セキュリティ脆弱性を確認
- パフォーマンス最適化の余地を検索
- アクセシビリティのガイドラインを確認

## 検索対象

### SwiftUI関連
- "SwiftUI [機能名] best practices 2025"
- "SwiftUI [機能名] performance optimization"
- "SwiftUI @Observable examples"
- "SwiftUI navigation patterns iOS 17"

### Core Data関連
- "Core Data iOS 17 best practices"
- "Core Data performance optimization swift"
- "Core Data migration strategies"
- "Core Data @Observable integration"

### セキュリティ関連
- "Swift CryptoKit best practices"
- "iOS location spoofing detection"
- "Keychain Swift implementation"
- "iOS security vulnerabilities 2025"

### アーキテクチャ関連
- "SwiftUI MVVM vs MV 2025"
- "Feature-based architecture Swift"
- "iOS app architecture patterns"
- "SwiftUI dependency injection"

### エラー対応
- "[エラーメッセージ] Swift"
- "[エラーメッセージ] SwiftUI"
- "[エラーメッセージ] Core Data"

## 検索結果の活用

### 1. ベストプラクティスの適用
- 検索結果を既存のアーキテクチャガイドと照合
- プロジェクトの方針と矛盾しない場合は採用
- 矛盾する場合はユーザーに相談

### 2. 情報の検証
- 複数のソースで確認
- 公式ドキュメントを優先
- コミュニティの評価を参考

### 3. メモリへの保存
- 重要な知見は`write_memory`で保存
- 今後の参考になる情報をドキュメント化
- チーム全体で共有すべき情報を記録

## 検索を行わない場合

以下の場合は検索不要：
- プロジェクト固有の実装詳細（Serenaメモリで対応）
- 基本的なSwift文法（知識で対応）
- 既に確認済みの情報（重複確認を避ける）

## 検索クエリのテンプレート

### 機能実装時
```
"SwiftUI [機能名] implementation best practices 2025"
"iOS [機能名] example code"
"[機能名] performance considerations iOS"
```

### エラー解決時
```
"[エラーメッセージ全文] Swift"
"how to fix [エラーの概要] SwiftUI"
"[エラー名] workaround iOS 17"
```

### 設計判断時
```
"[技術A] vs [技術B] Swift 2025"
"when to use [パターン名] SwiftUI"
"[設計手法] pros and cons iOS development"
```

### セキュリティ確認時
```
"[技術名] security best practices iOS"
"[機能名] vulnerability Swift"
"iOS security checklist 2025"
```

## 優先する情報源

1. **Apple公式ドキュメント**: developer.apple.com
2. **Swift公式**: swift.org
3. **信頼できる開発者ブログ**: raywenderlich.com, hackingwithswift.com等
4. **Stack Overflow**: 具体的な問題解決
5. **GitHub**: 実装例とサンプルコード

## 注意事項

- 検索結果をそのまま適用せず、プロジェクトの文脈で評価
- 古い情報（iOS 16以前）は注意して使用
- @Observableマクロは iOS 17+なので、それ以前の情報は適用不可
- ObservableObjectパターンは旧パターンとして扱う

## 検索結果の報告

ユーザーに報告する際は：
- 検索した内容を明記
- 採用した理由を説明
- 代替案があれば提示
- 参照URLを提供（可能な場合）