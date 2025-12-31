import Foundation
import UIKit
import ZIPFoundation

/// データバックアップサービス
actor DataBackupService {
    private let repo: CoreDataVisitRepository

    init(repo: CoreDataVisitRepository) {
        self.repo = repo
    }

    /// バックアップを作成
    func createBackup() async throws -> BackupResult {
        // 1. 全データを取得
        let allData = try await collectAllData()

        // 2. JSON化
        let jsonData = try encodeToJSON(allData)

        // 3. 写真ファイルを収集
        let photoFiles = try await collectPhotoFiles(from: allData.visits)

        // 4. 一時ディレクトリにファイルを作成
        let tempDir = FileManager.default.temporaryDirectory
        let backupDir = tempDir.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: backupDir, withIntermediateDirectories: true)

        // JSONエンコーダーを設定
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601

        // manifest.json
        let manifestURL = backupDir.appendingPathComponent("manifest.json")
        let manifest = BackupManifest(
            version: "1.0",
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown",
            backupDate: ISO8601DateFormatter().string(from: Date()),
            visitCount: allData.visits.count,
            labelCount: allData.labels.count,
            groupCount: allData.groups.count,
            memberCount: allData.members.count,
            photoCount: photoFiles.count
        )
        try encoder.encode(manifest).write(to: manifestURL)

        // visits.json
        let visitsURL = backupDir.appendingPathComponent("visits.json")
        try encoder.encode(allData.visits).write(to: visitsURL)

        // labels.json
        let labelsURL = backupDir.appendingPathComponent("labels.json")
        try encoder.encode(allData.labels).write(to: labelsURL)

        // groups.json
        let groupsURL = backupDir.appendingPathComponent("groups.json")
        try encoder.encode(allData.groups).write(to: groupsURL)

        // members.json
        let membersURL = backupDir.appendingPathComponent("members.json")
        try encoder.encode(allData.members).write(to: membersURL)

        // 写真フォルダ
        if !photoFiles.isEmpty {
            let photosDir = backupDir.appendingPathComponent("photos")
            try FileManager.default.createDirectory(at: photosDir, withIntermediateDirectories: true)

            for (filename, imageData) in photoFiles {
                let photoURL = photosDir.appendingPathComponent(filename)
                try imageData.write(to: photoURL)
            }
        }

        // 5. ZIPに圧縮
        let timestamp = DateFormatter.backupTimestamp.string(from: Date())
        let zipFilename = "kokokita_backup_\(timestamp).zip"
        let zipURL = tempDir.appendingPathComponent(zipFilename)

        try await zipDirectory(at: backupDir, to: zipURL)

        // 6. 一時ディレクトリを削除
        try FileManager.default.removeItem(at: backupDir)

        // 7. ファイルサイズを取得
        let fileSize = try FileManager.default.attributesOfItem(atPath: zipURL.path)[.size] as? Int64 ?? 0

        return BackupResult(
            filename: zipFilename,
            fileURL: zipURL,
            fileSize: fileSize,
            visitCount: allData.visits.count
        )
    }

    // MARK: - Data Collection

    private func collectAllData() throws -> BackupData {
        // Visits - fetch all with no filters
        let visitAggregates = try repo.fetchAll(
            filterLabel: nil,
            filterGroup: nil,
            filterMember: nil,
            titleQuery: nil,
            dateFrom: nil,
            dateToExclusive: nil
        )
        let visits = visitAggregates.map { agg -> BackupVisit in
            let visit = agg.visit
            let details = agg.details
            return BackupVisit(
                id: visit.id,
                timestampUTC: visit.timestampUTC,
                latitude: visit.latitude,
                longitude: visit.longitude,
                horizontalAccuracy: visit.horizontalAccuracy,
                isSimulatedBySoftware: visit.isSimulatedBySoftware,
                isProducedByAccessory: visit.isProducedByAccessory,
                integrityAlgo: visit.integrity.algo,
                integritySigDER: visit.integrity.signatureDERBase64,
                integrityPubRaw: visit.integrity.publicKeyRawBase64,
                integrityPayloadHash: visit.integrity.payloadHashHex,
                integrityCreatedAtUTC: visit.integrity.createdAtUTC,
                title: details.title,
                facilityName: details.facilityName,
                facilityAddress: details.facilityAddress,
                facilityCategory: details.facilityCategory,
                comment: details.comment,
                labelIds: details.labelIds,
                groupId: details.groupId,
                memberIds: details.memberIds,
                resolvedAddress: details.resolvedAddress,
                photoPaths: details.photoPaths
            )
        }

        // Labels
        let labels = try repo.allLabels().map { label in
            BackupLabel(id: label.id, name: label.name)
        }

        // Groups
        let groups = try repo.allGroups().map { group in
            BackupGroup(id: group.id, name: group.name)
        }

        // Members
        let members = try repo.allMembers().map { member in
            BackupMember(id: member.id, name: member.name)
        }

        return BackupData(
            visits: visits,
            labels: labels,
            groups: groups,
            members: members
        )
    }

    private func encodeToJSON(_ data: BackupData) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(data)
    }

    private func collectPhotoFiles(from visits: [BackupVisit]) async throws -> [(filename: String, data: Data)] {
        var results: [(String, Data)] = []
        var missingCount = 0
        var collectedPaths = Set<String>() // 重複を防ぐ

        // ImageStoreと同じディレクトリを使用
        let appSupportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let photosDir = appSupportDir.appendingPathComponent(AppConfig.photoDirectoryName, isDirectory: true)

        Logger.info("Starting photo collection from \(visits.count) visits")
        Logger.info("Photos directory: \(photosDir.path)")

        // photosディレクトリの中身を確認
        if FileManager.default.fileExists(atPath: photosDir.path) {
            do {
                let photoContents = try FileManager.default.contentsOfDirectory(atPath: photosDir.path)
                Logger.info("Photos directory exists with \(photoContents.count) files")
            } catch {
                Logger.error("Failed to list directory contents: \(error)")
            }
        } else {
            Logger.warning("Photos directory does not exist at \(photosDir.path)")
        }

        for visit in visits {
            if !visit.photoPaths.isEmpty {
                Logger.debug("Visit \(visit.id) has \(visit.photoPaths.count) photos: \(visit.photoPaths)")
            }

            for photoPath in visit.photoPaths {
                // photoPathはファイル名のみ（例："ABC-123.jpg"）
                let photoURL = photosDir.appendingPathComponent(photoPath)

                if FileManager.default.fileExists(atPath: photoURL.path) {
                    do {
                        let data = try Data(contentsOf: photoURL)
                        let filename = photoURL.lastPathComponent

                        // 重複チェック
                        if !collectedPaths.contains(filename) {
                            results.append((filename, data))
                            collectedPaths.insert(filename)
                            Logger.debug("✓ Collected photo: \(photoPath) (\(data.count) bytes)")
                        }
                    } catch {
                        Logger.error("✗ Failed to read photo at \(photoPath): \(error.localizedDescription)")
                        missingCount += 1
                    }
                } else {
                    Logger.warning("✗ Photo file not found: \(photoPath) (full path: \(photoURL.path))")
                    missingCount += 1
                }
            }
        }

        Logger.info("Photo collection complete: \(results.count) collected, \(missingCount) missing")
        return results
    }

    // MARK: - ZIP Compression

    private func zipDirectory(at sourceURL: URL, to destinationURL: URL) async throws {
        // ZIPFoundationを使用してZIPを作成
        try FileManager.default.zipItem(at: sourceURL, to: destinationURL)
    }
}

// MARK: - Data Models

struct BackupData: Codable {
    let visits: [BackupVisit]
    let labels: [BackupLabel]
    let groups: [BackupGroup]
    let members: [BackupMember]
}

struct BackupManifest: Codable {
    let version: String
    let appVersion: String
    let backupDate: String
    let visitCount: Int
    let labelCount: Int
    let groupCount: Int
    let memberCount: Int
    let photoCount: Int
}

struct BackupVisit: Codable {
    let id: UUID
    let timestampUTC: Date
    let latitude: Double
    let longitude: Double
    let horizontalAccuracy: Double?
    let isSimulatedBySoftware: Bool?
    let isProducedByAccessory: Bool?

    // Integrity
    let integrityAlgo: String
    let integritySigDER: String
    let integrityPubRaw: String
    let integrityPayloadHash: String
    let integrityCreatedAtUTC: Date

    // Details
    let title: String?
    let facilityName: String?
    let facilityAddress: String?
    let facilityCategory: String?
    let comment: String?
    let labelIds: [UUID]
    let groupId: UUID?
    let memberIds: [UUID]
    let resolvedAddress: String?
    let photoPaths: [String]
}

struct BackupLabel: Codable {
    let id: UUID
    let name: String
}

struct BackupGroup: Codable {
    let id: UUID
    let name: String
}

struct BackupMember: Codable {
    let id: UUID
    let name: String
}

// MARK: - Helpers

extension DateFormatter {
    static let backupTimestamp: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        formatter.timeZone = TimeZone.current
        return formatter
    }()
}
