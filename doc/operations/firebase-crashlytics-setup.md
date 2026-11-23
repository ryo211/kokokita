# Firebase Crashlytics セットアップガイド

## 📋 概要

Firebase Crashlyticsは、アプリのクラッシュとエラーをリアルタイムで追跡・分析できるサービスです。

**導入日:** 2025-11-12
**バージョン:** 1.0

---

## ✅ セットアップ完了項目

### 1. Firebase SDKの追加
- ✅ Swift Package Manager経由で追加済み
- ✅ `FirebaseCore`
- ✅ `FirebaseCrashlytics`

### 2. GoogleService-Info.plist
- ✅ プロジェクトルートに配置済み
- Bundle ID: `com.hashimoto.kokokita`

### 3. コード統合
- ✅ `AppDelegate.swift` - Firebase初期化
- ✅ `Logger.swift` - Crashlytics連携
- ✅ `SettingsHomeScreen.swift` - テスト用UI

---

## 🔧 実装内容

### 1. AppDelegate.swift

**場所:** `/App/AppDelegate.swift`

```swift
import FirebaseCore
import FirebaseCrashlytics

func application(...) -> Bool {
    // Firebase初期化
    FirebaseApp.configure()

    // Crashlyticsの設定
    #if DEBUG
    // デバッグビルドではデータ収集を無効化（オプション）
    // Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(false)
    #endif

    // ...
}
```

**機能:**
- アプリ起動時にFirebaseを初期化
- DEBUGビルドではCrashlyticsのデータ収集を無効化可能（コメントアウト済み）

---

### 2. Logger.swift

**場所:** `/Shared/Utilities/Logger.swift`

**変更内容:**

#### error() メソッド
```swift
static func error(_ message: String, error: Error? = nil, ...) {
    // DEBUGビルドではコンソール出力
    #if DEBUG
    print("❌ ERROR ...")
    #endif

    // Firebase Crashlyticsに送信
    let crashlytics = Crashlytics.crashlytics()
    crashlytics.log("\(location) - \(message)")

    if let error = error {
        crashlytics.record(error: error as NSError)
    } else {
        // カスタムエラーを作成
        let customError = NSError(
            domain: "com.hashimoto.kokokita",
            code: -1,
            userInfo: [
                NSLocalizedDescriptionKey: message,
                "location": location
            ]
        )
        crashlytics.record(error: customError)
    }
}
```

#### warning() メソッド
```swift
static func warning(_ message: String, ...) {
    // DEBUGビルドではコンソール出力
    #if DEBUG
    print("⚠️ WARNING ...")
    #endif

    // Crashlyticsにログ送信（非致命的エラー）
    let crashlytics = Crashlytics.crashlytics()
    crashlytics.log("⚠️ WARNING \(location) - \(message)")
}
```

**機能:**
- すべてのエラーと警告をFirebaseに自動送信
- エラーオブジェクトがない場合でも記録可能
- ファイル名、行番号、関数名を自動的に含める

---

### 3. SettingsHomeScreen.swift

**場所:** `/Features/SettingsScreen/Views/SettingsHomeScreen.swift`

**追加機能:**

```swift
#if DEBUG
Section {
    Button {
        testErrorLogging()
    } label: {
        Label("エラーログをテスト", systemImage: "ladybug")
    }

    Button {
        showCrashAlert = true
    } label: {
        Label("クラッシュをテスト", systemImage: "exclamationmark.triangle")
    }
} header: {
    Text("開発者向けテスト")
}
#endif
```

**機能:**
1. **エラーログをテスト**
   - `Logger.error()` と `Logger.warning()` の動作確認
   - Firebaseダッシュボードに記録される

2. **クラッシュをテスト**
   - 意図的にクラッシュを発生させる
   - Crashlyticsでクラッシュレポートを確認できる
   - 確認ダイアログ付き

**重要:** DEBUGビルドでのみ表示され、本番環境では非表示

---

## 🧪 動作確認手順

### ステップ1: ビルドして起動

1. Xcodeでプロジェクトを開く
2. Debugスキームでビルド
3. シミュレーターまたは実機で起動
4. エラーがないことを確認

---

### ステップ2: エラーログのテスト

1. アプリ内で「メニュー」タブを開く
2. 「開発者向けテスト」セクションが表示されていることを確認
3. **「エラーログをテスト」**をタップ
4. Xcodeのコンソールに以下が表示される:
   ```
   ❌ ERROR [SettingsHomeScreen.swift:78] testErrorLogging()
      Message: テストエラー：これはFirebase Crashlyticsのテストです
   ⚠️ WARNING [SettingsHomeScreen.swift:79] testErrorLogging()
      Message: テスト警告：非致命的なエラーのテストです
   ```

**期待される動作:**
- コンソールにログが表示される
- Firebaseにエラーが送信される（数分後にダッシュボードで確認可能）

---

### ステップ3: クラッシュのテスト

1. **「クラッシュをテスト」**をタップ
2. 確認ダイアログが表示される
3. **「実行」**をタップ
4. アプリが強制終了する

**期待される動作:**
- アプリが即座に終了
- 次回起動時にクラッシュレポートがFirebaseに送信される
- 5〜10分後にFirebaseダッシュボードでクラッシュレポートが確認できる

**重要:** クラッシュレポートは即座には表示されません。初回は10分程度かかることがあります。

---

### ステップ4: Firebaseダッシュボードで確認

1. **Firebase Consoleにアクセス**
   - https://console.firebase.google.com/
   - プロジェクトを選択

2. **Crashlyticsを開く**
   - 左メニュー: `ビルド` → `Crashlytics`

3. **確認項目**
   - **Issues（問題）**: クラッシュが記録されている
   - **Non-fatals（非致命的エラー）**: エラーログが記録されている
   - **Event log**: ログメッセージが記録されている

4. **詳細を確認**
   - クラッシュをクリックして詳細を表示
   - スタックトレース、デバイス情報、iOSバージョンを確認

---

## 📊 Firebaseダッシュボードの見方

### Issues（問題）タブ

```
┌─────────────────────────────────────┐
│ Issues                              │
├─────────────────────────────────────┤
│ Test Crash for Firebase Crashlytics│
│ 1 user affected                     │
│ 1 crash                             │
│ SettingsHomeScreen.swift:85         │
│ iOS 17.5                            │
└─────────────────────────────────────┘
```

**確認できる情報:**
- クラッシュメッセージ
- 影響を受けたユーザー数
- クラッシュ回数
- 発生場所（ファイル名と行番号）
- iOSバージョン
- デバイスモデル

---

### Non-fatals（非致命的エラー）タブ

```
┌─────────────────────────────────────┐
│ Non-fatal issues                    │
├─────────────────────────────────────┤
│ テストエラー：これは...             │
│ 1 user affected                     │
│ 1 event                             │
│ SettingsHomeScreen.swift:78         │
└─────────────────────────────────────┘
```

**確認できる情報:**
- エラーメッセージ
- 影響を受けたユーザー数
- 発生回数
- 発生場所

---

### Event log（イベントログ）

個々のクラッシュやエラーの詳細を開くと、以下が表示される:

```
Logs:
⚠️ WARNING [SettingsHomeScreen.swift:79] - テスト警告：...
❌ ERROR [SettingsHomeScreen.swift:78] - テストエラー：...
```

**便利な使い方:**
- エラー発生前の操作フローを追跡
- 問題の再現条件を特定

---

## 🎯 実際の運用での使い方

### 1. エラー検知

```swift
// 既存のコードでLogger.error()を呼ぶだけ
do {
    try someOperation()
} catch {
    Logger.error("操作に失敗しました", error: error)
}
```

→ 自動的にFirebaseに送信される

---

### 2. ユーザー情報の記録（オプション）

```swift
// AppDelegate.swift または適切な場所で
func setUserIdentifier(userId: String) {
    Crashlytics.crashlytics().setUserID(userId)
}
```

→ どのユーザーでエラーが発生したか追跡可能

---

### 3. カスタムキーの追加

```swift
// 追加のコンテキスト情報を記録
Crashlytics.crashlytics().setCustomValue(visitId, forKey: "current_visit_id")
Crashlytics.crashlytics().setCustomValue("map_view", forKey: "current_screen")
```

→ エラー発生時の状態を詳細に記録

---

## ⚠️ 注意事項

### 1. プライバシーへの配慮

**個人情報を含めない:**
- ❌ `Logger.error("User email: user@example.com")`
- ✅ `Logger.error("Failed to load user profile")`

**Firebaseに送信されるデータ:**
- クラッシュのスタックトレース
- デバイス情報（機種、iOSバージョン）
- ログメッセージ
- カスタムキー

**送信されないデータ:**
- ユーザーの個人情報（明示的に含めない限り）
- アプリのローカルデータ

---

### 2. DEBUGビルドのデータ収集

現在の設定では、DEBUGビルドでもCrashlyticsが有効です。

**無効化する場合:**

`AppDelegate.swift:17` のコメントを外す:
```swift
#if DEBUG
Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(false)
#endif
```

---

### 3. App Store審査

Firebase Crashlyticsの使用は、App Storeの審査に影響しません。

**必要な対応:**
- App Storeのプライバシー申告で「Crashlyticsを使用」を選択
- クラッシュデータを収集することを明記

---

### 4. データ保持期間

Firebase Crashlyticsのデータ保持期間:
- **無料プラン**: 90日間
- **Blazeプラン**: 90日間（同じ）

90日以上前のデータは自動削除されます。

---

## 🐛 トラブルシューティング

### 問題1: Firebaseダッシュボードにデータが表示されない

**原因:**
- Crashlyticsは初回起動後、データ送信に5〜10分かかる
- クラッシュレポートは次回起動時に送信される

**対処法:**
1. アプリを完全に終了（バックグラウンドからも削除）
2. 再度起動
3. 10分待つ
4. Firebaseダッシュボードをリロード

---

### 問題2: ビルドエラー「Module 'FirebaseCrashlytics' not found」

**原因:**
- Firebase SDKがプロジェクトに正しく追加されていない

**対処法:**
1. Xcode: `File` → `Packages` → `Resolve Package Versions`
2. それでも解決しない場合:
   - Xcodeを再起動
   - DerivedDataを削除: `~/Library/Developer/Xcode/DerivedData`

---

### 問題3: GoogleService-Info.plistが見つからない

**原因:**
- ファイルが正しく配置されていない
- Targetに追加されていない

**対処法:**
1. Xcodeのプロジェクトナビゲーターで確認
2. `GoogleService-Info.plist` を選択
3. 右側の`File Inspector`で`Target Membership`を確認
4. `kokokita`にチェックが入っていることを確認

---

### 問題4: テストボタンが表示されない

**原因:**
- Releaseスキームでビルドしている

**対処法:**
1. Xcode: メニューバー `Product` → `Scheme` → `Edit Scheme...`
2. `Run` → `Build Configuration` を `Debug` に変更

---

## 📈 推奨される運用フロー

### 日次チェック

1. **Firebaseダッシュボードを確認**
   - 新しいクラッシュがないか
   - エラー発生率の変化

2. **重大度の判定**
   - 影響を受けたユーザー数
   - 発生頻度

3. **優先順位付け**
   - クラッシュ > エラー > 警告
   - 多数のユーザーに影響 > 少数

---

### 週次レビュー

1. **トレンド分析**
   - エラー率の推移
   - 特定のiOSバージョンでの問題

2. **対応計画**
   - 修正すべきバグのリストアップ
   - 次回リリースでの対応予定

---

### リリース前チェック

1. **Crashlyticsが有効か確認**
   - `AppDelegate.swift` で `FirebaseApp.configure()` が呼ばれている
   - `GoogleService-Info.plist` が含まれている

2. **テストボタンを削除**
   - 本番ビルドでは `#if DEBUG` により自動的に非表示
   - 念のため確認

---

## 📚 参考資料

### 公式ドキュメント
- [Firebase Crashlytics iOS Setup](https://firebase.google.com/docs/crashlytics/get-started?platform=ios)
- [Customize Crash Reports](https://firebase.google.com/docs/crashlytics/customize-crash-reports?platform=ios)

### 社内ドキュメント
- `coredata-error-handling.md` - CoreDataエラーハンドリング仕様
- `Logger.swift` - ログ記録の実装

---

## 🔄 更新履歴

| 日付 | バージョン | 変更内容 | 担当者 |
|------|-----------|---------|--------|
| 2025-11-12 | 1.0 | 初版作成：Firebase Crashlytics統合完了 | - |

---

## 🎉 まとめ

Firebase Crashlyticsの統合が完了しました。

**これでできるようになったこと:**
- ✅ ユーザーのアプリで発生したクラッシュを自動収集
- ✅ エラーをリアルタイムで追跡
- ✅ 影響を受けたユーザー数を把握
- ✅ iOSバージョン別、デバイス別の分析
- ✅ プロアクティブな問題対応

**次のステップ:**
1. アプリをビルドして動作確認
2. テスト用ボタンでCrashlyticsをテスト
3. Firebaseダッシュボードでデータを確認
4. 本番リリース後、定期的にダッシュボードをチェック

---

**END OF DOCUMENT**
