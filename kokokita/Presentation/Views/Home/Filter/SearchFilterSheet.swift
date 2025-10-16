//
//  Untitled.swift
//  kokokita
//
//  Created by 橋本遼 on 2025/09/29.
//

// SearchFilterSheet.swift
import SwiftUI
import MapKit

struct SearchFilterSheet: View {
    @ObservedObject var vm: HomeViewModel
    var onClose: () -> Void

    // 編集用ローカル状態（キャンセルで破棄できるように別持ち）
    @State private var titleQuery: String = ""
    @State private var useDateRange: Bool = false
    @State private var dateFrom: Date = Date()
    @State private var dateTo: Date = Date()

    @State private var selectedLabel: UUID? = nil
    @State private var selectedGroup: UUID? = nil

    @State private var titleDraft: String = ""
    @State private var debounceTask: Task<Void, Never>? = nil
    
    private func resetLocalFields() {
        titleQuery = ""
        selectedLabel = nil
        selectedGroup = nil
        useDateRange = false
        dateFrom = Date()
        dateTo   = Date()
    }
    
    var body: some View {
        Form {
            Section("キーワード") {
                TextField("タイトルまたは住所に含む語", text: $titleDraft)
                    .textInputAutocapitalization(.never)
                    .submitLabel(.done)
                    .onChange(of: titleDraft) { new in
                        // 入力中は 250ms デバウンスで反映
                        debounceTask?.cancel()
                        debounceTask = Task { @MainActor in
                            try? await Task.sleep(nanoseconds: 250_000_000)
                            vm.titleQuery = new.trimmingCharacters(in: .whitespacesAndNewlines)
                            vm.applyAndReload()
                        }
                    }
            }

            Section("期間") {
                Toggle("日付で絞り込む", isOn: $useDateRange)
                    .onChange(of: useDateRange) { on in
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

            Section("ラベル") {
                Picker(selection: $vm.labelFilter) {
                    Text("指定なし").tag(UUID?.none)
                    ForEach(
                        vm.labels
                            .filter { !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                            .sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
                    ) { t in
                        Text(t.name).tag(Optional(t.id))
                    }
                } label: { EmptyView() }
                .labelsHidden()
                .onChange(of: vm.labelFilter) { _ in vm.applyAndReload() }
            }

            Section("グループ") {
                Picker(selection: $vm.groupFilter) {
                    Text("指定なし").tag(UUID?.none)
                    ForEach(
                        vm.groups
                            .filter { !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                            .sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
                    ) { t in
                        Text(t.name).tag(Optional(t.id))
                    }
                } label: { EmptyView() }
                .labelsHidden()
                .onChange(of: vm.groupFilter) { _ in vm.applyAndReload() }
            }

            Section("メンバー") {
                Picker(selection: $vm.memberFilter) {
                    Text("指定なし").tag(UUID?.none)
                    ForEach(
                        vm.members
                            .filter { !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                            .sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
                    ) { t in
                        Text(t.name).tag(Optional(t.id))
                    }
                } label: { EmptyView() }
                .labelsHidden()
                .onChange(of: vm.memberFilter) { _ in vm.applyAndReload() }
            }

            Section("施設カテゴリ") {
                Picker(selection: $vm.categoryFilter) {
                    Text("指定なし").tag(String?.none)
                    ForEach(MKPointOfInterestCategory.allCases, id: \.rawValue) { category in
                        Text(category.japaneseName).tag(Optional(category.rawValue))
                    }
                } label: { EmptyView() }
                .labelsHidden()
                .onChange(of: vm.categoryFilter) { _ in vm.applyAndReload() }
            }
        }
        .navigationTitle("検索")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("閉じる") { onClose() }
            }
            ToolbarItem(placement: .primaryAction) {
                Button("クリア") {
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
            titleDraft = vm.titleQuery // ← 追加
            selectedLabel = vm.labelFilter
            selectedGroup = vm.groupFilter

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

    // 時刻丸め（比較の安定化）
    private func stripTime(_ d: Date) -> Date {
        Calendar.current.startOfDay(for: d)
    }
}
