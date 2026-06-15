import Foundation

/// 簡易DIコンテナ（依存性注入）
final class AppContainer {
    static let shared = AppContainer()

    // Repository（具体的な実装に直接依存）
    let repo = CoreDataVisitRepository()
    let taxonomyRepo = CoreDataTaxonomyRepository()
    let courseRepo: CoreDataCourseRepository = CoreDataCourseRepository()
    let candidateRepo = VisitCandidateRepository()

    // Rate Limiter (共有インスタンス)
    let rateLimiter = RateLimiter(minimumInterval: 0.5)

    // Services（具体的な実装に直接依存）
    let loc = DefaultLocationService()
    lazy var poi: MapKitPlaceLookupService = MapKitPlaceLookupService(rateLimiter: rateLimiter)
    let integ = DefaultIntegrityService()
    lazy var courseRecognitionService: CourseRecognitionService = CourseRecognitionService(repo: courseRepo)
    lazy var retroactiveService: CourseRetroactiveRecognitionService = CourseRetroactiveRecognitionService(courseRepo: courseRepo)
    lazy var courseJSONService: CourseJSONService = CourseJSONService(repo: courseRepo)
    lazy var courseStoreService: CourseStoreService = CourseStoreService()

    private init() {}
}
