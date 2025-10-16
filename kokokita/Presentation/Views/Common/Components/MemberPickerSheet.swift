//
//  MemberPickerSheet.swift
//  kokokita
//
//  Created by Claude on 2025/10/16.
//

import SwiftUI

/// メンバー複数選択シート
struct MemberPickerSheet: View {
    @Binding var selectedIds: Set<UUID>
    @Binding var memberOptions: [MemberTag]
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
                }
                Section {
                    ForEach(memberOptions) { t in
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
            .navigationTitle("メンバーを選択")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(L.Common.done) { isPresented = false }
                }
            }
        }
    }
}
