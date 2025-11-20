import Foundation
import UIKit
import ZIPFoundation

/// データリストアサービス
actor DataRestoreService {
    private let repo: CoreDataVisitRepository

    init(repo: CoreDataVisitRepository) {
        self.repo = repo
    }

    /// ZIPファイルからデータをリストア
    func restore(from zipURL: URL) async throws {
        // 1. ZIPを解凍
        let extractedDir = try await extractZIP(zipURL)

        defer {
            // 一時ディレクトリを削除
            try? FileManager.default.removeItem(at: extractedDir)
        }

        // 2. バックアップデータのルートディレクトリを見つける
        // ZIP内にディレクトリが含まれている場合があるため
        let backupRootDir = try findBackupRoot(in: extractedDir)

        // 3. manifest.jsonを読み込んで検証
        let manifestURL = backupRootDir.appendingPathComponent("manifest.json")
        guard FileManager.default.fileExists(atPath: manifestURL.path) else {
            throw RestoreError.invalidBackupFile("manifest.jsonが見つかりません")
        }

        let manifestData = try Data(contentsOf: manifestURL)
        let manifest = try JSONDecoder().decode(BackupManifest.self, from: manifestData)

        // バージョンチェック（必要に応じて）
        guard manifest.version == "1.0" else {
            throw RestoreError.unsupportedVersion(manifest.version)
        }

        // 4. JSONファイルを読み込み
        let backupData = try loadBackupData(from: backupRootDir)

        // 5. 写真ファイルを復元
        try await restorePhotos(from: backupRootDir)

        // 6. データをインポート
        try await importData(backupData)

        Logger.info("Restore completed: \(backupData.visits.count) visits restored")
    }

    // MARK: - Backup Root Discovery

    private func findBackupRoot(in directory: URL) throws -> URL {
        // まず、直接manifest.jsonがあるかチェック
        let directManifest = directory.appendingPathComponent("manifest.json")
        if FileManager.default.fileExists(atPath: directManifest.path) {
            return directory
        }

        // なければ、サブディレクトリを探す
        let contents = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )

        // 最初のディレクトリを見つける
        for item in contents {
            var isDirectory: ObjCBool = false
            if FileManager.default.fileExists(atPath: item.path, isDirectory: &isDirectory),
               isDirectory.boolValue {
                let manifestInSubdir = item.appendingPathComponent("manifest.json")
                if FileManager.default.fileExists(atPath: manifestInSubdir.path) {
                    return item
                }
            }
        }

        throw RestoreError.invalidBackupFile("バックアップデータが見つかりません")
    }

    // MARK: - ZIP Extraction

    private func extractZIP(_ zipURL: URL) async throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let extractDir = tempDir.appendingPathComponent(UUID().uuidString)

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            do {
                let coordinator = NSFileCoordinator()
                var error: NSError?

                // セキュリティスコープ付きアクセス開始
                let accessing = zipURL.startAccessingSecurityScopedResource()
                defer {
                    if accessing {
                        zipURL.stopAccessingSecurityScopedResource()
                    }
                }

                coordinator.coordinate(readingItemAt: zipURL, options: [], error: &error) { url in
                    do {
                        try FileManager.default.createDirectory(at: extractDir, withIntermediateDirectories: true)

                        // ZIPファイルを解凍
                        try FileManager.default.unzipItem(at: url, to: extractDir)
                        continuation.resume()
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }

                if let error = error {
                    continuation.resume(throwing: error)
                }
            }
        }

        return extractDir
    }

    // MARK: - Load Backup Data

    private func loadBackupData(from directory: URL) throws -> BackupData {
        // visits.json
        let visitsURL = directory.appendingPathComponent("visits.json")
        let visitsData = try Data(contentsOf: visitsURL)
        let visits = try decodeWithFallback([BackupVisit].self, from: visitsData)

        // labels.json
        let labelsURL = directory.appendingPathComponent("labels.json")
        let labelsData = try Data(contentsOf: labelsURL)
        let labels = try decodeWithFallback([BackupLabel].self, from: labelsData)

        // groups.json
        let groupsURL = directory.appendingPathComponent("groups.json")
        let groupsData = try Data(contentsOf: groupsURL)
        let groups = try decodeWithFallback([BackupGroup].self, from: groupsData)

        // members.json
        let membersURL = directory.appendingPathComponent("members.json")
        let membersData = try Data(contentsOf: membersURL)
        let members = try decodeWithFallback([BackupMember].self, from: membersData)

        return BackupData(
            visits: visits,
            labels: labels,
            groups: groups,
            members: members
        )
    }

    /// 複数のデコード戦略を試して互換性を保つ
    private func decodeWithFallback<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        // まずISO8601を試す（新しいフォーマット）
        let iso8601Decoder = JSONDecoder()
        iso8601Decoder.dateDecodingStrategy = .iso8601

        if let result = try? iso8601Decoder.decode(type, from: data) {
            return result
        }

        // 次にデフォルト（タイムスタンプ）を試す（古いフォーマット）
        let defaultDecoder = JSONDecoder()
        if let result = try? defaultDecoder.decode(type, from: data) {
            return result
        }

        // どちらも失敗した場合は詳細なエラーを投げる
        throw RestoreError.invalidBackupFile("JSONデータのデコードに失敗しました")
    }

    // MARK: - Restore Photos

    private func restorePhotos(from directory: URL) async throws {
        let photosDir = directory.appendingPathComponent("photos")

        guard FileManager.default.fileExists(atPath: photosDir.path) else {
            // 写真がない場合はスキップ
            Logger.info("No photos directory found in backup, skipping photo restore")
            return
        }

        // ImageStoreと同じディレクトリを使用
        let appSupportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let destinationPhotosDir = appSupportDir.appendingPathComponent(AppConfig.photoDirectoryName, isDirectory: true)

        // photosディレクトリが存在しない場合は作成
        if !FileManager.default.fileExists(atPath: destinationPhotosDir.path) {
            try FileManager.default.createDirectory(at: destinationPhotosDir, withIntermediateDirectories: true)
            Logger.info("Created photos directory at: \(destinationPhotosDir.path)")
        }

        // photosディレクトリ内のすべてのファイルをコピー
        let photoFiles = try FileManager.default.contentsOfDirectory(
            at: photosDir,
            includingPropertiesForKeys: nil
        )

        for photoURL in photoFiles {
            let filename = photoURL.lastPathComponent
            let destinationURL = destinationPhotosDir.appendingPathComponent(filename)

            // 既存ファイルがあれば削除
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }

            try FileManager.default.copyItem(at: photoURL, to: destinationURL)
            Logger.debug("Restored photo: \(filename)")
        }

        Logger.info("Restored \(photoFiles.count) photo files to \(destinationPhotosDir.path)")
    }

    // MARK: - Import Data

    private func importData(_ backupData: BackupData) async throws {
        // Labels（空の名前はスキップ）バッチ処理で作成
        var importedLabels = 0
        for label in backupData.labels {
            guard !label.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                Logger.warning("Skipping label with empty name: \(label.id)")
                continue
            }
            try repo.createLabel(id: label.id, name: label.name, saveImmediately: false)
            importedLabels += 1
        }
        Logger.info("Created \(importedLabels) labels (skipped \(backupData.labels.count - importedLabels))")

        // Groups（空の名前はスキップ）バッチ処理で作成
        var importedGroups = 0
        for group in backupData.groups {
            guard !group.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                Logger.warning("Skipping group with empty name: \(group.id)")
                continue
            }
            try repo.createGroup(id: group.id, name: group.name, saveImmediately: false)
            importedGroups += 1
        }
        Logger.info("Created \(importedGroups) groups (skipped \(backupData.groups.count - importedGroups))")

        // Members（空の名前はスキップ）バッチ処理で作成
        var importedMembers = 0
        for member in backupData.members {
            guard !member.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                Logger.warning("Skipping member with empty name: \(member.id)")
                continue
            }
            try repo.createMember(id: member.id, name: member.name, saveImmediately: false)
            importedMembers += 1
        }
        Logger.info("Created \(importedMembers) members (skipped \(backupData.members.count - importedMembers))")

        // 一括保存してコンテキストをリフレッシュ（一時ObjectIDを永続IDに変換）
        try repo.refreshContext()
        Logger.info("Saved and refreshed all taxonomy entities")

        // Visits（エラーが発生しても続行、バッチ処理で保存）
        var successCount = 0
        var failureCount = 0
        let batchSize = 50 // 50件ごとに保存

        for (index, backupVisit) in backupData.visits.enumerated() {
            do {
                let visit = Visit(
                    id: backupVisit.id,
                    timestampUTC: backupVisit.timestampUTC,
                    latitude: backupVisit.latitude,
                    longitude: backupVisit.longitude,
                    horizontalAccuracy: backupVisit.horizontalAccuracy,
                    isSimulatedBySoftware: backupVisit.isSimulatedBySoftware,
                    isProducedByAccessory: backupVisit.isProducedByAccessory,
                    integrity: Visit.Integrity(
                        algo: backupVisit.integrityAlgo,
                        signatureDERBase64: backupVisit.integritySigDER,
                        publicKeyRawBase64: backupVisit.integrityPubRaw,
                        payloadHashHex: backupVisit.integrityPayloadHash,
                        createdAtUTC: backupVisit.integrityCreatedAtUTC
                    )
                )

                let details = VisitDetails(
                    title: backupVisit.title,
                    facilityName: backupVisit.facilityName,
                    facilityAddress: backupVisit.facilityAddress,
                    facilityCategory: backupVisit.facilityCategory,
                    comment: backupVisit.comment,
                    labelIds: backupVisit.labelIds,
                    groupId: backupVisit.groupId,
                    memberIds: backupVisit.memberIds,
                    resolvedAddress: backupVisit.resolvedAddress,
                    photoPaths: backupVisit.photoPaths
                )

                // バッチ処理：最後以外は保存しない
                let isLastInBatch = (index + 1) % batchSize == 0 || (index + 1) == backupData.visits.count
                try repo.create(visit: visit, details: details, saveImmediately: isLastInBatch)
                successCount += 1

                // バッチごとにログ出力
                if isLastInBatch {
                    Logger.info("Imported \(index + 1)/\(backupData.visits.count) visits...")
                }
            } catch {
                failureCount += 1
                Logger.error("Failed to import visit \(backupVisit.id): \(error.localizedDescription)")
                Logger.error("Visit details - title: \(backupVisit.title ?? "nil"), labelIds: \(backupVisit.labelIds), groupId: \(backupVisit.groupId?.uuidString ?? "nil")")
                // エラーが発生した場合は、現在のバッチを保存して続行
                if failureCount % 5 == 0 {
                    try? repo.refreshContext()
                }
            }
        }

        Logger.info("Imported \(successCount)/\(backupData.visits.count) visits (failed: \(failureCount))")

        // 通知を送信
        await MainActor.run {
            NotificationCenter.default.post(name: .visitsChanged, object: nil)
            NotificationCenter.default.post(name: .taxonomyChanged, object: nil)
        }
    }
}

// MARK: - Errors

enum RestoreError: LocalizedError {
    case invalidBackupFile(String)
    case unsupportedVersion(String)

    var errorDescription: String? {
        switch self {
        case .invalidBackupFile(let message):
            return "バックアップファイルが不正です: \(message)"
        case .unsupportedVersion(let version):
            return "サポートされていないバージョンです: \(version)"
        }
    }
}

// MARK: - FileManager Extension

extension FileManager {
    /// ZIPファイルを解凍する（ZIPFoundation使用）
    func unzipItem(at sourceURL: URL, to destinationURL: URL) throws {
        guard let archive = Archive(url: sourceURL, accessMode: .read) else {
            throw RestoreError.invalidBackupFile("ZIPファイルを開けません")
        }

        for entry in archive {
            let destinationEntryURL = destinationURL.appendingPathComponent(entry.path)

            if entry.type == .directory {
                try createDirectory(at: destinationEntryURL, withIntermediateDirectories: true)
            } else {
                let parentDirectory = destinationEntryURL.deletingLastPathComponent()
                try createDirectory(at: parentDirectory, withIntermediateDirectories: true)

                _ = try archive.extract(entry, to: destinationEntryURL)
            }
        }
    }
}
