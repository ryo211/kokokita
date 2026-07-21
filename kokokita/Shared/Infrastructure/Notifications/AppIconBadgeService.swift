import Foundation
import UserNotifications

/// アプリアイコンのバッジ件数を管理するサービス
final class AppIconBadgeService {
    static let shared = AppIconBadgeService()

    private let notificationCenter: UNUserNotificationCenter

    init(notificationCenter: UNUserNotificationCenter = .current()) {
        self.notificationCenter = notificationCenter
    }

    /// 自動記録候補の pending 件数を読み取り、アプリアイコンのバッジへ反映する。
    func syncAutoRecordCandidateCount(candidateRepo: VisitCandidateRepository = AppContainer.shared.candidateRepo) {
        do {
            let count = try candidateRepo.countPending()
            setBadgeCount(count)
        } catch {
            Logger.error("自動記録候補のバッジ件数取得に失敗しました", error: error)
        }
    }

    /// バッジ件数を直接反映する。0件の場合は権限要求せずクリアだけ行う。
    func setBadgeCount(_ count: Int) {
        let badgeCount = max(0, count)
        Task {
            if badgeCount > 0 {
                let canSetBadge = await ensureBadgeAuthorization()
                guard canSetBadge else {
                    Logger.info("アプリアイコンバッジが許可されていないため、件数を表示できません")
                    return
                }
            }

            do {
                try await setSystemBadgeCount(badgeCount)
                Logger.debug("アプリアイコンバッジを更新しました: \(badgeCount)")
            } catch {
                Logger.error("アプリアイコンバッジの更新に失敗しました", error: error)
            }
        }
    }

    private func ensureBadgeAuthorization() async -> Bool {
        let settings = await notificationCenter.notificationSettings()

        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return settings.badgeSetting == .enabled
        case .notDetermined:
            do {
                return try await notificationCenter.requestAuthorization(options: [.badge])
            } catch {
                Logger.error("アプリアイコンバッジ権限の要求に失敗しました", error: error)
                return false
            }
        case .denied:
            return false
        @unknown default:
            return false
        }
    }

    private func setSystemBadgeCount(_ count: Int) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            notificationCenter.setBadgeCount(count) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }
}
