import UIKit
import CoreLocation
import Observation

/// 自動記録ON/OFF操作の共通ハンドラ
/// HomeScreenの新設ボタン・SettingsSheetのトグル、どちらの入口からも同じインスタンス化パターンで使う
/// （永続状態は AutoRecordSettings.shared に一元化されているため、画面ごとに個別インスタンスを持ってよい）
///
/// 自動記録はAlways許可がなければ実際には機能しないため、`isEnabled`はAlways許可が
/// 確定した場合にのみtrueにする（When In Useのままでは有効化しない）
@MainActor
@Observable
final class AutoRecordToggleEffects {
    /// 初回説明シート（AutoRecordIntroSheet）の表示状態
    var showIntroSheet = false
    /// 「常に許可」への案内アラートの表示状態（許可が得られなかった/昇格ダイアログが出せない場合）
    var showSettingsGuidance = false

    private let settings: AutoRecordSettings
    private let service: AutoRecordService

    init(
        settings: AutoRecordSettings = .shared,
        service: AutoRecordService = AppContainer.shared.autoRecord
    ) {
        self.settings = settings
        self.service = service
    }

    /// ON操作の共通入口
    func handleToggleOn() {
        if settings.hasSeenIntro {
            Task { await proceedWithAlwaysAuthorization() }
        } else {
            // 許可リクエストは説明シートを閉じてから行う
            showIntroSheet = true
        }
    }

    func handleToggleOff() {
        settings.isEnabled = false
        service.stopMonitoring()
    }

    /// AutoRecordIntroSheet の閉じるアクションから呼ぶ
    func introSheetDismissed() {
        settings.hasSeenIntro = true
        showIntroSheet = false
        Task { await proceedWithAlwaysAuthorization() }
    }

    /// 設定案内アラートの「設定を開く」アクションから呼ぶ
    func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    // MARK: - Private

    /// 現在の許可状態に応じてAlways許可を確定させ、確定した場合のみ isEnabled を true にする
    private func proceedWithAlwaysAuthorization() async {
        let currentStatus = service.authorizationStatus

        // 既にAlways許可済みならそのまま有効化
        if currentStatus == .authorizedAlways {
            settings.isEnabled = true
            service.startMonitoring()
            return
        }

        // 拒否/制限されている、または既に昇格ダイアログに回答済み（iOSは二度と出さない）の場合は
        // OSに問い合わせず直接、設定アプリへの案内を出す
        if currentStatus == .denied
            || currentStatus == .restricted
            || (currentStatus == .authorizedWhenInUse && settings.hasAttemptedAlwaysUpgrade) {
            settings.isEnabled = false
            showSettingsGuidance = true
            return
        }

        let finalStatus = await service.requestAlwaysAuthorizationAndAwaitResult()
        if finalStatus == .authorizedAlways {
            settings.isEnabled = true
            service.startMonitoring()
        } else {
            settings.isEnabled = false
            showSettingsGuidance = true
        }
    }
}
