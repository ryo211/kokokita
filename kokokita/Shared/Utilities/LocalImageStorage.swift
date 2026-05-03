import UIKit

/// コース・スポットのローカル画像を端末内に保存・読み込み・削除するユーティリティ
/// 保存先: Documents/course_images/{uuid}.jpg
///
/// ⚠️ CoreData には絶対パスではなく「ファイル名のみ」を保存すること。
/// iOSはビルド/再インストール時にDocumentsのプレフィックス（UUID部分）が変わるため、
/// 絶対パスを保存すると再起動後に画像が読み込めなくなる。
/// save() はファイル名のみを返し、load(from:) はファイル名または絶対パスの両方に対応する。
final class LocalImageStorage {
    static let shared = LocalImageStorage()
    private init() {}

    private var baseURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("course_images", isDirectory: true)
    }

    // MARK: - 保存

    /// 画像を保存してファイル名を返す（絶対パスではなくファイル名のみ）
    /// - Parameters:
    ///   - image: 保存する UIImage
    ///   - id: ファイル識別子（UUID文字列等）
    /// - Returns: ファイル名文字列（例: "abc123.jpg"）
    func save(_ image: UIImage, id: String) throws -> String {
        let dir = baseURL
        if !FileManager.default.fileExists(atPath: dir.path) {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        let fileName = "\(id).jpg"
        let fileURL = dir.appendingPathComponent(fileName)
        guard let data = image.jpegData(compressionQuality: 0.8) else {
            throw LocalImageStorageError.encodeFailed
        }
        try data.write(to: fileURL, options: .atomic)
        return fileName
    }

    // MARK: - 読み込み

    /// ファイル名または絶対パスから画像を読み込む
    /// - Parameter path: ファイル名（推奨）または絶対パス（後方互換）
    /// - Returns: UIImage（ファイルが存在しない場合は nil）
    func load(from path: String) -> UIImage? {
        // ファイル名のみの場合は baseURL から組み立てる
        if !path.contains("/") {
            let fileURL = baseURL.appendingPathComponent(path)
            return UIImage(contentsOfFile: fileURL.path)
        }
        // 絶対パスの場合はそのまま試みる（後方互換）
        // 絶対パスで失敗した場合はファイル名部分だけ取り出してリトライ
        if let image = UIImage(contentsOfFile: path) {
            return image
        }
        let fileName = (path as NSString).lastPathComponent
        let fileURL = baseURL.appendingPathComponent(fileName)
        return UIImage(contentsOfFile: fileURL.path)
    }

    // MARK: - 削除

    /// 指定ファイル名または絶対パスの画像を削除する
    func delete(at path: String) throws {
        let targetPath: String
        if !path.contains("/") {
            targetPath = baseURL.appendingPathComponent(path).path
        } else {
            targetPath = path
        }
        guard FileManager.default.fileExists(atPath: targetPath) else { return }
        try FileManager.default.removeItem(atPath: targetPath)
    }
}

enum LocalImageStorageError: Error {
    case encodeFailed
}
