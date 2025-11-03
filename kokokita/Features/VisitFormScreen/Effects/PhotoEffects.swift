import UIKit
import Foundation
import Observation

/// 写真の追加・削除・ドラフト管理の副作用を担当
@MainActor
@Observable
final class PhotoEffects {

    // MARK: - State

    /// 表示用の写真パス（新規作成時）
    var photoPaths: [String] = []

    /// 編集用の一時コピー（編集モード時）
    var photoPathsEditing: [String] = []

    /// 保存済みフラグ
    var didSave: Bool = false

    // MARK: - Private State

    /// 編集開始時の元データ
    private var originalPhotoPaths: [String] = []

    /// セッション中に追加された画像
    private var pendingAdds: Set<String> = []

    /// 削除予約された既存画像
    private var pendingDeletes: Set<String> = []

    /// 編集モード中か
    private var isEditing: Bool = false

    // MARK: - Initialization

    init() {}

    // MARK: - Load/Reset

    /// 新規作成モード用の初期化
    func resetForCreate() {
        photoPaths = []
        photoPathsEditing = []
        originalPhotoPaths = []
        pendingAdds.removeAll()
        pendingDeletes.removeAll()
        didSave = false
        isEditing = false
    }

    /// 既存データの編集モード用の初期化
    func loadForEdit(_ paths: [String]) {
        photoPaths = paths
        photoPathsEditing = paths
        originalPhotoPaths = paths
        pendingAdds.removeAll()
        pendingDeletes.removeAll()
        didSave = false
        isEditing = true
    }

    // MARK: - Add Photos (Side Effect)

    /// 写真を追加する
    func addPhotos(_ images: [UIImage]) {
        let current = photoPathsEditing
        let remain = max(0, AppConfig.maxPhotosPerVisit - current.count)
        guard remain > 0 else { return }
        let picked = images.prefix(remain)

        for ui in picked {
            if let saved = try? ImageStore.save(ui) {
                photoPathsEditing.append(saved)
                if isEditing && !originalPhotoPaths.contains(saved) {
                    pendingAdds.insert(saved)  // キャンセル時に掃除
                }
            }
        }
    }

    // MARK: - Remove Photo (Side Effect)

    /// 写真を削除する
    func removePhoto(at index: Int) {
        guard photoPathsEditing.indices.contains(index) else { return }
        let path = photoPathsEditing.remove(at: index)

        if isEditing {
            if pendingAdds.contains(path) {
                ImageStore.delete(path)
                pendingAdds.remove(path)
            } else if originalPhotoPaths.contains(path) {
                pendingDeletes.insert(path) // 保存時に削除確定
            }
        } else {
            // 新規作成：即座に削除
            ImageStore.delete(path)
        }
    }

    // MARK: - Save/Discard (Side Effect)

    /// 編集を確定する（削除予約を実行）
    func commitEdits() {
        // 削除予約を確定
        for path in pendingDeletes {
            ImageStore.delete(path)
        }

        // 状態を同期
        originalPhotoPaths = photoPathsEditing
        photoPaths = photoPathsEditing
        pendingAdds.removeAll()
        pendingDeletes.removeAll()
        didSave = true
    }

    /// 保存せず閉じた場合の後処理（onDisappear などで呼ぶ）
    func discardEditingIfNeeded() {
        guard isEditing, didSave == false else { return }

        // セッション中に追加した画像を削除
        for path in pendingAdds {
            ImageStore.delete(path)
        }

        // 編集前の状態に戻す
        photoPathsEditing = originalPhotoPaths
        pendingAdds.removeAll()
        pendingDeletes.removeAll()
    }

    // MARK: - Getters

    /// 現在有効な写真パスを取得（保存時に使用）
    func getCurrentPaths() -> [String] {
        photoPathsEditing
    }

    /// 削除予約されたパスのセットを取得
    func getPendingDeletes() -> Set<String> {
        pendingDeletes
    }
}
