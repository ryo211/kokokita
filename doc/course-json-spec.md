# コース JSON 仕様書

コース機能で使用する JSON ファイルは3種類あります。

---

## ファイル一覧

| ファイル | 役割 | 配置場所 |
|---------|------|---------|
| `courses/index.json` | バンドルコースの一覧と表示順 | アプリバンドル内 |
| `courses/{id}.json` | コースデータ本体 | バンドル内 / サーバー |
| `store/index.json` | ストア公開コースの一覧とメタ情報 | サーバー |

---

## 1. バンドルコース インデックス（`courses/index.json`）

アプリに同梱するコースの一覧と表示順を管理します。

### スキーマ

```json
["world_heritage_japan_001", "100_famous_castles_japan_001"]
```

文字列配列で、各要素は `courses/` フォルダ内の JSON ファイル名（拡張子なし）です。

### ルール

- 配列の順番がコース一覧の表示順になります
- ここに記載のないバンドルコース（`source: "bundled"`）はアプリ起動時に CoreData から自動削除されます
- ダウンロードコース（`source: "downloaded"`）・ユーザー作成コース（`source: "user"`）はこのファイルの影響を受けません

---

## 2. コース JSON（`courses/{id}.json`）

バンドルコースとストアからのダウンロードコースで共通のフォーマットです。

### トップレベル フィールド

| フィールド | 型 | 必須 | 説明 |
|-----------|-----|:----:|------|
| `id` | string | ✅ | コースの一意識別子 |
| `courseType` | string | ✅ | コース種別（[種別一覧](#courseType)を参照） |
| `title` | string | ✅ | コース名 |
| `summary` | string? | | コース概要 |
| `source` | string | ✅ | データソース（[ソース一覧](#source)を参照） |
| `isUserCreated` | bool | ✅ | ユーザー作成コースかどうか |
| `version` | int | ✅ | バージョン番号。内容更新時にインクリメントする |
| `recognitionRadiusMeters` | double | ✅ | GPS認識半径のデフォルト値（メートル） |
| `detailUrl` | string? | | コース詳細ページの URL |
| `coverImageUrl` | string? | | カバー画像の URL |
| `categories` | string[]? | | カテゴリ（[カテゴリ一覧](#categories)を参照） |
| `sections` | SectionJSON[]? | ※1 | セクション形式（新フォーマット） |
| `spots` | SpotJSON[]? | ※1 | スポット直下形式（後方互換フォーマット） |

**※1** `sections` または `spots` のどちらか一方を必ず指定します。両方ある場合は `sections` が優先されます。

---

### SectionJSON フィールド

セクション形式を使う場合、スポットをセクション（エリア・章など）でグループ化できます。

| フィールド | 型 | 必須 | 説明 |
|-----------|-----|:----:|------|
| `sectionId` | string | ✅ | セクションの識別子 |
| `name` | string | ✅ | セクション名 |
| `sectionDescription` | string? | | セクション概要 |
| `orderIndex` | int | ✅ | 表示順（0始まり） |
| `coverImageUrl` | string? | | セクションのカバー画像 URL |
| `spots` | SpotJSON[] | ✅ | このセクションに含まれるスポット |

---

### SpotJSON フィールド

| フィールド | 型 | 必須 | 説明 |
|-----------|-----|:----:|------|
| `spotId` | string | ✅ | スポットの識別子（コース内で一意） |
| `name` | string | ✅ | スポット名 |
| `address` | string? | | 住所 |
| `latitude` | double? | | 緯度。`null` の場合は GPS 認識の対象外 |
| `longitude` | double? | | 経度。`null` の場合は GPS 認識の対象外 |
| `spotDescription` | string? | | スポット説明 |
| `coverImageUrl` | string? | | スポット固有のカバー画像 URL |
| `orderIndex` | int | ✅ | 表示順（0始まり） |
| `recognitionRadiusMeters` | double? | | 個別の GPS 認識半径。`null` の場合はコースのデフォルト値を使用 |

---

### <a name="courseType">courseType 値一覧</a>

| 値 | 意味 |
|----|------|
| `"pilgrimage"` | 聖地巡礼 |
| `"stamp_rally"` | スタンプラリー |
| `"my_list"` | マイリスト |

### <a name="source">source 値一覧</a>

| 値 | 意味 |
|----|------|
| `"bundled"` | アプリに同梱されたコース |
| `"downloaded"` | ストアからダウンロードしたコース |
| `"user"` | ユーザーが作成したコース |

### <a name="categories">categories 値一覧</a>

| 値 | 表示名 |
|----|--------|
| `"history_culture"` | 歴史・文化 |
| `"nature"` | 自然 |
| `"art_entertainment"` | アート・エンタメ |
| `"movie_drama"` | 映画・ドラマ |
| `"travel_sightseeing"` | 旅行・観光 |
| `"anime"` | アニメ・漫画 |

---

### コース JSON の例（spots 形式）

```json
{
  "id": "course-world-heritage-japan-001",
  "courseType": "pilgrimage",
  "title": "日本の世界遺産",
  "summary": "ユネスコ世界遺産に登録された日本の遺産地を巡るコースです。",
  "source": "bundled",
  "isUserCreated": false,
  "version": 1,
  "recognitionRadiusMeters": 500.0,
  "detailUrl": null,
  "coverImageUrl": "https://kokokita-app.irodoriq.com/course/images/course/course-world-heritage-japan-001.jpg",
  "categories": ["history_culture"],
  "spots": [
    {
      "spotId": "wh-jp-001",
      "name": "法隆寺",
      "latitude": 34.6148,
      "longitude": 135.7345,
      "spotDescription": "世界最古の木造建築群。",
      "coverImageUrl": null,
      "orderIndex": 0,
      "recognitionRadiusMeters": null,
      "address": "奈良県生駒郡斑鳩町法隆寺山内1-1"
    }
  ]
}
```

### コース JSON の例（sections 形式）

```json
{
  "id": "course-tokyo-shitamachi-walk-001",
  "courseType": "pilgrimage",
  "title": "東京下町さんぽ",
  "source": "bundled",
  "isUserCreated": false,
  "version": 1,
  "recognitionRadiusMeters": 150.0,
  "categories": ["history_culture"],
  "sections": [
    {
      "sectionId": "sec-asakusa",
      "name": "浅草エリア",
      "sectionDescription": "雷門・仲見世・浅草寺を中心とした浅草観光スポット。",
      "orderIndex": 0,
      "coverImageUrl": null,
      "spots": [
        {
          "spotId": "shitamachi-001",
          "name": "浅草寺",
          "latitude": 35.7147,
          "longitude": 139.7966,
          "spotDescription": "東京最古の寺院。",
          "coverImageUrl": null,
          "orderIndex": 0,
          "recognitionRadiusMeters": null,
          "address": "東京都台東区浅草2-3-1"
        }
      ]
    }
  ]
}
```

---

## 3. ストア インデックス（`store/index.json`）

コースストア画面に表示するダウンロード可能コースの一覧とメタ情報を管理します。個別コース JSON を取得せずとも一覧表示できる情報をここに含めます。

**本番配置先**: `https://kokokita-app.irodoriq.com/course/store/index.json`

### トップレベル フィールド

| フィールド | 型 | 必須 | 説明 |
|-----------|-----|:----:|------|
| `schemaVersion` | int | ✅ | スキーマバージョン（現在は `1`） |
| `generatedAt` | string（ISO8601） | ✅ | インデックス生成日時 |
| `courses` | StoreCourseSummary[] | ✅ | ダウンロード可能コースの一覧 |

### StoreCourseSummary フィールド

| フィールド | 型 | 必須 | 説明 |
|-----------|-----|:----:|------|
| `id` | string | ✅ | コース ID（コース JSON の `id` と同一） |
| `title` | string | ✅ | コース名 |
| `summary` | string? | | コース概要 |
| `categories` | string[] | ✅ | カテゴリ（空配列可） |
| `version` | int | ✅ | バージョン番号。ローカルと比較して更新判定に使用 |
| `coverImageUrl` | string? | | カバー画像 URL |
| `spotCount` | int | ✅ | スポット数（UI 表示用。個別 JSON 未取得時にも表示） |
| `jsonPath` | string | ✅ | ベース URL からの相対パス（例: `"courses/xxx.json"`） |
| `updatedAt` | string?（ISO8601） | | 最終更新日時 |

### ストア インデックスの例

```json
{
  "schemaVersion": 1,
  "generatedAt": "2026-03-08T00:00:00Z",
  "courses": [
    {
      "id": "course-continued-100-famous-castles-japan-001",
      "title": "続日本100名城",
      "summary": "公益財団法人日本城郭協会が2017年に選定する「続日本100名城」を巡るコースです。",
      "categories": ["history_culture"],
      "version": 1,
      "coverImageUrl": null,
      "spotCount": 100,
      "jsonPath": "courses/continued_100_castles_course.json",
      "updatedAt": "2026-03-08T00:00:00Z"
    }
  ]
}
```

---

## ファイル配置

### アプリバンドル（Xcode プロジェクト内）

```
kokokita/Resources/
├── courses/
│   ├── index.json                          ← バンドルコース インデックス
│   ├── world_heritage_japan_001.json
│   └── 100_famous_castles_japan_001.json
└── store_index.json                        ← ストア index のローカル参照用コピー（開発用）
```

### サーバー（https://kokokita-app.irodoriq.com/course/）

```
/store/index.json              ← ストア インデックス（アプリが参照）
/courses/{id}.json             ← 個別コース JSON
/images/course/{id}.jpg        ← カバー画像
```

---

## ダウンロード状態の判定ロジック

ストア画面では、ローカル DB とストア index を照合して各コースの状態を判定します。

| 判定条件 | 状態 | UI |
|---------|------|-----|
| ローカル DB にコースが存在しない | 未ダウンロード | 「取得」ボタン |
| ローカルの `version` ≥ ストアの `version` | ダウンロード済み | 「済み」バッジ（非活性） |
| ローカルの `version` < ストアの `version` | 更新あり | 「更新」ボタン |

- バンドルコースとダウンロードコースは同等に扱われます
- コースを削除すると「未ダウンロード」状態に戻り、ストアから再取得できます

---

## ID 命名規則

### コース ID

```
course-{内容を表す英数字ハイフン区切り}-{3桁連番}
```

例: `course-world-heritage-japan-001`、`course-tokyo-shitamachi-walk-001`

### スポット ID

```
{コース略称}-{3桁連番}
```

例: `wh-jp-001`（世界遺産）、`c100-jp-001`（100名城）、`shitamachi-001`（下町さんぽ）

### セクション ID

```
sec-{エリア・章名の英数字}
```

例: `sec-asakusa`、`sec-ueno`
