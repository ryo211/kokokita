//
//  ImageStore.swift
//  kokokita
//
//  Created by 橋本遼 on 2025/10/07.
//

// Shared/Media/ImageStore.swift
import UIKit

enum ImageStore {
    private static var dir: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        var url = base.appendingPathComponent("Photos", isDirectory: true)
        if !FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
        return url
    }

    @discardableResult
    static func save(_ image: UIImage, quality: CGFloat = 0.9) throws -> String {
        let name = UUID().uuidString + ".jpg"
        var url = dir.appendingPathComponent(name)
        guard let data = image.jpegData(compressionQuality: quality) else {
            throw NSError(domain: "ImageStore", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "JPEGエンコードに失敗"])
        }
        try data.write(to: url, options: .atomic)
        // バックアップ除外（任意）
        var rv = URLResourceValues(); rv.isExcludedFromBackup = true
        try? url.setResourceValues(rv)
        return name
    }

    static func load(_ relativePath: String) -> UIImage? {
        let url = dir.appendingPathComponent(relativePath)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    static func delete(_ relativePath: String) {
        let url = dir.appendingPathComponent(relativePath)
        try? FileManager.default.removeItem(at: url)
    }

    static func fileURL(_ relativePath: String) -> URL {
        dir.appendingPathComponent(relativePath)
    }
}
