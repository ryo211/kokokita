import Foundation

/// 簡易DIコンテナ（依存性注入）
final class AppContainer {
    static let shared = AppContainer()

    // Repository（具体的な実装に直接依存）
    let repo = CoreDataVisitRepository()
    let taxonomyRepo = CoreDataTaxonomyRepository()
    let bookRepo = CoreDataBookRepository()
    let courseRepo: CoreDataCourseRepository = CoreDataCourseRepository()
    let candidateRepo = VisitCandidateRepository()

    // Rate Limiter (共有インスタンス)
    let rateLimiter = RateLimiter(minimumInterval: 0.5)

    // Services（具体的な実装に直接依存）
    let loc = DefaultLocationService()
    lazy var autoRecord: AutoRecordService = AutoRecordService(candidateRepo: candidateRepo)
    let autoRecordSettings = AutoRecordSettings.shared
    lazy var poi: MapKitPlaceLookupService = MapKitPlaceLookupService(rateLimiter: rateLimiter)
    let integ = DefaultIntegrityService()
    lazy var courseRecognitionService: CourseRecognitionService = CourseRecognitionService(repo: courseRepo)
    lazy var retroactiveService: CourseRetroactiveRecognitionService = CourseRetroactiveRecognitionService(courseRepo: courseRepo)
    lazy var courseJSONService: CourseJSONService = CourseJSONService(repo: courseRepo)
    lazy var courseStoreService: CourseStoreService = CourseStoreService()

    /// 現在選択中のブック（UI参照用）
    var currentBook: Book? = nil

    private init() {}

    /// ブックを切り替え、リポジトリの currentBookId を同期する
    func setCurrentBook(_ book: Book) {
        repo.currentBookId = book.id
        taxonomyRepo.currentBookId = book.id
        currentBook = book
        UserDefaults.standard.set(book.id.uuidString, forKey: "currentBookId")
        NotificationCenter.default.post(name: .bookChanged, object: nil)
        NotificationCenter.default.post(name: .visitsChanged, object: nil)
        NotificationCenter.default.post(name: .taxonomyChanged, object: nil)
    }

    /// 起動時にブックを初期化（マイグレーション + 前回選択ブックの復元）
    func setupBook(defaultName: String) {
        do {
            let defaultBook = try bookRepo.ensureDefaultBookAndMigrateOrphanedData(defaultName: defaultName)
            let savedId = UserDefaults.standard.string(forKey: "currentBookId").flatMap { UUID(uuidString: $0) }
            let allBooks = try bookRepo.allBooks()
            let book = allBooks.first(where: { $0.id == savedId }) ?? defaultBook
            setCurrentBook(book)
        } catch {
            Logger.error("ブック初期化エラー", error: error)
        }
    }
}
