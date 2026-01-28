import SwiftUI

struct SettingsHomeScreen: View {
    var body: some View {
        List {
            Section {
                NavigationLink {
                    LabelListScreen()
                } label: {
                    Label(L.Settings.editLabels, systemImage: "tag")
                        .foregroundStyle(.purple)
                }

                NavigationLink {
                    GroupListScreen()
                } label: {
                    Label(L.Settings.editGroups, systemImage: "folder")
                        .foregroundStyle(.teal)
                }

                NavigationLink {
                    MemberListScreen()
                } label: {
                    Label(L.Settings.editMembers, systemImage: "person")
                        .foregroundStyle(.blue)
                }
            }
        }
        .navigationTitle(L.Settings.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

