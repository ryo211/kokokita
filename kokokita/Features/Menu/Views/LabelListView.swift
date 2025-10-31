import SwiftUI

struct LabelListView: View {
    @State private var labels: [LabelTag] = []
    @State private var loading = true
    @State private var alert: String?

    // 新規作成用
    @State private var showCreate = false
    @State private var newLabelName = ""

    var body: some View {
        List {
            ForEach(labels) { tag in
                NavigationLink {
                    LabelDetailView(label: tag) { updated, deleted in
                        if deleted {
                            labels.removeAll { $0.id == tag.id }
                        } else if let updated {
                            if let idx = labels.firstIndex(where: { $0.id == tag.id }) {
                                labels[idx] = updated
                            }
                        }
                    }
                } label: {
                    HStack { Image(systemName: "tag"); Text(tag.name) }
                }
            }
        }
        .overlay {
            if loading {
                ProgressView().controlSize(.large)
            } else if labels.isEmpty {
                ContentUnavailableView("ラベルはありません", systemImage: "tag",
                    description: Text("右上の＋から作成できます。"))
            }
        }
        .navigationTitle("ラベル")
        .navigationBarTitleDisplayMode(.inline)
        .task { await reload() }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    newLabelName = ""
                    showCreate = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("ラベルを新規作成")
            }
        }
        .sheet(isPresented: $showCreate) {
            NavigationStack {
                Form {
                    Section { TextField("ラベル名", text: $newLabelName)
                        .textInputAutocapitalization(.none)
                        .disableAutocorrection(true)
                        .submitLabel(.done)
                        .onSubmit {
                            if !newLabelName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                createLabel()
                            }
                        }
                    }
                    Section {
                        Button("作成") { createLabel() }
                            .disabled(newLabelName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        Button("キャンセル", role: .cancel) { showCreate = false }
                    }
                }
                .navigationTitle("ラベル新規作成")
            }
        }
        .alert("エラー", isPresented: Binding(get: { alert != nil }, set: { _ in alert = nil })) {
            Button("OK", role: .cancel) {}
        } message: { Text(alert ?? "") }
    }

    private func reload() async {
        loading = true; defer { loading = false }
        do {
            let rows = try AppContainer.shared.repo.allLabels()
            labels = rows
                .filter { !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                .sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
        } catch { alert = error.localizedDescription }
    }

    private func createLabel() {
        let name = newLabelName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        if labels.contains(where: { $0.name == name }) {
            alert = "同じ名前のラベルが既にあります。"; return
        }
        do {
            let id = try AppContainer.shared.repo.createLabel(name: name)
            labels.append(.init(id: id, name: name))
            labels.sort { $0.name.localizedCompare($1.name) == .orderedAscending }
            showCreate = false
            NotificationCenter.default.post(name: .taxonomyChanged, object: nil)
        } catch { alert = error.localizedDescription }
    }
}

// === 同じファイル内に保持 ===
struct LabelDetailView: View {
    let label: LabelTag
    var onFinish: (_ updated: LabelTag?, _ deleted: Bool) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var showDeleteConfirm = false
    @State private var saving = false
    @State private var alert: String?

    init(label: LabelTag, onFinish: @escaping (_ updated: LabelTag?, _ deleted: Bool) -> Void) {
        self.label = label
        self.onFinish = onFinish
        _name = State(initialValue: label.name)
    }

    var body: some View {
        Form {
            Section { TextField("ラベル名", text: $name)
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
                } label: { Label("このラベルを削除", systemImage: "trash") }
            } footer: { Text("ラベルを削除しても、記録自体は削除されません。") }
        }
        .navigationTitle("ラベル詳細")
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
            try AppContainer.shared.repo.renameLabel(id: label.id,
                                                     newName: name.trimmingCharacters(in: .whitespacesAndNewlines))
            onFinish(LabelTag(id: label.id, name: name), false)
            NotificationCenter.default.post(name: .taxonomyChanged, object: nil)
            dismiss()
        } catch { alert = error.localizedDescription }
    }

    private func delete() {
        do {
            try AppContainer.shared.repo.deleteLabel(id: label.id)
            onFinish(nil, true)
            NotificationCenter.default.post(name: .taxonomyChanged, object: nil)
            dismiss()
        } catch { alert = error.localizedDescription }
    }
}
