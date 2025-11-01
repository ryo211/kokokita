import SwiftUI

/// ラベル複数選択シート
struct LabelPickerSheet: View {
    @Binding var selectedIds: Set<UUID>
    @Binding var labelOptions: [LabelTag]
    @Binding var isPresented: Bool
    @Binding var showCreateSheet: Bool
    var showDoneButton: Bool = true

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        showCreateSheet = true
                    } label: {
                        Label(L.VisitEdit.createNew, systemImage: "plus.circle")
                    }
                }
                Section {
                    ForEach(labelOptions) { t in
                        Button {
                            if selectedIds.contains(t.id) {
                                selectedIds.remove(t.id)
                            } else {
                                selectedIds.insert(t.id)
                            }
                        } label: {
                            HStack {
                                Text(t.name)
                                Spacer()
                                if selectedIds.contains(t.id) {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(L.VisitEdit.selectLabel)
            .toolbar {
                if showDoneButton {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(L.Common.done) { isPresented = false }
                    }
                }
            }
        }
    }
}
