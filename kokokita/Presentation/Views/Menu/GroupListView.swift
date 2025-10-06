import SwiftUI

struct GroupListView: View {
    @State private var groups: [GroupTag] = []
    @State private var loading = true
    @State private var alert: String?

    // 新規作成用
    @State private var showCreate = false
    @State private var newGroupName = ""

    var body: some View {
        List {
            ForEach(groups) { tag in
                NavigationLink {
                    GroupDetailView(group: tag) { updated, deleted in
                        if deleted {
                            groups.removeAll { $0.id == tag.id }
                        } else if let updated {
                            if let idx = groups.firstIndex(where: { $0.id == tag.id }) {
                                groups[idx] = updated
                            }
                        }
                    }
                } label: {
                    HStack { Image(systemName: "folder"); Text(tag.name) }
                }
            }
        }
        .overlay {
            if loading {
                ProgressView().controlSize(.large)
            } else if groups.isEmpty {
                ContentUnavailableView("グループはありません", systemImage: "folder",
                    description: Text("右上の＋から作成できます。"))
            }
        }
        .navigationTitle("グループ")
        .navigationBarTitleDisplayMode(.inline)
        .task { await reload() }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    newGroupName = ""
                    showCreate = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("グループを新規作成")
            }
        }
        .sheet(isPresented: $showCreate) {
            NavigationStack {
                Form {
                    Section { TextField("グループ名", text: $newGroupName)
                        .textInputAutocapitalization(.none)
                        .disableAutocorrection(true)
                    }
                    Section {
                        Button("作成") { createGroup() }
                            .disabled(newGroupName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        Button("キャンセル", role: .cancel) { showCreate = false }
                    }
                }
                .navigationTitle("グループ新規作成")
            }
        }
        .alert("エラー", isPresented: Binding(get: { alert != nil }, set: { _ in alert = nil })) {
            Button("OK", role: .cancel) {}
        } message: { Text(alert ?? "") }
    }

    private func reload() async {
        loading = true; defer { loading = false }
        do {
            let rows = try AppContainer.shared.repo.allGroups()
            groups = rows
                .filter { !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                .sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
        } catch { alert = error.localizedDescription }
    }

    private func createGroup() {
        let name = newGroupName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        if groups.contains(where: { $0.name == name }) {
            alert = "同じ名前のグループが既にあります。"; return
        }
        do {
            let id = try AppContainer.shared.repo.createGroup(name: name)
            groups.append(.init(id: id, name: name))
            groups.sort { $0.name.localizedCompare($1.name) == .orderedAscending }
            showCreate = false
            NotificationCenter.default.post(name: .taxonomyChanged, object: nil)
        } catch { alert = error.localizedDescription }
    }
}

// === 同じファイル内に保持 ===
struct GroupDetailView: View {
    let group: GroupTag
    var onFinish: (_ updated: GroupTag?, _ deleted: Bool) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var showDeleteConfirm = false
    @State private var saving = false
    @State private var alert: String?

    init(group: GroupTag, onFinish: @escaping (_ updated: GroupTag?, _ deleted: Bool) -> Void) {
        self.group = group
        self.onFinish = onFinish
        _name = State(initialValue: group.name)
    }

    var body: some View {
        Form {
            Section { TextField("グループ名", text: $name) }
            Section {
                Button(role: .destructive) { showDeleteConfirm = true } label: {
                    Label("このグループを削除", systemImage: "trash")
                }
            } footer: { Text("グループを削除しても、記録自体は削除されません。") }
        }
        .navigationTitle("グループ詳細")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("保存") { save() }
                    .disabled(saving || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .alert("本当に削除しますか？", isPresented: $showDeleteConfirm) {
            Button("キャンセル", role: .cancel) {}
            Button("削除", role: .destructive) { delete() }
        } message: { Text("この操作は取り消せません。") }
        .alert("エラー", isPresented: Binding(get: { alert != nil }, set: { _ in alert = nil })) {
            Button("OK", role: .cancel) {}
        } message: { Text(alert ?? "") }
    }

    private func save() {
        saving = true; defer { saving = false }
        do {
            try AppContainer.shared.repo.renameGroup(id: group.id,
                                                     newName: name.trimmingCharacters(in: .whitespacesAndNewlines))
            onFinish(GroupTag(id: group.id, name: name), false)
            NotificationCenter.default.post(name: .taxonomyChanged, object: nil)
            dismiss()
        } catch { alert = error.localizedDescription }
    }

    private func delete() {
        do {
            try AppContainer.shared.repo.deleteGroup(id: group.id)
            onFinish(nil, true)
            NotificationCenter.default.post(name: .taxonomyChanged, object: nil)
            dismiss()
        } catch { alert = error.localizedDescription }
    }
}
