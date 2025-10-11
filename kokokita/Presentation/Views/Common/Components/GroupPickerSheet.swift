//
//  GroupPickerSheet.swift
//  kokokita
//
//  Created by Claude on 2025/10/11.
//

import SwiftUI

/// グループ単一選択シート
struct GroupPickerSheet: View {
    @Binding var selectedId: UUID?
    @Binding var groupOptions: [GroupTag]
    @Binding var isPresented: Bool
    @Binding var showCreateSheet: Bool

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        showCreateSheet = true
                    } label: {
                        Label(L.VisitEdit.createNew, systemImage: "plus.circle")
                    }
                    Button(L.VisitEdit.clearSelection) { selectedId = nil }
                }
                Section {
                    ForEach(groupOptions) { t in
                        Button {
                            selectedId = t.id
                        } label: {
                            HStack {
                                Text(t.name)
                                Spacer()
                                if selectedId == t.id {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(L.VisitEdit.selectGroup)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(L.Common.done) { isPresented = false }
                }
            }
        }
    }
}
