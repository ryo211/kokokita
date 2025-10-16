import SwiftUI

struct MemberListView: View {
    @State private var members: [MemberTag] = []
    @State private var loading = true
    @State private var alert: String?

    // 新規作成用
    @State private var showCreate = false
    @State private var newMemberName = ""

    var body: some View {
        List {
            ForEach(members) { tag in
                NavigationLink {
                    MemberDetailView(member: tag) { updated, deleted in
                        if deleted {
                            members.removeAll { $0.id == tag.id }
                        } else if let updated {
                            if let idx = members.firstIndex(where: { $0.id == tag.id }) {
                                members[idx] = updated
                            }
                        }
                    }
                } label: {
                    HStack { Image(systemName: "person"); Text(tag.name) }
                }
            }
        }
        .overlay {
            if loading {
                ProgressView().controlSize(.large)
            } else if members.isEmpty {
                ContentUnavailableView("メンバーはありません", systemImage: "person",
                    description: Text("右上の＋から作成できます。"))
            }
        }
        .navigationTitle("メンバー")
        .navigationBarTitleDisplayMode(.inline)
        .task { await reload() }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    newMemberName = ""
                    showCreate = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("メンバーを新規作成")
            }
        }
        .sheet(isPresented: $showCreate) {
            NavigationStack {
                Form {
                    Section { TextField("メンバー名", text: $newMemberName)
                        .textInputAutocapitalization(.none)
                        .disableAutocorrection(true)
                        .submitLabel(.done)
                        .onSubmit {
                            if !newMemberName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                createMember()
                            }
                        }
                    }
                    Section {
                        Button("作成") { createMember() }
                            .disabled(newMemberName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        Button("キャンセル", role: .cancel) { showCreate = false }
                    }
                }
                .navigationTitle("メンバー新規作成")
            }
        }
        .alert("エラー", isPresented: Binding(get: { alert != nil }, set: { _ in alert = nil })) {
            Button("OK", role: .cancel) {}
        } message: { Text(alert ?? "") }
    }

    private func reload() async {
        loading = true; defer { loading = false }
        do {
            let rows = try AppContainer.shared.repo.allMembers()
            members = rows
                .filter { !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                .sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
        } catch { alert = error.localizedDescription }
    }

    private func createMember() {
        let name = newMemberName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        if members.contains(where: { $0.name == name }) {
            alert = "同じ名前のメンバーが既にあります。"; return
        }
        do {
            let id = try AppContainer.shared.repo.createMember(name: name)
            members.append(.init(id: id, name: name))
            members.sort { $0.name.localizedCompare($1.name) == .orderedAscending }
            showCreate = false
            NotificationCenter.default.post(name: .taxonomyChanged, object: nil)
        } catch { alert = error.localizedDescription }
    }
}

// === 同じファイル内に保持 ===
struct MemberDetailView: View {
    let member: MemberTag
    var onFinish: (_ updated: MemberTag?, _ deleted: Bool) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var showDeleteConfirm = false
    @State private var saving = false
    @State private var alert: String?

    init(member: MemberTag, onFinish: @escaping (_ updated: MemberTag?, _ deleted: Bool) -> Void) {
        self.member = member
        self.onFinish = onFinish
        _name = State(initialValue: member.name)
    }

    var body: some View {
        Form {
            Section { TextField("メンバー名", text: $name)
                .submitLabel(.done)
                .onSubmit {
                    if !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        save()
                    }
                }
            }
            Section {
                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: { Label("このメンバーを削除", systemImage: "trash") }
            } footer: { Text("メンバーを削除しても、記録自体は削除されません。") }
        }
        .navigationTitle("メンバー詳細")
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
            try AppContainer.shared.repo.renameMember(id: member.id,
                                                     newName: name.trimmingCharacters(in: .whitespacesAndNewlines))
            onFinish(MemberTag(id: member.id, name: name), false)
            NotificationCenter.default.post(name: .taxonomyChanged, object: nil)
            dismiss()
        } catch { alert = error.localizedDescription }
    }

    private func delete() {
        do {
            try AppContainer.shared.repo.deleteMember(id: member.id)
            onFinish(nil, true)
            NotificationCenter.default.post(name: .taxonomyChanged, object: nil)
            dismiss()
        } catch { alert = error.localizedDescription }
    }
}
