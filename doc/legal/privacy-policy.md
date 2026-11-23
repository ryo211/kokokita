# プライバシーポリシー

最終更新日：2026年11月23日

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
- **収集方法**:
  - 通常の記録: ユーザーが「ココキタ」ボタンを押した際に、デバイスの位置情報サービスを使用して取得
  - 自動記録機能（オプション機能、デフォルトはオフ）: ユーザーがONにし、iOSの位置情報権限を「常に許可」にした場合、滞在地点をバックグラウンドでも検知し、訪問の「候補」として保存します。候補は自動的に訪問記録になるのではなく、ユーザーが確認・承認した場合のみ正式な訪問記録として保存されます
- **利用タイミング**:
  - 通常の記録: アプリ使用中のみ取得（ユーザーの操作時のみ）
  - 自動記録機能: ONにしている間は、バックグラウンドでも滞在地点の検知のために位置情報サービスが利用されます（iOSの滞在検知の仕組みにより省電力で動作し、常時のGPS追跡は行いません）

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

### 3.5 匿名データ送信（巡礼コースの到達記録・関心度情報）
- **収集する情報**: 匿名のユーザーID（ログインやアカウント登録は不要）、巡礼コースのスポットに到達した記録（コースID・スポットID・到達日時）、コースの閲覧・お気に入り追加の履歴（コースID・スポットID・日付）
- **収集目的**: スポットに到達した「◯人目」の表示、コースごとの到達者数・人気度の集計のため
- **収集方法**: 巡礼モードでコースのスポットへの到達を記録したとき、またはコースの閲覧・お気に入り追加を行ったときに、該当する情報のみを自動的に送信
- **送信しないもの**: 日常の訪問記録（カフェなど）、生のGPS座標の履歴、写真、タイトル・コメントなどのメタデータは送信しません
- **送信の停止**: 設定画面からいつでも送信を停止できます。停止後も記録機能はすべてそのまま利用できます（詳細は7.6を参照）

## 4. 情報の保存と管理

### 4.1 保存場所
- 訪問記録（タイトル・コメント・写真・ラベル等）、位置情報の暗号署名、アプリ設定は**すべてデバイス内のみに保存されます**
- 上記3.5に記載した匿名データ（到達記録・コース閲覧情報・匿名ID）のみ、開発者が運用するサーバーに送信されます。これ以外のユーザーデータが開発者のサーバーやクラウドに送信されることはありません
- インターネット接続がなくても記録機能は完全に動作します（匿名データの送信は、接続が確保されたタイミングでまとめて行われます）

### 4.2 データの保護
- **暗号署名**: 位置情報データには暗号署名（P256 ECDSA）が付与され、改ざんを防止
- **秘密鍵の保護**: 暗号署名に使用する秘密鍵はiOSのKeychainに安全に保存
- **写真の保存**: アプリ専用のディレクトリに保存され、他のアプリからはアクセス不可

### 4.3 偽装位置情報の検出
本アプリは、位置情報の信頼性を確保するため、以下をチェックします：
- ソフトウェアによる位置情報シミュレーション
- 外部アクセサリによる位置情報送信

偽装が検出された場合、訪問記録の作成はできません。

### 4.4 匿名データの送信先について
- 匿名データ（3.5）の保存・集計には、Supabase, Inc.が提供するクラウドサービスを利用しています
- 送信される匿名IDは本アプリ専用のものであり、他のサービスのアカウントやApple IDとは結び付けられません
- Supabaseのプライバシーポリシー: [https://supabase.com/privacy](https://supabase.com/privacy)

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
- 匿名データによる、スポットの到達順位表示・コースの人気度集計（3.5参照）

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
- アプリをアンインストールすることで、デバイス内のすべてのデータが完全に削除されます

### 7.6 匿名データ送信の停止とサーバー上のデータ削除
- 設定画面から、匿名データ（3.5）の送信をいつでもオフにできます。オフにしても記録機能や既存のデバイス内データには影響しません
- 設定画面の「サーバーのデータを削除」から、これまでに送信した匿名データ（到達記録・コース閲覧情報）をサーバーから削除できます

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
**最終改定日**: 2026年11月23日

ryo hashimoto

---
---

# Privacy Policy

Last Updated: November 23, 2026

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
- **Collection Method**:
  - Standard recording: Collected using the device's location services when the user presses the "Kokokita" button
  - Auto-Record feature (optional, off by default): When the user turns this on and grants "Always" location permission in iOS, the app detects visited places in the background and saves them as "candidates." Candidates are not automatically turned into visit records — they become official visit records only after the user reviews and approves them
- **Timing**:
  - Standard recording: Only while using the app (only on user action)
  - Auto-Record feature: While enabled, location services may be used in the background to detect visited places (this uses iOS's low-power visit-detection mechanism, not continuous GPS tracking)

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

### 3.5 Anonymous Data Transmission (Pilgrimage Course Arrivals and Interest Information)
- **Information Collected**: An anonymous user ID (no login or account registration required), records of arrivals at pilgrimage course spots (course ID, spot ID, arrival timestamp), and course viewing/favoriting activity (course ID, spot ID, date)
- **Purpose**: To display arrival rank ("You are visitor number N to arrive"), and to aggregate arrival counts and popularity per course
- **Collection Method**: Automatically sent, limited to the relevant information only, when a spot arrival is recorded in Pilgrimage Mode, or when a course is viewed or favorited
- **Not Sent**: Everyday visit records (e.g., cafes), raw GPS coordinate history, photos, and metadata such as titles or comments are never sent
- **Opting Out**: Can be disabled anytime from the Settings screen; all recording features remain fully available after opting out (see 7.6)

## 4. Information Storage and Management

### 4.1 Storage Location
- Visit records (title, comments, photos, labels, etc.), cryptographic location signatures, and app settings are **all stored only on your device**
- Only the anonymous data described in 3.5 (arrival records, course viewing information, anonymous ID) is transmitted to a server operated by the Developer. No other user data is transmitted to the Developer's servers or cloud services
- Recording features function fully without an internet connection (anonymous data is transmitted in batches once a connection is available)

### 4.2 Data Protection
- **Cryptographic Signatures**: Location data is signed with P256 ECDSA cryptographic signatures to prevent tampering
- **Private Key Protection**: Private keys used for cryptographic signatures are securely stored in iOS Keychain
- **Photo Storage**: Photos are stored in an app-specific directory and cannot be accessed by other apps

### 4.3 Fake Location Detection
The App checks for the following to ensure location data reliability:
- Software-based location simulation
- Location transmission from external accessories

If fake location is detected, visit record creation will be disabled.

### 4.4 About the Destination of Anonymous Data
- Anonymous data (3.5) is stored and aggregated using cloud services provided by Supabase, Inc.
- The anonymous ID transmitted is specific to this app and is not linked to accounts on other services or to your Apple ID
- Supabase's Privacy Policy: [https://supabase.com/privacy](https://supabase.com/privacy)

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
- Displaying spot arrival rank and aggregating course popularity using anonymous data (see 3.5)

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
- All data on your device is completely deleted by uninstalling the app

### 7.6 Stopping Anonymous Data Transmission and Deleting Server-Side Data
- Anonymous data transmission (3.5) can be turned off anytime from the Settings screen. Turning it off does not affect recording features or existing data on your device
- "Delete Server Data" in the Settings screen deletes any anonymous data (arrival records, course viewing information) previously transmitted to the server

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
**Last Revised**: November 23, 2026

ryo hashimoto
