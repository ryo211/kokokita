import Foundation
import CoreData

// Core Data を使った CourseRepository の実装
final class CoreDataCourseRepository: CourseRepository {
    private let ctx: NSManagedObjectContext

    init(context: NSManagedObjectContext = CoreDataStack.shared.context) {
        self.ctx = context
    }

    // MARK: - 読み取り

    func fetchAll() throws -> [Course] {
        // viewContext はメインキュー専用のため、呼び出し元のスレッドに関わらず
        // performAndWait でコンテキスト自身のキュー上での実行を保証する
        try ctx.performAndWait {
            let req = CourseEntity.fetchRequest()
            req.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: true)]
            let entities = try ctx.fetch(req)
            return entities.map { mapToCourse($0) }
        }
    }

    func fetch(id: UUID) throws -> Course? {
        try ctx.performAndWait {
            guard let entity = try fetchEntity(id: id) else { return nil }
            return mapToCourse(entity)
        }
    }

    // MARK: - 書き込み

    func save(_ course: Course) throws {
        try ctx.performAndWait {
            let entity = (try fetchEntity(id: course.id)) ?? CourseEntity(context: ctx)
            try apply(course: course, to: entity)
            try ctx.save()
        }
    }

    func saveAll(_ courses: [Course]) throws {
        try ctx.performAndWait {
            for course in courses {
                let entity = (try fetchEntity(id: course.id)) ?? CourseEntity(context: ctx)
                try apply(course: course, to: entity)
            }
            try ctx.save()
        }
    }

    func setEverEnabled(_ courseId: UUID) throws {
        try ctx.performAndWait {
            guard let entity = try fetchEntity(id: courseId) else { return }
            entity.everEnabled = NSNumber(value: true)
            entity.updatedAt = Date()
            try ctx.save()
        }
    }

    func checkIn(spotId: UUID, visitId: UUID?) throws {
        try ctx.performAndWait {
            // fetchLimit を設けず同UUID の全エンティティを更新する
            // （syncSections の不具合で重複エンティティが生成された場合も確実にリンクを反映するため）
            let req = CourseSpotEntity.fetchRequest()
            req.predicate = NSPredicate(format: "id == %@", spotId as NSUUID)
            let found = try ctx.fetch(req)

            guard !found.isEmpty else { return }

            // visitId → VisitDetailsEntity を解決
            var visitDetails: VisitDetailsEntity? = nil
            if let visitId = visitId {
                let vReq = VisitEntity.fetchRequest()
                vReq.predicate = NSPredicate(format: "id == %@", visitId as NSUUID)
                vReq.fetchLimit = 1
                if let visitEntity = try ctx.fetch(vReq).first {
                    visitDetails = visitEntity.details
                }
            }

            for spot in found {
                // isCheckedIn / firstCheckedInAt はフラグとして書き込まず visits リレーションから導出
                if let details = visitDetails,
                   !(spot.visits?.contains(details) ?? false) {
                    spot.addToVisits(details)
                }
            }
            try ctx.save()
            // 関係キャッシュを無効化して次回フェッチ時に必ず永続化ストアから取得させる
            ctx.refreshAllObjects()
        }
    }

    func delete(_ courseId: UUID) throws {
        try ctx.performAndWait {
            guard let entity = try fetchEntity(id: courseId) else { return }
            ctx.delete(entity)
            try ctx.save()
        }
    }

    func fetchSpotsForRetroactive(courseId: UUID) throws -> [CourseSpot] {
        try ctx.performAndWait {
            guard let entity = try fetchEntity(id: courseId) else { return [] }
            return mapToSections(entity).flatMap(\.spots)
        }
    }

    // MARK: - 起動時マイグレーション

    /// syncSections/syncSpots の過去の不具合により生成された、同一ID（決定論的UUID）を持つ
    /// 重複 CourseSectionEntity / CourseSpotEntity を統合する（起動時に呼ぶ）。
    /// スポットのチェックイン記録（visits リレーション）は必ず統合前にマージしてから削除するため、
    /// 既存の訪問記録との紐づけは失われない。
    func cleanUpDuplicateSectionsAndSpots() throws {
        try ctx.performAndWait {
            // スポットを先に統合する（visits を失わないよう、セクション統合より先に行う必要がある）
            try dedupeSpots()
            // セクションを統合する。統合対象セクションの子スポットは、既に統合済みの単一エンティティに
            // 付け替えてから削除するため、Cascade削除でチェックイン記録ごと失われることはない
            try dedupeSections()
            if ctx.hasChanges {
                try ctx.save()
            }
        }
    }

    private func dedupeSpots() throws {
        let all = try ctx.fetch(CourseSpotEntity.fetchRequest())
        let grouped = Dictionary(grouping: all) { $0.id }

        for (id, group) in grouped {
            guard id != nil, group.count > 1 else { continue }

            // spotId はコースをまたいで同一文字列が使われることがある（例: 同名スポットの偶然の一致）。
            // 決定論的IDはコースを区別しないため、異なるコースに現在アタッチされている複数のスポットが
            // 同一IDを持つケースが実在する。これは「同じスポットの重複」ではなく「別コースの別スポットが
            // たまたま同じIDになっただけ」なので、統合してはいけない。
            let attachedCourses = Set(group.compactMap { $0.section?.course?.objectID })
            guard attachedCourses.count <= 1 else {
                Logger.warning("スポットID衝突（別コース間）を検出したためスキップ: id=\(id?.uuidString ?? ""), 該当コース数=\(attachedCourses.count)")
                continue
            }

            // セクションにアタッチされているものを優先して winner に選ぶ
            let sorted = group.sorted { lhs, rhs in
                (lhs.section != nil ? 0 : 1) < (rhs.section != nil ? 0 : 1)
            }
            let winner = sorted[0]
            let losers = sorted.dropFirst()

            for loser in losers {
                // チェックイン記録（visits リレーション）を winner へ統合
                if let loserVisits = loser.visits as? Set<VisitDetailsEntity> {
                    for v in loserVisits where !(winner.visits?.contains(v) ?? false) {
                        winner.addToVisits(v)
                    }
                }
                // レガシーフラグもマージ（isCheckedIn は true 優先、firstCheckedInAt は最古優先）
                if loser.isCheckedIn?.boolValue == true {
                    winner.isCheckedIn = NSNumber(value: true)
                }
                if let loserDate = loser.firstCheckedInAt {
                    winner.firstCheckedInAt = winner.firstCheckedInAt.map { min($0, loserDate) } ?? loserDate
                }
                ctx.delete(loser)
            }
            Logger.info("重複スポットを統合しました: id=\(id?.uuidString ?? ""), 統合件数=\(losers.count)")
        }
    }

    private func dedupeSections() throws {
        let all = try ctx.fetch(CourseSectionEntity.fetchRequest())
        let grouped = Dictionary(grouping: all) { $0.id }

        for (id, group) in grouped {
            guard id != nil, group.count > 1 else { continue }

            // sectionId は地方名等の一般的な文字列が複数コースで再利用されることが実際にある
            // （例: "sec-tokyo" が7コースで使われている）。決定論的IDはコースを区別しないため、
            // 異なるコースに現在アタッチされている複数のセクションが同一IDを持つケースが実在する。
            // これは「同じセクションの重複」ではなく「別コースの別セクションが偶然同じIDになっただけ」
            // なので、統合してはいけない（統合するとスポットが誤って他コースへ付け替わってしまう）。
            let attachedCourses = Set(group.compactMap { $0.course?.objectID })
            guard attachedCourses.count <= 1 else {
                Logger.warning("セクションID衝突（別コース間）を検出したためスキップ: id=\(id?.uuidString ?? ""), 該当コース数=\(attachedCourses.count)")
                continue
            }

            // コースにアタッチされているものを優先して winner に選ぶ
            let sorted = group.sorted { lhs, rhs in
                (lhs.course != nil ? 0 : 1) < (rhs.course != nil ? 0 : 1)
            }
            let winner = sorted[0]
            let losers = sorted.dropFirst()

            for loser in losers {
                // 削除前に子スポットを winner へ付け替える（Cascade削除でチェックイン記録ごと消えるのを防ぐ）
                if let loserSpots = loser.spots?.array as? [CourseSpotEntity] {
                    for spot in loserSpots {
                        spot.section = winner
                    }
                }
                ctx.delete(loser)
            }
            Logger.info("重複セクションを統合しました: id=\(id?.uuidString ?? ""), 統合件数=\(losers.count)")
        }
    }

    // MARK: - Private ヘルパー

    private func fetchEntity(id: UUID) throws -> CourseEntity? {
        let req = CourseEntity.fetchRequest()
        req.predicate = NSPredicate(format: "id == %@", id as NSUUID)
        req.fetchLimit = 1
        return try ctx.fetch(req).first
    }

    /// Course ドメインモデル → CoreData エンティティへの書き込み
    private func apply(course: Course, to entity: CourseEntity) throws {
        entity.id = course.id
        entity.courseType = course.courseType.rawValue
        entity.title = course.title
        entity.summary = course.summary
        entity.source = course.source.rawValue
        entity.isUserCreated = NSNumber(value: course.isUserCreated)
        entity.version = Int32(course.version)
        entity.recognitionRadiusMeters = course.recognitionRadiusMeters
        entity.everEnabled = NSNumber(value: course.everEnabled)
        entity.isEnabled = NSNumber(value: course.isEnabled)
        entity.allowRetroactive = NSNumber(value: course.allowRetroactive)
        entity.detailUrl = course.detailUrl
        entity.coverImageUrl = course.coverImageUrl
        entity.imageCredit = course.imageCredit
        entity.localCoverImagePath = course.localCoverImagePath
        entity.categories = course.categories.isEmpty ? nil : course.categories.map(\.rawValue).joined(separator: ",")
        entity.createdAt = course.createdAt
        entity.updatedAt = course.updatedAt

        // セクション（内包スポット）を同期
        try syncSections(course.sections, to: entity)
    }

    /// セクション一覧を同期
    ///
    /// 既存エンティティの突き合わせは「現在 courseEntity.sections にアタッチされているもの」ではなく、
    /// ストア全体から決定論的ID（CourseJSONParser.uuidFromString 由来）で検索する。
    /// section.id/spot.id は文字列から決定論的に導出されるため、過去のsyncで一時的にリレーションが
    /// 切れて孤立したエンティティも同じIDで再登場しうる。孤立エンティティを無視して新規作成すると
    /// 同一IDのエンティティが重複生成されてしまうため（Core Data には uniquenessConstraints が無く
    /// 検知・拒否されない）、孤立分も含めて再利用することで重複生成を防ぐ。
    private func syncSections(_ sections: [CourseSection], to courseEntity: CourseEntity) throws {
        let existingSections = try fetchSectionEntities(ids: sections.map(\.id), scopedTo: courseEntity)
        // spotId も地方名等の一般的な文字列が複数コースで再利用される可能性があるため
        // （実際に sectionId で同様の衝突が複数コース間で確認されている）、セクションと同様に
        // このコースに属するもの・孤立しているものに限定して検索する。他コースの同名スポットを
        // 誤って奪わないための絞り込み。checkIn(spotId:visitId:) は別途コース横断でグローバルに
        // 扱う設計のままで問題ない（内容の上書き・付け替えを行わないため）。
        let existingSpots = try fetchSpotEntities(ids: sections.flatMap { $0.spots.map(\.id) }, scopedTo: courseEntity)

        var orderedSections: [CourseSectionEntity] = []
        for section in sections {
            let sectionEntity = existingSections[section.id] ?? CourseSectionEntity(context: ctx)
            sectionEntity.id = section.id
            sectionEntity.sectionId = section.sectionId
            sectionEntity.name = section.name
            sectionEntity.sectionDescription = section.sectionDescription
            sectionEntity.orderIndex = Int32(section.orderIndex)
            sectionEntity.coverImageUrl = section.coverImageUrl
            sectionEntity.course = courseEntity

            // スポットを同期
            syncSpots(section.spots, to: sectionEntity, existingSpots: existingSpots)
            orderedSections.append(sectionEntity)
        }

        courseEntity.sections = NSOrderedSet(array: orderedSections)
        // v3 互換の直下 spots リレーションはクリア（セクション経由に一本化）
        courseEntity.spots = NSOrderedSet()
    }

    /// 指定IDのセクションエンティティを検索する。対象はこのコースに現在属するもの、
    /// および過去のsyncでリレーションが切れて孤立した（course == nil）ものに限定する。
    /// 他コースに属する同名sectionIdのエンティティを誤って奪わないための絞り込み。
    private func fetchSectionEntities(ids: [UUID], scopedTo courseEntity: CourseEntity) throws -> [UUID: CourseSectionEntity] {
        guard !ids.isEmpty else { return [:] }
        let req = CourseSectionEntity.fetchRequest()
        req.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            NSPredicate(format: "id IN %@", ids),
            NSCompoundPredicate(orPredicateWithSubpredicates: [
                NSPredicate(format: "course == %@", courseEntity),
                NSPredicate(format: "course == nil")
            ])
        ])
        let found = try ctx.fetch(req)
        // 同一IDが既に複数存在する場合（既存の重複データ）は先勝ちで1件のみ採用する
        return found.reduce(into: [:]) { dict, e in
            guard let id = e.id, dict[id] == nil else { return }
            dict[id] = e
        }
    }

    /// 指定IDのスポットエンティティを検索する。対象はこのコースに現在属するもの、
    /// および過去のsyncでリレーションが切れて孤立した（section == nil）ものに限定する。
    /// 他コースに属する同名spotIdのエンティティを誤って奪わないための絞り込み。
    private func fetchSpotEntities(ids: [UUID], scopedTo courseEntity: CourseEntity) throws -> [UUID: CourseSpotEntity] {
        guard !ids.isEmpty else { return [:] }
        let req = CourseSpotEntity.fetchRequest()
        req.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            NSPredicate(format: "id IN %@", ids),
            NSCompoundPredicate(orPredicateWithSubpredicates: [
                NSPredicate(format: "section.course == %@", courseEntity),
                NSPredicate(format: "section == nil")
            ])
        ])
        let found = try ctx.fetch(req)
        // 同一IDが既に複数存在する場合（既存の重複データ）は先勝ちで1件のみ採用する
        return found.reduce(into: [:]) { dict, e in
            guard let id = e.id, dict[id] == nil else { return }
            dict[id] = e
        }
    }

    /// スポット一覧を同期（チェックイン済みフラグは上書きしない）
    private func syncSpots(
        _ spots: [CourseSpot],
        to sectionEntity: CourseSectionEntity,
        existingSpots: [UUID: CourseSpotEntity]
    ) {
        var ordered: [CourseSpotEntity] = []
        for spot in spots {
            let e = existingSpots[spot.id] ?? CourseSpotEntity(context: ctx)
            e.id = spot.id
            e.spotId = spot.spotId
            e.name = spot.name
            e.address = spot.address
            e.latitude = spot.latitude
            e.longitude = spot.longitude
            e.spotDescription = spot.spotDescription
            e.coverImageUrl = spot.coverImageUrl
            e.imageCredit = spot.imageCredit
            e.localCoverImagePath = spot.localCoverImagePath
            e.orderIndex = Int32(spot.orderIndex)
            e.recognitionRadiusMeters = spot.recognitionRadiusMeters.map { NSNumber(value: $0) }
            // チェックイン状態は既存の値を保持（JSONで上書きしない）
            if existingSpots[spot.id] == nil {
                e.isCheckedIn = NSNumber(value: false)
                e.firstCheckedInAt = nil
            }
            // v3 互換の course リレーションをクリアし section に付け替え
            e.course = nil
            e.section = sectionEntity
            ordered.append(e)
        }
        sectionEntity.spots = NSOrderedSet(array: ordered)
    }

    /// CoreData エンティティ → Course ドメインモデルへの変換
    private func mapToCourse(_ entity: CourseEntity) -> Course {
        Course(
            id: entity.id ?? UUID(),
            courseType: CourseType(rawValue: entity.courseType ?? "") ?? .myList,
            title: entity.title ?? "",
            summary: entity.summary,
            source: { let s = CourseSource(rawValue: entity.source ?? "") ?? .downloaded; return s == .bundled ? .downloaded : s }(),
            isUserCreated: entity.isUserCreated?.boolValue ?? false,
            version: Int(entity.version),
            recognitionRadiusMeters: entity.recognitionRadiusMeters,
            everEnabled: entity.everEnabled?.boolValue ?? false,
            isEnabled: entity.isEnabled?.boolValue ?? false,
            allowRetroactive: entity.allowRetroactive?.boolValue ?? false,
            detailUrl: entity.detailUrl,
            coverImageUrl: entity.coverImageUrl,
            imageCredit: entity.imageCredit,
            localCoverImagePath: entity.localCoverImagePath,
            createdAt: entity.createdAt ?? Date(),
            updatedAt: entity.updatedAt ?? Date(),
            categories: (entity.categories ?? "")
                .split(separator: ",")
                .compactMap { CourseCategory(rawValue: String($0)) },
            sections: mapToSections(entity)
        )
    }

    /// CourseEntity → [CourseSection] への変換。
    /// v4 以降は sections リレーションを使用。
    /// v3 からの移行データは spots 直下にあるため仮想セクションとして包む（後方互換）
    private func mapToSections(_ entity: CourseEntity) -> [CourseSection] {
        // v4: sections リレーションが存在する場合はそれを使用
        if let sectionsOrdered = entity.sections?.array as? [CourseSectionEntity],
           !sectionsOrdered.isEmpty {
            return sectionsOrdered.map { mapToSection($0) }
        }
        // v3 互換: spots が course 直下に紐づいている場合、仮想セクションとして扱う
        let legacySpots = mapToSpotsFromEntity(entity)
        guard !legacySpots.isEmpty else { return [] }
        return [CourseSection(
            id: entity.id ?? UUID(),
            sectionId: nil,
            name: "",
            sectionDescription: nil,
            orderIndex: 0,
            coverImageUrl: nil,
            spots: legacySpots
        )]
    }

    private func mapToSection(_ entity: CourseSectionEntity) -> CourseSection {
        CourseSection(
            id: entity.id ?? UUID(),
            sectionId: entity.sectionId,
            name: entity.name ?? "",
            sectionDescription: entity.sectionDescription,
            orderIndex: Int(entity.orderIndex),
            coverImageUrl: entity.coverImageUrl,
            spots: mapToSpotsFromSection(entity)
        )
    }

    /// CourseSectionEntity → [CourseSpot] への変換
    private func mapToSpotsFromSection(_ entity: CourseSectionEntity) -> [CourseSpot] {
        guard let ordered = entity.spots?.array as? [CourseSpotEntity] else { return [] }
        return ordered.map { mapToSpot($0) }
    }

    /// v3 互換: CourseEntity.spots 直下からスポットを取得
    private func mapToSpotsFromEntity(_ entity: CourseEntity) -> [CourseSpot] {
        guard let ordered = entity.spots?.array as? [CourseSpotEntity] else { return [] }
        return ordered.map { mapToSpot($0) }
    }

    private func mapToSpot(_ s: CourseSpotEntity) -> CourseSpot {
        // visits リレーション（CourseSpotEntity → VisitDetailsEntity）からリンク済み VisitDetailsEntity を取得
        let rawVisits = s.visits as? Set<VisitDetailsEntity> ?? []
        // ZVISITDETAILSENTITY.ZVISIT（逆方向FK）はCoreDataが書き込まないため nil になる。
        // 代わりに ZVISITENTITY.ZDETAILS（VisitEntity.details FK）方向でバッチフェッチする。
        let visitReq = VisitEntity.fetchRequest()
        visitReq.predicate = NSPredicate(format: "details IN %@", rawVisits)
        visitReq.sortDescriptors = [NSSortDescriptor(key: "timestampUTC", ascending: true)]
        let linkedVisits = (try? ctx.fetch(visitReq)) ?? []
        let visitIds: [UUID] = linkedVisits.compactMap { $0.id }
        // firstCheckedInAt は visits の最古の訪問日時から導出（CoreData フラグは参照しない）
        let firstCheckedInAt: Date? = linkedVisits.first?.timestampUTC
        return CourseSpot(
            id: s.id ?? UUID(),
            spotId: s.spotId ?? "",
            name: s.name ?? "",
            address: s.address,
            latitude: s.latitude,
            longitude: s.longitude,
            spotDescription: s.spotDescription,
            coverImageUrl: s.coverImageUrl,
            imageCredit: s.imageCredit,
            localCoverImagePath: s.localCoverImagePath,
            orderIndex: Int(s.orderIndex),
            recognitionRadiusMeters: s.recognitionRadiusMeters?.doubleValue,
            firstCheckedInAt: firstCheckedInAt,
            visitIds: visitIds
        )
    }
}
