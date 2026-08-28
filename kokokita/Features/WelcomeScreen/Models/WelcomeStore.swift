import Foundation
import Observation

/// ウェルカム画面の状態管理
/// コース初期同期の進捗を保持し、「はじめる」ボタンの活性化を制御する
@Observable
final class WelcomeStore {
    /// 0.0〜1.0。CourseAutoSyncService からのコールバックで更新
    var syncProgress: Double = 0
    var isSyncComplete: Bool = false

    private let autoSyncService: CourseAutoSyncService
    private let locationService: DefaultLocationService

    init(
        autoSyncService: CourseAutoSyncService = AppContainer.shared.courseAutoSyncService,
        locationService: DefaultLocationService = AppContainer.shared.loc
    ) {
        self.autoSyncService = autoSyncService
        self.locationService = locationService
    }

    /// 画面表示と同時に呼ぶ。完了を待たせない（fire-and-forget）
    func startInitialCourseSync() {
        guard !isSyncComplete else { return }
        Task {
            await autoSyncService.sync { [weak self] progress in
                self?.syncProgress = progress
            }
            isSyncComplete = true
        }
    }

    /// 「はじめる」タップ時: 結果を待たずに許可ダイアログを発火する
    func requestLocationPermission() {
        locationService.requestWhenInUsePermissionOnly()
    }
}
