//
//  VisitEditScreen.swift
//  kokokita
//
//  Created by 橋本遼 on 2025/09/21.
//

import SwiftUI
import Foundation
import MapKit

enum VisitEditMode {
    case create
    case edit(id: UUID, onSaved: () -> Void = {})
}

struct VisitEditScreen: View {
    // 共有 ViewModel
    @Bindable var vm: CreateEditStore
    let mode: VisitEditMode
    let onClose: () -> Void
    var showsCloseButton: Bool = true
    var needsBottomSafePadding: Bool = false
    
    
    @FocusState private var focusedField: Field?
    private enum Field { case title, comment }
    
    // 状態管理（共通化）
    @State private var saving = false
    @State private var showFacilityPopover = false

    // ラベル/グループ/メンバー候補
    @State private var labelOptions: [LabelTag] = []
    @State private var groupOptions: [GroupTag] = []
    @State private var memberOptions: [MemberTag] = []

    // ピッカー/作成シート
    @State private var labelPickerShown = false
    @State private var groupPickerShown = false
    @State private var memberPickerShown = false
    @State private var labelCreateShown = false
    @State private var groupCreateShown = false
    @State private var memberCreateShown = false

    // 作成入力
    @State private var newLabelName = ""
    @State private var newGroupName = ""
    @State private var newMemberName = ""
    
    // 住所のプレビュー用
    @State private var showAddressPopover = false
    
    // 表示名（ラベル複数）
    private var selectedLabelNames: [String] {
        let dict = labelOptions.nameMap
        return vm.labelIds.compactMap { dict[$0] }
    }
    private var selectedLabelTitle: String {
        if selectedLabelNames.isEmpty { return L.Common.notSelected }
        if selectedLabelNames.count <= 2 { return selectedLabelNames.joined(separator: ", ") }
        let head = selectedLabelNames.prefix(2).joined(separator: ", ")
        return "\(head) ほか\(selectedLabelNames.count - 2)件"
    }
    // 表示名（グループ単一）
    private var selectedGroupName: String {
        let dict = groupOptions.nameMap
        return vm.groupId.flatMap { dict[$0] } ?? L.Common.notSelected
    }
    // 表示名（メンバー複数）
    private var selectedMemberNames: [String] {
        let dict = memberOptions.nameMap
        return vm.memberIds.compactMap { dict[$0] }
    }
    private var selectedMemberTitle: String {
        if selectedMemberNames.isEmpty { return L.Common.notSelected }
        if selectedMemberNames.count <= 2 { return selectedMemberNames.joined(separator: ", ") }
        let head = selectedMemberNames.prefix(2).joined(separator: ", ")
        return "\(head) ほか\(selectedMemberNames.count - 2)件"
    }

    var body: some View {
        NavigationStack {
            formContent
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Group {
                        if showsCloseButton {
                            Button(L.Common.close) { onClose() }
                        } else {
                            EmptyView()
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(L.Common.save) { saveTapped() }
                        .disabled(disableSave)
                }
                ToolbarItem(placement: .keyboard) {
                    // フォーカス中にだけ出したいなら条件で囲ってOK
                    if focusedField == .comment || focusedField == .title {
                        HStack {
                            Spacer()
                            Button(L.Common.done) {
                                focusedField = nil
                            }
                        }
                        .frame(maxWidth: .infinity)    // 幅0警告の回避に効く
                        .padding(.horizontal)
                    }
                }
            }

            .task {
                await onAppearTask()
            }

            .safeAreaInset(edge: .bottom) {
                if focusedField == nil {
                    VStack(spacing: 0) {
                        EditFooterBar(
                            onSave: {
                                focusedField = nil
                                saveTapped()
                            },
                            onPoi:  { Task {
                                focusedField = nil
                                await vm.openPOI() }
                            },
                            saveDisabled: disableSave
                        )
                        if needsBottomSafePadding {
                            Spacer()
                                .frame(height: max(0, bottomSafeInset() - UIConstants.Spacing.medium + UIConstants.Spacing.small))
                        }
                    }
                }
            }

            // POI 候補（データが揃っている場合のみ表示）
            .sheet(isPresented: Binding(
                get: { vm.shouldShowPOISheet },
                set: { newValue in
                    if !newValue {
                        vm.closePOISheet()
                    }
                }
            )) {
                NavigationStack {
                    // ★ 明示的に型を固定してあげると安定します
                    let items: [PlacePOI] = vm.poiCoordinator.poiList
                    let name: (PlacePOI) -> String = { $0.name }
                    let address: (PlacePOI) -> String? = { $0.address }
                    let poiCategory: (PlacePOI) -> MKPointOfInterestCategory? = { poi in
                        poi.poiCategoryRaw.flatMap(MKPointOfInterestCategory.init(rawValue:))
                    }

                    // ★ ジェネリクスも明示（なくても通ることは多いが、安定度が上がる）
                    KokokamoPOISheet<PlacePOI>(
                        items: items,
                        name: name,
                        address: address,
                        poiCategory: poiCategory
                    ) { selected in
                        vm.applyPOI(selected)
                    }
                }
            }

            // エラー
            .alert(
                item: Binding(
                    get: { vm.alert.map { AlertMsg(id: UUID(), text: $0) } },
                    set: { _ in vm.alert = nil }
                )
            ) { msg in
                Alert(title: Text(L.Common.error), message: Text(msg.text), dismissButton: .default(Text(L.Common.ok)))
            }
        }
        // —— ラベル複数選択
        .sheet(isPresented: $labelPickerShown) {
            LabelPickerSheet(
                selectedIds: $vm.labelIds,
                labelOptions: $labelOptions,
                isPresented: $labelPickerShown,
                showCreateSheet: $labelCreateShown
            )
            // ラベル新規作成
            .sheet(isPresented: $labelCreateShown) {
                LabelCreateSheet(
                    newLabelName: $newLabelName,
                    isPresented: $labelCreateShown,
                    onCreate: createLabelAndSelect
                )
            }
        }
        // —— グループ選択
        .sheet(isPresented: $groupPickerShown) {
            GroupPickerSheet(
                selectedId: $vm.groupId,
                groupOptions: $groupOptions,
                isPresented: $groupPickerShown,
                showCreateSheet: $groupCreateShown
            )
            // グループ新規作成
            .sheet(isPresented: $groupCreateShown) {
                GroupCreateSheet(
                    newGroupName: $newGroupName,
                    isPresented: $groupCreateShown,
                    onCreate: createGroupAndSelect
                )
            }
        }
        // —— メンバー複数選択
        .sheet(isPresented: $memberPickerShown) {
            MemberPickerSheet(
                selectedIds: $vm.memberIds,
                memberOptions: $memberOptions,
                isPresented: $memberPickerShown,
                showCreateSheet: $memberCreateShown
            )
            // メンバー新規作成
            .sheet(isPresented: $memberCreateShown) {
                MemberCreateSheet(
                    newMemberName: $newMemberName,
                    isPresented: $memberCreateShown,
                    onCreate: createMemberAndSelect
                )
            }
        }

        .ignoresSafeArea(.keyboard, edges: .bottom)
        .onDisappear {
            vm.discardPhotoEditingIfNeeded()
        }
    }

    // MARK: - Form共通
    private var formContent: some View {
        Form {
            Section(L.VisitEdit.editSection) {
                HStack(spacing: UIConstants.Spacing.medium) {
                    TextField(L.VisitEdit.titlePlaceholder, text: $vm.title)
                        .focused($focusedField, equals: .title)

                    // 施設情報ボタン（共通）
                    FacilityInfoButton(
                        name: vm.facilityName,
                        address: vm.facilityAddress,
                        phone: nil,                    // あれば vm.facilityPhone
                        categoryRawValue: vm.facilityCategory,
                        mode: .editable,
                        onClear: {
                            vm.clearFacilityInfo()
                        }
                    )
                }

                if #available(iOS 16.0, *) {
                    PhotoAttachmentSection(vm: vm, allowDelete: true)
                }

                TextEditor(text: $vm.comment)
                    .focused($focusedField, equals: .comment)
                    .frame(minHeight: 80)
                    .overlay(alignment: .topLeading) {
                        if vm.comment.isEmpty {
                            Text(L.VisitEdit.memoPlaceholder).foregroundStyle(.secondary)
                                .padding(.top, UIConstants.Spacing.medium).padding(.leading, 5)
                        }
                    }

                Button { labelPickerShown = true } label: {
                    Label("\(selectedLabelTitle)", systemImage: "tag")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                Button { groupPickerShown = true } label: {
                    Label("\(selectedGroupName)", systemImage: "folder")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                Button { memberPickerShown = true } label: {
                    Label("\(selectedMemberTitle)", systemImage: "person")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

        }
    }


    // MARK: - Actions
    private var disableSave: Bool {
        switch mode {
        case .create:
            return (vm.latitude == 0 && vm.longitude == 0)
        case .edit:
            return false
        }
    }

    private func saveTapped() {
        guard !saving else { return }
        saving = true
        defer { saving = false }

        switch mode {
        case .create:
            if vm.createNew() { onClose() }
        case .edit(let id, let onSaved):
            if vm.saveEdits(for: id) { onSaved(); onClose() }
        }
    }

    private func onAppearTask() async {
        // 候補をロード（空白除外 & 名前順）
        labelOptions = ((try? AppContainer.shared.repo.allLabels()) ?? []).sortedByName
        groupOptions = ((try? AppContainer.shared.repo.allGroups()) ?? []).sortedByName
        memberOptions = ((try? AppContainer.shared.repo.allMembers()) ?? []).sortedByName
    }

    private func createLabelAndSelect() {
        let name = newLabelName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        if let exist = labelOptions.first(where: { $0.name == name }) {
            vm.labelIds.insert(exist.id)
        } else if let id = vm.createLabel(name) {
            let tag = LabelTag(id: id, name: name)
            labelOptions.append(tag)
            vm.labelIds.insert(id)
        }
        newLabelName = ""
        labelCreateShown = false
    }

    private func createGroupAndSelect() {
        let name = newGroupName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        if let exist = groupOptions.first(where: { $0.name == name }) {
            vm.groupId = exist.id
        } else if let id = vm.createGroup(name) {
            let tag = GroupTag(id: id, name: name)
            groupOptions.append(tag)
            vm.groupId = id
        }
        newGroupName = ""
        groupCreateShown = false
    }

    private func createMemberAndSelect() {
        let name = newMemberName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        if let exist = memberOptions.first(where: { $0.name == name }) {
            vm.memberIds.insert(exist.id)
        } else if let id = vm.createMember(name) {
            let tag = MemberTag(id: id, name: name)
            memberOptions.append(tag)
            vm.memberIds.insert(id)
        }
        newMemberName = ""
        memberCreateShown = false
    }

    private func bottomSafeInset() -> CGFloat {
        // iOS 15+ で安全に keyWindow を探して bottom インセットを返す
        guard let scene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first,
              let window = scene.windows.first(where: { $0.isKeyWindow }) else {
            return 0
        }
        return window.safeAreaInsets.bottom
    }
}
