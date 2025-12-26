# 聖地巡礼機能 - 実装計画書

## 1. 機能概要

### 1.1 目的
「ココキタ」アプリに**聖地巡礼機能**を追加し、ユーザーがあらかじめ定義されたスポット群（聖地群）を巡り、訪問を記録・達成していく体験を提供する。

### 1.2 コンセプト
既存の「ココキタ（現在地記録）」機能に、**テーマ性のある目的地コレクション**という概念を追加することで、単なる訪問記録から**達成感のある巡礼体験**へと昇華させる。

**例:**
- 「日本百景」を巡る旅
- 「坂本龍馬ゆかりの地」を訪ねる
- 「富士山が見える場所100選」を制覇

### 1.3 ユーザー体験の流れ

```
1. 聖地群の選択
   ↓
   [内蔵マップから選択] または [新しいマップをダウンロード]
   ↓
2. 聖地群の有効化
   ↓
   地図・一覧でスポットを確認
   ↓
3. 現地で「ココキタ」
   ↓
   自動的に巡礼判定（半径300m以内）
   ↓
4. 巡礼達成の記録
   ↓
   [スポット] 訪問済みマーク付与
   [Visit] 巡礼マーク付与
   ↓
5. 達成状況の確認
   ↓
   聖地群の達成率を表示
```

---

## 2. 主要概念（ユビキタス言語）

| 用語 | 説明 |
|-----|------|
| **聖地巡礼（Pilgrimage）** | あらかじめ定義されたスポット群を巡り、訪問を記録・達成していく体験 |
| **聖地群（PilgrimageMap）** | 1つのテーマに属するスポット集合（例：日本百景） |
| **聖地（PilgrimageSpot）** | 聖地群に含まれる個別スポット（緯度経度を持つ） |
| **内蔵マップ（Bundled Map）** | アプリ内に同梱される代表的な聖地群 |
| **ダウンロード済み（Downloaded）** | 端末内に保存され、アプリで利用可能な状態 |
| **有効化（Enabled）** | ユーザが閲覧対象として選択中の聖地群（地図に表示） |
| **巡礼判定（Recognition）** | ココキタ地点が聖地に十分近いとして訪問済みと認められること |
| **認定距離（Recognition Radius）** | 巡礼判定に用いる半径（デフォルト: 300m） |
| **巡礼達成（Completion）** | 特定スポットが訪問済みになった状態 |
| **巡礼マーク** | スポット側とVisit側の両方に付与される訪問証明 |

---

## 3. コア機能仕様

### 3.1 データ配布方式

#### (A) 内蔵マップ
- **配布方法:** アプリバンドルにJSON同梱
- **対象:** 代表的な聖地群（例：日本百景）
- **初期化:** アプリ初回起動時に端末DBへ取り込み

#### (B) ダウンロードマップ
- **配布方法:** 静的ホスティング（S3 + CloudFront等）からHTTP GET
- **取得手順:**
  1. `index.json`で聖地群一覧を取得
  2. 詳細JSON（`{mapId}.json`）で各聖地群のスポットを取得
  3. 端末Core Dataに保存

### 3.2 巡礼判定のアルゴリズム

**ココキタ時に自動実行:**

```
1. 記録地点（latitude, longitude）を取得
2. 有効化された聖地群のスポット一覧を取得
3. 各スポットについて距離を計算
   distance = CLLocation.distance(from: spotLocation)
4. distance <= 認定距離（300m） のスポットを抽出
5. 複数該当する場合は最短距離のスポットを採用
6. 認定結果を保存:
   - スポット側: isCompleted = true, firstVisitedAt = 記録日時
   - Visit側: pilgrimageSpotId = スポットID, recognizedDistance = 距離
```

**重複訪問の扱い:**
- すでに訪問済みスポットへの再訪: スポット側は更新せず、Visit側には巡礼マークを付与

### 3.3 地図表示

**要件:**
- 有効化された聖地群のスポットをMapKitにピン表示
- ピンの見分け:
  - 未訪問: 通常ピン（例: グレー）
  - 訪問済み: 達成ピン（例: ゴールド）
- ピンタップでスポット情報を表示（名称、説明、訪問状態）

### 3.4 UI要件

| 画面 | 機能 |
|-----|------|
| **聖地群一覧** | 内蔵/ダウンロードの区別、DL状態、有効化切り替え |
| **聖地群詳細** | スポット一覧、達成率、地図プレビュー |
| **巡礼マップ** | 有効化された聖地群のピン表示、訪問済み表示 |
| **スポット詳細** | 名称、説明、座標、訪問状態、訪問日時 |
| **Visit詳細** | 既存情報 + 巡礼マーク（該当聖地群/スポット表示） |

---

## 4. 技術実装

### 4.1 Core Dataモデル拡張

#### 新規エンティティ

**PilgrimageMapEntity（聖地群）**
```
- id: UUID
- title: String
- summary: String?
- source: String ("bundled" or "remote")
- version: String
- recognitionRadiusMeters: Double? (デフォルト: 300)
- updatedAt: Date
- detailUrl: String? (remote用)
- isEnabled: Boolean
- spots: [PilgrimageSpotEntity] (cascade delete)
```

**PilgrimageSpotEntity（聖地スポット）**
```
- id: UUID
- spotId: String (JSON内のID)
- name: String
- latitude: Double
- longitude: Double
- spotDescription: String?
- isCompleted: Boolean
- firstVisitedAt: Date?
- map: PilgrimageMapEntity
- visits: [VisitDetailsEntity]
```

**VisitDetailsEntity（既存エンティティに追加）**
```
- pilgrimageSpot: PilgrimageSpotEntity? (many-to-one)
- pilgrimageRecognizedDistance: Double?
```

#### マイグレーション戦略
- **Lightweight Migration**を使用（新規エンティティ追加は自動対応可能）
- 新しいモデルバージョン作成: `Kokokita 2.xcdatamodel`
- マイグレーションオプション:
  - `NSMigratePersistentStoresAutomaticallyOption = true`
  - `NSInferMappingModelAutomaticallyOption = true`

### 4.2 アーキテクチャ統合

#### リポジトリ層
```swift
protocol PilgrimageRepository {
    func fetchAllMaps() async throws -> [PilgrimageMap]
    func saveMap(_ map: PilgrimageMap, spots: [PilgrimageSpot]) async throws
    func deleteMap(id: UUID) async throws
    func setMapEnabled(id: UUID, enabled: Bool) async throws
    func fetchEnabledMapSpots() async throws -> [(map: PilgrimageMap, spots: [PilgrimageSpot])]
    func updateSpotCompletion(spotId: UUID, completed: Bool, visitedAt: Date?) async throws
}
```

#### サービス層
```swift
// JSON取得・パース
protocol PilgrimageJSONService {
    func fetchMapIndex() async throws -> [PilgrimageMapIndex]
    func fetchMapDetail(url: String) async throws -> PilgrimageMapDetail
}

// 巡礼判定ロジック
protocol PilgrimageRecognitionService {
    func recognizePilgrimage(
        coordinate: CLLocationCoordinate2D,
        enabledMaps: [(map: PilgrimageMap, spots: [PilgrimageSpot])]
    ) -> (spot: PilgrimageSpot, distance: CLLocationDistance)?
}
```

#### プレゼンテーション層
- **PilgrimageMapListViewModel**: 聖地群一覧管理
- **PilgrimageSpotListViewModel**: スポット一覧・達成率管理
- **PilgrimageMapView**: MapKitピン表示
- **CreateEditViewModel**: ココキタ時の巡礼判定統合

### 4.3 JSONフォーマット

#### index.json（聖地群一覧）
```json
{
  "maps": [
    {
      "mapId": "jp-100-views",
      "title": "日本百景",
      "summary": "日本を代表する美しい景観100選",
      "spotCount": 100,
      "version": "1.0.0",
      "updatedAt": "2025-01-01T00:00:00Z",
      "detailUrl": "https://example.com/maps/jp-100-views.json"
    }
  ]
}
```

#### map.json（聖地群詳細）
```json
{
  "mapId": "jp-100-views",
  "title": "日本百景",
  "version": "1.0.0",
  "recognitionRadiusMeters": 300,
  "spots": [
    {
      "spotId": "fuji-001",
      "name": "富士山頂",
      "latitude": 35.3606,
      "longitude": 138.7274,
      "description": "日本最高峰"
    }
  ]
}
```

---

## 5. 段階的開発計画

### Phase 1: MVPコア機能【優先度: 最高】

**目標:** 聖地巡礼の基本体験を実現

#### 実装内容
1. **Core Data拡張**
   - PilgrimageMapEntity、PilgrimageSpotEntity追加
   - VisitDetailsEntityに巡礼フィールド追加
   - モデルバージョン作成とLightweight Migration設定

2. **内蔵マップ実装**
   - サンプル聖地群1つをJSONでバンドル（例: 日本百景の一部10箇所）
   - アプリ起動時にCore Dataへ取り込むロジック

3. **聖地群一覧画面**
   - 内蔵マップの表示
   - 有効化トグル（1つのみ有効化可能）

4. **スポット一覧画面**
   - 選択した聖地群のスポット表示
   - 訪問済みマークの表示

5. **巡礼判定ロジック**
   - `PilgrimageRecognitionService`実装
   - `CreateEditViewModel`に統合（ココキタ時に自動判定）
   - 判定結果の保存（スポット側・Visit側）

6. **Visit詳細への巡礼マーク表示**
   - 巡礼済みVisitに聖地群名・スポット名を表示

#### 成果物
- 内蔵マップで聖地巡礼体験が可能
- ココキタ時に自動判定され、達成状況が記録される
- 訪問済みスポットが一覧で確認できる

#### テスト観点
- ✅ 既存ユーザーのデータが保持される（マイグレーション成功）
- ✅ 巡礼判定が正確（300m以内で認定）
- ✅ 重複訪問が正しく処理される
- ✅ Visit詳細に巡礼マークが表示される

---

### Phase 2: ダウンロード機能【優先度: 高】

**目標:** 新しい聖地群を追加できる拡張性を確保

#### 実装内容
1. **静的JSONホスティング準備**
   - S3バケット作成 + CloudFront設定
   - index.jsonとmap.jsonの配置
   - CORS設定

2. **PilgrimageJSONService実装**
   - index.json取得・パース
   - map.json取得・パース
   - エラーハンドリング（ネットワークエラー、JSONパースエラー）

3. **聖地群一覧画面の拡張**
   - ダウンロード可能な聖地群の表示
   - ダウンロードボタン・進捗表示
   - ダウンロード済み・未ダウンロードの区別

4. **聖地群削除機能**
   - 端末からの削除（Core Data cascade delete）
   - 内蔵マップは削除不可

5. **バージョン管理**
   - 聖地群のバージョン比較
   - 更新通知（任意）

#### 成果物
- ユーザーが好きな聖地群をダウンロードして追加可能
- 不要な聖地群を削除可能
- オフラインでもダウンロード済み聖地群を利用可能

#### テスト観点
- ✅ index.json取得が成功する
- ✅ map.jsonダウンロードが成功する
- ✅ ネットワークエラー時の適切なエラー表示
- ✅ 削除後もアプリが正常動作する

---

### Phase 3: 地図表示機能【優先度: 中】

**目標:** 視覚的に聖地を確認できる体験を提供

#### 実装内容
1. **PilgrimageMapView実装**
   - MapKitで有効化された聖地群のスポットをピン表示
   - ピンの色・アイコンで訪問済み/未訪問を区別
   - ピンタップでスポット詳細を表示（Annotation Callout）

2. **スポット詳細表示**
   - スポット名、説明、座標
   - 訪問状態（未訪問 / 訪問済み + 訪問日時）
   - 「この地点までの距離」表示（現在地から）

3. **地図と一覧の切り替え**
   - タブまたはセグメントコントロールで切り替え

4. **既存HomeViewとの統合**
   - 既存の訪問記録地図と聖地巡礼地図の共存
   - フィルタリング機能（訪問記録のみ / 聖地のみ / 両方）

#### 成果物
- 地図上で聖地の位置を確認できる
- 訪問済み聖地が一目でわかる
- 地図と一覧を自由に切り替え可能

#### テスト観点
- ✅ 複数スポットのピンが正しく表示される
- ✅ 訪問済み/未訪問のピンが区別できる
- ✅ ピンタップで詳細が表示される
- ✅ 既存の訪問記録地図との共存

---

### Phase 4: 拡張・改善機能【優先度: 低】

**目標:** ユーザー体験の向上と機能の洗練

#### 実装内容
1. **複数聖地群の同時有効化**
   - 複数の聖地群を同時に地図表示
   - 聖地群ごとに色分け

2. **達成率・統計表示**
   - 聖地群ごとの達成率（例: 35/100 達成）
   - 達成率に応じたバッジ・称号
   - 達成グラフ（都道府県別など）

3. **巡礼履歴詳細**
   - 特定スポットへの訪問回数
   - 訪問日時の履歴一覧
   - 最初の訪問と最新の訪問の比較

4. **カスタム聖地群**
   - ユーザーが独自の聖地群を作成
   - 友人と共有（URLまたはQRコード）

5. **通知機能**
   - 聖地の近くに来たら通知（ジオフェンシング）
   - 達成時の通知（例: 「50%達成おめでとう！」）

6. **認定距離のカスタマイズ**
   - 聖地群ごとに認定距離を設定
   - スポットごとに上書き可能

#### 成果物
- より豊かな巡礼体験
- ソーシャル要素の追加
- ゲーミフィケーション強化

#### テスト観点
- ✅ 複数聖地群が同時に動作する
- ✅ 達成率が正確に計算される
- ✅ 通知が適切なタイミングで表示される

---

## 6. 実装の前提条件と注意事項

### 6.1 技術的前提条件

| 項目 | 要件 |
|-----|------|
| **iOS対応バージョン** | iOS 15.0以上（既存アプリと同じ） |
| **Core Dataマイグレーション** | Lightweight Migration必須 |
| **位置情報権限** | 既存の位置情報サービスを活用 |
| **ネットワーク** | ダウンロード機能にHTTP通信必須 |
| **静的ホスティング** | S3 + CloudFront等の準備 |

### 6.2 データ保護とマイグレーション

**重要:** 既にApp Storeでリリース済みのため、Core Dataマイグレーションは慎重に実施

**対策:**
1. ✅ 新規エンティティ追加のみ（既存エンティティは変更しない）
2. ✅ Lightweight Migration有効化
3. ✅ マイグレーション前後のデータ検証テスト
4. ✅ TestFlightで既存ユーザーデータを使った実機テスト
5. ✅ ロールバックプラン（最悪の場合の対処）

### 6.3 パフォーマンス考慮事項

**距離計算の最適化:**
- 有効化された聖地群のみを判定対象（仕様で対応済み）
- スポット数が100以上の場合、粗い範囲チェック（緯度経度±0.003度程度）で事前フィルタ

**地図表示の最適化:**
- 表示範囲外のピンは非表示（MapKit標準機能）
- スポット数が多い場合はクラスタリング検討

### 6.4 静的JSON配布の設計

**推奨構成:**
```
https://cdn.example.com/pilgrimage/
├── index.json                    # 聖地群一覧（軽量）
└── maps/
    ├── jp-100-views.json         # 日本百景詳細
    ├── ryoma-spots.json          # 坂本龍馬ゆかりの地
    └── fuji-views.json           # 富士山が見える場所100選
```

**バージョニング戦略:**
- URLにバージョン番号を含めない（キャッシュ制御で対応）
- JSON内の`version`フィールドで差分判定
- 更新時はCloudFrontキャッシュを無効化

### 6.5 開発リソース見積もり

| Phase | 実装期間（参考） | テスト期間 | 合計 |
|-------|----------------|----------|------|
| Phase 1 (MVP) | 設計を含む | 十分なテスト期間 | フル実装 |
| Phase 2 (DL機能) | 追加実装期間 | テスト期間 | 段階的追加 |
| Phase 3 (地図) | UI実装期間 | テスト期間 | 段階的追加 |
| Phase 4 (拡張) | 機能追加 | テスト期間 | 長期的改善 |

※ 個人開発の場合、Phase 1〜3を複数バージョンに分けてリリース推奨

---

## 7. リリース戦略

### 7.1 段階的リリース案

**バージョン 1.1.0: Phase 1 (MVPコア機能)**
- 内蔵マップ1つで聖地巡礼体験を提供
- 既存機能への影響を最小化
- TestFlightで十分にテスト

**バージョン 1.2.0: Phase 2 (ダウンロード機能)**
- 聖地群の拡張性を提供
- 静的JSONホスティングの安定性確認

**バージョン 1.3.0: Phase 3 (地図表示)**
- 視覚的体験の向上
- 既存地図機能との統合完成

**バージョン 2.0.0: Phase 4 (拡張機能)**
- メジャーアップデートとして大型機能追加
- ゲーミフィケーション要素の強化

### 7.2 App Store申請時の考慮点

**新機能の訴求:**
- 聖地巡礼機能を目玉機能としてアピール
- スクリーンショットに地図・達成率を含める
- プライバシー項目の追加は不要（既存の位置情報権限を活用）

**レビューリスク:**
- 内蔵マップのコンテンツ内容（著作権・正確性）
- ダウンロード機能の安定性

---

## 8. まとめ

### 8.1 実装の実現性
✅ **実装可能**
現在のアーキテクチャとの親和性が高く、既存の技術スタックを活用できる。

### 8.2 最重要ポイント
1. **Core Dataマイグレーション**の慎重な実施
2. **巡礼判定ロジック**の正確性確保
3. **段階的リリース**による安定性の担保

### 8.3 期待される効果
- ユーザーのエンゲージメント向上（目的のある訪問記録）
- アプリの差別化（競合アプリにない独自機能）
- 長期的なユーザー定着（達成型コンテンツ）

### 8.4 次のステップ
1. **Phase 1の詳細設計**を開始
2. **内蔵マップのコンテンツ選定**（日本百景、観光地等）
3. **Core Dataモデルバージョン2の作成**
4. **マイグレーションテスト環境**の準備

---

## 9. 参考資料

### 技術ドキュメント
- [Core Data Model Versioning and Data Migration](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/CoreDataVersioning/Articles/Introduction.html)
- [Mastering Core Data Migration in Swift (2025)](https://medium.com/reversebits/mastering-core-data-migration-in-swift-a-complete-guide-2025-ec9633321b85)
- [CLLocation distance(from:) Documentation](https://developer.apple.com/documentation/corelocation/cllocation/1423689-distance)

### 関連ドキュメント
- `CLAUDE.md` - プロジェクト概要とアーキテクチャ
- `BRANCHING_STRATEGY.md` - Git運用戦略

---

**文書バージョン:** 1.0.0
**作成日:** 2025-12-27
**ステータス:** 計画策定完了・実装待機中
