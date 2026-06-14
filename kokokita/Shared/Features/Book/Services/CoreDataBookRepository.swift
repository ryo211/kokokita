import Foundation
import CoreData

final class CoreDataBookRepository {
    private let ctx: NSManagedObjectContext

    init(context: NSManagedObjectContext = CoreDataStack.shared.context) {
        self.ctx = context
    }

    // MARK: - Read

    func allBooks() throws -> [Book] {
        let req: NSFetchRequest<BookEntity> = BookEntity.fetchRequest()
        req.sortDescriptors = [NSSortDescriptor(key: "sortOrder", ascending: true),
                               NSSortDescriptor(key: "createdAt", ascending: true)]
        return try ctx.fetch(req).compactMap { toBook($0) }
    }

    // MARK: - Create

    @discardableResult
    func createBook(name: String, colorId: String? = Book.defaultColorId) throws -> Book {
        let e = BookEntity(context: ctx)
        e.id = UUID()
        e.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        e.colorId = colorId
        e.createdAt = Date()
        e.sortOrder = Int16((try? allBooks().count) ?? 0)
        try ctx.save()
        guard let book = toBook(e) else {
            throw NSError(domain: "Book", code: 1, userInfo: [NSLocalizedDescriptionKey: "ブックの保存に失敗しました"])
        }
        Logger.info("ブックを作成しました: \(book.name)")
        return book
    }

    // MARK: - Update

    func updateBook(id: UUID, name: String, colorId: String?) throws {
        guard let e = try fetchEntity(id: id) else { return }
        e.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        e.colorId = colorId
        try ctx.save()
    }

    // MARK: - Delete

    func deleteBook(id: UUID) throws {
        guard let e = try fetchEntity(id: id) else { return }
        ctx.delete(e)
        try ctx.save()
        Logger.info("ブックを削除しました: \(id)")
    }

    // MARK: - 起動時マイグレーション

    /// デフォルトブックを保証し、bookId 未割り当てのデータを移行する
    @discardableResult
    func ensureDefaultBookAndMigrateOrphanedData(defaultName: String) throws -> Book {
        let books = try allBooks()
        let defaultBook: Book
        if let first = books.first {
            defaultBook = first
        } else {
            defaultBook = try createBook(name: defaultName, colorId: Book.defaultColorId)
        }

        let bid = defaultBook.id as CVarArg
        try assignOrphanedEntities(entityName: "VisitEntity", bookId: bid)
        try assignOrphanedEntities(entityName: "LabelEntity", bookId: bid)
        try assignOrphanedEntities(entityName: "GroupEntity", bookId: bid)
        try assignOrphanedEntities(entityName: "MemberEntity", bookId: bid)

        return defaultBook
    }

    // MARK: - Private

    private func assignOrphanedEntities(entityName: String, bookId: CVarArg) throws {
        let req = NSFetchRequest<NSManagedObject>(entityName: entityName)
        req.predicate = NSPredicate(format: "bookId == nil")
        let rows = try ctx.fetch(req)
        guard !rows.isEmpty else { return }
        for row in rows { row.setValue(bookId as? UUID, forKey: "bookId") }
        try ctx.save()
        Logger.info("\(entityName): \(rows.count)件をデフォルトブックに移行しました")
    }

    private func fetchEntity(id: UUID) throws -> BookEntity? {
        let req: NSFetchRequest<BookEntity> = BookEntity.fetchRequest()
        req.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        req.fetchLimit = 1
        return try ctx.fetch(req).first
    }

    private func toBook(_ e: BookEntity) -> Book? {
        guard let id = e.id, let name = e.name, let createdAt = e.createdAt else { return nil }
        return Book(id: id, name: name, colorId: e.colorId, createdAt: createdAt, sortOrder: Int(e.sortOrder))
    }
}
