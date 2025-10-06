import Foundation
import CoreData

final class CoreDataVisitRepository: VisitRepository, TaxonomyRepository {
    private let ctx: NSManagedObjectContext

    init(context: NSManagedObjectContext = CoreDataStack.shared.context) {
        self.ctx = context
    }

    // MARK: - VisitRepository

    func create(visit: Visit, details: VisitDetails) throws {
        let v = VisitEntity(context: ctx)

        // ---- Visit（不変部）を先にすべて代入 ----
        v.id = visit.id
        v.timestampUTC = visit.timestampUTC
        v.latitude = visit.latitude
        v.longitude = visit.longitude

        // Optional（Data Model を NSNumber? にしている想定）
        v.horizontalAccuracy    = visit.horizontalAccuracy.map { NSNumber(value: $0) }
        v.isSimulatedBySoftware = visit.isSimulatedBySoftware.map { NSNumber(value: $0) }
        v.isProducedByAccessory = visit.isProducedByAccessory.map { NSNumber(value: $0) }

        // 改ざん検出メタ（Integrity）
        v.integrityAlgo         = visit.integrity.algo
        v.integritySigDER       = visit.integrity.signatureDERBase64
        v.integrityPubRaw       = visit.integrity.publicKeyRawBase64
        v.integrityPayloadHash  = visit.integrity.payloadHashHex
        v.integrityCreatedAtUTC = visit.integrity.createdAtUTC

        // ---- VisitDetails（可変部） ----
        let d = VisitDetailsEntity(context: ctx)
        d.title     = details.title
        d.facilityName = details.facilityName
        d.facilityAddress = details.facilityAddress
        d.comment   = details.comment
        d.groupId   = details.groupId
        d.resolvedAddress = details.resolvedAddress
        // to-many labels
        d.labels    = NSSet(array: try fetchLabelEntities(for: details.labelIds))

        // リレーション接続（inverse は DataModel 側で設定しておく）
        v.details = d

        // 保存直前チェック（必須が nil ならここでログに出る）
        preflightValidate([v, d])

        try ctx.save()
    }

    func updateDetails(id: UUID, transform: (inout VisitDetails) -> Void) throws {
        guard let v = try fetchVisitEntity(id: id), let d = v.details else { return }

        // 現状値を Domain 型に戻してから編集クロージャを適用
        var cur = VisitDetails(
            title: d.title,
            facilityName: d.facilityName,
            facilityAddress: d.facilityAddress,
            comment: d.comment,
            labelIds: (d.labels as? Set<LabelEntity>)?.compactMap { $0.id } ?? [],
            groupId: d.groupId
        )
        transform(&cur)

        // 反映
        d.title     = cur.title
        d.facilityName = cur.facilityName
        d.facilityAddress = cur.facilityAddress
        d.comment   = cur.comment
        d.groupId   = cur.groupId
        d.resolvedAddress = cur.resolvedAddress
        d.labels    = NSSet(array: try fetchLabelEntities(for: cur.labelIds))

        // 不変部は触っていないので d のみチェックで十分
        preflightValidate([d])

        try ctx.save()
    }



    func delete(id: UUID) throws {
        if let v = try fetchVisitEntity(id: id) {
            ctx.delete(v)
            try ctx.save()
        }
    }

    func fetchAll(
        filterLabel: UUID?,
        filterGroup: UUID?,
        titleQuery: String?,
        dateFrom: Date?,
        dateToExclusive: Date?
    ) throws -> [VisitAggregate] {
        // 型を明示
        let request: NSFetchRequest<VisitEntity> = VisitEntity.fetchRequest()
        var predicates: [NSPredicate] = []

        // VisitEntity(1) -details-> VisitDetailsEntity(1) -labels-> LabelEntity(*)
        if let lf = filterLabel {
            // details.labels の id にヒットするもの
            predicates.append(NSPredicate(format: "ANY details.labels.id == %@", lf as CVarArg))
        }
        
        if let gf = filterGroup {
            // details の groupId
            predicates.append(NSPredicate(format: "details.groupId == %@", gf as CVarArg))
        }
        if let q = titleQuery, !q.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            // タイトルは details.title
            predicates.append(NSPredicate(format: "details.title CONTAINS[cd] %@", q))
        }
        if let from = dateFrom {
            // 日付は VisitEntity 側の timestampUTC を使用
            predicates.append(NSPredicate(format: "timestampUTC >= %@", from as NSDate))
        }
        if let to = dateToExclusive {
            // 半開区間上端（<）で指定
            predicates.append(NSPredicate(format: "timestampUTC < %@", to as NSDate))
        }

        if !predicates.isEmpty {
            request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        }

        // ここを ctx に
        let rows = try ctx.fetch(request)

        // toAggregate(_:) は free関数/メンバ関数なので self.toAggregate(_:) で呼ぶ
        // Optional を落とすために compactMap
        return rows.compactMap { self.toAggregate($0) }
    }



    func get(by id: UUID) throws -> VisitAggregate? {
        guard let v = try fetchVisitEntity(id: id) else { return nil }
        return toAggregate(v)
    }

    // MARK: - TaxonomyRepository

    func allLabels() throws -> [LabelTag] {
        let req: NSFetchRequest<LabelEntity> = LabelEntity.fetchRequest()
        req.sortDescriptors = [NSSortDescriptor(key: #keyPath(LabelEntity.name), ascending: true)]
        return try ctx.fetch(req).compactMap { row in
            guard let id = row.id, let name = row.name else { return nil }
            return LabelTag(id: id, name: name)
        }
    }

    func allGroups() throws -> [GroupTag] {
        let req: NSFetchRequest<GroupEntity> = GroupEntity.fetchRequest()
        req.sortDescriptors = [NSSortDescriptor(key: #keyPath(GroupEntity.name), ascending: true)]
        return try ctx.fetch(req).compactMap { row in
            guard let id = row.id, let name = row.name else { return nil }
            return GroupTag(id: id, name: name)
        }
    }

    func upsertLabel(name: String) throws -> LabelTag {
        let req: NSFetchRequest<LabelEntity> = LabelEntity.fetchRequest()
        req.predicate = NSPredicate(format: "name == %@", name)
        if let hit = try ctx.fetch(req).first, let id = hit.id, let nm = hit.name {
            return LabelTag(id: id, name: nm)
        }
        let e = LabelEntity(context: ctx)
        e.id = UUID()
        e.name = name
        try ctx.save()
        return LabelTag(id: e.id!, name: e.name!)
    }

    func upsertGroup(name: String) throws -> GroupTag {
        let req: NSFetchRequest<GroupEntity> = GroupEntity.fetchRequest()
        req.predicate = NSPredicate(format: "name == %@", name)
        if let hit = try ctx.fetch(req).first, let id = hit.id, let nm = hit.name {
            return GroupTag(id: id, name: nm)
        }
        let e = GroupEntity(context: ctx)
        e.id = UUID()
        e.name = name
        try ctx.save()
        return GroupTag(id: e.id!, name: e.name!)
    }

    // MARK: - Helpers

    private func fetchVisitEntity(id: UUID) throws -> VisitEntity? {
        let req: NSFetchRequest<VisitEntity> = VisitEntity.fetchRequest()
        req.fetchLimit = 1
        req.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        return try ctx.fetch(req).first
    }

    private func toAggregate(_ v: VisitEntity) -> VisitAggregate? {
        // 必須フィールド
        guard
            let id   = v.id,
            let ts   = v.timestampUTC,
            let algo = v.integrityAlgo,
            let sig  = v.integritySigDER,
            let pub  = v.integrityPubRaw,
            let hash = v.integrityPayloadHash,
            let ic   = v.integrityCreatedAtUTC
        else { return nil }

        // Visit（不変部）
        let visit = Visit(
            id: id,
            timestampUTC: ts,
            latitude: v.latitude,
            longitude: v.longitude,
            // ★ Data Model を NSNumber? にしている場合はこちら
            horizontalAccuracy: (v.horizontalAccuracy as? NSNumber)?.doubleValue,
            isSimulatedBySoftware: (v.isSimulatedBySoftware as? NSNumber)?.boolValue,
            isProducedByAccessory: (v.isProducedByAccessory as? NSNumber)?.boolValue,
            // ↓ Integrity
            integrity: .init(
                algo: algo,
                signatureDERBase64: sig,
                publicKeyRawBase64: pub,
                payloadHashHex: hash,
                createdAtUTC: ic
            )
        )

        // Details（可変部）
        let d = v.details
        let labelEntities = (d?.labels as? Set<LabelEntity>) ?? []
        let labelIds = labelEntities.compactMap { $0.id }

        let details = VisitDetails(
            title: d?.title,
            facilityName: d?.facilityName, 
            facilityAddress: d?.facilityAddress,
            comment: d?.comment,
            labelIds: labelIds,
            groupId: d?.groupId,
            resolvedAddress: d?.resolvedAddress
        )

        return VisitAggregate(id: id, visit: visit, details: details)
    }

    
    private func fetchLabelEntities(for ids: [UUID]) throws -> [LabelEntity] {
        guard !ids.isEmpty else { return [] }
        let req: NSFetchRequest<LabelEntity> = LabelEntity.fetchRequest()
        req.predicate = NSPredicate(format: "id IN %@", ids)
        let found = try ctx.fetch(req)
        // 見つからない id があっても無視（スキップ）
        return found
    }
    
    // ① 追加：保存直前に必須項目の nil を検知してログする
    private func preflightValidate(_ objs: [NSManagedObject]) {
        for o in objs {
            guard let entity = o.entity.name else { continue }
            // 必須属性の nil を列挙
            for (name, attr) in o.entity.attributesByName where !attr.isOptional {
                if o.value(forKey: name) == nil {
                    print("❌ [\(entity)] required attr '\(name)' is nil")
                }
            }
            // to-one リレーションの MinCount > 0 で未設定を検知
            for (name, rel) in o.entity.relationshipsByName where !rel.isToMany && rel.minCount > 0 {
                if o.value(forKey: name) == nil {
                    print("❌ [\(entity)] required to-one relation '\(name)' is nil (minCount=\(rel.minCount))")
                }
            }
            // to-many リレーションの MinCount > 0 で空配列を検知
            for (name, rel) in o.entity.relationshipsByName where rel.isToMany && rel.minCount > 0 {
                if let set = o.value(forKey: name) as? NSSet, set.count == 0 {
                    print("❌ [\(entity)] required to-many relation '\(name)' is empty (minCount=\(rel.minCount))")
                }
            }
        }
    }
    
    // MARK: - Taxonomy: Label

    func renameLabel(id: UUID, newName: String) throws {
        guard let label = try fetchLabelEntity(id: id) else { return }
        label.name = newName
        try ctx.save()
    }

    func deleteLabel(id: UUID) throws {
        guard let label = try fetchLabelEntity(id: id) else { return }

        // 関連から外す（安全のため）
        let req = VisitDetailsEntity.fetchRequest()
        req.predicate = NSPredicate(format: "ANY labels == %@", label)
        let affected = try ctx.fetch(req)
        for d in affected {
            if var set = d.labels as? Set<LabelEntity> {
                set.remove(label)
                d.labels = NSSet(set: set)
            }
        }

        ctx.delete(label)
        try ctx.save()
    }

    // MARK: - Taxonomy: Group

    func renameGroup(id: UUID, newName: String) throws {
        guard let group = try fetchGroupEntity(id: id) else { return }
        group.name = newName
        try ctx.save()
    }

    func deleteGroup(id: UUID) throws {
        guard let group = try fetchGroupEntity(id: id) else { return }

        // このグループを参照している詳細の groupId を外す
        if let gid = group.id {
            let req = VisitDetailsEntity.fetchRequest()
            req.predicate = NSPredicate(format: "groupId == %@", gid as CVarArg)
            let affected = try ctx.fetch(req)
            for d in affected {
                d.groupId = nil
            }
        }

        ctx.delete(group)
        try ctx.save()
    }

    // MARK: - Visit: 全削除（初期化）

    func deleteAllVisits() throws {
        // VisitDetails から先に消す（参照整合のため）
        do {
            let del = NSBatchDeleteRequest(fetchRequest: VisitDetailsEntity.fetchRequest())
            del.resultType = .resultTypeObjectIDs
            let res = try ctx.execute(del) as? NSBatchDeleteResult
            if let ids = res?.result as? [NSManagedObjectID] {
                NSManagedObjectContext.mergeChanges(fromRemoteContextSave: [NSDeletedObjectsKey: ids], into: [ctx])
            }
        }
        // Visit 本体
        do {
            let del = NSBatchDeleteRequest(fetchRequest: VisitEntity.fetchRequest())
            del.resultType = .resultTypeObjectIDs
            let res = try ctx.execute(del) as? NSBatchDeleteResult
            if let ids = res?.result as? [NSManagedObjectID] {
                NSManagedObjectContext.mergeChanges(fromRemoteContextSave: [NSDeletedObjectsKey: ids], into: [ctx])
            }
        }
    }
    private func fetchLabelEntity(id: UUID) throws -> LabelEntity? {
        let req = LabelEntity.fetchRequest()
        req.fetchLimit = 1
        req.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        return try ctx.fetch(req).first
    }

    private func fetchGroupEntity(id: UUID) throws -> GroupEntity? {
        let req = GroupEntity.fetchRequest()
        req.fetchLimit = 1
        req.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        return try ctx.fetch(req).first
    }

    private func normalizedName(_ s: String) -> String {
        s.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    func createLabel(name: String) throws -> UUID {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw NSError(domain: "Label", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "空名は作成できません"])
        }
        let e = LabelEntity(context: ctx)
        e.id = UUID()
        e.name = trimmed
        try ctx.save()
        return e.id!
    }

    func createGroup(name: String) throws -> UUID {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw NSError(domain: "Group", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "空名は作成できません"])
        }
        let e = GroupEntity(context: ctx)
        e.id = UUID()
        e.name = trimmed
        try ctx.save()
        return e.id!
    }
}

