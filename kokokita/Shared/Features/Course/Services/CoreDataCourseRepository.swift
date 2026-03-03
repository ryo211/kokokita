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

    func fetchEnabled() throws -> [Course] {
        let req = CourseEntity.fetchRequest()
        req.predicate = NSPredicate(format: "isEnabled == YES")
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

    func setEnabled(_ courseId: UUID, enabled: Bool) throws {
        guard let entity = try fetchEntity(id: courseId) else { return }
        entity.isEnabled = NSNumber(value: enabled)
        // 初めて有効化する場合は everEnabled を true にする
        if enabled, entity.everEnabled?.boolValue == false {
            entity.everEnabled = NSNumber(value: true)
        }
        entity.updatedAt = Date()
        try ctx.save()
    }

    func checkIn(spotId: UUID, at date: Date) throws {
        let req = CourseSpotEntity.fetchRequest()
        req.predicate = NSPredicate(format: "id == %@", spotId as CVarArg)
        req.fetchLimit = 1
        guard let spot = try ctx.fetch(req).first else { return }
        spot.isCheckedIn = NSNumber(value: true)
        spot.firstCheckedInAt = date
        try ctx.save()
    }

    func delete(_ courseId: UUID) throws {
        guard let entity = try fetchEntity(id: courseId) else { return }
        ctx.delete(entity)
        try ctx.save()
    }

    func fetchSpotsForRetroactive(courseId: UUID) throws -> [CourseSpot] {
        guard let entity = try fetchEntity(id: courseId) else { return [] }
        return mapToSpots(entity)
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
        entity.isEnabled = NSNumber(value: course.isEnabled)
        entity.everEnabled = NSNumber(value: course.everEnabled)
        entity.detailUrl = course.detailUrl
        entity.coverImageUrl = course.coverImageUrl
        entity.createdAt = course.createdAt
        entity.updatedAt = course.updatedAt

        // スポットを同期（既存スポットのチェックイン状態を保持しつつメタ情報を更新）
        syncSpots(course.spots, to: entity)
    }

    /// スポット一覧を同期（チェックイン済みフラグは上書きしない）
    private func syncSpots(_ spots: [CourseSpot], to courseEntity: CourseEntity) {
        // 既存スポットを id でマッピング
        let existing: [UUID: CourseSpotEntity] = (courseEntity.spots as? Set<CourseSpotEntity>)?
            .reduce(into: [:]) { dict, e in
                if let id = e.id { dict[id] = e }
            } ?? [:]

        var ordered: [CourseSpotEntity] = []
        for spot in spots {
            let e = existing[spot.id] ?? CourseSpotEntity(context: ctx)
            e.id = spot.id
            e.spotId = spot.spotId
            e.name = spot.name
            e.latitude = spot.latitude
            e.longitude = spot.longitude
            e.spotDescription = spot.spotDescription
            e.orderIndex = Int32(spot.orderIndex)
            e.recognitionRadiusMeters = spot.recognitionRadiusMeters.map { NSNumber(value: $0) }
            // チェックイン状態は既存の値を保持（JSONで上書きしない）
            if existing[spot.id] == nil {
                e.isCheckedIn = NSNumber(value: false)
                e.firstCheckedInAt = nil
            }
            e.course = courseEntity
            ordered.append(e)
        }

        // ordered relationship に設定
        courseEntity.spots = NSOrderedSet(array: ordered)
    }

    /// CoreData エンティティ → Course ドメインモデルへの変換
    private func mapToCourse(_ entity: CourseEntity) -> Course {
        Course(
            id: entity.id ?? UUID(),
            courseType: CourseType(rawValue: entity.courseType ?? "") ?? .custom,
            title: entity.title ?? "",
            summary: entity.summary,
            source: CourseSource(rawValue: entity.source ?? "") ?? .bundled,
            isUserCreated: entity.isUserCreated?.boolValue ?? false,
            version: Int(entity.version),
            recognitionRadiusMeters: entity.recognitionRadiusMeters,
            isEnabled: entity.isEnabled?.boolValue ?? false,
            everEnabled: entity.everEnabled?.boolValue ?? false,
            detailUrl: entity.detailUrl,
            coverImageUrl: entity.coverImageUrl,
            createdAt: entity.createdAt ?? Date(),
            updatedAt: entity.updatedAt ?? Date(),
            spots: mapToSpots(entity)
        )
    }

    private func mapToSpots(_ entity: CourseEntity) -> [CourseSpot] {
        guard let ordered = entity.spots?.array as? [CourseSpotEntity] else { return [] }
        return ordered.map { s in
            CourseSpot(
                id: s.id ?? UUID(),
                spotId: s.spotId ?? "",
                name: s.name ?? "",
                latitude: s.latitude,
                longitude: s.longitude,
                spotDescription: s.spotDescription,
                orderIndex: Int(s.orderIndex),
                recognitionRadiusMeters: s.recognitionRadiusMeters?.doubleValue,
                isCheckedIn: s.isCheckedIn?.boolValue ?? false,
                firstCheckedInAt: s.firstCheckedInAt
            )
        }
    }
}
