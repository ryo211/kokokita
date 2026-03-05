import Foundation

// バンドルされた JSON ファイルからコースデータを読み込み、DB に取り込むサービス
final class CourseJSONService {
    private let repo: CourseRepository

    init(repo: CourseRepository) {
        self.repo = repo
    }

    // JSON 構造体（デコード用）
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

    /// バンドルの bundled_courses.json を読み込んで DB に取り込む
    /// - 既存コースは version が新しい場合のみメタ情報を更新（チェックイン状態は保持）
    func importBundledCoursesIfNeeded() throws {
        guard let url = Bundle.main.url(forResource: "bundled_courses", withExtension: "json") else {
            Logger.warning("bundled_courses.json が見つかりません")
            return
        }

        let data = try Data(contentsOf: url)
        let decoded = try JSONDecoder().decode([CourseJSON].self, from: data)

        let courses = try decoded.map { json -> Course in
            // 既存コースがある場合は isEnabled/everEnabled/チェックイン状態を保持
            let existing = try repo.fetch(id: uuidFromString(json.id))

            let spots = json.spots.enumerated().map { (i, s) in
                // 既存スポットのチェックイン状態を保持
                let existingSpot = existing?.spots.first { $0.spotId == s.spotId }
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
                spots: spots
            )
        }

        try repo.saveAll(courses)
        Logger.info("バンドルコース取り込み完了: \(courses.count)件")
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
