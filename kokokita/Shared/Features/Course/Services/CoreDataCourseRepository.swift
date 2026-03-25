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
        let req = CourseEntity.fetchRequest()
        req.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: true)]
        let entities = try ctx.fetch(req)
        return entities.map { mapToCourse($0) }
    }

    func fetch(id: UUID) throws -> Course? {
        guard let entity = try fetchEntity(id: id) else { return nil }
        return mapToCourse(entity)
    }

    // MARK: - 書き込み

    func save(_ course: Course) throws {
        let entity = (try fetchEntity(id: course.id)) ?? CourseEntity(context: ctx)
        apply(course: course, to: entity)
        try ctx.save()
    }

    func saveAll(_ courses: [Course]) throws {
        for course in courses {
            let entity = (try fetchEntity(id: course.id)) ?? CourseEntity(context: ctx)
            apply(course: course, to: entity)
        }
        try ctx.save()
    }

    func setEverEnabled(_ courseId: UUID) throws {
        guard let entity = try fetchEntity(id: courseId) else { return }
        entity.everEnabled = NSNumber(value: true)
        entity.updatedAt = Date()
        try ctx.save()
    }

    func checkIn(spotId: UUID, visitId: UUID?) throws {
        // fetchLimit を設けず同UUID の全エンティティを更新する
        // （syncSections の不具合で重複エンティティが生成された場合も確実にリンクを反映するため）
        let req = CourseSpotEntity.fetchRequest()
        req.predicate = NSPredicate(format: "id == %@", spotId as CVarArg)
        let found = try ctx.fetch(req)

        guard !found.isEmpty else {
            Logger.warning("checkIn: スポットが見つかりません spotId=\(spotId)")
            return
        }

        // visitId → VisitDetailsEntity を解決
        var visitDetails: VisitDetailsEntity? = nil
        if let visitId = visitId {
            let vReq = VisitEntity.fetchRequest()
            vReq.predicate = NSPredicate(format: "id == %@", visitId as CVarArg)
            vReq.fetchLimit = 1
            visitDetails = try ctx.fetch(vReq).first?.details
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

    func delete(_ courseId: UUID) throws {
        guard let entity = try fetchEntity(id: courseId) else { return }
        ctx.delete(entity)
        try ctx.save()
    }

    func fetchSpotsForRetroactive(courseId: UUID) throws -> [CourseSpot] {
        guard let entity = try fetchEntity(id: courseId) else { return [] }
        return mapToSections(entity).flatMap(\.spots)
    }

    // MARK: - Private ヘルパー

    private func fetchEntity(id: UUID) throws -> CourseEntity? {
        let req = CourseEntity.fetchRequest()
        req.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        req.fetchLimit = 1
        return try ctx.fetch(req).first
    }

    /// Course ドメインモデル → CoreData エンティティへの書き込み
    private func apply(course: Course, to entity: CourseEntity) {
        entity.id = course.id
        entity.courseType = course.courseType.rawValue
        entity.title = course.title
        entity.summary = course.summary
        entity.source = course.source.rawValue
        entity.isUserCreated = NSNumber(value: course.isUserCreated)
        entity.version = Int32(course.version)
        entity.recognitionRadiusMeters = course.recognitionRadiusMeters
        entity.everEnabled = NSNumber(value: course.everEnabled)
        entity.detailUrl = course.detailUrl
        entity.coverImageUrl = course.coverImageUrl
        entity.categories = course.categories.isEmpty ? nil : course.categories.map(\.rawValue).joined(separator: ",")
        entity.createdAt = course.createdAt
        entity.updatedAt = course.updatedAt

        // セクション（内包スポット）を同期
        syncSections(course.sections, to: entity)
    }

    /// セクション一覧を同期
    private func syncSections(_ sections: [CourseSection], to courseEntity: CourseEntity) {
        // 既存セクションを sectionId でマッピング（nil の場合は id で識別）
        let existingSections: [String: CourseSectionEntity] =
            (courseEntity.sections?.array as? [CourseSectionEntity])?
                .reduce(into: [:]) { dict, e in
                    let key = e.sectionId ?? e.id?.uuidString ?? UUID().uuidString
                    dict[key] = e
                } ?? [:]

        // 既存スポットを id でマッピング（セクション横断で収集）
        let existingSpots: [UUID: CourseSpotEntity] =
            (courseEntity.sections?.array as? [CourseSectionEntity])?
                .flatMap { ($0.spots?.array as? [CourseSpotEntity]) ?? [] }
                .reduce(into: [:]) { dict, e in
                    if let id = e.id { dict[id] = e }
                } ?? [:]

        // v3 互換: course.spots 直下のスポットも収集
        let legacySpots: [UUID: CourseSpotEntity] =
            (courseEntity.spots?.array as? [CourseSpotEntity])?
                .reduce(into: [:]) { dict, e in
                    if let id = e.id { dict[id] = e }
                } ?? [:]

        let allExistingSpots = existingSpots.merging(legacySpots) { current, _ in current }

        var orderedSections: [CourseSectionEntity] = []
        for section in sections {
            let key = section.sectionId ?? section.id.uuidString
            let sectionEntity = existingSections[key] ?? CourseSectionEntity(context: ctx)
            sectionEntity.id = section.id
            sectionEntity.sectionId = section.sectionId
            sectionEntity.name = section.name
            sectionEntity.sectionDescription = section.sectionDescription
            sectionEntity.orderIndex = Int32(section.orderIndex)
            sectionEntity.coverImageUrl = section.coverImageUrl
            sectionEntity.course = courseEntity

            // スポットを同期
            syncSpots(section.spots, to: sectionEntity, existingSpots: allExistingSpots)
            orderedSections.append(sectionEntity)
        }

        courseEntity.sections = NSOrderedSet(array: orderedSections)
        // v3 互換の直下 spots リレーションはクリア（セクション経由に一本化）
        courseEntity.spots = NSOrderedSet()
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
            source: CourseSource(rawValue: entity.source ?? "") ?? .bundled,
            isUserCreated: entity.isUserCreated?.boolValue ?? false,
            version: Int(entity.version),
            recognitionRadiusMeters: entity.recognitionRadiusMeters,
            everEnabled: entity.everEnabled?.boolValue ?? false,
            detailUrl: entity.detailUrl,
            coverImageUrl: entity.coverImageUrl,
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
        // visits リレーションから VisitEntity.id を日時昇順で取得
        let sortedVisitDetails = ((s.visits as? Set<VisitDetailsEntity>) ?? [])
            .sorted { ($0.visit?.timestampUTC ?? .distantPast) < ($1.visit?.timestampUTC ?? .distantPast) }
        let visitIds: [UUID] = sortedVisitDetails.compactMap { $0.visit?.id }
        // firstCheckedInAt は visits の最古の訪問日時から導出（CoreData フラグは参照しない）
        let firstCheckedInAt: Date? = sortedVisitDetails.first?.visit?.timestampUTC
        return CourseSpot(
            id: s.id ?? UUID(),
            spotId: s.spotId ?? "",
            name: s.name ?? "",
            address: s.address,
            latitude: s.latitude,
            longitude: s.longitude,
            spotDescription: s.spotDescription,
            coverImageUrl: s.coverImageUrl,
            orderIndex: Int(s.orderIndex),
            recognitionRadiusMeters: s.recognitionRadiusMeters?.doubleValue,
            firstCheckedInAt: firstCheckedInAt,
            visitIds: visitIds
        )
    }
}
