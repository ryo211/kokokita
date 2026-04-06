import UIKit

/// コース・スポットのローカル画像を端末内に保存・読み込み・削除するユーティリティ
/// 保存先: Documents/course_images/{uuid}.jpg
final class LocalImageStorage {
    static let shared = LocalImageStorage()
    private init() {}

    private var baseURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("course_images", isDirectory: true)
    }

    // MARK: - 保存

    /// 画像を保存してパス文字列を返す
    /// - Parameters:
    ///   - image: 保存する UIImage
    ///   - id: ファイル識別子（UUID文字列等）
    /// - Returns: 保存先の絶対パス文字列
    func save(_ image: UIImage, id: String) throws -> String {
        let dir = baseURL
        if !FileManager.default.fileExists(atPath: dir.path) {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        let fileURL = dir.appendingPathComponent("\(id).jpg")
        guard let data = image.jpegData(compressionQuality: 0.8) else {
            throw LocalImageStorageError.encodeFailed
        }
        try data.write(to: fileURL, options: .atomic)
        return fileURL.path
    }

    // MARK: - 読み込み

    /// パスから画像を読み込む
    /// - Parameter path: 保存時に返されたパス文字列
    /// - Returns: UIImage（ファイルが存在しない場合は nil）
    func load(from path: String) -> UIImage? {
        UIImage(contentsOfFile: path)
    }

    // MARK: - 削除

    /// 指定パスの画像を削除する
    /// - Parameter path: 削除対象のパス文字列
    func delete(at path: String) throws {
        guard FileManager.default.fileExists(atPath: path) else { return }
        try FileManager.default.removeItem(atPath: path)
    }
}

enum LocalImageStorageError: Error {
    case encodeFailed
}
