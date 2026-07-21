import SwiftUI

// スポットをフォルダに追加するシート（一方向・追加のみ）
struct FolderPickerSheet: View {
    let spot: CourseSpot

    @Environment(\.dismiss) private var dismiss
    @Environment(\.spotFolderStore) private var folderStore

    @State private var isCreating = false
    @State private var newFolderName = ""
    @FocusState private var newFolderFieldFocused: Bool
    @State private var renamingFolderId: UUID? = nil
    @State private var renameText = ""
    @FocusState private var renameFocused: Bool
    @State private var deleteTarget: SpotFolder? = nil
    @State private var showDeleteAlert = false

    var body: some View {
        NavigationStack {
            List {
                folderListSection
                createSection
            }
            .navigationTitle(L.Folder.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L.Common.done) { dismiss() }
                        .font(.subheadline.weight(.semibold))
                }
            }
            .alert(L.Folder.deleteConfirm, isPresented: $showDeleteAlert) {
                Button(L.Common.delete, role: .destructive) { confirmDelete() }
                Button(L.Common.cancel, role: .cancel) { deleteTarget = nil }
            } message: {
                Text(L.Folder.deleteConfirmMessage)
            }
        }
    }

    // MARK: - セクション

    private var folderListSection: some View {
        Section {
            ForEach(folderStore.folders) { folder in
                folderRow(folder)
            }
        }
    }

    @ViewBuilder
    private func folderRow(_ folder: SpotFolder) -> some View {
        if renamingFolderId == folder.id {
            renameRow(folder)
        } else {
            normalRow(folder)
        }
    }

    private func renameRow(_ folder: SpotFolder) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "folder.fill")
                .foregroundStyle(.indigo)
                .frame(width: 24)
            TextField(L.Folder.namePlaceholder, text: $renameText)
                .focused($renameFocused)
                .onSubmit { commitRename(folder: folder) }
            Spacer()
            Button(L.Common.save) { commitRename(folder: folder) }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.indigo)
            Button(L.Common.cancel) { renamingFolderId = nil }
                .foregroundStyle(.secondary)
        }
    }

    // タップで追加して閉じる（一方向）
    private func normalRow(_ folder: SpotFolder) -> some View {
        Button {
            folderStore.addSpot(spot.id, to: folder.id)
            dismiss()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "folder.fill")
                    .foregroundStyle(.indigo)
                    .frame(width: 24)
                Text(folder.name)
                    .foregroundStyle(Color.primary)
                Spacer()
                Image(systemName: "plus")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.secondary)
            }
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if !folder.isDefault {
                Button(role: .destructive) {
                    deleteTarget = folder
                    showDeleteAlert = true
                } label: {
                    Label(L.Folder.delete, systemImage: "trash")
                }
            }
            Button {
                startRename(folder: folder)
            } label: {
                Label(L.Folder.rename, systemImage: "pencil")
            }
            .tint(.indigo)
        }
    }

    @ViewBuilder
    private var createSection: some View {
        Section {
            if isCreating {
                createRow
            } else {
                newFolderButton
            }
        }
    }

    private var createRow: some View {
        let trimmed = newFolderName.trimmingCharacters(in: .whitespacesAndNewlines)
        return HStack(spacing: 12) {
            Image(systemName: "folder.badge.plus")
                .foregroundStyle(.indigo)
                .frame(width: 24)
            TextField(L.Folder.namePlaceholder, text: $newFolderName)
                .focused($newFolderFieldFocused)
                .onSubmit { commitCreate() }
            Spacer()
            Button(L.Folder.create) { commitCreate() }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(trimmed.isEmpty ? Color.secondary : Color.indigo)
                .disabled(trimmed.isEmpty)
            Button(L.Common.cancel) {
                isCreating = false
                newFolderName = ""
            }
            .foregroundStyle(.secondary)
        }
    }

    private var newFolderButton: some View {
        Button {
            isCreating = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                newFolderFieldFocused = true
            }
        } label: {
            Label(L.Folder.new, systemImage: "folder.badge.plus")
                .foregroundStyle(.indigo)
        }
    }

    // MARK: - ヘルパー

    private func commitCreate() {
        let name = newFolderName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        let folder = folderStore.createFolder(name: name)
        folderStore.addSpot(spot.id, to: folder.id)
        isCreating = false
        newFolderName = ""
        dismiss()
    }

    private func startRename(folder: SpotFolder) {
        renamingFolderId = folder.id
        renameText = folder.name
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            renameFocused = true
        }
    }

    private func commitRename(folder: SpotFolder) {
        let name = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !name.isEmpty {
            folderStore.renameFolder(folder.id, name: name)
        }
        renamingFolderId = nil
    }

    private func confirmDelete() {
        if let target = deleteTarget {
            folderStore.deleteFolder(target.id)
        }
        deleteTarget = nil
    }
}
