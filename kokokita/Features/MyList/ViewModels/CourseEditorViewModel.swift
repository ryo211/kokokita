import SwiftUI
import PhotosUI
import Combine

/// コース編集画面で扱うスポットの一時的なデータ構造
struct EditingSpot: Identifiable, Equatable {
    var id: UUID = UUID()
    /// CoreDataの既存スポットID（新規の場合は新しいUUID）
    var existingId: UUID?
    var name: String = ""
    var address: String?
    var latitude: Double?
    var longitude: Double?
    var spotDescription: String?
    var coverImage: UIImage?
    var localCoverImagePath: String?
    var coverImageUrl: String?
    /// コース固有の半径を使用するか
    var useCustomRadius: Bool = false
    var customRadius: Double = 150
    /// 有効な座標が設定されているか
    var hasValidCoordinate: Bool {
        guard let lat = latitude, let lon = longitude else { return false }
        return !(lat == 0 && lon == 0) &&
               lat >= -90 && lat <= 90 &&
               lon >= -180 && lon <= 180
    }
}

/// CourseEditorView の状態管理 ViewModel
@MainActor
@Observable
final class CourseEditorViewModel {

    // MARK: - 編集モード

    enum Mode {
        case create
        case edit(courseId: UUID)
    }

    // MARK: - 編集中フィールド

    var title: String = ""
    var summary: String = ""
    var recognitionRadiusMeters: Double = 150
    var isEnabled: Bool = true
    var categories: [CourseCategory] = [.userCreated]
    var coverImage: UIImage?
    var localCoverImagePath: String?
    var coverImageUrl: String?
    var spots: [EditingSpot] = []

    // MARK: - UI 状態

    var isSaving: Bool = false
    var saveError: String?
    var showSpotEditor: Bool = false
    var editingSpot: EditingSpot?
    var editingSpotIndex: Int?

    // MARK: - 内部状態

    /// CourseEditorView からモードを参照できるように internal に公開
    /// 新規作成保存後に .edit へ遷移するため var にしている
    private(set) var mode: Mode
    private let repo: CourseRepository
    private var originalCourse: Course?

    /// 保存に成功したかどうか（画面を閉じるトリガー）
    var didSave: Bool = false
    /// 新規作成時に保存したコースID（edit モード遷移用）
    private(set) var savedCourseId: UUID?

    // MARK: - 初期化

    init(mode: Mode, repo: CourseRepository = AppContainer.shared.courseRepo) {
        self.mode = mode
        self.repo = repo
    }

    // MARK: - 読み込み

    func loadIfNeeded() {
        guard case .edit(let courseId) = mode else { return }
        guard originalCourse == nil else { return }
        do {
            guard let course = try repo.fetch(id: courseId) else { return }
            originalCourse = course
            title = course.title
            summary = course.summary ?? ""
            recognitionRadiusMeters = course.recognitionRadiusMeters
            isEnabled = course.isEnabled
            categories = course.categories
            localCoverImagePath = course.localCoverImagePath
            coverImageUrl = course.coverImageUrl
            if let path = course.localCoverImagePath {
                coverImage = LocalImageStorage.shared.load(from: path)
            }
            // スポット一覧をフラット化
            spots = course.spots.map { Self.makeEditingSpot(from: $0) }
        } catch {
            Logger.error("コース読み込み失敗: \(error)")
        }
    }

    // MARK: - 変更検知

    var hasChanges: Bool {
        guard !didSave else { return false }
        if case .create = mode {
            return !title.isEmpty || !spots.isEmpty || coverImage != nil
        }
        guard let original = originalCourse else { return false }
        return title != original.title ||
               summary != (original.summary ?? "") ||
               recognitionRadiusMeters != original.recognitionRadiusMeters ||
               spots.count != original.spots.count ||
               coverImage != nil
    }

    // MARK: - 保存

    func save() async {
        guard !title.isEmpty else { return }
        isSaving = true
        saveError = nil
        defer { isSaving = false }

        do {
            // カバー画像を保存
            var savedCoverPath: String? = localCoverImagePath
            if let newImage = coverImage, localCoverImagePath == nil || isNewCoverImage {
                let imageId = UUID().uuidString
                savedCoverPath = try LocalImageStorage.shared.save(newImage, id: imageId)
            }

            // スポットを CourseSpot に変換
            let builtSpots = try buildSpots(savedCoverPath: savedCoverPath)

            // Course ドメインモデルを組み立て
            let course = buildCourse(spots: builtSpots, coverPath: savedCoverPath)
            // 新規作成時は保存後に edit モードへ遷移できるよう ID を保持
            if case .create = mode { savedCourseId = course.id }
            try repo.save(course)
            NotificationCenter.default.post(name: .courseChanged, object: nil)
            // 新規作成 or 有効化済みコースの保存時は NEW バッジ・タブアニメーションを発火
            let isNewCourse = { if case .create = mode { return true }; return false }()
            if isNewCourse && course.isEnabled {
                NotificationCenter.default.post(name: .courseEnabled, object: course.id)
            }
            didSave = true
        } catch {
            saveError = error.localizedDescription
            Logger.error("コース保存失敗: \(error)")
        }
    }

    // MARK: - Private

    private var isNewCoverImage: Bool {
        // カバー画像が新規選択された場合は true
        // localCoverImagePath がある場合でも coverImage が変わっていれば再保存
        guard let path = localCoverImagePath else { return coverImage != nil }
        let existing = LocalImageStorage.shared.load(from: path)
        return existing == nil
    }

    /// CourseSpot → EditingSpot 変換（loadIfNeeded / reloadOriginalData で共用）
    private static func makeEditingSpot(from spot: CourseSpot) -> EditingSpot {
        EditingSpot(
            id: spot.id,
            existingId: spot.id,
            name: spot.name,
            address: spot.address,
            latitude: spot.latitude == 0 ? nil : spot.latitude,
            longitude: spot.longitude == 0 ? nil : spot.longitude,
            spotDescription: spot.spotDescription,
            coverImage: spot.localCoverImagePath.flatMap { LocalImageStorage.shared.load(from: $0) },
            localCoverImagePath: spot.localCoverImagePath,
            coverImageUrl: spot.coverImageUrl,
            useCustomRadius: spot.recognitionRadiusMeters != nil,
            customRadius: spot.recognitionRadiusMeters ?? 150
        )
    }

    private func buildSpots(savedCoverPath: String?) throws -> [CourseSpot] {
        var result: [CourseSpot] = []
        for (index, editingSpot) in spots.enumerated() {
            // スポット画像を保存
            var spotImagePath: String? = editingSpot.localCoverImagePath
            if let img = editingSpot.coverImage,
               editingSpot.localCoverImagePath == nil {
                let spotImgId = UUID().uuidString
                spotImagePath = try LocalImageStorage.shared.save(img, id: spotImgId)
            }

            let spotId = generateSpotId(index: index)
            let spot = CourseSpot(
                id: editingSpot.existingId ?? UUID(),
                spotId: spotId,
                name: editingSpot.name,
                address: editingSpot.address,
                latitude: editingSpot.latitude ?? 0,
                longitude: editingSpot.longitude ?? 0,
                spotDescription: editingSpot.spotDescription,
                coverImageUrl: editingSpot.coverImageUrl,
                imageCredit: nil,
                localCoverImagePath: spotImagePath,
                orderIndex: index,
                recognitionRadiusMeters: editingSpot.useCustomRadius ? editingSpot.customRadius : nil,
                firstCheckedInAt: nil,
                visitIds: []
            )
            result.append(spot)
        }
        return result
    }

    private func buildCourse(spots: [CourseSpot], coverPath: String?) -> Course {
        let now = Date()
        let courseId: UUID
        let version: Int
        let createdAt: Date

        switch mode {
        case .create:
            courseId = UUID()
            version = 1
            createdAt = now
        case .edit:
            courseId = originalCourse?.id ?? UUID()
            version = (originalCourse?.version ?? 0) + 1
            createdAt = originalCourse?.createdAt ?? now
        }

        // v1はセクションなしのスポット直下構造
        let section = CourseSection(
            id: courseId,
            sectionId: nil,
            name: "",
            sectionDescription: nil,
            orderIndex: 0,
            coverImageUrl: nil,
            spots: spots
        )

        return Course(
            id: courseId,
            courseType: .myList,
            title: title,
            summary: summary.isEmpty ? nil : summary,
            source: .user,
            isUserCreated: true,
            version: version,
            recognitionRadiusMeters: recognitionRadiusMeters,
            everEnabled: originalCourse?.everEnabled ?? false,
            isEnabled: isEnabled,
            allowRetroactive: originalCourse?.allowRetroactive ?? true,
            detailUrl: nil,
            coverImageUrl: coverImageUrl,
            imageCredit: nil,
            localCoverImagePath: coverPath,
            createdAt: createdAt,
            updatedAt: now,
            categories: categories.isEmpty ? [.userCreated] : categories,
            sections: [section]
        )
    }

    private func generateSpotId(index: Int) -> String {
        "user-\(String(format: "%03d", index + 1))"
    }

    // MARK: - 編集キャンセル / 保存後リセット

    /// 編集をキャンセルし、元のコースデータに戻す
    func reloadOriginalData() {
        guard case .edit = mode, let original = originalCourse else { return }
        title = original.title
        summary = original.summary ?? ""
        recognitionRadiusMeters = original.recognitionRadiusMeters
        isEnabled = original.isEnabled
        categories = original.categories
        localCoverImagePath = original.localCoverImagePath
        coverImageUrl = original.coverImageUrl
        coverImage = original.localCoverImagePath.flatMap { LocalImageStorage.shared.load(from: $0) }
        spots = original.spots.map { Self.makeEditingSpot(from: $0) }
    }

    /// 保存後に didSave をリセットし、次回編集の差分検知を正常化する（edit モード用）
    func resetAfterSave() {
        didSave = false
        guard case .edit(let courseId) = mode else { return }
        do {
            originalCourse = try repo.fetch(id: courseId)
        } catch {
            Logger.error("コース再読み込み失敗: \(error)")
        }
    }

    /// 新規作成保存後に edit モードへ遷移し、閲覧モードで表示できるようにする
    func resetAfterCreateSave() {
        guard let id = savedCourseId else { return }
        didSave = false
        mode = .edit(courseId: id)
        do {
            originalCourse = try repo.fetch(id: id)
        } catch {
            Logger.error("作成後のコース再読み込み失敗: \(error)")
        }
    }

    // MARK: - スポット操作

    func addSpot(_ spot: EditingSpot) {
        var s = spot
        if s.existingId == nil { s.existingId = s.id }
        spots.append(s)
    }

    func updateSpot(_ spot: EditingSpot, at index: Int) {
        guard spots.indices.contains(index) else { return }
        spots[index] = spot
    }

    func moveSpot(from source: IndexSet, to destination: Int) {
        spots.move(fromOffsets: source, toOffset: destination)
    }

    func deleteSpot(at offsets: IndexSet) {
        spots.remove(atOffsets: offsets)
    }
}
