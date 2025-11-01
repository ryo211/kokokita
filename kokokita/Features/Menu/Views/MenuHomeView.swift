import SwiftUI

struct MenuHomeView: View {
    var body: some View {
        List {
            Section {
                NavigationLink {
                    LabelListView()
                } label: {
                    Label("ラベルを編集", systemImage: "tag")
                }

                NavigationLink {
                    GroupListView()
                } label: {
                    Label("グループを編集", systemImage: "folder")
                }

                NavigationLink {
                    MemberListView()
                } label: {
                    Label("メンバーを編集", systemImage: "person")
                }
            }

            Section {
                NavigationLink {
                    ResetAllView()
                } label: {
                    Label("初期化（全削除）", systemImage: "trash")
                        .foregroundStyle(.red)
                }
            } footer: {
                Text("「初期化」は全ての記録を削除します。元に戻せません。")
            }
        }
        .navigationTitle("メニュー")
        .navigationBarTitleDisplayMode(.inline)
    }
}
