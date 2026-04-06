# コース作成機能 実装仕様書

## 概要

ユーザーが独自の聖地巡礼コースを作成・管理できる機能を実装する。
既存のコース詳細画面（SwiftUI）をベースとしたUIで、スポットの追加・編集・並び替えが可能。
作成したコースはCoreDataに保存され、コース一覧に反映して巡礼達成判定の対象にできる。

---

## 前提・制約

- 言語: Swift / SwiftUI
- データ層: CoreData（既存スキーマを拡張）
- 画像保存: 端末内ローカル（FileManager）
- v1スコープ: セクション機能は対象外（スポット直下のみ）
- 遷移方式: NavigationPush

---

## 1. CoreDataモデル変更

### 既存エンティティ `Course` に追加するフィールド

| フィールド名 | 型 | デフォルト | 説明 |
|---|---|---|---|
| `isUserCreated` | Bool | false | ユーザー作成コースかどうか（既存フィールドの確認・追加） |
| `isEnabled` | Bool | true | コース一覧への表示・達成判定の有効/無効 |
| `allowRetroactive` | Bool | false | 後付け記録を達成判定に含めるか |
| `localCoverImagePath` | String? | nil | 端末内カバー画像パス |

### 既存エンティティ `Spot` に追加するフィールド

| フィールド名 | 型 | デフォルト | 説明 |
|---|---|---|---|
| `localCoverImagePath` | String? | nil | 端末内スポット画像パス |

> 既存の `coverImageUrl` はURL文字列として残す。ローカル画像はパスで別管理する。

---

## 2. JSON仕様との対応関係

ユーザー作成コースのデータ構造は **`course-json-spec.md`のコースJSONフォーマット**に準拠する。
CoreDataの各フィールドとJSON仕様フィールドの対応は以下の通り。

### Courseエンティティ ↔ CourseJSON

| JSON仕様フィールド | CoreData フィールド | ユーザー作成時の固定値 / 備考 |
|---|---|---|
| `id` | `id` | 新規作成時に `course-user-{UUID下8桁}-001` 形式で生成 |
| `courseType` | `courseType` | `"my_list"` 固定 |
| `title` | `title` | ユーザー入力 |
| `summary` | `summary` | ユーザー入力（任意） |
| `source` | `source` | `"user"` 固定 |
| `isUserCreated` | `isUserCreated` | `true` 固定 |
| `version` | `version` | 初回作成時 `1`、編集保存のたびにインクリメント |
| `recognitionRadiusMeters` | `recognitionRadiusMeters` | ユーザー設定（デフォルト `150.0`） |
| `detailUrl` | `detailUrl` | `null` 固定 |
| `coverImageUrl` | `coverImageUrl` / `localCoverImagePath` | ローカル画像は `localCoverImagePath` に保存。`coverImageUrl` は将来のUGC公開時に使用 |
| `categories` | `categories` | `["anime"]` をデフォルト。UIで変更可能 |
| `sections` | — | v1は非対応。`spots` 直下形式のみ |
| `spots` | `spots`（リレーション） | 後述のSpotJSON対応を参照 |

### Spotエンティティ ↔ SpotJSON

| JSON仕様フィールド | CoreData フィールド | 備考 |
|---|---|---|
| `spotId` | `spotId` | 新規作成時に `{コース略称}-{3桁連番}` 形式で生成 |
| `name` | `name` | ユーザー入力 |
| `address` | `address` | 場所選択時に自動入力（任意） |
| `latitude` | `latitude` | 場所選択時に自動入力。未設定時は `null`（GPS認識対象外） |
| `longitude` | `longitude` | 場所選択時に自動入力。未設定時は `null`（GPS認識対象外） |
| `spotDescription` | `spotDescription` | ユーザー入力（任意） |
| `coverImageUrl` | `coverImageUrl` / `localCoverImagePath` | ローカル画像は `localCoverImagePath` に保存 |
| `orderIndex` | `orderIndex` | 並び替え後に配列順で連番振り直し |
| `recognitionRadiusMeters` | `recognitionRadiusMeters` | 個別設定時のみ値を持つ。コースデフォルト使用時は `null` |

### CourseJSONへのエクスポートメソッド

将来のUGC公開・バックアップ対応を見据え、CoreDataエンティティからJSON仕様準拠の構造体に変換するメソッドを実装すること。

```swift
// Course+Export.swift（Courseエンティティの拡張として実装）
extension Course {
    /// course-json-spec.md 準拠のCourseJSONに変換する
    func toCourseJSON() -> CourseJSON {
        CourseJSON(
            id: self.id ?? "",
            courseType: self.courseType ?? "my_list",
            title: self.title ?? "",
            summary: self.summary,
            source: self.source ?? "user",
            isUserCreated: self.isUserCreated,
            version: Int(self.version),
            recognitionRadiusMeters: self.recognitionRadiusMeters,
            detailUrl: self.detailUrl,
            coverImageUrl: self.coverImageUrl,   // UGC公開時はS3 URLを設定
            categories: self.categoriesArray,    // CoreDataのtransformableまたはカンマ区切りString
            sections: nil,                        // v1非対応
            spots: self.spotsArray
                .sorted { $0.orderIndex < $1.orderIndex }
                .map { $0.toSpotJSON() }
        )
    }
}

extension Spot {
    func toSpotJSON() -> SpotJSON {
        SpotJSON(
            spotId: self.spotId ?? "",
            name: self.name ?? "",
            address: self.address,
            latitude: self.latitude == 0 ? nil : self.latitude,
            longitude: self.longitude == 0 ? nil : self.longitude,
            spotDescription: self.spotDescription,
            coverImageUrl: self.coverImageUrl,
            orderIndex: Int(self.orderIndex),
            recognitionRadiusMeters: self.recognitionRadiusMeters == 0 ? nil : self.recognitionRadiusMeters
        )
    }
}
```

> `CourseJSON` / `SpotJSON` は既存のJSONデコード用Codable構造体を流用すること。
> 既存構造体がない場合は `course-json-spec.md` のスキーマに従い新規定義する。

---

## 3. タブバー変更

### 対象: 巡礼モードのタブバー

現在の構成:
```
[ホーム] [コース]
```

変更後の構成:
```
[ホーム] [コース] [マイリスト]
```

- タブ名: `マイリスト`
- アイコン: `person.text.rectangle`（SF Symbols）
- タブIndex: 2

---

## 4. マイリスト画面

### ファイル
`Views/MyList/MyListView.swift`

### 概要
ユーザーが作成したコースの一覧画面。

### UI仕様

- **ナビゲーションタイトル**: `マイリスト`
- **新規作成ボタン**: ナビゲーションバー右上に `+` ボタン
  - タップ → `CourseEditorView` へNavigationPush（新規作成モード）
- **コース一覧**: `List` または `ScrollView + LazyVStack`
  - `isUserCreated == true` のコースのみ表示
  - `CoreData` から `@FetchRequest` で取得

### コース行セル（`MyListCourseRowView`）

```
[ カバー画像 or プレースホルダー ]  コースタイトル
                                  スポット数 件
                                  [ 有効 / 無効 トグル ]
```

- カバー画像: `localCoverImagePath` があれば表示、なければカテゴリアイコン
- トグル: `isEnabled` をその場で更新（CoreData save）
- 行タップ: `CourseEditorView` へNavigationPush（編集モード）
- スワイプ削除: コース・紐づくスポットをCoreDataから削除

### 空状態

コースが0件のとき:
```
（アイコン）
まだコースがありません
+ 新しいコースを作成する  ← タップで新規作成
```

---

## 5. コース作成・編集画面

### ファイル
`Views/MyList/CourseEditorView.swift`

### 初期化

```swift
// 新規作成
CourseEditorView(mode: .create)

// 編集
CourseEditorView(mode: .edit(course: existingCourse))
```

### レイアウト

既存のコース詳細画面と同じ **地図上半分・スポットリスト下半分** の構成。

```
┌─────────────────────────────┐
│  ← [コースタイトル（編集可）]  ✓保存  │  ← ナビゲーションバー
├─────────────────────────────┤
│                             │
│       MapView（上半分）       │
│  スポットのピンを番号付きで表示   │
│                             │
├─────────────────────────────┤
│  [コース設定セクション]        │
│  説明文 / 画像 / 半径 / 設定   │
│                             │
│  スポット一覧（番号付き）       │
│  ┌──────────────────────┐  │
│  │ ① スポット名          │  │
│  │   説明文             ≡ │  │  ← ドラッグハンドル
│  └──────────────────────┘  │
│  ┌──────────────────────┐  │
│  │ ② スポット名          │  │
│  └──────────────────────┘  │
│                             │
│  [＋ スポットを追加]ボタン    │
└─────────────────────────────┘
```

### ナビゲーションバー

| 要素 | 内容 |
|---|---|
| 左: 戻るボタン | 未保存変更がある場合は確認ダイアログを表示 |
| 中央: タイトル | インライン編集可能なTextField |
| 右: 保存ボタン | `保存` テキストボタン。バリデーション通過後にCoreData保存 |

### コース設定セクション

スポット一覧の上部に折りたたみ可能なセクションとして配置。

| 項目 | UI | 説明 |
|---|---|---|
| カバー画像 | `PhotosPicker` + プレビュー表示 | 選択画像をFileManagerに保存しパスを記録 |
| コース説明 | 複数行 `TextField` | `summary` に対応 |
| 達成判定半径 | `Slider`（50m〜1000m） + 数値表示 | `recognitionRadiusMeters` のデフォルト値 |
| 後付け記録を有効にする | `Toggle` | `allowRetroactive` |

### スポット一覧

- `List` の `EditMode` を使い、ドラッグによる並び替えを実現
- 各スポット行:
  - 左: 番号バッジ（`①②③`形式、または数字丸囲み）
  - 中央: スポット名・説明文（タップで `SpotEditorSheet` を表示）
  - 右: ドラッグハンドル（`≡`）
  - スワイプ削除対応
- 並び替え後に `orderIndex` を連番で振り直す

### ＋ スポットを追加ボタン

リスト末尾に固定表示。タップで `SpotEditorSheet` を表示（新規作成モード）。

### バリデーション

- タイトルが空のとき保存ボタンをdisabled
- スポットが0件でも保存可（空コースを許容）

### 保存処理

保存するデータは **`course-json-spec.md` のCourseJSON / SpotJSONスキーマに準拠**すること（セクション2「JSON仕様との対応関係」参照）。

1. CoreDataのCourseエンティティを作成または更新
2. 以下の固定値を設定:
   - `source = "user"`
   - `isUserCreated = true`
   - `courseType = "my_list"`
   - `id`: 新規作成時のみ `course-user-{UUID下8桁}-001` 形式で生成
   - `version`: 新規作成時 `1`、編集時はインクリメント
3. ユーザー入力値を設定: `title`, `summary`, `recognitionRadiusMeters`, `categories`
4. 全Spotを保存（`orderIndex` を配列順に `0` 始まりの連番で設定）
   - 各SpotのID: `{コース略称}-{3桁連番}`（例: `user-001`）
5. カバー画像がある場合: `LocalImageStorage` で保存し、パスを `localCoverImagePath` に記録
6. `context.save()`

---

## 6. スポット作成・編集シート

### ファイル
`Views/MyList/SpotEditorSheet.swift`

### 初期化

```swift
// 新規作成
SpotEditorSheet(mode: .create, onSave: { spot in ... })

// 編集
SpotEditorSheet(mode: .edit(spot: existingSpot), onSave: { spot in ... })
```

### 表示形式
`.sheet` モーダル（`.presentationDetents([.large])`）

### シート構成

タブまたはセグメントで **場所選択モード** を切り替える。

```
┌─────────────────────────────┐
│  キャンセル  スポット追加  追加 │
├─────────────────────────────┤
│ [場所名検索｜地図選択｜写真から｜記録から] │  ← セグメント
├─────────────────────────────┤
│                             │
│   （選択モードに応じたUI）    │
│                             │
├─────────────────────────────┤
│  ── スポット情報 ──          │
│  タイトル: [___________]    │
│  説明文:  [___________]    │
│  画像:    [PhotosPicker]   │
│  判定半径: [Slider or nil]  │
└─────────────────────────────┘
```

### 場所選択モード①: 場所名検索

- `TextField` に場所名・住所を入力
- MKLocalSearch を使用して候補リストを表示
- 候補タップ → `MKMapItem` から `coordinate`, `name`, `placemark.thoroughfare` を取得
- 取得した情報でタイトル・緯度経度を自動入力

### 場所選択モード②: 地図選択

- `Map` を全幅表示
- 地図の中央に固定ピン（`Image(systemName: "mappin")` をオーバーレイ）
- 「この場所を選択」ボタンで、現在の地図中央座標を緯度経度として確定
- 逆ジオコーディング（`CLGeocoder`）で住所を取得してaddressに設定

### 場所選択モード③: 写真から取り込み

- `PhotosPicker` でフォトライブラリから画像を選択
- `PHAsset` のEXIF情報から `CLLocationCoordinate2D` を取得
- 座標が取得できた場合: 緯度経度を自動入力
- 座標が取得できない場合: `「この写真には位置情報が含まれていません」` を表示

```swift
// EXIF座標取得の実装イメージ
PHImageManager.default().requestImageDataAndOrientation(for: asset, options: nil) { data, _, _, _ in
    guard let data, let source = CGImageSourceCreateWithData(data as CFData, nil),
          let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any],
          let gps = props[kCGImagePropertyGPSDictionary as String] as? [String: Any],
          let lat = gps[kCGImagePropertyGPSLatitude as String] as? Double,
          let lon = gps[kCGImagePropertyGPSLongitude as String] as? Double else { return }
    // latRef/lonRef で符号を決定
}
```

### 場所選択モード④: 記録から選択

- 既存の訪問記録（CoreDataの `VisitRecord` 等）の一覧を表示
- 検索・フィルタ対応（日付・ラベル等）
- 記録を選択 → その記録の緯度経度・場所名をスポット情報に自動入力

### スポット情報フォーム（共通）

| 項目 | UI | 備考 |
|---|---|---|
| タイトル | `TextField` | 必須。場所選択時に自動入力（上書き可） |
| 説明文 | `TextField`（複数行） | 任意 |
| 画像 | `PhotosPicker` + サムネイル | 選択画像をローカル保存 |
| 達成判定半径 | `Toggle`（コースデフォルトを使用）+ `Slider`（個別設定時） | toggleオフでnull扱い |

### 追加ボタン

- タイトルが空のとき disabled
- 緯度経度が未設定のとき警告表示（保存は可能、GPS認識対象外として扱う）
- タップ → `onSave` クロージャを呼び出し、シートを閉じる

---

## 7. 画像ローカル保存ユーティリティ

### ファイル
`Utilities/LocalImageStorage.swift`

```swift
final class LocalImageStorage {
    static let shared = LocalImageStorage()
    
    /// 画像を保存してパスを返す
    func save(_ image: UIImage, id: String) throws -> String
    
    /// パスから画像を読み込む
    func load(from path: String) -> UIImage?
    
    /// 画像を削除する
    func delete(at path: String) throws
}
```

- 保存先: `FileManager.default.urls(for: .documentDirectory)[0]/course_images/`
- ファイル名: `{uuid}.jpg`
- JPEG圧縮率: 0.8

---

## 8. コース一覧への反映

既存のコース一覧画面（`CourseListView` 等）の `@FetchRequest` 条件を変更する。

### 変更前（推定）
```swift
// bundled / downloaded のコースを表示
```

### 変更後
```swift
// bundled / downloaded に加えて、
// isUserCreated == true かつ isEnabled == true のコースも表示
let predicate = NSPredicate(
    format: "source IN %@ OR (isUserCreated == YES AND isEnabled == YES)",
    ["bundled", "downloaded"]
)
```

---

## 9. 達成判定ロジックへの影響

既存の巡礼達成判定（GPS認識でスポットをチェック済みにする処理）に以下の条件を追加する。

- コースの `isEnabled == false` のコースは判定対象外
- コースの `allowRetroactive == false` のとき、後付け記録はそのコースの達成にカウントしない

> 既存のバンドル・ダウンロードコースは `allowRetroactive` のデフォルトを既存挙動に合わせること（`false` を推奨）。

---

## 10. ファイル構成（追加・変更対象）

```
kokokita/
├── CoreData/
│   └── KokokitaModel.xcdatamodeld     # Course, Spot に新規フィールド追加
│
├── Views/
│   ├── TabBar/
│   │   └── MainTabView.swift          # マイリストタブ追加
│   │
│   └── MyList/
│       ├── MyListView.swift           # マイリスト一覧画面（新規）
│       ├── MyListCourseRowView.swift  # コース行セル（新規）
│       ├── CourseEditorView.swift     # コース作成・編集画面（新規）
│       └── SpotEditorSheet.swift     # スポット作成・編集シート（新規）
│
├── Utilities/
│   └── LocalImageStorage.swift       # 画像ローカル保存（新規）
│
└── ViewModels/ （使用している場合）
    └── CourseEditorViewModel.swift    # 編集状態管理（新規）
```

---

## 11. 実装順序（推奨）

1. **CoreDataモデル変更** → マイグレーション設定
2. **LocalImageStorage** ユーティリティ実装
3. **タブバーにマイリストタブ追加**
4. **MyListView** + **MyListCourseRowView**（一覧表示・isEnabled切り替え）
5. **CourseEditorView**（コース情報編集・スポット一覧・保存処理）
6. **SpotEditorSheet** の各選択モード実装
   - 場所名検索（MKLocalSearch）
   - 地図選択（Map + 中央ピン）
   - 写真から（EXIF取得）
   - 記録から選択
7. **コース一覧への反映**（FetchRequest条件追加）
8. **達成判定ロジック**への条件追加

---

## 12. スコープ外（v2以降）

- セクション（グループ）機能
- コースのJSONエクスポート・インポート
- コースのストア公開（UGCフェーズ）