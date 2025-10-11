//
//  CoreDataTaxonomyRepository.swift
//  kokokita
//
//  Created by Claude on 2025/10/11.
//

import Foundation
import CoreData

/// Label と Group のCRUD操作を担当するリポジトリ
final class CoreDataTaxonomyRepository: TaxonomyRepository {
    private let ctx: NSManagedObjectContext

    init(context: NSManagedObjectContext = CoreDataStack.shared.context) {
        self.ctx = context
    }

    // MARK: - Read Operations

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

    // MARK: - Upsert Operations

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

    // MARK: - Create Operations

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

    // MARK: - Update Operations

    func renameLabel(id: UUID, newName: String) throws {
        guard let label = try fetchEntity(LabelEntity.self, id: id) else {
            Logger.warning("Label not found for rename: \(id)")
            return
        }
        label.name = newName
        try ctx.save()
    }

    func renameGroup(id: UUID, newName: String) throws {
        guard let group = try fetchEntity(GroupEntity.self, id: id) else {
            Logger.warning("Group not found for rename: \(id)")
            return
        }
        group.name = newName
        try ctx.save()
    }

    // MARK: - Delete Operations

    func deleteLabel(id: UUID) throws {
        guard let label = try fetchEntity(LabelEntity.self, id: id) else {
            Logger.warning("Label not found for delete: \(id)")
            return
        }

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

    func deleteGroup(id: UUID) throws {
        guard let group = try fetchEntity(GroupEntity.self, id: id) else {
            Logger.warning("Group not found for delete: \(id)")
            return
        }

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

    // MARK: - Helpers

    /// ジェネリックなエンティティ取得ヘルパー
    private func fetchEntity<T: NSManagedObject>(_ type: T.Type, id: UUID) throws -> T? {
        let req = T.fetchRequest()
        req.fetchLimit = 1
        req.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        return try ctx.fetch(req).first as? T
    }
}
