# CoreDataエラーハンドリング仕様書

## 📋 概要

CoreDataの読み込みに失敗した場合、アプリをクラッシュさせず、ユーザーに適切なエラー画面を表示して復旧手段を提供する仕組み。

**実装日:** 2025-11-12
**バージョン:** 1.0

---

## 🎯 目的と背景

### 実装前の問題点

```swift
// 旧実装
container.loadPersistentStores { _, error in
    if let error = error {
        fatalError("Core Data load error: \(error)")  // ← アプリが即座にクラッシュ
    }
}
```

**問題:**
- CoreData読み込み失敗時、アプリが即座に終了
- ユーザーには何も表示されない（突然ホーム画面に戻る）
- 何度起動しても同じ結果で完全に使用不可能
- ユーザーはアプリ削除→再インストールしか手段がない（全データ失う）

### 実装後の改善点

**改善:**
- エラー発生時も専用画面を表示
- ユーザーに状況を説明し、復旧手段を提供
- データ消失リスクのない誠実な対応

---

## 🏗️ アーキテクチャ

### システム構成図

```
┌─────────────────────┐
│   アプリ起動        │
└──────┬──────────────┘
       │
       ▼
┌─────────────────────┐
│ CoreDataStack.init()│
└──────┬──────────────┘
       │
       ▼
  CoreData読み込み
       │
       ├─ 成功 ──────────────┐
       │                     ▼
       │            ┌─────────────────┐
       │            │  isHealthy=true │
       │            └────────┬────────┘
       │                     ▼
       │            ┌─────────────────┐
       │            │  RootTabView    │
       │            │  通常画面表示   │
       │            └─────────────────┘
       │
       └─ 失敗 ──────────────┐
                             ▼
                    ┌─────────────────┐
                    │  loadError設定  │
                    │ isHealthy=false │
                    └────────┬────────┘
                             ▼
                    ┌─────────────────┐
                    │  RootTabView    │
                    │ エラーチェック  │
                    └────────┬────────┘
                             ▼
                    ┌─────────────────┐
                    │ DataErrorView   │
                    │  エラー画面表示 │
                    └─────────────────┘
```

---

## 📦 コンポーネント詳細

### 1. CoreDataStack.swift

**場所:** `/Shared/Infrastructure/Persistence/CoreDataStack.swift`

**役割:** CoreDataの初期化とエラー状態の管理

**主要プロパティ:**

```swift
private(set) var loadError: Error?
```
- CoreData読み込み時のエラーを保持
- 読み込み成功時は `nil`
- `private(set)` で外部からの変更を防止

```swift
var isHealthy: Bool {
    return loadError == nil
}
```
- CoreDataが正常に動作しているかを判定
- UI側でこのフラグを確認して分岐

**エラーハンドリング:**

```swift
container.loadPersistentStores { [weak self] storeDescription, error in
    if let error = error {
        Logger.error("Core Data load error", error: error)
        self?.loadError = error
        // UI側でエラー画面を表示するため、ここでは何もしない
    }
}
```

**設計方針:**
- `fatalError` を使用せず、エラーを保持するだけ
- インメモリフォールバックなし（データ消失リスク回避）
- UI層にエラー表示の責任を委譲

---

### 2. DataErrorView.swift

**場所:** `/Shared/Components/DataErrorView.swift`

**役割:** CoreDataエラー時の専用画面

**UI構成:**

```
┌─────────────────────────────────┐
│                                 │
│    ⚠️ (オレンジの警告アイコン)  │
│                                 │
│  データの読み込みに失敗しました  │
│                                 │
│  アプリのデータベースに問題が... │
│                                 │
├─────────────────────────────────┤
│                                 │
│  ┌───────────────────────────┐  │
│  │  🔄 アプリを再起動        │  │
│  └───────────────────────────┘  │
│                                 │
│  ┌───────────────────────────┐  │
│  │  ✉️ サポートに連絡        │  │
│  └───────────────────────────┘  │
│                                 │
│  ┌───────────────────────────┐  │
│  │  🗑️ データをリセット      │  │
│  └───────────────────────────┘  │
│                                 │
├─────────────────────────────────┤
│  エラー詳細: (error.description)│
└─────────────────────────────────┘
```

**提供する機能:**

#### 1) アプリを再起動

```swift
private func restartApp() {
    exit(0)
}
```

- アプリを終了（ユーザーが手動で再起動）
- 一時的なエラーの場合、再起動で復旧する可能性がある

#### 2) サポートに連絡

```swift
private func contactSupport() {
    // メールアプリを起動
    let email = "support@kokokita.example.com"
    let subject = "データ読み込みエラーの報告"

    // エラー詳細、iOSバージョン、アプリバージョンを自動付与
    // ...
}
```

- メールアプリを起動してサポートに連絡
- エラー情報を自動的に含める
- **⚠️ 注意:** リリース前に実際のサポートメールアドレスに変更必須

#### 3) データをリセット

```swift
private func resetData() {
    // 1. CoreDataストアを削除
    for store in coordinator.persistentStores {
        if let storeURL = store.url {
            try? coordinator.remove(store)
            try? FileManager.default.removeItem(at: storeURL)

            // WAL/SHMファイルも削除
            // ...
        }
    }

    // 2. アプリを再起動
    exit(0)
}
```

- **確認ダイアログ付き**（誤操作防止）
- CoreDataファイル（.sqlite + .sqlite-wal + .sqlite-shm）を削除
- 全データが失われることをユーザーに明示
- 削除後、アプリを再起動（次回起動時に新規DBが作成される）

---

### 3. RootTabView.swift

**場所:** `/App/RootTabView.swift`

**役割:** アプリのエントリーポイントでヘルスチェック

**実装:**

```swift
var body: some View {
    // CoreDataの読み込み状態をチェック
    if !CoreDataStack.shared.isHealthy {
        // エラー画面を表示
        DataErrorView()
    } else {
        // 通常のUI
        normalTabView
    }
}

private var normalTabView: some View {
    // 既存のタブUI実装
    VStack(spacing: 0) {
        // ...
    }
}
```

**設計ポイント:**
- 起動時に1回だけチェック（リアルタイム監視ではない）
- エラー時は通常UIを一切表示しない
- `normalTabView` として既存実装を分離

---

## 🔄 動作フロー

### シナリオ1: 正常起動

```
1. ユーザーがアプリアイコンをタップ
   ↓
2. CoreDataStack.init() 実行
   ↓
3. container.loadPersistentStores 成功
   ↓
4. loadError = nil（isHealthy = true）
   ↓
5. RootTabView.body で分岐
   ↓
6. normalTabView が表示される
   ↓
7. ✅ 通常通り使用可能
```

---

### シナリオ2: CoreData読み込み失敗

```
1. ユーザーがアプリアイコンをタップ
   ↓
2. CoreDataStack.init() 実行
   ↓
3. container.loadPersistentStores 失敗
   ↓
4. Logger.error でログ記録
   ↓
5. loadError = error（isHealthy = false）
   ↓
6. RootTabView.body で分岐
   ↓
7. DataErrorView が表示される
   ↓
8. ユーザーが選択:

   【A. アプリを再起動】
   ↓
   exit(0) でアプリ終了
   ↓
   ユーザーが手動で再起動
   ↓
   → シナリオ1 または シナリオ2

   【B. サポートに連絡】
   ↓
   メールアプリ起動
   ↓
   エラー詳細が自動入力
   ↓
   → サポートチームが調査

   【C. データをリセット】
   ↓
   確認ダイアログ表示
   「すべての訪問記録が削除されます。この操作は取り消せません。」
   ↓
   ユーザーが「リセット」をタップ
   ↓
   CoreDataファイル削除
   ↓
   exit(0) でアプリ終了
   ↓
   ユーザーが手動で再起動
   ↓
   新規DBが作成される
   ↓
   → シナリオ1（クリーンな状態で起動）
```

---

## 👤 ユーザー体験の比較

### 実装前（fatalError）

| 段階 | ユーザー体験 |
|------|------------|
| 起動 | アプリアイコンタップ |
| エラー発生 | **突然ホーム画面に戻る**（何も表示されない） |
| 再試行 | 何度起動しても同じ |
| 感情 | 😡😡😡 「壊れた！」 |
| 対処 | アプリ削除→再インストール（**全データ失う**） |

---

### 実装後（DataErrorView）

| 段階 | ユーザー体験 |
|------|------------|
| 起動 | アプリアイコンタップ |
| エラー発生 | **エラー画面が表示される** |
| メッセージ | 「データの読み込みに失敗しました」<br>「以下の対処方法をお試しください」 |
| 選択肢 | 1. 再起動<br>2. サポート連絡<br>3. データリセット |
| 感情 | 😐 「エラーだけど、何か対処できそう」 |
| 対処 | 再起動で復旧する可能性<br>サポートに問い合わせ可能<br>最終手段としてリセット |

---

## 🐛 CoreData読み込み失敗が起こる状況

### 発生頻度と原因

| 原因 | 頻度 | 説明 | 復旧方法 |
|------|------|------|---------|
| **マイグレーション失敗** | 低 | アプリ更新時にデータモデル変更が失敗 | 再起動で復旧する場合あり |
| **ストレージ満杯** | 中 | iPhoneの空き容量が完全にゼロ | 写真等を削除して容量確保→再起動 |
| **ファイル破損** | 極低 | システムクラッシュ中にファイル破損 | データリセットが必要 |
| **権限問題** | 極低 | サンドボックスのアクセス権限エラー | 再起動で復旧する可能性 |
| **iOSバグ** | 極低 | OS側の不具合 | iOSアップデート待ち |

---

## 🔧 開発者向け情報

### ログ出力

エラー発生時、以下のログが記録される：

```swift
Logger.error("Core Data load error", error: error)
```

**DEBUG時の出力例:**
```
❌ ERROR [CoreDataStack.swift:19] init(modelName:)
   Message: Core Data load error
   Error: The operation couldn't be completed. (NSCocoaErrorDomain error 134110.)
   Details: Error Domain=NSCocoaErrorDomain Code=134110 "An error occurred during persistent store migration." ...
```

**本番環境:**
- 現在はDEBUG時のみコンソール出力
- TODO: Firebase Crashlytics等に送信する実装が推奨

---

### テスト方法

#### 1. CoreData読み込み失敗をシミュレート

```swift
// CoreDataStack.swift（テスト用）
init(modelName: String = "Kokokita") {
    container = NSPersistentContainer(name: modelName)

    // 🧪 テスト用：意図的にエラーを発生させる
    #if DEBUG
    if ProcessInfo.processInfo.arguments.contains("--test-coredata-error") {
        self.loadError = NSError(domain: "TestError", code: 999,
                                 userInfo: [NSLocalizedDescriptionKey: "Simulated CoreData error"])
        return
    }
    #endif

    // 通常の処理...
}
```

起動引数に `--test-coredata-error` を追加してテスト実行。

#### 2. CoreDataファイルを破損させる

```bash
# Simulatorのアプリディレクトリに移動
cd ~/Library/Developer/CoreSimulator/Devices/{DEVICE_ID}/data/Containers/Data/Application/{APP_ID}/Library/Application\ Support/

# CoreDataファイルを破損させる
echo "CORRUPTED" > Kokokita.sqlite
```

---

### 拡張ポイント

#### 1. 自動バックアップからの復旧

```swift
// DataErrorView.swift に追加
private func restoreFromBackup() {
    if let backupURL = findLatestBackup() {
        // バックアップからコピー
        try? FileManager.default.copyItem(at: backupURL, to: storeURL)
        restartApp()
    }
}
```

#### 2. リトライ機能

```swift
// CoreDataStack.swift に追加
func retryLoad() -> Bool {
    loadError = nil
    container.loadPersistentStores { [weak self] _, error in
        if let error = error {
            self?.loadError = error
        }
    }
    return isHealthy
}
```

#### 3. Analytics統合

```swift
// Logger.error の実装を拡張
static func error(_ message: String, error: Error? = nil, ...) {
    #if DEBUG
    // コンソール出力
    #endif

    // 本番環境では Analytics に送信
    FirebaseCrashlytics.record(error: error, message: message)
}
```

---

## ⚠️ 重要な注意事項

### 1. サポートメールアドレスの設定

**ファイル:** `DataErrorView.swift:108`

```swift
let email = "support@kokokita.example.com"  // TODO: 実際のサポートメールアドレスに変更
```

**リリース前に必ず実際のサポートメールアドレスに変更してください。**

---

### 2. exit(0) の使用について

```swift
private func restartApp() {
    exit(0)
}
```

**Apple公式ガイドライン:**
- 通常、アプリ内から `exit()` を呼ぶことは推奨されない
- ただし、**復旧不可能なエラー時の最終手段**としては許容される
- App Store審査で問題になる可能性は低いが、レビュー時に説明できるようにしておく

**代替案（より安全）:**
```swift
// ホーム画面に戻る
UIControl().sendAction(#selector(URLSessionTask.suspend), to: UIApplication.shared, for: nil)
```

---

### 3. データリセットの確認ダイアログ

**実装済み:**
```swift
.alert("データをリセットしますか？", isPresented: $showResetConfirmation) {
    Button("キャンセル", role: .cancel) { }
    Button("リセット", role: .destructive) {
        resetData()
    }
} message: {
    Text("すべての訪問記録が削除されます。この操作は取り消せません。")
}
```

誤タップによるデータ削除を防ぐため、必ず2段階確認を実施。

---

### 4. 起動時チェックのタイミング

現在の実装では、`RootTabView.body` で1回だけチェック。

**制限事項:**
- アプリ起動後にCoreDataが破損した場合は検知できない
- ランタイム中のエラーは別途ハンドリングが必要

**将来的な改善案:**
```swift
// AppContainer や Repository レベルでエラーハンドリング
func saveContext() throws {
    do {
        try context.save()
    } catch {
        // エラー時にグローバル通知を発行
        NotificationCenter.default.post(name: .coreDataError, object: error)
    }
}
```

---

## 📊 メトリクス（計測推奨項目）

### 本番環境で追跡すべき指標

| 指標 | 目的 |
|------|------|
| CoreData読み込み失敗率 | エラー発生頻度の把握 |
| エラー種別の内訳 | 主な原因の特定 |
| 「再起動」選択率 | ユーザーの第一選択を把握 |
| 「サポート連絡」選択率 | サポート負荷の予測 |
| 「データリセット」選択率 | データ消失の発生頻度 |
| 再起動後の復旧率 | 一時的エラーの割合 |

**実装例（Firebase Analytics）:**
```swift
Analytics.logEvent("coredata_load_error", parameters: [
    "error_domain": error.domain,
    "error_code": error.code,
    "ios_version": UIDevice.current.systemVersion
])

Analytics.logEvent("error_action_selected", parameters: [
    "action": "restart" // or "contact_support" or "reset_data"
])
```

---

## 📚 参考資料

### Apple公式ドキュメント

- [Core Data Programming Guide - Error Handling](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/CoreData/ErrorHandling.html)
- [NSPersistentContainer Documentation](https://developer.apple.com/documentation/coredata/nspersistentcontainer)

### 関連実装

- `Logger.swift` - ログ記録の実装
- `CoreDataVisitRepository.swift` - CoreData操作の実装

---

## 📝 変更履歴

| 日付 | バージョン | 変更内容 | 担当者 |
|------|-----------|---------|--------|
| 2025-11-12 | 1.0 | 初版作成：fatalErrorからDataErrorViewへの移行 | - |

---

## 🎯 今後の改善案

### 優先度: 高

- [ ] サポートメールアドレスの設定
- [ ] Firebase Crashlytics統合
- [ ] 本番環境でのエラー発生率の計測

### 優先度: 中

- [ ] 自動バックアップ機能の実装
- [ ] リトライ機能の追加
- [ ] エラー種別に応じたメッセージのカスタマイズ

### 優先度: 低

- [ ] ランタイム中のCoreDataエラー検知
- [ ] オフラインモード（インメモリ一時保存）の検討
- [ ] データエクスポート機能（復旧支援）

---

**END OF DOCUMENT**
