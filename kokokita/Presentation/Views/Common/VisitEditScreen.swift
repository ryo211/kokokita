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
    @ObservedObject var vm: CreateEditViewModel
    let mode: VisitEditMode
    let onClose: () -> Void
    var showsCloseButton: Bool = true
    var needsBottomSafePadding: Bool = false
    
    
    @FocusState private var focusedField: Field?
    private enum Field { case title, comment }
    
    // 状態管理（共通化）
    @State private var saving = false
    @State private var locating = false
    @State private var showActionPromptLocal = false
    @State private var showFacilityPopover = false

    // ラベル/グループ候補
    @State private var labelOptions: [LabelTag] = []
    @State private var groupOptions: [GroupTag] = []

    // ピッカー/作成シート
    @State private var labelPickerShown = false
    @State private var groupPickerShown = false
    @State private var labelCreateShown = false
    @State private var groupCreateShown = false

    // 作成入力
    @State private var newLabelName = ""
    @State private var newGroupName = ""
    
    // 住所のプレビュー用
    @State private var showAddressPopover = false
    
    // 表示名（ラベル複数）
    private var selectedLabelNames: [String] {
        let dict = Dictionary(uniqueKeysWithValues: labelOptions.map { ($0.id, $0.name) })
        return vm.labelIds.compactMap { dict[$0] }
    }
    private var selectedLabelTitle: String {
        if selectedLabelNames.isEmpty { return "未選択" }
        if selectedLabelNames.count <= 2 { return selectedLabelNames.joined(separator: ", ") }
        let head = selectedLabelNames.prefix(2).joined(separator: ", ")
        return "\(head) ほか\(selectedLabelNames.count - 2)件"
    }
    // 表示名（グループ単一）
    private var selectedGroupName: String {
        let dict = Dictionary(uniqueKeysWithValues: groupOptions.map { ($0.id, $0.name) })
        return vm.groupId.flatMap { dict[$0] } ?? "未選択"
    }
    
    private var actionPromptBinding: Binding<Bool> {
        Binding<Bool>(
            get: {
                if case .create = mode { return vm.showActionPrompt }
                return false
            },
            set: { newVal in
                if case .create = mode { vm.showActionPrompt = newVal }
                // edit のときは無視（= 常に false）
            }
        )
    }

    var body: some View {
        NavigationStack {
            ZStack {
                formContent
                    .disabled(locating)

                if locating {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("現在地を取得しています…")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        if vm.alert != nil {
                            Button("再試行") {
                                Task {
                                    locating = true
                                    await vm.requestLocation()
                                    locating = false
                                }
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .padding()
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Group {
                        if showsCloseButton {
                            Button("閉じる") { onClose() }
                        } else {
                            EmptyView()
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") { saveTapped() }
                        .disabled(disableSave)
                }
                ToolbarItem(placement: .keyboard) {
                    // フォーカス中にだけ出したいなら条件で囲ってOK
                    if focusedField == .comment || focusedField == .title {
                        HStack {
                            Spacer()
                            Button("完了") {
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
            
            .onChange(of: vm.showActionPrompt) { newVal in
                if case .create = mode {
                    showActionPromptLocal = newVal
                } else {
                    showActionPromptLocal = false
                }
            }
            
            .safeAreaInset(edge: .bottom) {
                if focusedField == nil {
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
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, needsBottomSafePadding ? max(8, bottomSafeInset() + 4) : 8) // ← 端末の安全領域ぶんを加算
                    .background(.regularMaterial)
                }
            }

            // POI 候補
            .sheet(isPresented: $vm.showPOI) {
                NavigationStack {
                    // ★ 明示的に型を固定してあげると安定します
                    let items: [PlacePOI] = vm.poiList
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
                Alert(title: Text("エラー"), message: Text(msg.text), dismissButton: .default(Text("OK")))
            }
        }
        // —— ラベル複数選択
        .sheet(isPresented: $labelPickerShown) {
            NavigationStack {
                List {
                    Section {
                        Button {
                            labelCreateShown = true
                        } label: {
                            Label("新規作成…", systemImage: "plus.circle")
                        }
                    }
                    Section {
                        ForEach(labelOptions) { t in
                            Button {
                                if vm.labelIds.contains(t.id) {
                                    vm.labelIds.remove(t.id)
                                } else {
                                    vm.labelIds.insert(t.id)
                                }
                            } label: {
                                HStack {
                                    Text(t.name)
                                    Spacer()
                                    if vm.labelIds.contains(t.id) {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    }
                }
                .navigationTitle("ラベルを選択")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("完了") { labelPickerShown = false }
                    }
                }
            }
            // ラベル新規作成
            .sheet(isPresented: $labelCreateShown) {
                NavigationStack {
                    Form {
                        Section {
                            TextField("ラベル名", text: $newLabelName)
                        }
                        Section {
                            Button("作成して選択") {
                                createLabelAndSelect()
                            }
                            .disabled(newLabelName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                            Button("キャンセル", role: .cancel) {
                                newLabelName = ""
                                labelCreateShown = false
                            }
                        }
                    }
                    .navigationTitle("ラベル新規作成")
                }
            }
        }
        // —— グループ選択
        .sheet(isPresented: $groupPickerShown) {
            NavigationStack {
                List {
                    Section {
                        Button {
                            groupCreateShown = true
                        } label: {
                            Label("新規作成…", systemImage: "plus.circle")
                        }
                        Button("未選択にする") { vm.groupId = nil }
                    }
                    Section {
                        ForEach(groupOptions) { t in
                            Button {
                                vm.groupId = t.id
                            } label: {
                                HStack {
                                    Text(t.name)
                                    Spacer()
                                    if vm.groupId == t.id {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    }
                }
                .navigationTitle("グループを選択")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("完了") { groupPickerShown = false }
                    }
                }
            }
            // グループ新規作成
            .sheet(isPresented: $groupCreateShown) {
                NavigationStack {
                    Form {
                        Section {
                            TextField("グループ名", text: $newGroupName)
                        }
                        Section {
                            Button("作成して選択") {
                                createGroupAndSelect()
                            }
                            .disabled(newGroupName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                            Button("キャンセル", role: .cancel) {
                                newGroupName = ""
                                groupCreateShown = false
                            }
                        }
                    }
                    .navigationTitle("グループ新規作成")
                }
            }
        }
        
        // 3択 “ココキタ！” プロンプト（create のときだけ）
        .sheet(isPresented: $showActionPromptLocal) {
            PostKokokitaPromptSheet(
                timestamp: vm.timestampDisplay,
                addressText: vm.addressLine,
                latitude: vm.latitude,
                longitude: vm.longitude,
                canSave: (vm.latitude != 0 || vm.longitude != 0),
                onSaveNow: {
                    // ① 今は保存
                    vm.showActionPrompt = false
                    showActionPromptLocal = false
                    saveTapped()
                },
                onManualInput: {
                    // ② 自分で入力
                    vm.showActionPrompt = false
                    showActionPromptLocal = false
                },
                onPickPOI: {
                    // ③ 周辺から
                    vm.showActionPrompt = false
                    showActionPromptLocal = false
                    Task { await vm.openPOI() }
                }
            )
            .presentationDetents([.large, .large])
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .onDisappear {
            vm.discardPhotoEditingIfNeeded()
        }
    }

    // MARK: - Form共通
    private var formContent: some View {
        Form {
            Section("編集") {
                HStack(spacing: 8) {
                    TextField("タイトル", text: $vm.title)
                        .focused($focusedField, equals: .title)

                    // 施設情報ボタン（共通）
                    FacilityInfoButton(
                        name: vm.facilityName,
                        address: vm.facilityAddress,
                        phone: nil,                    // あれば vm.facilityPhone
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
                            Text("メモ").foregroundStyle(.secondary)
                                .padding(.top, 8).padding(.leading, 5)
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
            }

        }
    }


    // MARK: - Actions
    private var disableSave: Bool {
        switch mode {
        case .create:
            return locating || (vm.latitude == 0 && vm.longitude == 0)
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
        labelOptions = ((try? AppContainer.shared.repo.allLabels()) ?? [])
            .filter { !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .sorted { $0.name.localizedCompare($1.name) == .orderedAscending }

        groupOptions = ((try? AppContainer.shared.repo.allGroups()) ?? [])
            .filter { !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .sorted { $0.name.localizedCompare($1.name) == .orderedAscending }

        // create だけ即測位
        if case .create = mode {
            locating = true
            await vm.requestLocation()
            locating = false
            await MainActor.run { vm.presentPostKokokitaPromptIfReady() }
            showActionPromptLocal = vm.showActionPrompt
        }
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
    
    private struct EditFooterBar: View {
        var onSave: () -> Void
        var onPoi: () -> Void
        var saveDisabled: Bool

        var body: some View {
            // TabBarやホームインジケータを避けつつ、上に固定表示される
            HStack(spacing: 12) {
                // 保存（プライマリ）
                Button {
                    onSave()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                        Text("保存")
                    }
                    .frame(maxWidth: .infinity, minHeight: 32)
                }
                .buttonStyle(BorderedProminentButtonStyle())
                .controlSize(.large)
                .buttonBorderShape(.roundedRectangle(radius: 14))
                .disabled(saveDisabled)
                
                // ココカモ？
                Button {
                    onPoi()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass.circle.fill")
                        Text("ココカモ？")
                    }
                    .frame(maxWidth: .infinity, minHeight: 32)
                }
                .buttonStyle(BorderedButtonStyle())
                .controlSize(.large)
                .buttonBorderShape(.roundedRectangle(radius: 14))
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 8) // 安全地帯上での余白
            .background(.regularMaterial) // 半透明で上に敷く
        }
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
