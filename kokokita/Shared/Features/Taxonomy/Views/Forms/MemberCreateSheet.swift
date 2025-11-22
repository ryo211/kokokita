import SwiftUI

/// メンバー新規作成シート
struct MemberCreateSheet: View {
    @Binding var newMemberName: String
    @Binding var isPresented: Bool
    var onCreate: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(L.MemberManagement.namePlaceholder, text: $newMemberName)
                        .submitLabel(.done)
                        .onSubmit {
                            if !newMemberName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                onCreate()
                            }
                        }
                }
                Section {
                    Button(L.VisitEdit.createAndSelect) {
                        onCreate()
                    }
                    .disabled(newMemberName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    Button(L.Common.cancel, role: .cancel) {
                        newMemberName = ""
                        isPresented = false
                    }
                }
            }
            .navigationTitle(L.MemberManagement.createTitle)
        }
    }
}
