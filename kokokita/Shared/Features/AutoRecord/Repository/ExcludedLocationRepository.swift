import Foundation
import CoreData
import CoreLocation

/// 除外エリアの永続化を担当するリポジトリ
final class ExcludedLocationRepository {
    private let ctx: NSManagedObjectContext

    init(context: NSManagedObjectContext = CoreDataStack.shared.context) {
        self.ctx = context
    }

    // MARK: - 取得

    // CLLocationManagerDelegate 等、メインスレッド外から呼ばれる可能性があるため
    // performAndWait でコンテキスト自身のキュー上での実行を保証する
    func fetchAll() throws -> [ExcludedLocation] {
        try ctx.performAndWait {
            let req = ExcludedLocationEntity.fetchRequest()
            req.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
            return try ctx.fetch(req).map { $0.toDomain() }
        }
    }

    // MARK: - 保存

    func save(_ location: ExcludedLocation) throws {
        try ctx.performAndWait {
            let entity = ExcludedLocationEntity(context: ctx)
            entity.id = location.id
            entity.label = location.label
            entity.latitude = location.latitude
            entity.longitude = location.longitude
            entity.radiusMeters = location.radiusMeters
            entity.createdAt = location.createdAt
            try ctx.save()
        }
        Logger.info("除外エリアを保存しました: \(location.displayLabel)")
    }

    // MARK: - 削除

    func delete(id: UUID) throws {
        let deleted = try ctx.performAndWait { () -> Bool in
            let req = ExcludedLocationEntity.fetchRequest()
            req.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            req.fetchLimit = 1
            guard let entity = try ctx.fetch(req).first else { return false }
            ctx.delete(entity)
            try ctx.save()
            return true
        }
        if deleted {
            Logger.info("除外エリアを削除しました: \(id)")
        }
    }

    // MARK: - 判定

    /// 指定座標が除外エリア内かどうかチェックする
    func isExcluded(latitude: Double, longitude: Double) throws -> Bool {
        let all = try fetchAll()
        let target = CLLocation(latitude: latitude, longitude: longitude)
        return all.contains { ex in
            let exLocation = CLLocation(latitude: ex.latitude, longitude: ex.longitude)
            return target.distance(from: exLocation) <= ex.radiusMeters
        }
    }
}
