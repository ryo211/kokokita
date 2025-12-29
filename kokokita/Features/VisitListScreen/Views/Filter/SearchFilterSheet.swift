import SwiftUI
import MapKit

struct SearchFilterSheet: View {
    @Bindable var store: VisitListStore
    var onClose: () -> Void

    private var vm: VisitListStore { store }

    // 編集用ローカル状態（キャンセルで破棄できるように別持ち）
    @State private var titleQuery: String = ""
    @State private var useDateRange: Bool = false
    @State private var dateFrom: Date = Date()
    @State private var dateTo: Date = Date()

    @State private var titleDraft: String = ""
    @State private var debounceTask: Task<Void, Never>? = nil

    // シート表示状態
    @State private var showLabelPicker = false
    @State private var showGroupPicker = false
    @State private var showMemberPicker = false
    @State private var showCategoryPicker = false

    private func resetLocalFields() {
        titleQuery = ""
        useDateRange = false
        dateFrom = Date()
        dateTo   = Date()
    }
    
    var body: some View {
        Form {
            keywordSection
            periodSection
            labelSection
            groupSection
            memberSection
            categorySection
        }
        .navigationTitle(L.SearchFilter.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(L.Common.cancel) { onClose() }
            }
            ToolbarItem(placement: .primaryAction) {
                Button(L.Common.clear) {
                    debounceTask?.cancel()
                    vm.clearAllFilters()
                    titleDraft = ""
                    useDateRange = false
                    vm.applyAndReload()
                }
                .fontWeight(.regular)
            }
        }
        .onAppear {
            // 既存値を編集用に反映
            titleQuery = vm.titleQuery
            titleDraft = vm.titleQuery

            if let f = vm.dateFrom, let t = vm.dateTo {
                useDateRange = true
                dateFrom = f
                dateTo = t
            } else {
                useDateRange = false
                dateFrom = Date()
                dateTo = Date()
            }
        }
        .environment(\.locale, Locale(identifier: "ja_JP"))               // 日本語UI
        .environment(\.calendar, Calendar(identifier: .gregorian))        // ←西暦のまま
        // 和暦にしたい場合は上を .japanese に変更

    }

    // MARK: - Form Sections

    private var keywordSection: some View {
        Section(L.SearchFilter.sectionKeyword) {
            TextField(L.SearchFilter.titleOrAddressPlaceholder, text: $titleDraft)
                .textInputAutocapitalization(.never)
                .submitLabel(.done)
                .onChange(of: titleDraft) { _, new in
                    // 入力中は 250ms デバウンスで反映
                    debounceTask?.cancel()
                    debounceTask = Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 250_000_000)
                        vm.titleQuery = new.trimmingCharacters(in: .whitespacesAndNewlines)
                        vm.applyAndReload()
                    }
                }
        }
    }

    private var periodSection: some View {
        Section(L.SearchFilter.sectionPeriod) {
            Toggle(L.SearchFilter.filterByDate, isOn: $useDateRange)
                .onChange(of: useDateRange) { _, on in
                    if on {
                        if vm.dateFrom == nil { vm.dateFrom = stripTime(Date()) }
                        if vm.dateTo   == nil { vm.dateTo   = stripTime(Date()) }
                    } else {
                        vm.dateFrom = nil
                        vm.dateTo   = nil
                    }
                    vm.applyAndReload()
                }

            if useDateRange {
                DatePicker("From", selection: Binding(
                    get: { vm.dateFrom ?? stripTime(Date()) },
                    set: { vm.dateFrom = stripTime($0); vm.applyAndReload() }
                ), displayedComponents: .date)

                DatePicker("To", selection: Binding(
                    get: { vm.dateTo ?? stripTime(Date()) },
                    set: {
                        let new = stripTime($0)
                        // 逆転防止：To < From のときは From を合わせる
                        if let f = vm.dateFrom, new < f { vm.dateFrom = new }
                        vm.dateTo = new
                        vm.applyAndReload()
                    }
                ), displayedComponents: .date)
            }
        }
    }

    private var labelSection: some View {
        Section(L.SearchFilter.sectionLabel) {
            Button {
                showLabelPicker = true
            } label: {
                HStack {
                    Label("選択", systemImage: "tag")
                        .foregroundStyle(.purple)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .sheet(isPresented: $showLabelPicker) {
                FilterLabelPickerSheet(
                    selectedIds: $store.labelFilters,
                    labelOptions: vm.labels,
                    isPresented: $showLabelPicker,
                    onDismiss: { vm.applyAndReload() }
                )
            }

            if !store.labelFilters.isEmpty {
                let lmap = Dictionary(uniqueKeysWithValues: vm.labels.map { ($0.id, $0.name) })
                FlowRow(spacing: 6, rowSpacing: 6) {
                    ForEach(store.labelFilters, id: \.self) { lid in
                        if let name = lmap[lid]?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
                            Chip(name, kind: .label) {
                                store.labelFilters.removeAll { $0 == lid }
                                vm.applyAndReload()
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    private var groupSection: some View {
        Section(L.SearchFilter.sectionGroup) {
            Button {
                showGroupPicker = true
            } label: {
                HStack {
                    Label("選択", systemImage: "folder")
                        .foregroundStyle(.teal)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .sheet(isPresented: $showGroupPicker) {
                FilterGroupPickerSheet(
                    selectedIds: $store.groupFilters,
                    groupOptions: vm.groups,
                    isPresented: $showGroupPicker,
                    onDismiss: { vm.applyAndReload() }
                )
            }

            if !store.groupFilters.isEmpty {
                let gmap = Dictionary(uniqueKeysWithValues: vm.groups.map { ($0.id, $0.name) })
                FlowRow(spacing: 6, rowSpacing: 6) {
                    ForEach(store.groupFilters, id: \.self) { gid in
                        if let name = gmap[gid]?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
                            Chip(name, kind: .group) {
                                store.groupFilters.removeAll { $0 == gid }
                                vm.applyAndReload()
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    private var memberSection: some View {
        Section(L.SearchFilter.sectionMember) {
            Button {
                showMemberPicker = true
            } label: {
                HStack {
                    Label("選択", systemImage: "person")
                        .foregroundStyle(.blue)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .sheet(isPresented: $showMemberPicker) {
                FilterMemberPickerSheet(
                    selectedIds: $store.memberFilters,
                    memberOptions: vm.members,
                    isPresented: $showMemberPicker,
                    onDismiss: { vm.applyAndReload() }
                )
            }

            if !store.memberFilters.isEmpty {
                let mmap = Dictionary(uniqueKeysWithValues: vm.members.map { ($0.id, $0.name) })
                FlowRow(spacing: 6, rowSpacing: 6) {
                    ForEach(store.memberFilters, id: \.self) { mid in
                        if let name = mmap[mid]?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
                            Chip(name, kind: .member) {
                                store.memberFilters.removeAll { $0 == mid }
                                vm.applyAndReload()
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    private var categorySection: some View {
        Section(L.SearchFilter.sectionCategory) {
            Button {
                showCategoryPicker = true
            } label: {
                HStack {
                    Text("選択")
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .sheet(isPresented: $showCategoryPicker) {
                FilterCategoryPickerSheet(
                    selectedCategories: $store.categoryFilters,
                    isPresented: $showCategoryPicker,
                    onDismiss: { vm.applyAndReload() }
                )
            }

            if !store.categoryFilters.isEmpty {
                FlowRow(spacing: 6, rowSpacing: 6) {
                    ForEach(store.categoryFilters, id: \.self) { catRaw in
                        let category = MKPointOfInterestCategory(rawValue: catRaw)
                        let name = category.localizedName
                        Chip(name, kind: .category) {
                            store.categoryFilters.removeAll { $0 == catRaw }
                            vm.applyAndReload()
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    // 時刻丸め（比較の安定化）
    private func stripTime(_ d: Date) -> Date {
        Calendar.current.startOfDay(for: d)
    }
}

// MARK: - Filter Label Picker Sheet
struct FilterLabelPickerSheet: View {
    @Binding var selectedIds: [UUID]
    let labelOptions: [LabelTag]
    @Binding var isPresented: Bool
    let onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(
                        labelOptions
                            .filter { !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                            .sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
                    ) { label in
                        Button {
                            if selectedIds.contains(label.id) {
                                selectedIds.removeAll { $0 == label.id }
                            } else {
                                selectedIds.append(label.id)
                            }
                        } label: {
                            HStack {
                                Text(label.name)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if selectedIds.contains(label.id) {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.blue)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(L.LabelManagement.selectTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(L.Common.done) {
                        isPresented = false
                        onDismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Filter Group Picker Sheet
struct FilterGroupPickerSheet: View {
    @Binding var selectedIds: [UUID]
    let groupOptions: [GroupTag]
    @Binding var isPresented: Bool
    let onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(
                        groupOptions
                            .filter { !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                            .sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
                    ) { group in
                        Button {
                            if selectedIds.contains(group.id) {
                                selectedIds.removeAll { $0 == group.id }
                            } else {
                                selectedIds.append(group.id)
                            }
                        } label: {
                            HStack {
                                Text(group.name)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if selectedIds.contains(group.id) {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.blue)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(L.GroupManagement.selectTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(L.Common.done) {
                        isPresented = false
                        onDismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Filter Member Picker Sheet
struct FilterMemberPickerSheet: View {
    @Binding var selectedIds: [UUID]
    let memberOptions: [MemberTag]
    @Binding var isPresented: Bool
    let onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(
                        memberOptions
                            .filter { !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                            .sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
                    ) { member in
                        Button {
                            if selectedIds.contains(member.id) {
                                selectedIds.removeAll { $0 == member.id }
                            } else {
                                selectedIds.append(member.id)
                            }
                        } label: {
                            HStack {
                                Text(member.name)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if selectedIds.contains(member.id) {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.blue)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(L.MemberManagement.selectTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(L.Common.done) {
                        isPresented = false
                        onDismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Filter Category Picker Sheet
struct FilterCategoryPickerSheet: View {
    @Binding var selectedCategories: [String]
    @Binding var isPresented: Bool
    let onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(MKPointOfInterestCategory.allCases, id: \.rawValue) { category in
                        Button {
                            if selectedCategories.contains(category.rawValue) {
                                selectedCategories.removeAll { $0 == category.rawValue }
                            } else {
                                selectedCategories.append(category.rawValue)
                            }
                        } label: {
                            HStack {
                                Text(category.localizedName)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if selectedCategories.contains(category.rawValue) {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.blue)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(L.Category.selectTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(L.Common.done) {
                        isPresented = false
                        onDismiss()
                    }
                }
            }
        }
    }
}
