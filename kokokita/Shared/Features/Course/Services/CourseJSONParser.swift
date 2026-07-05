import Foundation

/// コース JSON のデコード構造体とビルドロジックを共有するパーサー
/// CourseJSONService（バンドル読み込み）と CourseStoreService（Web ダウンロード）の両方が利用する
enum CourseJSONParser {

    // MARK: - デコード用構造体

    struct CourseJSON: Decodable {
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
        /// カバー画像のクレジット表記（Wikimedia Commons 等の帰属表示用）
        let imageCredit: String?
        /// カテゴリ（rawValue 文字列の配列）
        let categories: [String]?
        /// セクション形式（新フォーマット）
        let sections: [SectionJSON]?
        /// スポット直下形式（後方互換フォーマット）
        let spots: [SpotJSON]?
    }

    struct SectionJSON: Decodable {
        let sectionId: String
        let name: String
        let sectionDescription: String?
        let orderIndex: Int
        let coverImageUrl: String?
        let spots: [SpotJSON]
    }

    struct SpotJSON: Decodable {
        let spotId: String
        let name: String
        let address: String?
        /// null の場合は GPS 認識対象外（座標未登録）
        let latitude: Double?
        let longitude: Double?
        let spotDescription: String?
        let coverImageUrl: String?
        /// 画像のクレジット表記（Wikimedia Commons 等の帰属表示用）
        let imageCredit: String?
        let orderIndex: Int
        let recognitionRadiusMeters: Double?
    }

    // MARK: - ビルドロジック

    /// JSON から Course ドメインモデルを構築する
    /// - sourceOverride: nil の場合は JSON の source フィールドをそのまま使用
    static func buildCourse(
        from json: CourseJSON,
        existing: Course?,
        sourceOverride: CourseSource? = nil
    ) -> Course {
        let sections = buildSections(from: json, existing: existing)
        return Course(
            id: uuidFromString(json.id),
            courseType: CourseType(rawValue: json.courseType) ?? .myList,
            title: json.title,
            summary: json.summary,
            source: sourceOverride ?? (CourseSource(rawValue: json.source) ?? .bundled),
            isUserCreated: json.isUserCreated,
            version: json.version,
            recognitionRadiusMeters: json.recognitionRadiusMeters,
            everEnabled: existing?.everEnabled ?? false,
            isEnabled: existing?.isEnabled ?? true,
            isHidden: existing?.isHidden ?? false,
            allowRetroactive: existing?.allowRetroactive ?? false,
            detailUrl: json.detailUrl,
            coverImageUrl: json.coverImageUrl,
            imageCredit: json.imageCredit.flatMap { $0.isEmpty ? nil : $0 },
            localCoverImagePath: existing?.localCoverImagePath,
            createdAt: existing?.createdAt ?? Date(),
            updatedAt: Date(),
            categories: (json.categories ?? []).compactMap { CourseCategory(rawValue: $0) },
            sections: sections
        )
    }

    /// JSON から CourseSection 配列を構築する
    /// - sections キーがある場合 → セクション形式として解析
    /// - spots キーのみの場合 → 全スポットを仮想セクション1つに包む（後方互換）
    static func buildSections(from json: CourseJSON, existing: Course?) -> [CourseSection] {
        if let jsonSections = json.sections {
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

    static func buildSpots(from jsonSpots: [SpotJSON], existingSpots: [CourseSpot]) -> [CourseSpot] {
        jsonSpots.map { s in
            let existingSpot = existingSpots.first { $0.spotId == s.spotId }
            return CourseSpot(
                id: existingSpot?.id ?? uuidFromString(s.spotId),
                spotId: s.spotId,
                name: s.name,
                address: s.address,
                latitude: s.latitude ?? 0,
                longitude: s.longitude ?? 0,
                spotDescription: s.spotDescription,
                coverImageUrl: s.coverImageUrl,
                imageCredit: s.imageCredit,
                localCoverImagePath: existingSpot?.localCoverImagePath,
                orderIndex: s.orderIndex,
                recognitionRadiusMeters: s.recognitionRadiusMeters,
                firstCheckedInAt: existingSpot?.firstCheckedInAt,
                visitIds: existingSpot?.visitIds ?? []
            )
        }
    }

    /// 文字列を UUID に変換（決定論的な UUID5 相当の変換）
    static func uuidFromString(_ string: String) -> UUID {
        if let uuid = UUID(uuidString: string) { return uuid }
        let hash = string.utf8.reduce(UInt64(5381)) { ($0 << 5) &+ $0 &+ UInt64($1) }
        let hash2 = string.unicodeScalars.reduce(UInt64(0)) { $0 &+ UInt64($1.value) }
        var bytes = withUnsafeBytes(of: (hash, hash2)) { Array($0) }
        bytes[6] = (bytes[6] & 0x0F) | 0x50
        bytes[8] = (bytes[8] & 0x3F) | 0x80
        return NSUUID(uuidBytes: bytes) as UUID
    }
}
