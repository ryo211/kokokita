import Foundation
import CoreData

/// 到達記録の送信待ちキュー（アウトボックス）をCoreDataで管理するリポジトリ
final class SpotArrivalOutboxRepository {
    private let ctx: NSManagedObjectContext

    init(context: NSManagedObjectContext = CoreDataStack.shared.context) {
        self.ctx = context
    }

    /// 到達記録をキューに追加する。同一id（(visitId, spotId)から導出）が既にあれば何もしない
    /// （再チェックイン等で複数回呼ばれても二重送信しないようにするため）
    func enqueue(_ arrival: SpotArrival) throws {
        try ctx.performAndWait {
            guard try fetchEntity(id: arrival.id) == nil else { return }
            let entity = SpotArrivalEntity(context: ctx)
            entity.id = arrival.id
            entity.visitId = arrival.visitId
            entity.courseId = arrival.courseId
            entity.spotId = arrival.spotId
            entity.distanceMeters = arrival.distanceMeters
            entity.arrivedAt = arrival.arrivedAt
            entity.appVersion = arrival.appVersion
            entity.isSent = false
            entity.createdAt = Date()
            try ctx.save()
        }
    }

    /// 未送信の到達記録を古い順に取得する
    func fetchPending() throws -> [SpotArrival] {
        try ctx.performAndWait {
            let req = SpotArrivalEntity.fetchRequest()
            req.predicate = NSPredicate(format: "isSent == NO")
            req.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: true)]
            return try ctx.fetch(req).map(Self.toDomain)
        }
    }

    /// 指定visitIdに紐づく到達記録（送信済み含む）を取得する。達成シートでの順位表示に使う
    func fetchByVisitId(_ visitId: UUID) throws -> [SpotArrival] {
        try ctx.performAndWait {
            let req = SpotArrivalEntity.fetchRequest()
            req.predicate = NSPredicate(format: "visitId == %@", visitId as NSUUID)
            return try ctx.fetch(req).map(Self.toDomain)
        }
    }

    /// 送信成功後に送信済みへ更新する
    func markSent(_ id: UUID, rank: Int?) throws {
        try ctx.performAndWait {
            guard let entity = try fetchEntity(id: id) else { return }
            entity.isSent = true
            if let rank {
                entity.rank = NSNumber(value: Int32(rank))
            }
            try ctx.save()
        }
    }

    /// デバッグ用: 全件の送信済みフラグをリセットする。
    /// サーバー側のテストデータを手動で削除した後、ローカルの送信待ちキューを
    /// 再送信可能な状態に戻すために使う（DeveloperToolsScreen専用）
    func resetAllSentFlagsForDebug() throws {
        try ctx.performAndWait {
            let req = SpotArrivalEntity.fetchRequest()
            let all = try ctx.fetch(req)
            for entity in all {
                entity.isSent = false
                entity.rank = nil
            }
            try ctx.save()
        }
    }

    private func fetchEntity(id: UUID) throws -> SpotArrivalEntity? {
        let req = SpotArrivalEntity.fetchRequest()
        req.predicate = NSPredicate(format: "id == %@", id as NSUUID)
        req.fetchLimit = 1
        return try ctx.fetch(req).first
    }

    private static func toDomain(_ e: SpotArrivalEntity) -> SpotArrival {
        SpotArrival(
            id: e.id ?? UUID(),
            visitId: e.visitId ?? UUID(),
            courseId: e.courseId ?? UUID(),
            spotId: e.spotId ?? UUID(),
            distanceMeters: e.distanceMeters,
            arrivedAt: e.arrivedAt ?? Date(),
            appVersion: e.appVersion ?? "",
            isSent: e.isSent,
            rank: e.rank?.intValue
        )
    }
}
