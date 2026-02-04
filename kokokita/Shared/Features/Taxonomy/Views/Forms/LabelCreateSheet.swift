import SwiftUI

/// ラベル新規作成シート
struct LabelCreateSheet: View {
    @Binding var newLabelName: String
    @Binding var newLabelColorId: String?
    @Binding var isPresented: Bool
    var onCreate: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(L.VisitEdit.labelName, text: $newLabelName)
                        .submitLabel(.done)
                        .onSubmit {
                            if !newLabelName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                onCreate()
                            }
                        }
                }
                Section {
                    LabelColorPicker(selectedColorId: newLabelColorId) { colorId in
                        newLabelColorId = colorId
                    }
                } header: {
                    Text(L.LabelColor.sectionTitle)
                }
                Section {
                    Button(L.VisitEdit.createAndSelect) {
                        onCreate()
                    }
                    .disabled(newLabelName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    Button(L.Common.cancel, role: .cancel) {
                        newLabelName = ""
                        newLabelColorId = nil
                        isPresented = false
                    }
                }
            }
            .navigationTitle(L.VisitEdit.newLabel)
        }
    }
}
