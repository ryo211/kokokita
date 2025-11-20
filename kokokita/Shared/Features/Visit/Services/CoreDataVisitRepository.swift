import Foundation
import CoreData

final class CoreDataVisitRepository {
    private let ctx: NSManagedObjectContext

    init(context: NSManagedObjectContext = CoreDataStack.shared.context) {
        self.ctx = context
    }

    // MARK: - VisitRepository

    func create(visit: Visit, details: VisitDetails, saveImmediately: Bool = true) throws {
        // 既存のVisitをチェック（リストア時の重複防止）
        if let existing = try fetchVisitEntity(id: visit.id) {
            Logger.warning("Visit with ID \(visit.id) already exists, skipping creation")
            throw NSError(domain: "Visit", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "Visit with ID \(visit.id) already exists"])
        }

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
        d.facilityCategory = details.facilityCategory
        d.comment   = details.comment
        d.groupId   = details.groupId
        d.resolvedAddress = details.resolvedAddress
        // to-many labels
        d.labels    = NSSet(array: try fetchLabelEntities(for: details.labelIds))
        // to-many members
        d.members   = NSSet(array: try fetchMemberEntities(for: details.memberIds))

        if !details.photoPaths.isEmpty {
            let ordered = NSMutableOrderedSet()
            for (idx, path) in details.photoPaths.enumerated() {
                let p = VisitPhotoEntity(context: ctx)
                p.id = UUID()
                p.filePath = path
                p.orderIndex = Int16(idx)   // Ordered リレーションがあるなら任意
                p.createdAt = Date()
                p.details = d
                ordered.add(p)
            }
            d.photos = ordered
        }
        
        // リレーション接続（inverse は DataModel 側で設定しておく）
        v.details = d

        // 保存直前チェック（必須が nil ならここでログに出る）
        preflightValidate([v, d])

        if saveImmediately {
            try ctx.save()
        }
    }

    func updateDetails(id: UUID, transform: (inout VisitDetails) -> Void) throws {
        guard let v = try fetchVisitEntity(id: id) else {
            Logger.warning("Visit not found for update: \(id)")
            return
        }
        guard let d = v.details else {
            Logger.error("Visit details missing for id: \(id)")
            return
        }

        // 現状値を Domain 型に戻してから編集クロージャを適用
        var cur = VisitDetails(
            title: d.title,
            facilityName: d.facilityName,
            facilityAddress: d.facilityAddress,
            facilityCategory: d.facilityCategory,
            comment: d.comment,
            labelIds: (d.labels as? Set<LabelEntity>)?.compactMap { $0.id } ?? [],
            groupId: d.groupId,
            memberIds: (d.members as? Set<MemberEntity>)?.compactMap { $0.id } ?? [],
            resolvedAddress: d.resolvedAddress,
            photoPaths: photoEntities(from: d).compactMap { $0.filePath }
        )
        transform(&cur)

        // 既存の PhotoEntity をマップ化（filePath を一意キー扱い）
        let existing = photoEntities(from: d)
        var byPath = Dictionary(uniqueKeysWithValues: existing.compactMap { e in
            (e.filePath ?? "") .isEmpty ? nil : (e.filePath!, e)
        })

        // 削除（無くなったパス）
        let newSet = Set(cur.photoPaths)
        for e in existing {
            let path = e.filePath ?? ""
            if !newSet.contains(path) {
                // ファイルも削除
                if !path.isEmpty { ImageStore.delete(path) }
                ctx.delete(e)
                byPath.removeValue(forKey: path)
            }
        }

        // 追加/並べ替え
        let ordered = NSMutableOrderedSet()
        for (idx, path) in cur.photoPaths.enumerated() {
            if let exist = byPath[path] {
                exist.orderIndex = Int16(idx)
                ordered.add(exist)
            } else {
                // 追加
                let p = VisitPhotoEntity(context: ctx)
                p.id = UUID()
                p.filePath = path
                p.orderIndex = Int16(idx)
                p.createdAt = Date()
                p.details = d
                ordered.add(p)
            }
        }
        
        // 反映
        d.title     = cur.title
        d.facilityName = cur.facilityName
        d.facilityAddress = cur.facilityAddress
        d.facilityCategory = cur.facilityCategory
        d.comment   = cur.comment
        d.groupId   = cur.groupId
        d.resolvedAddress = cur.resolvedAddress
        d.labels    = NSSet(array: try fetchLabelEntities(for: cur.labelIds))
        d.members   = NSSet(array: try fetchMemberEntities(for: cur.memberIds))
        d.photos    = ordered

        // 不変部は触っていないので d のみチェックで十分
        preflightValidate([d])

        try ctx.save()
    }



    func delete(id: UUID) throws {
        if let v = try fetchVisitEntity(id: id) {
            // ファイルパスを先に退避して削除
            let photos = photoEntities(from: v.details)
            for p in photos { if let path = p.filePath { ImageStore.delete(path) } }
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
            // タイトルまたは住所に含まれる（OR検索）
            let titlePredicate = NSPredicate(format: "details.title CONTAINS[cd] %@", q)
            let addressPredicate = NSPredicate(format: "details.resolvedAddress CONTAINS[cd] %@", q)
            predicates.append(NSCompoundPredicate(orPredicateWithSubpredicates: [titlePredicate, addressPredicate]))
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
        guard let v = try fetchVisitEntity(id: id) else {
            Logger.debug("Visit not found: \(id)")
            return nil
        }
        return toAggregate(v)
    }

    // MARK: - TaxonomyRepository

    func allLabels() throws -> [LabelTag] {
        let req: NSFetchRequest<LabelEntity> = LabelEntity.fetchRequest()
        req.sortDescriptors = [NSSortDescriptor(key: #keyPath(LabelEntity.name), ascending: true)]
        return try ctx.fetch(req).compactMap { row in
            guard let id = row.id, let name = row.name else {
                Logger.warning("Label entity missing required fields (id or name)")
                return nil
            }
            return LabelTag(id: id, name: name)
        }
    }

    func allGroups() throws -> [GroupTag] {
        let req: NSFetchRequest<GroupEntity> = GroupEntity.fetchRequest()
        req.sortDescriptors = [NSSortDescriptor(key: #keyPath(GroupEntity.name), ascending: true)]
        return try ctx.fetch(req).compactMap { row in
            guard let id = row.id, let name = row.name else {
                Logger.warning("Group entity missing required fields (id or name)")
                return nil
            }
            return GroupTag(id: id, name: name)
        }
    }

    func allMembers() throws -> [MemberTag] {
        let req: NSFetchRequest<MemberEntity> = MemberEntity.fetchRequest()
        req.sortDescriptors = [NSSortDescriptor(key: #keyPath(MemberEntity.name), ascending: true)]
        return try ctx.fetch(req).compactMap { row in
            guard let id = row.id, let name = row.name else {
                Logger.warning("Member entity missing required fields (id or name)")
                return nil
            }
            return MemberTag(id: id, name: name)
        }
    }

    func upsertLabel(name: String) throws -> LabelTag {
        let req: NSFetchRequest<LabelEntity> = LabelEntity.fetchRequest()
        req.predicate = NSPredicate(format: "name == %@", name)
        if let hit = try ctx.fetch(req).first, let id = hit.id, let nm = hit.name {
            return LabelTag(id: id, name: nm)
        }
        let e = LabelEntity(context: ctx)
        let newId = UUID()
        e.id = newId
        e.name = name
        try ctx.save()
        guard let savedId = e.id, let savedName = e.name else {
            Logger.error("Failed to save label entity properly")
            throw NSError(domain: "Repository", code: 2, userInfo: [NSLocalizedDescriptionKey: "ラベルの保存に失敗しました"])
        }
        return LabelTag(id: savedId, name: savedName)
    }

    func upsertGroup(name: String) throws -> GroupTag {
        let req: NSFetchRequest<GroupEntity> = GroupEntity.fetchRequest()
        req.predicate = NSPredicate(format: "name == %@", name)
        if let hit = try ctx.fetch(req).first, let id = hit.id, let nm = hit.name {
            return GroupTag(id: id, name: nm)
        }
        let e = GroupEntity(context: ctx)
        let newId = UUID()
        e.id = newId
        e.name = name
        try ctx.save()
        guard let savedId = e.id, let savedName = e.name else {
            Logger.error("Failed to save group entity properly")
            throw NSError(domain: "Repository", code: 2, userInfo: [NSLocalizedDescriptionKey: "グループの保存に失敗しました"])
        }
        return GroupTag(id: savedId, name: savedName)
    }

    func upsertMember(name: String) throws -> MemberTag {
        let req: NSFetchRequest<MemberEntity> = MemberEntity.fetchRequest()
        req.predicate = NSPredicate(format: "name == %@", name)
        if let hit = try ctx.fetch(req).first, let id = hit.id, let nm = hit.name {
            return MemberTag(id: id, name: nm)
        }
        let e = MemberEntity(context: ctx)
        let newId = UUID()
        e.id = newId
        e.name = name
        try ctx.save()
        guard let savedId = e.id, let savedName = e.name else {
            Logger.error("Failed to save member entity properly")
            throw NSError(domain: "Repository", code: 2, userInfo: [NSLocalizedDescriptionKey: "メンバーの保存に失敗しました"])
        }
        return MemberTag(id: savedId, name: savedName)
    }

    // MARK: - Helpers

    private func fetchVisitEntity(id: UUID) throws -> VisitEntity? {
        let req: NSFetchRequest<VisitEntity> = VisitEntity.fetchRequest()
        req.fetchLimit = 1
        req.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        return try ctx.fetch(req).first
    }

    /// 写真エンティティを取得（NSOrderedSet から配列に変換）
    private func photoEntities(from details: VisitDetailsEntity?) -> [VisitPhotoEntity] {
        guard let details = details,
              let ordered = details.photos,
              let casted = ordered.array as? [VisitPhotoEntity] else {
            return []
        }
        return casted
    }

    /// ジェネリックなエンティティ取得ヘルパー
    private func fetchEntity<T: NSManagedObject>(_ type: T.Type, id: UUID) throws -> T? {
        let req = T.fetchRequest()
        req.fetchLimit = 1
        req.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        return try ctx.fetch(req).first as? T
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
        else {
            Logger.error("Visit entity has missing required fields")
            return nil
        }

        // Visit（不変部）
        let visit = Visit(
            id: id,
            timestampUTC: ts,
            latitude: v.latitude,
            longitude: v.longitude,
            horizontalAccuracy: v.horizontalAccuracy?.doubleValue,
            isSimulatedBySoftware: v.isSimulatedBySoftware?.boolValue,
            isProducedByAccessory: v.isProducedByAccessory?.boolValue,
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

        let memberEntities = (d?.members as? Set<MemberEntity>) ?? []
        let memberIds = memberEntities.compactMap { $0.id }

        let photos = photoEntities(from: d)
        let photoPaths = photos.compactMap { $0.filePath }

        let details = VisitDetails(
            title: d?.title,
            facilityName: d?.facilityName,
            facilityAddress: d?.facilityAddress,
            facilityCategory: d?.facilityCategory,
            comment: d?.comment,
            labelIds: labelIds,
            groupId: d?.groupId,
            memberIds: memberIds,
            resolvedAddress: d?.resolvedAddress,
            photoPaths: photoPaths
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

    private func fetchMemberEntities(for ids: [UUID]) throws -> [MemberEntity] {
        guard !ids.isEmpty else { return [] }
        let req: NSFetchRequest<MemberEntity> = MemberEntity.fetchRequest()
        req.predicate = NSPredicate(format: "id IN %@", ids)
        let found = try ctx.fetch(req)
        // 見つからない id があっても無視（スキップ）
        return found
    }
    
    // ① 追加：保存直前に必須項目の nil を検知してログする
    private func preflightValidate(_ objs: [NSManagedObject]) {
        #if DEBUG
        for o in objs {
            guard let entity = o.entity.name else { continue }
            // 必須属性の nil を列挙
            for (name, attr) in o.entity.attributesByName where !attr.isOptional {
                if o.value(forKey: name) == nil {
                    Logger.error("[\(entity)] required attr '\(name)' is nil")
                }
            }
            // to-one リレーションの MinCount > 0 で未設定を検知
            for (name, rel) in o.entity.relationshipsByName where !rel.isToMany && rel.minCount > 0 {
                if o.value(forKey: name) == nil {
                    Logger.error("[\(entity)] required to-one relation '\(name)' is nil (minCount=\(rel.minCount))")
                }
            }
            // to-many リレーションの MinCount > 0 で空配列を検知
            for (name, rel) in o.entity.relationshipsByName where rel.isToMany && rel.minCount > 0 {
                if let set = o.value(forKey: name) as? NSSet, set.count == 0 {
                    Logger.error("[\(entity)] required to-many relation '\(name)' is empty (minCount=\(rel.minCount))")
                }
            }
        }
        #endif
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

    // MARK: - Taxonomy: Member

    func renameMember(id: UUID, newName: String) throws {
        guard let member = try fetchMemberEntity(id: id) else { return }
        member.name = newName
        try ctx.save()
    }

    func deleteMember(id: UUID) throws {
        guard let member = try fetchMemberEntity(id: id) else { return }

        // 関連から外す（安全のため）
        let req = VisitDetailsEntity.fetchRequest()
        req.predicate = NSPredicate(format: "ANY members == %@", member)
        let affected = try ctx.fetch(req)
        for d in affected {
            if var set = d.members as? Set<MemberEntity> {
                set.remove(member)
                d.members = NSSet(set: set)
            }
        }

        ctx.delete(member)
        try ctx.save()
    }

    // MARK: - Visit: カウント

    func allVisitsCount() throws -> Int {
        let request: NSFetchRequest<VisitEntity> = VisitEntity.fetchRequest()
        return try ctx.count(for: request)
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
        try fetchEntity(LabelEntity.self, id: id)
    }

    private func fetchGroupEntity(id: UUID) throws -> GroupEntity? {
        try fetchEntity(GroupEntity.self, id: id)
    }

    private func fetchMemberEntity(id: UUID) throws -> MemberEntity? {
        try fetchEntity(MemberEntity.self, id: id)
    }

    private func normalizedName(_ s: String) -> String {
        s.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    func createLabel(name: String) throws -> UUID {
        let trimmed = name.trimmed
        guard !trimmed.isEmpty else {
            Logger.warning("Attempted to create label with empty name")
            throw NSError(domain: "Label", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "空名は作成できません"])
        }
        let e = LabelEntity(context: ctx)
        let newId = UUID()
        e.id = newId
        e.name = trimmed
        try ctx.save()
        guard let savedId = e.id else {
            Logger.error("Label entity ID is nil after save")
            throw NSError(domain: "Repository", code: 2, userInfo: [NSLocalizedDescriptionKey: "ラベルの保存に失敗しました"])
        }
        return savedId
    }

    func createGroup(name: String) throws -> UUID {
        let trimmed = name.trimmed
        guard !trimmed.isEmpty else {
            Logger.warning("Attempted to create group with empty name")
            throw NSError(domain: "Group", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "空名は作成できません"])
        }
        let e = GroupEntity(context: ctx)
        let newId = UUID()
        e.id = newId
        e.name = trimmed
        try ctx.save()
        guard let savedId = e.id else {
            Logger.error("Group entity ID is nil after save")
            throw NSError(domain: "Repository", code: 2, userInfo: [NSLocalizedDescriptionKey: "グループの保存に失敗しました"])
        }
        return savedId
    }

    func createMember(name: String) throws -> UUID {
        let trimmed = name.trimmed
        guard !trimmed.isEmpty else {
            Logger.warning("Attempted to create member with empty name")
            throw NSError(domain: "Member", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "空名は作成できません"])
        }
        let e = MemberEntity(context: ctx)
        let newId = UUID()
        e.id = newId
        e.name = trimmed
        try ctx.save()
        guard let savedId = e.id else {
            Logger.error("Member entity ID is nil after save")
            throw NSError(domain: "Repository", code: 2, userInfo: [NSLocalizedDescriptionKey: "メンバーの保存に失敗しました"])
        }
        return savedId
    }

    // MARK: - Restore用：既存IDでの作成

    func createLabel(id: UUID, name: String, saveImmediately: Bool = true) throws {
        let trimmed = name.trimmed
        guard !trimmed.isEmpty else {
            Logger.warning("Attempted to create label with empty name")
            throw NSError(domain: "Label", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "空名は作成できません"])
        }

        // 既存のラベルをチェック
        if let existing = try fetchLabelEntity(id: id) {
            Logger.info("Label with ID \(id) already exists, skipping creation")
            // 名前が異なる場合は更新
            if existing.name != trimmed {
                existing.name = trimmed
                if saveImmediately {
                    try ctx.save()
                }
                Logger.info("Updated label name to: \(trimmed)")
            }
            return
        }

        let e = LabelEntity(context: ctx)
        e.id = id
        e.name = trimmed
        if saveImmediately {
            try ctx.save()
        }
        Logger.info("Created label with existing ID: \(trimmed) (\(id))")
    }

    func createGroup(id: UUID, name: String, saveImmediately: Bool = true) throws {
        let trimmed = name.trimmed
        guard !trimmed.isEmpty else {
            Logger.warning("Attempted to create group with empty name")
            throw NSError(domain: "Group", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "空名は作成できません"])
        }

        // 既存のグループをチェック
        if let existing = try fetchGroupEntity(id: id) {
            Logger.info("Group with ID \(id) already exists, skipping creation")
            // 名前が異なる場合は更新
            if existing.name != trimmed {
                existing.name = trimmed
                if saveImmediately {
                    try ctx.save()
                }
                Logger.info("Updated group name to: \(trimmed)")
            }
            return
        }

        let e = GroupEntity(context: ctx)
        e.id = id
        e.name = trimmed
        if saveImmediately {
            try ctx.save()
        }
        Logger.info("Created group with existing ID: \(trimmed) (\(id))")
    }

    func createMember(id: UUID, name: String, saveImmediately: Bool = true) throws {
        let trimmed = name.trimmed
        guard !trimmed.isEmpty else {
            Logger.warning("Attempted to create member with empty name")
            throw NSError(domain: "Member", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "空名は作成できません"])
        }

        // 既存のメンバーをチェック
        if let existing = try fetchMemberEntity(id: id) {
            Logger.info("Member with ID \(id) already exists, skipping creation")
            // 名前が異なる場合は更新
            if existing.name != trimmed {
                existing.name = trimmed
                if saveImmediately {
                    try ctx.save()
                }
                Logger.info("Updated member name to: \(trimmed)")
            }
            return
        }

        let e = MemberEntity(context: ctx)
        e.id = id
        e.name = trimmed
        if saveImmediately {
            try ctx.save()
        }
        Logger.info("Created member with existing ID: \(trimmed) (\(id))")
    }

    /// CoreDataコンテキストをリフレッシュして一時ObjectIDを永続IDに変換
    func refreshContext() throws {
        // 未保存の変更があれば保存
        if ctx.hasChanges {
            try ctx.save()
        }

        // 一時ObjectIDを永続IDに変換
        let insertedObjects = Array(ctx.insertedObjects)
        if !insertedObjects.isEmpty {
            try ctx.obtainPermanentIDs(for: insertedObjects)
            Logger.info("Obtained permanent IDs for \(insertedObjects.count) objects")
        }

        Logger.info("CoreData context refreshed")
    }
}

