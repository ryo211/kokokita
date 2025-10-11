//
//  GroupCreateSheet.swift
//  kokokita
//
//  Created by Claude on 2025/10/11.
//

import SwiftUI

/// グループ新規作成シート
struct GroupCreateSheet: View {
    @Binding var newGroupName: String
    @Binding var isPresented: Bool
    var onCreate: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(L.VisitEdit.groupName, text: $newGroupName)
                }
                Section {
                    Button(L.VisitEdit.createAndSelect) {
                        onCreate()
                    }
                    .disabled(newGroupName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    Button(L.Common.cancel, role: .cancel) {
                        newGroupName = ""
                        isPresented = false
                    }
                }
            }
            .navigationTitle(L.VisitEdit.newGroup)
        }
    }
}
