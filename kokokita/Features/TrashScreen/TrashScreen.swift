import SwiftUI

// MARK: - Store

@MainActor
@Observable
final class TrashStore {
    private let repo: CoreDataVisitRepository

    var items: [VisitAggregate] = []
    var isLoading = false
    var errorMessage: String?

    init(repo: CoreDataVisitRepository = AppContainer.shared.repo) {
        self.repo = repo
    }

    func load() {
        isLoading = true
        do {
            items = try repo.fetchTrashed()
        } catch {
            errorMessage = error.localizedDescription
            Logger.error("ゴミ箱の読み込みに失敗しました", error: error)
        }
        isLoading = false
    }

    func restore(id: UUID) {
        do {
            try repo.restore(id: id)
            items.removeAll { $0.visit.id == id }
        } catch {
            errorMessage = error.localizedDescription
            Logger.error("記録の復元に失敗しました", error: error)
        }
    }

    func permanentlyDelete(id: UUID) {
        do {
            try repo.permanentlyDelete(id: id)
            items.removeAll { $0.visit.id == id }
        } catch {
            errorMessage = error.localizedDescription
            Logger.error("記録の完全削除に失敗しました", error: error)
        }
    }

    func emptyTrash() {
        do {
            try repo.emptyTrash()
            items.removeAll()
        } catch {
            errorMessage = error.localizedDescription
            Logger.error("ゴミ箱の空にする処理に失敗しました", error: error)
        }
    }

    var count: Int { items.count }
}

// MARK: - View

struct TrashScreen: View {
    @State private var store = TrashStore()
    @State private var showEmptyConfirm = false
    @State private var permanentDeleteId: UUID?

    var body: some View {
        Group {
            if store.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if store.items.isEmpty {
                emptyView
            } else {
                itemList
            }
        }
        .onAppear { store.load() }
        .onReceive(NotificationCenter.default.publisher(for: .visitsChanged)) { _ in
            store.load()
        }
        .alert(L.Trash.emptyTrashConfirmTitle, isPresented: $showEmptyConfirm) {
            Button(L.Trash.emptyTrash, role: .destructive) {
                store.emptyTrash()
            }
            Button(L.Common.cancel, role: .cancel) {}
        } message: {
            Text(L.Trash.emptyTrashConfirmMessage(store.count))
        }
        .alert(L.Trash.permanentlyDeleteConfirmTitle, isPresented: Binding<Bool>(
            get: { permanentDeleteId != nil },
            set: { if !$0 { permanentDeleteId = nil } }
        )) {
            Button(L.Trash.permanentlyDelete, role: .destructive) {
                if let id = permanentDeleteId {
                    store.permanentlyDelete(id: id)
                    permanentDeleteId = nil
                }
            }
            Button(L.Common.cancel, role: .cancel) { permanentDeleteId = nil }
        } message: {
            Text(L.Trash.permanentlyDeleteConfirmMessage)
        }
        .alert(L.Common.error, isPresented: Binding<Bool>(
            get: { store.errorMessage != nil },
            set: { if !$0 { store.errorMessage = nil } }
        )) {
            Button(L.Common.ok, role: .cancel) { store.errorMessage = nil }
        } message: {
            Text(store.errorMessage ?? "")
        }
    }

    // MARK: - 空状態

    private var emptyView: some View {
        VStack(spacing: 12) {
            Image(systemName: "trash")
                .font(.system(size: 52))
                .foregroundStyle(.secondary)
            Text(L.Trash.empty)
                .font(.headline)
                .foregroundStyle(.secondary)
            Text(L.Trash.emptyDescription)
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    // MARK: - リスト

    private var itemList: some View {
        List {
            Section {
                Button(role: .destructive) {
                    showEmptyConfirm = true
                } label: {
                    Label(L.Trash.emptyTrash, systemImage: "trash.slash")
                        .foregroundStyle(.red)
                }
            } footer: {
                Text(L.Trash.emptyDescription)
            }

            Section {
                ForEach(store.items, id: \.visit.id) { aggregate in
                    TrashItemRow(
                        aggregate: aggregate,
                        onRestore: { store.restore(id: aggregate.visit.id) },
                        onPermanentlyDelete: { permanentDeleteId = aggregate.visit.id }
                    )
                }
            }
        }
    }
}

// MARK: - 行コンポーネント

private struct TrashItemRow: View {
    let aggregate: VisitAggregate
    let onRestore: () -> Void
    let onPermanentlyDelete: () -> Void

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        f.locale = .current
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // タイトルと場所
            Text(displayTitle)
                .font(.body)
                .fontWeight(.medium)
                .lineLimit(1)

            Text(Self.dateFormatter.string(from: aggregate.visit.timestampUTC))
                .font(.caption)
                .foregroundStyle(.secondary)

            if let deletedAt = aggregate.deletedAt {
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.caption2)
                    Text(expirationLabel(deletedAt: deletedAt))
                        .font(.caption2)
                }
                .foregroundStyle(isExpiringSoon(deletedAt: deletedAt) ? AnyShapeStyle(.orange) : AnyShapeStyle(.tertiary))
            }

            // アクションボタン
            HStack(spacing: 8) {
                Button {
                    onRestore()
                } label: {
                    Label(L.Trash.restore, systemImage: "arrow.uturn.backward")
                        .font(.caption)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.accentColor)

                Button(role: .destructive) {
                    onPermanentlyDelete()
                } label: {
                    Label(L.Trash.permanentlyDelete, systemImage: "trash.fill")
                        .font(.caption)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            .padding(.top, 2)
        }
        .padding(.vertical, 4)
    }

    private var displayTitle: String {
        if let title = aggregate.details.title, !title.isEmpty { return title }
        if let name = aggregate.details.facilityName, !name.isEmpty { return name }
        if let addr = aggregate.details.resolvedAddress, !addr.isEmpty { return addr }
        return String(format: "%.4f, %.4f", aggregate.visit.latitude, aggregate.visit.longitude)
    }

    private func expirationLabel(deletedAt: Date) -> String {
        let remaining = AppConfig.trashRetentionDays * 86400 - Date().timeIntervalSince(deletedAt)
        let days = max(0, Int(remaining / 86400))
        if days == 0 { return L.Trash.expiresToday }
        return L.Trash.expiresIn(days)
    }

    private func isExpiringSoon(deletedAt: Date) -> Bool {
        let remaining = AppConfig.trashRetentionDays * 86400 - Date().timeIntervalSince(deletedAt)
        return remaining < 3 * 86400
    }
}
