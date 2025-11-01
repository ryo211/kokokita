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
        var url = base.appendingPathComponent(AppConfig.photoDirectoryName, isDirectory: true)
        if !FileManager.default.fileExists(atPath: url.path) {
            do {
                try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            } catch {
                Logger.error("Failed to create Photos directory", error: error)
            }
        }
        return url
    }

    @discardableResult
    static func save(_ image: UIImage, quality: CGFloat = AppConfig.imageCompressionQuality) throws -> String {
        let name = UUID().uuidString + ".jpg"
        var url = dir.appendingPathComponent(name)
        guard let data = image.jpegData(compressionQuality: quality) else {
            Logger.error("Failed to encode image as JPEG")
            throw NSError(domain: "ImageStore", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "JPEGエンコードに失敗"])
        }
        do {
            try data.write(to: url, options: .atomic)
            Logger.debug("Image saved successfully: \(name)")
        } catch {
            Logger.error("Failed to write image file: \(name)", error: error)
            throw error
        }
        // バックアップ除外（任意）
        var rv = URLResourceValues(); rv.isExcludedFromBackup = true
        do {
            try url.setResourceValues(rv)
        } catch {
            Logger.warning("Failed to exclude image from backup: \(name)")
        }
        return name
    }

    static func load(_ relativePath: String) -> UIImage? {
        let url = dir.appendingPathComponent(relativePath)
        guard let data = try? Data(contentsOf: url) else {
            Logger.warning("Failed to load image: \(relativePath)")
            return nil
        }
        guard let image = UIImage(data: data) else {
            Logger.warning("Failed to decode image data: \(relativePath)")
            return nil
        }
        return image
    }

    static func delete(_ relativePath: String) {
        let url = dir.appendingPathComponent(relativePath)
        do {
            try FileManager.default.removeItem(at: url)
            Logger.debug("Image deleted: \(relativePath)")
        } catch {
            Logger.error("Failed to delete image: \(relativePath)", error: error)
        }
    }

    static func fileURL(_ relativePath: String) -> URL {
        dir.appendingPathComponent(relativePath)
    }
}
