import Foundation
import CoreData

/// コースへの「関心度」イベント（閲覧・お気に入り追加等）の送信待ちキュー（アウトボックス）をCoreDataで管理するリポジトリ。
/// SpotArrivalOutboxRepositoryと同じ設計（ローカルに貯めてから同期時にまとめて送る）
final class CourseEventOutboxRepository {
    private let ctx: NSManagedObjectContext

    init(context: NSManagedObjectContext = CoreDataStack.shared.context) {
        self.ctx = context
    }

    /// 指定コース（・スポット）・種別の今日のイベントをまだ記録していなければ1件追加する（1日1回までの冪等化）。
    /// idは(courseId, spotId, type, eventDay)から決定論的に導出するため、何度呼んでも同じ日のうちは
    /// 同じidの1件にしかならず、送信済みかどうかに関わらず再登録されない
    func recordEventIfNeeded(courseId: UUID, spotId: UUID? = nil, type: CourseEventType, on day: Date = Date()) throws {
        try ctx.performAndWait {
            let startOfDay = Calendar.current.startOfDay(for: day)
            let id = CourseEvent.makeId(courseId: courseId, spotId: spotId, type: type, eventDay: startOfDay)
            guard try fetchEntity(id: id) == nil else { return }

            let entity = CourseEventEntity(context: ctx)
            entity.id = id
            entity.courseId = courseId
            entity.spotId = spotId
            entity.type = type.rawValue
            entity.eventDay = startOfDay
            entity.isSent = false
            entity.createdAt = Date()
            try ctx.save()
        }
    }

    /// 未送信のイベントを古い順に取得する
    func fetchPending() throws -> [CourseEvent] {
        try ctx.performAndWait {
            let req = CourseEventEntity.fetchRequest()
            req.predicate = NSPredicate(format: "isSent == NO")
            req.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: true)]
            return try ctx.fetch(req).compactMap(Self.toDomain)
        }
    }

    /// 送信成功後に送信済みへ更新する
    func markSent(_ id: UUID) throws {
        try ctx.performAndWait {
            guard let entity = try fetchEntity(id: id) else { return }
            entity.isSent = true
            try ctx.save()
        }
    }

    /// デバッグ用: 全件削除する。サーバー側のテストデータ（course_events）を手動で削除した後、
    /// ローカルの「今日はもう記録済み」判定をリセットして再テスト可能にする（DeveloperToolsScreen専用）
    func deleteAllForDebug() throws {
        try ctx.performAndWait {
            let req = CourseEventEntity.fetchRequest()
            let all = try ctx.fetch(req)
            for entity in all {
                ctx.delete(entity)
            }
            try ctx.save()
        }
    }

    private func fetchEntity(id: UUID) throws -> CourseEventEntity? {
        let req = CourseEventEntity.fetchRequest()
        req.predicate = NSPredicate(format: "id == %@", id as NSUUID)
        req.fetchLimit = 1
        return try ctx.fetch(req).first
    }

    private static func toDomain(_ e: CourseEventEntity) -> CourseEvent? {
        guard let type = CourseEventType(rawValue: e.type ?? "view") else { return nil }
        return CourseEvent(
            id: e.id ?? UUID(),
            courseId: e.courseId ?? UUID(),
            spotId: e.spotId,
            type: type,
            eventDay: e.eventDay ?? Date(),
            isSent: e.isSent
        )
    }
}
