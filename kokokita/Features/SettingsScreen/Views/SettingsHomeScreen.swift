import SwiftUI

enum TaxonomyTab: String, CaseIterable {
    case label
    case member
    case group
    case trash

    var title: String {
        switch self {
        case .label: return L.Settings.editLabels
        case .group: return L.Settings.editGroups
        case .member: return L.Settings.editMembers
        case .trash: return L.Trash.title
        }
    }

    var icon: String {
        switch self {
        case .label: return "tag"
        case .group: return "airplane"
        case .member: return "person"
        case .trash: return "trash"
        }
    }

    var showAddButton: Bool {
        self != .trash
    }
}

struct SettingsHomeScreen: View {
    @State private var selectedTab: TaxonomyTab = .label
    @State private var showLabelCreate = false
    @State private var showGroupCreate = false
    @State private var showMemberCreate = false
    @State private var labelCount: Int = 0
    @State private var groupCount: Int = 0
    @State private var memberCount: Int = 0
    @State private var trashCount: Int = 0

    private let repo = AppContainer.shared.repo

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                // 左側：縦型タブバー
                verticalTabBar
                    .frame(width: geometry.size.width * 0.18)

                Divider()

                // 右側：選択されたタクソノミーの一覧画面
                VStack(spacing: 0) {
                    // ヘッダー部分
                    HStack {
                        HStack(spacing: 8) {
                            Image(systemName: selectedTab.icon)
                                .font(.title2)
                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text(selectedTab.title)
                                    .font(.title2)
                                    .fontWeight(.bold)
                                Text("(\(currentCount))")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                            }
                        }
                        .foregroundStyle(selectedTab == .trash ? Color.secondary : Color.accentColor)
                        Spacer()
                        if selectedTab.showAddButton {
                            Button {
                                switch selectedTab {
                                case .label:
                                    showLabelCreate = true
                                case .group:
                                    showGroupCreate = true
                                case .member:
                                    showMemberCreate = true
                                case .trash:
                                    break
                                }
                            } label: {
                                Image(systemName: "plus")
                                    .font(.title3)
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                    .background(Color(.systemBackground))

                    // 一覧画面
                    taxonomyListView
                        .frame(maxWidth: .infinity)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .task {
            loadCounts()
        }
        .onReceive(NotificationCenter.default.publisher(for: .taxonomyChanged)) { _ in
            loadCounts()
        }
        .onReceive(NotificationCenter.default.publisher(for: .visitsChanged)) { _ in
            loadCounts()
        }
        .onChange(of: showLabelCreate) { _, isShowing in
            if !isShowing { loadCounts() }
        }
        .onChange(of: showGroupCreate) { _, isShowing in
            if !isShowing { loadCounts() }
        }
        .onChange(of: showMemberCreate) { _, isShowing in
            if !isShowing { loadCounts() }
        }
    }

    // MARK: - Computed Properties

    private var currentCount: Int {
        switch selectedTab {
        case .label: return labelCount
        case .group: return groupCount
        case .member: return memberCount
        case .trash: return trashCount
        }
    }

    // MARK: - Helper Methods

    private func loadCounts() {
        do {
            labelCount = try repo.allLabels().count
            groupCount = try repo.allGroups().count
            memberCount = try repo.allMembers().count
            trashCount = try repo.countTrashed()
        } catch {
            Logger.error("Failed to load taxonomy counts", error: error)
        }
    }

    // MARK: - Vertical Tab Bar

    private var verticalTabBar: some View {
        VStack(spacing: 0) {
            // ヘッダーと同じ高さの余白
            Color.clear
                .frame(height: 57)

            ForEach(TaxonomyTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.interpolatingSpring(stiffness: 150, damping: 18)) {
                        selectedTab = tab
                    }
                } label: {
                    VStack(spacing: 4) {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 22))
                            // ゴミ箱タブのバッジ
                            if tab == .trash && trashCount > 0 {
                                Text("\(min(trashCount, 99))")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 2)
                                    .background(Color.red)
                                    .clipShape(Capsule())
                                    .offset(x: 10, y: -6)
                            }
                        }
                        Text(tab.title)
                            .font(.caption2)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .foregroundStyle(selectedTab == tab ? (tab == .trash ? Color.red : Color.accentColor) : Color.secondary)
                    .background(
                        RoundedRectangle(cornerRadius: 0)
                            .fill(selectedTab == tab ? (tab == .trash ? Color.red.opacity(0.08) : Color.accentColor.opacity(0.08)) : Color.clear)
                    )
                }
                .buttonStyle(.plain)
                .frame(height: 80)
            }

            Spacer()
        }
        .background(Color(.systemGroupedBackground))
        .animation(.interpolatingSpring(stiffness: 150, damping: 18), value: selectedTab)
    }

    // MARK: - Taxonomy List View

    private var taxonomyListView: some View {
        ZStack {
            LabelListScreen(showCreate: $showLabelCreate)
                .opacity(selectedTab == .label ? 1 : 0)
                .zIndex(selectedTab == .label ? 1 : 0)

            GroupListScreen(showCreate: $showGroupCreate)
                .opacity(selectedTab == .group ? 1 : 0)
                .zIndex(selectedTab == .group ? 1 : 0)

            MemberListScreen(showCreate: $showMemberCreate)
                .opacity(selectedTab == .member ? 1 : 0)
                .zIndex(selectedTab == .member ? 1 : 0)

            TrashScreen()
                .opacity(selectedTab == .trash ? 1 : 0)
                .zIndex(selectedTab == .trash ? 1 : 0)
        }
    }
}
