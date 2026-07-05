import Foundation

// コースデータの読み書きを抽象化するリポジトリプロトコル
protocol CourseRepository {
    // MARK: - 読み取り

    /// 全コースを取得（スポット含む）
    func fetchAll() throws -> [Course]

    /// ID でコースを取得
    func fetch(id: UUID) throws -> Course?

    // MARK: - 書き込み

    /// コースを保存（新規 or 更新）
    func save(_ course: Course) throws

    /// 複数コースを一括保存（バンドルJSON取り込み用）
    func saveAll(_ courses: [Course]) throws

    /// 遡り判定実施済みフラグをセットする
    func setEverEnabled(_ courseId: UUID) throws

    /// 指定スポットに訪問記録を紐づける（isCheckedIn は visitIds から自動導出）
    func checkIn(spotId: UUID, visitId: UUID?) throws

    /// コースを非表示にする（自動同期でも復活しない）
    func hide(_ courseId: UUID) throws

    /// コースを削除
    func delete(_ courseId: UUID) throws

    // MARK: - 遡り判定用

    /// 指定コースの全スポット（チェックイン済みも含む）を取得
    func fetchSpotsForRetroactive(courseId: UUID) throws -> [CourseSpot]
}
