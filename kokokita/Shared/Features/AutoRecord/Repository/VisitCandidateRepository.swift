import Foundation
import CoreData

/// 自動記録候補の永続化を担当するリポジトリ
final class VisitCandidateRepository {
    private let ctx: NSManagedObjectContext

    init(context: NSManagedObjectContext = CoreDataStack.shared.context) {
        self.ctx = context
    }

    // MARK: - 取得

    /// pending な候補を detectedAt 降順で取得
    // CLLocationManagerDelegate 等、メインスレッド外から呼ばれる可能性があるため
    // performAndWait でコンテキスト自身のキュー上での実行を保証する
    func fetchPending() throws -> [VisitCandidate] {
        try ctx.performAndWait {
            let req = VisitCandidateEntity.fetchRequest()
            req.predicate = NSPredicate(format: "status == %@", VisitCandidate.CandidateStatus.pending.rawValue)
            req.sortDescriptors = [NSSortDescriptor(key: "detectedAt", ascending: false)]
            let entities = try ctx.fetch(req)
            return entities.map { $0.toDomain() }
        }
    }

    /// 全件数（バッジ表示用）
    func countPending() throws -> Int {
        try ctx.performAndWait {
            let req = VisitCandidateEntity.fetchRequest()
            req.predicate = NSPredicate(format: "status == %@", VisitCandidate.CandidateStatus.pending.rawValue)
            return try ctx.count(for: req)
        }
    }

    // MARK: - 保存

    func save(_ candidate: VisitCandidate) throws {
        try ctx.performAndWait {
            let entity = VisitCandidateEntity(context: ctx)
            entity.id = candidate.id
            entity.latitude = candidate.latitude
            entity.longitude = candidate.longitude
            entity.arrivalDate = candidate.arrivalDate
            entity.departureDate = candidate.departureDate
            entity.horizontalAccuracy = candidate.horizontalAccuracy
            entity.placeName = candidate.placeName
            entity.status = candidate.status.rawValue
            entity.detectedAt = candidate.detectedAt
            try ctx.save()
        }
        NotificationCenter.default.post(name: .autoRecordCandidatesChanged, object: nil)
        Logger.info("自動記録候補を保存しました: \(candidate.id)")
    }

    // MARK: - 更新

    /// 逆ジオコーディング結果を候補に反映する
    func updatePlaceName(id: UUID, placeName: String) throws {
        try ctx.performAndWait {
            guard let entity = try fetchEntity(id: id) else { return }
            entity.placeName = placeName
            try ctx.save()
        }
    }

    // MARK: - 却下・削除

    /// 候補を却下して削除する
    func dismiss(id: UUID) throws {
        try ctx.performAndWait {
            guard let entity = try fetchEntity(id: id) else { return }
            ctx.delete(entity)
            try ctx.save()
        }
        NotificationCenter.default.post(name: .autoRecordCandidatesChanged, object: nil)
        Logger.info("自動記録候補を却下しました: \(id)")
    }

    /// 指定日時より古い候補を一括削除（保持期間管理）
    func dismissOlderThan(date: Date) throws {
        let deletedCount = try ctx.performAndWait { () -> Int in
            let req = VisitCandidateEntity.fetchRequest()
            req.predicate = NSPredicate(format: "detectedAt < %@", date as NSDate)
            let entities = try ctx.fetch(req)
            entities.forEach { ctx.delete($0) }
            if !entities.isEmpty {
                try ctx.save()
            }
            return entities.count
        }
        if deletedCount > 0 {
            NotificationCenter.default.post(name: .autoRecordCandidatesChanged, object: nil)
            Logger.info("古い自動記録候補を \(deletedCount) 件削除しました")
        }
    }

    /// 承認後に候補エンティティを削除する（Visit 確定後に呼ぶ）
    func deleteAfterApproval(id: UUID) throws {
        try ctx.performAndWait {
            guard let entity = try fetchEntity(id: id) else { return }
            ctx.delete(entity)
            try ctx.save()
        }
        NotificationCenter.default.post(name: .autoRecordCandidatesChanged, object: nil)
    }

    // MARK: - Private

    private func fetchEntity(id: UUID) throws -> VisitCandidateEntity? {
        let req = VisitCandidateEntity.fetchRequest()
        req.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        req.fetchLimit = 1
        return try ctx.fetch(req).first
    }
}

// MARK: - Entity → Domain 変換

private extension VisitCandidateEntity {
    func toDomain() -> VisitCandidate {
        VisitCandidate(
            id: id ?? UUID(),
            latitude: latitude,
            longitude: longitude,
            arrivalDate: arrivalDate ?? Date(),
            departureDate: departureDate,
            horizontalAccuracy: horizontalAccuracy,
            placeName: placeName,
            status: VisitCandidate.CandidateStatus(rawValue: status ?? "pending") ?? .pending,
            detectedAt: detectedAt ?? Date()
        )
    }
}
