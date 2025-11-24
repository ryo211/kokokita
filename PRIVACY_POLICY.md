# プライバシーポリシー

最終更新日：2025年11月

## 1. はじめに

ryo hashimoto（以下「開発者」）が提供するiOSアプリケーション「ココキタ」（以下「本アプリ」）は、ユーザーの皆様のプライバシーを尊重し、個人情報の保護に努めます。本プライバシーポリシーは、本アプリにおける情報の取り扱いについて説明するものです。

## 2. 開発者情報

- **開発者**: ryo hashimoto
- **アプリ名**: ココキタ
- **Bundle ID**: com.irodori.kokokita.app

## 3. 収集する情報

本アプリは、以下の情報を収集します。

### 3.1 位置情報
- **収集する情報**: GPS座標（緯度・経度）、位置精度、取得日時
- **収集目的**: 訪問記録の作成・管理機能を提供するため
- **収集方法**: ユーザーが「ココキタ」ボタンを押した際に、デバイスの位置情報サービスを使用して取得
- **利用タイミング**: アプリ使用中のみ（バックグラウンドでは取得しません）

### 3.2 写真
- **収集する情報**: ユーザーが選択した写真データ
- **収集目的**: 訪問記録に写真を添付する機能を提供するため
- **収集方法**: ユーザーがカメラで撮影、またはフォトライブラリから選択
- **保存枚数**: 1つの訪問記録につき最大4枚

### 3.3 訪問記録データ
- **収集する情報**: タイトル、コメント、施設情報（名称、住所、電話番号、カテゴリ）、ラベル、グループ、メンバー情報
- **収集目的**: 訪問記録の管理機能を提供するため
- **収集方法**: ユーザーがアプリ内で入力

### 3.4 アプリ設定情報
- **収集する情報**: フィルタ設定、表示順序などのアプリ内設定
- **収集目的**: アプリの利便性向上のため
- **保存場所**: デバイス内のローカルストレージ（UserDefaults）

## 4. 情報の保存と管理

### 4.1 保存場所
- **すべてのデータはデバイス内のみに保存されます**
- 開発者のサーバーやクラウドには一切送信されません
- インターネット接続がなくてもアプリは完全に動作します

### 4.2 データの保護
- **暗号署名**: 位置情報データには暗号署名（P256 ECDSA）が付与され、改ざんを防止
- **秘密鍵の保護**: 暗号署名に使用する秘密鍵はiOSのKeychainに安全に保存
- **写真の保存**: アプリ専用のディレクトリに保存され、他のアプリからはアクセス不可

### 4.3 偽装位置情報の検出
本アプリは、位置情報の信頼性を確保するため、以下をチェックします：
- ソフトウェアによる位置情報シミュレーション
- 外部アクセサリによる位置情報送信

偽装が検出された場合、訪問記録の作成はできません。

## 5. 第三者への情報提供

### 5.1 広告配信サービス
本アプリは、Google AdMob（Google LLC提供）を使用して広告を表示します。

- **提供される可能性のある情報**:
  - 広告識別子（IDFA）- ユーザーが許可した場合のみ
  - デバイス情報（OSバージョン、デバイスモデル）
  - アプリ使用状況（アプリの起動、広告の表示・クリック）
  - IPアドレス（概ねの位置情報の推定に使用される場合があります）

- **Google AdMobのプライバシーポリシー**:
  [https://policies.google.com/privacy](https://policies.google.com/privacy)

- **個人情報の送信について**:
  - 本アプリが記録する位置情報、写真、訪問記録データは、Google AdMobに送信されません
  - 広告配信に必要な情報のみがGoogle AdMobに送信されます

### 5.2 その他の第三者提供
上記以外に、ユーザーの個人情報を第三者に提供することはありません。ただし、以下の場合を除きます：
- 法令に基づく場合
- 人の生命、身体または財産の保護のために必要がある場合
- ユーザーの同意がある場合

## 6. 情報の利用目的

収集した情報は、以下の目的でのみ使用されます：
- 訪問記録の作成・表示・管理機能の提供
- アプリの機能改善および不具合修正
- 広告の配信（Google AdMob経由）
- カスタマーサポートの提供

## 7. ユーザーの権利

### 7.1 データの管理
- すべてのデータはユーザー自身が管理できます
- 訪問記録、写真、タグ（ラベル、グループ、メンバー）はアプリ内でいつでも削除可能

### 7.2 位置情報の利用停止
- iOSの設定から、いつでも位置情報の利用を停止できます
- 設定 > プライバシーとセキュリティ > 位置情報サービス > ココキタ

### 7.3 写真アクセスの停止
- iOSの設定から、いつでも写真アクセスを停止できます
- 設定 > プライバシーとセキュリティ > 写真 > ココキタ

### 7.4 広告トラッキングの制限
- iOSの設定から、広告トラッキングを制限できます
- 設定 > プライバシーとセキュリティ > トラッキング

### 7.5 データの完全削除
- アプリをアンインストールすることで、すべてのデータが完全に削除されます

## 8. 未成年者の利用

本アプリは、年齢制限なくご利用いただけます。ただし、13歳未満の方が本アプリを利用する場合は、保護者の方の同意を得た上でご利用いただくことを推奨します。本アプリは位置情報や写真などの個人情報を扱うため、保護者の方は本プライバシーポリシーの内容をご確認の上、お子様の利用を管理してください。

## 9. セキュリティ

開発者は、収集した情報の漏洩、紛失、改ざんを防止するため、以下の対策を実施しています：
- 暗号署名による改ざん検出
- iOS Keychainを使用した秘密鍵の安全な保管
- アプリサンドボックスによるデータの隔離
- 定期的なセキュリティレビュー

## 10. プライバシーポリシーの変更

開発者は、法令の変更や本アプリの機能追加に伴い、本プライバシーポリシーを変更することがあります。重要な変更がある場合は、アプリ内または本ページで通知します。

## 11. お問い合わせ

本プライバシーポリシーに関するご質問、ご意見、または個人情報の取り扱いに関するお問い合わせは、以下までご連絡ください。

- **メールアドレス**: irodori.developer@gmail.com

---

**制定日**: 2025年11月25日
**最終改定日**: 2025年11月25日

ryo hashimoto

---
---

# Privacy Policy

Last Updated: November 2025

## 1. Introduction

This Privacy Policy explains how ryo hashimoto (hereinafter referred to as "the Developer") handles information in the iOS application "Kokokita" (hereinafter referred to as "the App"). The Developer respects your privacy and is committed to protecting your personal information.

## 2. Developer Information

- **Developer**: ryo hashimoto
- **App Name**: Kokokita
- **Bundle ID**: com.irodori.kokokita.app

## 3. Information We Collect

The App collects the following information:

### 3.1 Location Information
- **Information Collected**: GPS coordinates (latitude and longitude), location accuracy, timestamp
- **Purpose**: To provide visit recording and management features
- **Collection Method**: Collected using the device's location services when the user presses the "Kokokita" button
- **Timing**: Only while using the app (not collected in the background)

### 3.2 Photos
- **Information Collected**: Photo data selected by the user
- **Purpose**: To attach photos to visit records
- **Collection Method**: Captured with the camera or selected from the photo library by the user
- **Storage Limit**: Maximum of 4 photos per visit record

### 3.3 Visit Record Data
- **Information Collected**: Title, comments, facility information (name, address, phone number, category), labels, groups, member information
- **Purpose**: To provide visit record management features
- **Collection Method**: Entered by the user within the app

### 3.4 App Settings Information
- **Information Collected**: Filter settings, display order, and other in-app settings
- **Purpose**: To improve app usability
- **Storage Location**: Device local storage (UserDefaults)

## 4. Information Storage and Management

### 4.1 Storage Location
- **All data is stored only on your device**
- No data is transmitted to the Developer's servers or cloud services
- The app functions fully without an internet connection

### 4.2 Data Protection
- **Cryptographic Signatures**: Location data is signed with P256 ECDSA cryptographic signatures to prevent tampering
- **Private Key Protection**: Private keys used for cryptographic signatures are securely stored in iOS Keychain
- **Photo Storage**: Photos are stored in an app-specific directory and cannot be accessed by other apps

### 4.3 Fake Location Detection
The App checks for the following to ensure location data reliability:
- Software-based location simulation
- Location transmission from external accessories

If fake location is detected, visit record creation will be disabled.

## 5. Third-Party Information Sharing

### 5.1 Advertising Services
The App uses Google AdMob (provided by Google LLC) to display advertisements.

- **Information that may be shared**:
  - Advertising Identifier (IDFA) - only if permitted by the user
  - Device information (OS version, device model)
  - App usage (app launches, ad views and clicks)
  - IP address (may be used to estimate approximate location)

- **Google AdMob Privacy Policy**:
  [https://policies.google.com/privacy](https://policies.google.com/privacy)

- **Personal Information Transmission**:
  - Location information, photos, and visit record data recorded by the App are NOT transmitted to Google AdMob
  - Only information necessary for ad delivery is transmitted to Google AdMob

### 5.2 Other Third-Party Sharing
The Developer does not provide user personal information to third parties except as described above, unless:
- Required by law
- Necessary to protect the life, body, or property of a person
- User consent is obtained

## 6. Purpose of Information Use

Collected information is used only for the following purposes:
- Providing visit record creation, display, and management features
- App improvement and bug fixes
- Ad delivery (via Google AdMob)
- Customer support

## 7. User Rights

### 7.1 Data Management
- All data can be managed by the user
- Visit records, photos, and tags (labels, groups, members) can be deleted anytime within the app

### 7.2 Disabling Location Services
- Location services can be disabled anytime from iOS settings
- Settings > Privacy & Security > Location Services > Kokokita

### 7.3 Disabling Photo Access
- Photo access can be disabled anytime from iOS settings
- Settings > Privacy & Security > Photos > Kokokita

### 7.4 Limiting Ad Tracking
- Ad tracking can be limited from iOS settings
- Settings > Privacy & Security > Tracking

### 7.5 Complete Data Deletion
- All data is completely deleted by uninstalling the app

## 8. Use by Minors

The App can be used without age restrictions. However, if a child under 13 years of age uses the App, we recommend obtaining parental consent before use. Since the App handles personal information such as location data and photos, parents should review this Privacy Policy and manage their child's use accordingly.

## 9. Security

The Developer implements the following measures to prevent information leakage, loss, and tampering:
- Tampering detection using cryptographic signatures
- Secure storage of private keys using iOS Keychain
- Data isolation through app sandboxing
- Regular security reviews

## 10. Changes to Privacy Policy

The Developer may update this Privacy Policy due to legal changes or app feature additions. In the event of significant changes, users will be notified within the app or on this page.

## 11. Contact

For questions, comments, or inquiries regarding this Privacy Policy or personal information handling, please contact:

- **Email**: irodori.developer@gmail.com

---

**Effective Date**: November 25, 2025
**Last Revised**: November 25, 2025

ryo hashimoto
