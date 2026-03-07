import SwiftUI
import MapKit
import CoreLocation

// コース詳細画面（地図＋スポット同期リスト）
struct CourseDetailView: View {
    // IDを別途保持することでナビゲーション遷移時のキャプチャに依存しない
    private let courseId: UUID
    var showTitle: Bool = true
    @State private var course: Course

    @State private var selectedSpotId: UUID? = nil
    @State private var cameraPosition: MapCameraPosition
    @State private var showSummary = false

    init(course: Course, showTitle: Bool = true, initialSelectedSpotId: UUID? = nil) {
        self.showTitle = showTitle
        self.courseId = course.id
        _course = State(initialValue: course)
        _selectedSpotId = State(initialValue: initialSelectedSpotId)
        if let spotId = initialSelectedSpotId,
           let spot = course.spots.first(where: { $0.id == spotId }) {
            let courseRegion = CourseDetailView.fitRegion(for: course.spots)
            let span = CourseDetailView.spotSpan(from: courseRegion)
            _cameraPosition = State(initialValue: .region(
                MKCoordinateRegion(
                    center: CLLocationCoordinate2D(latitude: spot.latitude, longitude: spot.longitude),
                    span: span
                )
            ))
        } else {
            _cameraPosition = State(initialValue: .region(CourseDetailView.fitRegion(for: course.spots)))
        }
    }

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                // 地図エリア（55%）
                mapArea
                    .frame(height: geo.size.height * 0.55)

                Divider()

                // スポットリストエリア（45%）
                spotListArea
            }
        }
        .navigationTitle(showTitle ? course.title : "")
        .navigationBarTitleDisplayMode(.inline)
        // 画面表示のたびに最新データを取得（CoreDataキャッシュを確実に反映）
        .task { reloadCourse() }
        .onReceive(NotificationCenter.default.publisher(for: .courseChanged)) { _ in
            // チェックイン通知受信時も即時更新
            reloadCourse()
        }
        .toolbar {
            if course.summary != nil {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showSummary = true
                    } label: {
                        Image(systemName: "info.circle")
                    }
                }
            }
        }
        .sheet(isPresented: $showSummary) {
            CourseSummarySheet(course: course)
        }
    }

    // MARK: - 地図エリア

    private var mapArea: some View {
        Map(position: $cameraPosition) {
            ForEach(Array(course.spots.enumerated()), id: \.element.id) { index, spot in
                Annotation(
                    "",
                    coordinate: CLLocationCoordinate2D(latitude: spot.latitude, longitude: spot.longitude),
                    anchor: .center
                ) {
                    SpotPinView(
                        orderNumber: index + 1,
                        isCheckedIn: spot.isCheckedIn,
                        isSelected: selectedSpotId == spot.id
                    )
                    .onTapGesture {
                        focusSpot(spot)
                    }
                }
            }
        }
        .mapStyle(.standard(emphasis: .muted))
        .mapControls {
            MapCompass()
            MapScaleView()
        }
        .overlay(alignment: .bottomTrailing) {
            progressBadge
                .padding([.trailing, .bottom], 12)
        }
    }

    // MARK: - 進捗バッジ（地図右下オーバーレイ）

    private var progressBadge: some View {
        Group {
            if course.isCompleted {
                // 完了バッジ
                Label(L.Course.completed, systemImage: "checkmark.seal.fill")
                    .font(.caption.bold())
                    .foregroundStyle(.indigo)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial, in: Capsule())
            } else {
                // 通常の進捗バッジ
                HStack(spacing: 6) {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 8))
                        .foregroundStyle(.indigo)
                    Text("\(course.checkedInCount)/\(course.totalSpotCount)")
                        .font(.caption.bold())
                        .foregroundStyle(.primary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial, in: Capsule())
            }
        }
    }

    // MARK: - スポットリスト

    /// グローバルスポット番号（全セクション横断、地図ピンと対応）
    private var globalSpotIndex: [UUID: Int] {
        Dictionary(uniqueKeysWithValues: course.spots.enumerated().map { ($1.id, $0) })
    }

    private var spotListArea: some View {
        ScrollViewReader { proxy in
            ScrollView {
                // LazyVStack は scrollTo 非対応のため VStack を使用
                VStack(spacing: 0) {
                    let indexMap = globalSpotIndex
                    ForEach(course.sections) { section in
                        // セクションヘッダー（名前付きセクションのみ表示）
                        if section.hasName {
                            CourseSectionHeaderView(section: section)
                        }

                        ForEach(section.spots) { spot in
                            SpotListRowView(
                                spot: spot,
                                orderNumber: (indexMap[spot.id] ?? 0) + 1,
                                isSelected: selectedSpotId == spot.id
                            )
                            .id(spot.id)
                            .onTapGesture {
                                focusSpot(spot)
                            }

                            // セクション内スポット間の区切り線（最後のスポット以外）
                            if spot.id != section.spots.last?.id {
                                Divider()
                                    .padding(.leading, 52)
                            }
                        }

                        // セクション間の区切り（最後のセクション以外）
                        if section.id != course.sections.last?.id {
                            Divider()
                        }
                    }
                }
            }
            .onChange(of: selectedSpotId) { _, newId in
                if let id = newId {
                    withAnimation {
                        proxy.scrollTo(id, anchor: .top)
                    }
                }
            }
            .task {
                // 初期選択スポットがある場合、レンダリング完了後にスクロール
                guard let id = selectedSpotId else { return }
                try? await Task.sleep(nanoseconds: 150_000_000) // 0.15秒待機
                withAnimation {
                    proxy.scrollTo(id, anchor: .top)
                }
            }
        }
    }

    // MARK: - データ再取得

    private func reloadCourse() {
        if let updated = try? AppContainer.shared.courseRepo.fetch(id: courseId) {
            course = updated
        }
    }

    // MARK: - フォーカス同期

    private func focusSpot(_ spot: CourseSpot) {
        withAnimation(.easeInOut(duration: 0.3)) {
            if selectedSpotId == spot.id {
                // 同じスポット再タップ → 選択解除＋全スポット表示
                selectedSpotId = nil
                cameraPosition = .region(CourseDetailView.fitRegion(for: course.spots))
            } else {
                selectedSpotId = spot.id
                let courseRegion = CourseDetailView.fitRegion(for: course.spots)
                let span = CourseDetailView.spotSpan(from: courseRegion)
                cameraPosition = .region(
                    MKCoordinateRegion(
                        center: CLLocationCoordinate2D(latitude: spot.latitude, longitude: spot.longitude),
                        span: span
                    )
                )
            }
        }
    }

    // MARK: - 全スポットフィット計算

    /// コース全体スパンの 1/10 をスポットフォーカス時のズームスパンとして返す。
    /// 最小 0.01°（約1km）、最大 0.08°（約9km）にクランプ。
    static func spotSpan(from courseRegion: MKCoordinateRegion) -> MKCoordinateSpan {
        let delta = max(0.01, min(courseRegion.span.latitudeDelta / 10, 0.5))
        return MKCoordinateSpan(latitudeDelta: delta, longitudeDelta: delta)
    }

    static func fitRegion(for spots: [CourseSpot]) -> MKCoordinateRegion {
        guard !spots.isEmpty else {
            // 0件 → 日本中心（span 10°）
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 36.5, longitude: 136.0),
                span: MKCoordinateSpan(latitudeDelta: 10.0, longitudeDelta: 10.0)
            )
        }

        guard spots.count > 1 else {
            // 1件 → span 0.02°
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: spots[0].latitude, longitude: spots[0].longitude),
                span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
            )
        }

        // 複数件 → バウンディングボックス * 1.5、最小 0.01°
        let lats = spots.map { $0.latitude }
        let lons = spots.map { $0.longitude }
        let minLat = lats.min()!
        let maxLat = lats.max()!
        let minLon = lons.min()!
        let maxLon = lons.max()!

        let centerLat = (minLat + maxLat) / 2
        let centerLon = (minLon + maxLon) / 2
        let spanLat = max((maxLat - minLat) * 1.5, 0.01)
        let spanLon = max((maxLon - minLon) * 1.5, 0.01)

        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon),
            span: MKCoordinateSpan(latitudeDelta: spanLat, longitudeDelta: spanLon)
        )
    }
}

// MARK: - セクションヘッダー

private struct CourseSectionHeaderView: View {
    let section: CourseSection

    var body: some View {
        HStack {
            Text(section.name)
                .font(.subheadline.bold())
                .foregroundStyle(.primary)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(uiColor: .secondarySystemBackground))
    }
}

// MARK: - 地図ピンビュー

private struct SpotPinView: View {
    let orderNumber: Int
    let isCheckedIn: Bool
    let isSelected: Bool

    private var pinColor: Color { isCheckedIn ? .indigo : Color(uiColor: .systemGray3) }
    private var size: CGFloat { isSelected ? 18 : 14 }

    var body: some View {
        ZStack {
            // 縁（通常: 白 / 選択: オレンジ）+ 影でピンを浮かせる
            Circle()
                .fill(isSelected ? Color.indigo : .white)
                .frame(width: size + 5, height: size + 5)
                .shadow(color: .black.opacity(0.35), radius: 4, x: 0, y: 2)

            // ピン本体
            Circle()
                .fill(pinColor)
                .frame(width: size, height: size)

            // 番号ラベル
            Text("\(orderNumber)")
                .font(.system(size: isSelected ? 8 : 6, weight: .bold))
                .foregroundStyle(.white)
        }
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}

// MARK: - スポットリスト行

private struct SpotListRowView: View {
    let spot: CourseSpot
    let orderNumber: Int
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 0) {
            // メイン行
            HStack(spacing: 12) {
                // 番号バッジ
                ZStack {
                    Circle()
                        .fill(spot.isCheckedIn ? Color.indigo : Color(uiColor: .systemGray4))
                        .frame(width: 32, height: 32)
                    Text("\(orderNumber)")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(spot.name)
                            .font(.body)

                        if spot.isCheckedIn {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.body)
                                .foregroundStyle(Color.indigo)
                        }
                    }

                    if let desc = spot.spotDescription {
                        Text(desc)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            // 展開詳細（選択時のみ）
            if isSelected {
                SpotDetailExpandedView(spot: spot)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(isSelected ? Color.indigo.opacity(0.07) : Color.clear)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

// MARK: - スポット詳細展開ビュー

private struct SpotDetailExpandedView: View {
    let spot: CourseSpot
    @State private var linkedVisits: [VisitAggregate] = []
    @State private var labelMap: [UUID: String] = [:]
    @State private var groupMap: [UUID: String] = [:]
    @State private var memberMap: [UUID: String] = [:]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 住所（未設定の場合はその旨を表示）
            Label(
                spot.address ?? L.Course.noAddress,
                systemImage: "mappin"
            )
            .font(.caption)
            .foregroundStyle(spot.address != nil ? .secondary : Color(uiColor: .tertiaryLabel))
            .padding(.leading, 60)
            .padding(.trailing, 16)

            // 訪問日（未訪問の場合はその旨を表示）
            if let date = spot.firstCheckedInAt {
                Label(
                    L.Course.visitedOn(date.formatted(date: .long, time: .omitted)),
                    systemImage: "calendar"
                )
                .font(.caption)
                .foregroundStyle(.indigo)
                .padding(.leading, 60)
                .padding(.trailing, 16)
            } else {
                Label(L.Course.notVisited, systemImage: "calendar")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 60)
                    .padding(.trailing, 16)
            }

            // 紐づいた記録カード横スクロール（紐づきがある場合のみ）
            if !linkedVisits.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(linkedVisits, id: \.visit.id) { aggregate in
                            NavigationLink {
                                VisitDetailScreen(
                                    data: toDetailData(aggregate),
                                    visitId: aggregate.id,
                                    onBack: {},
                                    onEdit: {},
                                    onShare: {},
                                    onDelete: {
                                        try? AppContainer.shared.repo.delete(id: aggregate.id)
                                        NotificationCenter.default.post(name: .visitsChanged, object: nil)
                                        reloadLinkedVisits()
                                    },
                                    onUpdate: {
                                        NotificationCenter.default.post(name: .visitsChanged, object: nil)
                                        reloadLinkedVisits()
                                    },
                                    onMapTap: nil
                                )
                            } label: {
                                CheckInVisitCard(aggregate: aggregate)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.leading, 60)
                    .padding(.trailing, 16)
                    .padding(.bottom, 4)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 10)
        .task(id: spot.id) {
            await loadData()
        }
        .onReceive(NotificationCenter.default.publisher(for: .visitsChanged)) { _ in
            reloadLinkedVisits()
        }
    }

    // MARK: - データ読み込み

    private func loadData() async {
        let repo = AppContainer.shared.repo
        labelMap = (try? repo.allLabels())?.reduce(into: [:]) { $0[$1.id] = $1.name } ?? [:]
        groupMap = (try? repo.allGroups())?.reduce(into: [:]) { $0[$1.id] = $1.name } ?? [:]
        memberMap = (try? repo.allMembers())?.reduce(into: [:]) { $0[$1.id] = $1.name } ?? [:]
        reloadLinkedVisits()
    }

    private func reloadLinkedVisits() {
        guard !spot.visitIds.isEmpty else {
            linkedVisits = []
            return
        }
        linkedVisits = spot.visitIds.compactMap { id in
            try? AppContainer.shared.repo.get(by: id)
        }
    }

    // MARK: - VisitDetailData 構築

    private func toDetailData(_ agg: VisitAggregate) -> VisitDetailData {
        let title: String = {
            let t = agg.details.title?.trimmingCharacters(in: .whitespacesAndNewlines)
            if let t, !t.isEmpty { return t }
            if let f = agg.details.facilityName, !f.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return f }
            return L.Home.noTitle
        }()

        let coord: CLLocationCoordinate2D? = {
            let lat = agg.visit.latitude
            let lon = agg.visit.longitude
            guard lat != 0 || lon != 0 else { return nil }
            return .init(latitude: lat, longitude: lon)
        }()

        return VisitDetailData(
            title: title,
            labels: agg.details.labelIds.compactMap { labelMap[$0] },
            group: agg.details.groupId.flatMap { groupMap[$0] },
            members: agg.details.memberIds.compactMap { memberMap[$0] },
            timestamp: agg.visit.timestampUTC,
            address: agg.details.resolvedAddress ?? agg.details.facilityAddress,
            coordinate: coord,
            memo: agg.details.comment,
            facility: FacilityInfo(
                name: agg.details.facilityName,
                address: agg.details.facilityAddress,
                phone: nil
            ),
            facilityCategory: agg.details.facilityCategory,
            photoPaths: agg.details.photoPaths,
            isManualEntry: agg.visit.isManualEntry
        )
    }
}

// MARK: - コース概要シート

private struct CourseSummarySheet: View {
    let course: Course
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(course.summary ?? "")
                    .font(.body)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
            .navigationTitle(course.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L.Common.close) { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
