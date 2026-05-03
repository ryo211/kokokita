import Foundation

// バンドルされた JSON ファイルからコースデータを読み込み、DB に取り込むサービス
final class CourseJSONService {
    private let repo: CourseRepository

    init(repo: CourseRepository) {
        self.repo = repo
    }

    // MARK: - インポート

    /// courses/index.json に列挙されたファイル名順に各コース JSON を読み込んで DB に取り込む
    /// - 既存 bundled コースは bundle 側の version が新しい場合のみ更新（チェックイン状態は保持）
    /// - downloaded / user コースは同一 ID でも bundle で上書きしない
    /// - sections 形式・spots 直下形式の両方をサポート
    func importBundledCoursesIfNeeded() throws {
        // courses/index.json からファイル名リスト（表示順）を取得
        // 実機では IPA バンドル内でリソースがフラット化される場合があるため
        // subdirectory あり → なし の順にフォールバック
        guard let indexUrl = bundleURL(resource: "index") else {
            Logger.warning("courses/index.json が見つかりません")
            return
        }
        let indexData = try Data(contentsOf: indexUrl)
        let fileNames = try JSONDecoder().decode([String].self, from: indexData)

        // index の順番通りに各コース JSON を読み込む
        let decoded: [CourseJSONParser.CourseJSON] = try fileNames.compactMap { name in
            guard let url = bundleURL(resource: name) else {
                Logger.warning("コース JSON が見つかりません: \(name).json")
                return nil
            }
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(CourseJSONParser.CourseJSON.self, from: data)
        }

        let coursesToSave = try decoded.compactMap { json -> Course? in
            let courseId = CourseJSONParser.uuidFromString(json.id)
            let existing = try repo.fetch(id: courseId)

            guard shouldImportBundledCourse(json: json, existing: existing) else {
                if let existing {
                    Logger.info("バンドルコース上書きをスキップ: \(existing.title) [source=\(existing.source.rawValue), local=\(existing.version), bundled=\(json.version)]")
                }
                return nil
            }

            return CourseJSONParser.buildCourse(from: json, existing: existing)
        }

        try repo.saveAll(coursesToSave)

        // index.json に存在しないバンドルコースのみ DB から削除
        // ダウンロードコース（source == .downloaded）はユーザーが取得したものなので削除しない
        let importedIds = Set(decoded.map { CourseJSONParser.uuidFromString($0.id) })
        let allCourses = try repo.fetchAll()
        let toDelete = allCourses.filter { $0.source == .bundled && !importedIds.contains($0.id) }
        for course in toDelete {
            try repo.delete(course.id)
            Logger.info("バンドルコース削除: \(course.title)")
        }

        Logger.info("バンドルコース取り込み完了: 保存 \(coursesToSave.count)件 / 削除 \(toDelete.count)件")
    }

    // MARK: - Private

    private func shouldImportBundledCourse(
        json: CourseJSONParser.CourseJSON,
        existing: Course?
    ) -> Bool {
        guard let existing else { return true }

        switch existing.source {
        case .downloaded, .user:
            return false
        case .bundled:
            return json.version > existing.version
        }
    }

    /// courses/ サブディレクトリ → バンドルルート の順で JSON URL を解決する。
    /// 実機では IPA のリソースがフラット化されてサブディレクトリが消えるため両方を試みる。
    private func bundleURL(resource name: String) -> URL? {
        Bundle.main.url(forResource: name, withExtension: "json", subdirectory: "courses")
            ?? Bundle.main.url(forResource: name, withExtension: "json")
    }
}
