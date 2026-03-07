import Foundation

// バンドルされた JSON ファイルからコースデータを読み込み、DB に取り込むサービス
final class CourseJSONService {
    private let repo: CourseRepository

    init(repo: CourseRepository) {
        self.repo = repo
    }

    // MARK: - JSON 構造体（デコード用）

    private struct CourseJSON: Decodable {
        let id: String
        let courseType: String
        let title: String
        let summary: String?
        let source: String
        let isUserCreated: Bool
        let version: Int
        let recognitionRadiusMeters: Double
        let detailUrl: String?
        let coverImageUrl: String?
        /// カテゴリ（rawValue 文字列の配列）
        let categories: [String]?
        /// セクション形式（新フォーマット）
        let sections: [SectionJSON]?
        /// スポット直下形式（後方互換フォーマット）
        let spots: [SpotJSON]?
    }

    private struct SectionJSON: Decodable {
        let sectionId: String
        let name: String
        let sectionDescription: String?
        let orderIndex: Int
        let coverImageUrl: String?
        let spots: [SpotJSON]
    }

    private struct SpotJSON: Decodable {
        let spotId: String
        let name: String
        let address: String?
        let latitude: Double
        let longitude: Double
        let spotDescription: String?
        let orderIndex: Int
        let recognitionRadiusMeters: Double?
    }

    // MARK: - インポート

    /// courses/index.json に列挙されたファイル名順に各コース JSON を読み込んで DB に取り込む
    /// - 既存コースは version が新しい場合のみメタ情報を更新（チェックイン状態は保持）
    /// - sections 形式・spots 直下形式の両方をサポート
    func importBundledCoursesIfNeeded() throws {
        // courses/index.json からファイル名リスト（表示順）を取得
        // 実機では IPA バンドル内でリソースがフラット化される場合があるため
        // subdirectory あり → なし の順にフォールバック
        guard let indexUrl = bundleURL(resource: "index") else {
            Logger.warning("courses/index.json が見つかりません")
            return
        }
        let indexData = try Data(contentsOf: indexUrl)
        let fileNames = try JSONDecoder().decode([String].self, from: indexData)

        // index の順番通りに各コース JSON を読み込む
        let decoded: [CourseJSON] = try fileNames.compactMap { name in
            guard let url = bundleURL(resource: name) else {
                Logger.warning("コース JSON が見つかりません: \(name).json")
                return nil
            }
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(CourseJSON.self, from: data)
        }

        let courses = try decoded.map { json -> Course in
            // 既存コースがある場合は everEnabled・チェックイン状態を保持
            let existing = try repo.fetch(id: uuidFromString(json.id))

            let sections = buildSections(from: json, existing: existing)

            return Course(
                id: uuidFromString(json.id),
                courseType: CourseType(rawValue: json.courseType) ?? .myList,
                title: json.title,
                summary: json.summary,
                source: CourseSource(rawValue: json.source) ?? .bundled,
                isUserCreated: json.isUserCreated,
                version: json.version,
                recognitionRadiusMeters: json.recognitionRadiusMeters,
                everEnabled: existing?.everEnabled ?? false,
                detailUrl: json.detailUrl,
                coverImageUrl: json.coverImageUrl,
                createdAt: existing?.createdAt ?? Date(),
                updatedAt: Date(),
                categories: (json.categories ?? []).compactMap { CourseCategory(rawValue: $0) },
                sections: sections
            )
        }

        try repo.saveAll(courses)

        // index.json に存在しないバンドルコースを DB から削除
        let importedIds = Set(courses.map(\.id))
        let allCourses = try repo.fetchAll()
        let toDelete = allCourses.filter { !$0.isUserCreated && !importedIds.contains($0.id) }
        for course in toDelete {
            try repo.delete(course.id)
            Logger.info("バンドルコース削除: \(course.title)")
        }

        Logger.info("バンドルコース取り込み完了: \(courses.count)件（削除: \(toDelete.count)件）")
    }

    // MARK: - Private

    /// JSON から CourseSection 配列を構築。
    /// - sections キーがある場合 → セクション形式として解析
    /// - spots キーのみの場合 → 全スポットを仮想セクション1つに包む（後方互換）
    private func buildSections(from json: CourseJSON, existing: Course?) -> [CourseSection] {
        if let jsonSections = json.sections {
            // 新フォーマット: セクション形式
            return jsonSections.map { sec in
                let spots = buildSpots(from: sec.spots, existingSpots: existing?.spots ?? [])
                return CourseSection(
                    id: uuidFromString(sec.sectionId),
                    sectionId: sec.sectionId,
                    name: sec.name,
                    sectionDescription: sec.sectionDescription,
                    orderIndex: sec.orderIndex,
                    coverImageUrl: sec.coverImageUrl,
                    spots: spots
                )
            }
        } else if let jsonSpots = json.spots {
            // 後方互換フォーマット: spots 直下 → 仮想セクション1つに包む
            let spots = buildSpots(from: jsonSpots, existingSpots: existing?.spots ?? [])
            return [CourseSection(
                id: uuidFromString(json.id + "-default"),
                sectionId: nil,
                name: "",
                sectionDescription: nil,
                orderIndex: 0,
                coverImageUrl: nil,
                spots: spots
            )]
        }
        return []
    }

    private func buildSpots(from jsonSpots: [SpotJSON], existingSpots: [CourseSpot]) -> [CourseSpot] {
        jsonSpots.map { s in
            let existingSpot = existingSpots.first { $0.spotId == s.spotId }
            return CourseSpot(
                id: existingSpot?.id ?? uuidFromString(s.spotId),
                spotId: s.spotId,
                name: s.name,
                address: s.address,
                latitude: s.latitude,
                longitude: s.longitude,
                spotDescription: s.spotDescription,
                orderIndex: s.orderIndex,
                recognitionRadiusMeters: s.recognitionRadiusMeters,
                firstCheckedInAt: existingSpot?.firstCheckedInAt,
                visitIds: existingSpot?.visitIds ?? []
            )
        }
    }

    /// courses/ サブディレクトリ → バンドルルート の順で JSON URL を解決する。
    /// 実機では IPA のリソースがフラット化されてサブディレクトリが消えるため両方を試みる。
    private func bundleURL(resource name: String) -> URL? {
        Bundle.main.url(forResource: name, withExtension: "json", subdirectory: "courses")
            ?? Bundle.main.url(forResource: name, withExtension: "json")
    }

    /// 文字列を UUID に変換（決定論的な UUID5 相当の変換）
    private func uuidFromString(_ string: String) -> UUID {
        // 文字列が UUID フォーマットであればそのまま使用
        if let uuid = UUID(uuidString: string) { return uuid }
        // そうでなければ文字列から決定論的に UUID を生成
        let hash = string.utf8.reduce(UInt64(5381)) { ($0 << 5) &+ $0 &+ UInt64($1) }
        let hash2 = string.unicodeScalars.reduce(UInt64(0)) { $0 &+ UInt64($1.value) }
        var bytes = withUnsafeBytes(of: (hash, hash2)) { Array($0) }
        // UUID version 5 風に設定
        bytes[6] = (bytes[6] & 0x0F) | 0x50
        bytes[8] = (bytes[8] & 0x3F) | 0x80
        return NSUUID(uuidBytes: bytes) as UUID
    }
}
