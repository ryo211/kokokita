import Foundation
import Observation

/// オンボーディングのページ
enum OnboardingPage: Int, CaseIterable, Hashable {
    /// ページ1: 聖地巡礼モードの紹介
    case pilgrimage
    /// ページ2: 記録モードの紹介
    case record
    /// ページ3: 位置情報の許可
    case location

    var next: OnboardingPage? { OnboardingPage(rawValue: rawValue + 1) }
}

/// オンボーディング画面の状態管理
/// - 表示中に裏でコースの初期同期を進め、ページ3のボタンは同期完了（または上限時間経過）まで無効にする
/// - 位置情報の許可は、ユーザーがダイアログに回答するまで待ってから完了を通知する
@MainActor
@Observable
final class OnboardingStore {
    /// 準備処理（コース初期同期）を待つ上限時間。回線が遅い場合でもこれ以上は待たせない
    /// （コース画面側に読み込み中表示があり、同期完了は通知で反映されるため、待たずに進んでも問題ない）
    static let preparationTimeout: Duration = .seconds(10)

    var currentPage: OnboardingPage
    /// 準備処理中か。true の間はページ3のボタンを無効にして小さな ProgressView を出す
    private(set) var isPreparing = true
    /// 位置情報の許可ダイアログへの回答待ちか（ボタンの二重タップ防止）
    private(set) var isRequestingPermission = false

    private var hasStartedPreparation = false
    private let syncCourses: () async -> Void
    private let requestLocationPermission: () async -> Bool

    init(
        initialPage: OnboardingPage = .pilgrimage,
        syncCourses: @escaping () async -> Void,
        requestLocationPermission: @escaping () async -> Bool
    ) {
        self.currentPage = initialPage
        self.syncCourses = syncCourses
        self.requestLocationPermission = requestLocationPermission
    }

    /// 実アプリ用の依存関係で生成する
    static func live() -> OnboardingStore {
        let container = AppContainer.shared
        return OnboardingStore(
            syncCourses: { _ = await container.courseAutoSyncService.sync() },
            requestLocationPermission: { await container.loc.requestWhenInUsePermissionAndWait() }
        )
    }

    /// 画面表示時に呼ぶ。コース同期を開始し、完了か上限時間経過の早い方で準備完了とする
    /// 同期自体はタイムアウト後もキャンセルせず最後まで進める（途中で止めるとダウンロードが中断されるため）
    func startPreparation() {
        guard !hasStartedPreparation else { return }
        hasStartedPreparation = true

        Task {
            await syncCourses()
            finishPreparation()
        }
        Task {
            try? await Task.sleep(for: Self.preparationTimeout)
            finishPreparation()
        }
    }

    /// 「つぎへ」: 次のページへ進む
    func goToNextPage() {
        guard let next = currentPage.next else { return }
        currentPage = next
    }

    /// 「位置情報を許可する」: 許可ダイアログを出し、回答（許可・拒否どちらでも）を待ってから onFinish を呼ぶ
    func requestPermissionAndFinish(onFinish: @escaping () -> Void) {
        guard !isPreparing, !isRequestingPermission else { return }
        isRequestingPermission = true
        Task {
            _ = await requestLocationPermission()
            isRequestingPermission = false
            onFinish()
        }
    }

    private func finishPreparation() {
        guard isPreparing else { return }
        isPreparing = false
    }
}

// MARK: - Preview用

extension OnboardingStore {
    /// AppContainer に依存しないプレビュー用のストア（準備処理は即完了）
    static func preview(initialPage: OnboardingPage = .pilgrimage) -> OnboardingStore {
        let store = OnboardingStore(
            initialPage: initialPage,
            syncCourses: {},
            requestLocationPermission: { true }
        )
        store.startPreparation()
        return store
    }
}
