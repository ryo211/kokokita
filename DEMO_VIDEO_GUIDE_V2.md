# デモビデオ作成ガイド V2 - ココキタ（写真機能を含む）

## App Review からの追加要求

**新しい要件**:
- 「Photo」ボタンをタップした時の動作を明確に示す
- カメラ権限リクエストの表示
- 写真添付の一連の流れ

---

## 撮影フロー（更新版）

### 準備
- アプリを削除して再インストール（初回起動状態にする）
- 画面収録を開始

### 撮影シナリオ

```
1. アプリ起動
   ↓
2. ホーム画面（空の状態）表示
   ↓
3. 「ココキタ」ボタンをタップ
   ↓
4. 【重要】位置情報許可ダイアログ表示
   → 「Appの使用中は許可」をタップ
   → スクリーンショット撮影（システムダイアログは録画されないため）
   ↓
5. 位置情報取得中のインジケーター表示
   ↓
6. プロンプトシート表示（「そのまま保存」「情報を入力」「ココカモ」）
   ↓
7. 「情報を入力」を選択
   ↓
8. 編集画面でタイトル入力
   ↓
9. 【新規追加】写真ボタンをタップ
   ↓
10. 【重要】カメラ権限リクエストダイアログ表示
    → 「許可」をタップ
    ↓
11. カメラ起動 → 写真撮影
    ↓
12. 写真が添付されたことを確認
    ↓
13. 【オプション】「写真」ボタンをタップして写真ライブラリから追加
    ↓
14. 【重要】写真ライブラリ権限リクエストダイアログ表示
    → 「フルアクセスを許可」をタップ
    ↓
15. 写真を選択して追加
    ↓
16. 複数枚の写真が添付されたことを確認
    ↓
17. 「保存」ボタンをタップ
    ↓
18. ホーム画面に戻り、記録が追加されたことを確認
    ↓
19. 記録をタップして詳細画面を表示
    ↓
20. 地図と写真が表示されることを確認
    ↓
21. 写真をタップして拡大表示を確認
```

---

## 撮影時の重要ポイント

### 必ず含めるべき内容

#### 1. 位置情報許可ダイアログ ✅
- 初回起動時に表示される
- スクリーンショットも撮影（録画に含まれないため）

#### 2. カメラ権限リクエストダイアログ ✅ **【新規要求】**
```
"Kokokita" Would Like to Access the Camera

Kokokita uses the camera to take photos that can be
attached to your visit records. For example, you can
capture a photo of a location you visited and save it
with your record. Photos are stored locally on your device.

[Don't Allow] [OK]
```
- **必ず「OK」をタップして許可する様子を見せる**

#### 3. 写真ライブラリ権限リクエストダイアログ ✅ **【新規要求】**
```
"Kokokita" Would Like to Access Your Photos

Kokokita accesses your photo library to let you attach
existing photos to your visit records. For example, you
can select a photo from your library and add it to a
location record. Photos are stored locally on your device.

[Select Photos...] [Allow Full Access] [Don't Allow]
```
- **必ず「Allow Full Access」をタップして許可する様子を見せる**

#### 4. 写真添付の動作 ✅ **【新規要求】**
- カメラボタンをタップ → カメラ起動 → 撮影
- 写真ボタンをタップ → 写真ライブラリ表示 → 選択
- サムネイルが表示されることを確認

#### 5. 複数枚の写真 ✅ **【推奨】**
- 2〜3枚の写真を添付して、複数枚対応を示す

---

## 撮影手順（詳細）

### ステップ1: アプリの初期化

```bash
# iPhoneでアプリを削除
長押し → 削除

# Xcodeから再インストール（リリースビルド）
Product → Run (Release scheme)
```

### ステップ2: 画面収録開始

1. コントロールセンターを開く
2. 画面収録ボタンをタップ
3. 3秒のカウントダウン後、録画開始

### ステップ3: アプリ起動〜位置情報許可

1. ホーム画面から「ココキタ」アイコンをタップ
2. アプリ起動（空のホーム画面表示）
3. 画面下部中央の「ココキタ」ボタンをタップ
4. 位置情報許可ダイアログ表示
   - **ここでスクリーンショット撮影**（電源+音量上げ）
   - 「Appの使用中は許可」をタップ
5. 位置情報取得中...（数秒待機）

### ステップ4: プロンプトシート〜編集画面

1. プロンプトシート表示
2. 「情報を入力」をタップ
3. タイトル欄に「Test Record」と入力

### ステップ5: 写真添付（カメラ） **【重要】**

1. **「カメラ」ボタン**をタップ
   - カメラアイコンのボタン
2. **カメラ権限リクエストダイアログ表示**
   - Purpose Stringが表示される
   - **必ず「OK」をタップ**
3. カメラ起動
4. 何かを撮影（机、壁、手など何でもOK）
5. 「Use Photo」をタップ
6. サムネイルが表示されることを確認（1〜2秒待機）

### ステップ6: 写真添付（ライブラリ） **【重要】**

1. **「写真」ボタン**をタップ
   - 写真アイコンのボタン
2. **写真ライブラリ権限リクエストダイアログ表示**
   - Purpose Stringが表示される
   - **必ず「Allow Full Access」をタップ**
3. 写真ライブラリ表示
4. 写真を1〜2枚選択
5. サムネイルが複数表示されることを確認（1〜2秒待機）

### ステップ7: 保存〜確認

1. 画面上部の「保存」ボタンをタップ
2. ホーム画面に戻る
3. 記録が1件追加されたことを確認（1〜2秒待機）
4. 記録をタップして詳細画面を表示
5. 地図が表示されることを確認
6. 写真が表示されることを確認
7. 写真をタップして拡大表示（1〜2秒待機）

### ステップ8: 画面収録停止

1. コントロールセンターを開く
2. 画面収録ボタンをタップして停止
3. ビデオが写真アプリに保存される

---

## アップロードと提出

### 1. ビデオの確認

撮影後、以下を確認：
- ✅ カメラ権限ダイアログが含まれている
- ✅ 写真ライブラリ権限ダイアログが含まれている
- ✅ 位置情報許可ダイアログのスクリーンショットを撮影した
- ✅ 写真添付の動作が明確
- ✅ 複数枚の写真が表示されている

### 2. アップロード

前回と同様にYouTube（限定公開）とGoogle Driveにアップロード

### 3. App Store Connect での設定

App Review Information セクションに新しいビデオURLを追加

---

## Resolution Center への返信

```
Thank you for your feedback.

We have updated the camera and photo library permission purpose strings in Info.plist to provide clear explanations with specific examples of how the app uses these permissions.

Updated Purpose Strings:

1. Camera Access (NSCameraUsageDescription):
"Kokokita uses the camera to take photos that can be attached to your visit records. For example, you can capture a photo of a location you visited and save it with your record. Photos are stored locally on your device."

2. Photo Library Access (NSPhotoLibraryUsageDescription):
"Kokokita accesses your photo library to let you attach existing photos to your visit records. For example, you can select a photo from your library and add it to a location record. Photos are stored locally on your device."

3. Location Access (NSLocationWhenInUseUsageDescription):
"Kokokita uses your location to record where you have been. For example, when you tap the 'Kokokita' button, the app captures your current GPS coordinates and saves them with a tamper-proof digital signature. Location data is stored locally on your device and never shared without your permission."

We have also created a new demo video showing the complete flow including:
- Location permission request
- Camera permission request with the new purpose string
- Taking a photo with the camera
- Photo library permission request with the new purpose string
- Selecting photos from the library
- Attaching multiple photos to a visit record
- Viewing the saved record with photos

Demo Video Links:
YouTube (Unlisted): [YouTube URL]
Google Drive: [Google Drive URL]

Both links contain the same video content.

Test device information:
- Device: iPhone 17
- iOS version: 26.1
- Build: Build 5 (Version 1.0)

Please let us know if you need any additional information.

Best regards,
```

---

## チェックリスト

提出前に確認：

### コード変更（Build 5）
- [ ] Info.plist に NSCameraUsageDescription を追加
- [ ] Info.plist に NSPhotoLibraryUsageDescription を追加
- [ ] Info.plist に NSLocationWhenInUseUsageDescription を確認
- [ ] ビルド番号を 5 にインクリメント
- [ ] Archive と Upload を実行

### デモビデオ
- [ ] アプリを再インストール（初回起動状態）
- [ ] 位置情報許可ダイアログ表示
- [ ] 位置情報許可ダイアログのスクリーンショット撮影
- [ ] カメラ権限ダイアログ表示 ← **重要**
- [ ] カメラで写真撮影
- [ ] 写真ライブラリ権限ダイアログ表示 ← **重要**
- [ ] ライブラリから写真選択
- [ ] 複数枚の写真が添付されたことを確認
- [ ] 保存して詳細画面で写真確認
- [ ] YouTube と Google Drive にアップロード

### App Store Connect
- [ ] Build 5 を選択
- [ ] 新しいビデオURLを App Review 情報に追加
- [ ] Resolution Center で返信
- [ ] 審査に提出

---

このガイドに従って撮影すれば、Apple の要求を満たすデモビデオが完成します。
