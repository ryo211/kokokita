import SwiftUI
import MapKit

/// ココキタ選択シート（タクソノミーコピー用）
struct VisitCopyPickerSheet: View {
    @Binding var isPresented: Bool
    let onSelect: (VisitAggregate) -> Void

    @State private var visits: [VisitAggregate] = []
    @State private var isLoading = true

    // タクソノミー名前マップ
    @State private var labelMap: [UUID: String] = [:]
    @State private var groupMap: [UUID: String] = [:]
    @State private var memberMap: [UUID: String] = [:]

    private let repo = AppContainer.shared.repo

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if visits.isEmpty {
                    emptyStateView
                } else {
                    visitListView
                }
            }
            .navigationTitle(L.VisitEdit.selectVisitToCopy)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(L.Common.cancel) {
                        isPresented = false
                    }
                }
            }
            .task {
                await loadVisits()
            }
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: UIConstants.Spacing.medium) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            Text(L.EmptyState.noRecords)
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Visit List

    private var visitListView: some View {
        List {
            ForEach(visits) { visit in
                Button {
                    onSelect(visit)
                } label: {
                    visitRowView(visit: visit)
                }
                .buttonStyle(.plain)
            }
        }
        .listStyle(.plain)
    }

    // MARK: - Visit Row

    private func visitRowView(visit: VisitAggregate) -> some View {
        VStack(alignment: .leading, spacing: UIConstants.Spacing.small) {
            // タイムスタンプと住所
            HStack {
                Text(formatTimestamp(visit.visit.timestampUTC))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            Text(visit.details.resolvedAddress ?? "")
                .font(.footnote)
                .foregroundStyle(.secondary)

            // タイトルとカテゴリ
            if let title = visit.details.title, !title.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                    if let catRaw = visit.details.facilityCategory {
                        let category = MKPointOfInterestCategory(rawValue: catRaw)
                        Text(category.localizedName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // タクソノミー情報（チップで表示）
            let labelNames = visit.details.labelIds.compactMap { labelMap[$0] }
            let groupName = visit.details.groupId.flatMap { groupMap[$0] }
            let memberNames = visit.details.memberIds.compactMap { memberMap[$0] }

            if groupName != nil || !labelNames.isEmpty || !memberNames.isEmpty {
                FlowRow(spacing: 6, rowSpacing: 6) {
                    if let g = groupName {
                        Chip(g, kind: .group, size: .small, showRemoveButton: false)
                    }
                    ForEach(labelNames, id: \.self) { name in
                        Chip(name, kind: .label, size: .small, showRemoveButton: false)
                    }
                    ForEach(memberNames, id: \.self) { name in
                        Chip(name, kind: .member, size: .small, showRemoveButton: false)
                    }
                }
                .padding(.top, 2)
            }
        }
        .padding(.vertical, UIConstants.Spacing.extraSmall)
    }

    // MARK: - Data Loading

    private func loadVisits() async {
        isLoading = true
        defer { isLoading = false }

        do {
            // タクソノミーの名前マップを先に取得
            let labels = try repo.allLabels()
            let groups = try repo.allGroups()
            let members = try repo.allMembers()

            labelMap = Dictionary(uniqueKeysWithValues: labels.map { ($0.id, $0.name) })
            groupMap = Dictionary(uniqueKeysWithValues: groups.map { ($0.id, $0.name) })
            memberMap = Dictionary(uniqueKeysWithValues: members.map { ($0.id, $0.name) })

            // 最新の訪問記録を取得（フィルターなしで全件取得）
            let allVisits = try repo.fetchAll(
                filterLabel: nil,
                filterGroup: nil,
                titleQuery: nil,
                dateFrom: nil,
                dateToExclusive: nil
            )
            // 日付順、降順でソート
            visits = allVisits.sorted { $0.visit.timestampUTC > $1.visit.timestampUTC }
        } catch {
            // エラーが発生しても空のリストを表示
            visits = []
        }
    }

    // MARK: - Formatters

    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale.current
        return formatter.string(from: date)
    }
}
