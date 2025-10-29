# 技術スタック

## プログラミング言語
- **Swift** (iOS 17+ 対応)
- エンコーディング: UTF-8

## フレームワーク

### UI
- **SwiftUI**: 宣言的UIフレームワーク
- NavigationStack、List、Sheet等を使用

### データ管理
- **Core Data**: 永続化レイヤー
- **@Observable**: iOS 17+の新しい状態管理（Observationフレームワーク）
- ~~ObservableObject + @Published~~（旧パターン、使用しない）

### セキュリティ
- **CryptoKit**: P256 ECDSA署名による改ざん検出
- **Keychain**: 秘密鍵の安全な保存

### 位置情報
- **CoreLocation**: GPS位置情報取得
  - CLLocationManagerで権限管理
  - ワンショット位置情報取得
  - ソースフラグ検出（シミュレート/アクセサリ）
- **MapKit**: POI検索、逆ジオコーディング
  - MKLocalSearch.Requestで近隣POI検索
  - CLGeocoder使用は非推奨

### メディア
- **UIKit**: 写真選択（PHPickerViewController経由）
- **ImageStore**: ファイルシステムでの画像管理
  - 保存先: アプリのDocumentsディレクトリ
  - パスのみCore Dataに保存

### ローカライゼーション
- 日本語（ja.lproj）と英語（en.lproj）をサポート
- `LocalizedString.swift`でアクセス（L列挙型）

## 開発環境
- **Xcode**: macOS用IDE
- **macOS** (Darwin): 開発プラットフォーム
- **iOS Simulator**: テスト環境

## ビルドシステム
- **xcodebuild**: コマンドラインビルド
- ターゲット: `kokokita`
- スキーム: `kokokita`

## バージョン管理
- **Git**: バージョン管理
- ブランチ戦略: mainブランチをベースに開発

## 設定管理
- **AppConfig.swift**: アプリ全体の設定
- **UIConstants.swift**: UI定数の集約