import Foundation

// コースデータの読み書きを抽象化するリポジトリプロトコル
protocol CourseRepository {
    // MARK: - 読み取り

    /// 全コースを取得（スポット含む）
    func fetchAll() throws -> [Course]

    /// 有効なコースのみ取得（スポット含む）
    func fetchEnabled() throws -> [Course]

    /// ID でコースを取得
    func fetch(id: UUID) throws -> Course?

    // MARK: - 書き込み

    /// コースを保存（新規 or 更新）
    func save(_ course: Course) throws

    /// 複数コースを一括保存（バンドルJSON取り込み用）
    func saveAll(_ courses: [Course]) throws

    /// コースの有効/無効を切り替える
    func setEnabled(_ courseId: UUID, enabled: Bool) throws

    /// 指定スポットのチェックイン状態を更新
    func checkIn(spotId: UUID, at date: Date) throws

    /// コースを削除
    func delete(_ courseId: UUID) throws

    // MARK: - 遡り判定用

    /// 指定コースの全スポット（チェックイン済みも含む）を取得
    func fetchSpotsForRetroactive(courseId: UUID) throws -> [CourseSpot]
}
