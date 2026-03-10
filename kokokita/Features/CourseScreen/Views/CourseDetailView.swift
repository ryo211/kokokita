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
    /// 遡り判定結果（この画面を開いたタイミングで表示）
    @State private var pendingRetroactiveResult: RetroactiveResultItem? = nil
    /// コース一覧ストア（遡り判定結果の取得に使用）
    var courseListStore: CourseListStore? = nil
    /// 現在地表示
    @State private var userLocation: CLLocationCoordinate2D? = nil
    @State private var isFetchingLocation = false
    /// 距離順ソート
    @State private var sortByDistance = false

    init(course: Course, showTitle: Bool = true, initialSelectedSpotId: UUID? = nil, courseListStore: CourseListStore? = nil) {
        self.showTitle = showTitle
        self.courseId = course.id
        self.courseListStore = courseListStore
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
                    .frame(height: geo.size.height * 0.50)

                // 進捗バー（地図とリストの間に固定表示）
                progressStrip

                Divider()

                // スポットリストエリア（45%）
                spotListArea
            }
        }
        .navigationTitle(showTitle ? course.title : "")
        .navigationBarTitleDisplayMode(.inline)
        // 画面表示のたびに最新データを取得（CoreDataキャッシュを確実に反映）
        .task {
            reloadCourse()
            // ハイライトを解除（詳細を開いたことで「新規」状態を消費）
            courseListStore?.newlyAddedCourseIds.remove(courseId)
            // everEnabled == false のコースは遡り判定未実施 → 直接実行
            if !course.everEnabled {
                await performRetroactiveRecognition()
            }
            // 現在地を初回取得
            await fetchUserLocation(zoomTo: false)
        }
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
        // 遡り判定結果シート（ストアシートとの競合を避けるためここに配置）
        .sheet(item: $pendingRetroactiveResult) { result in
            RetroactiveCheckInResultSheet(result: result)
        }
    }

    // MARK: - 遡り判定

    /// コース詳細を開いたタイミングで遡り判定を直接実行し、結果をシートで表示する
    private func performRetroactiveRecognition() async {
        let svc = AppContainer.shared.retroactiveService
        let repo = AppContainer.shared.courseRepo
        do {
            // 二重実行防止のため先にフラグをセット
            try repo.setEverEnabled(courseId)
            let result = try svc.recognize(for: courseId)
            guard let r = result, !r.checkedInSpots.isEmpty else { return }
            // コース情報を最新化してからシートを表示
            reloadCourse()
            pendingRetroactiveResult = RetroactiveResultItem(
                course: r.course,
                checkedInSpots: r.checkedInSpots
            )
        } catch {
            Logger.error("遡り判定エラー", error: error)
        }
    }

    // MARK: - 地図エリア

    private var mapArea: some View {
        Map(position: $cameraPosition) {
            ForEach(Array(course.spots.enumerated()), id: \.element.id) { index, spot in
                // 不正な座標のスポットはピンを立てない
                if spot.hasValidCoordinate {
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

                    // フォーカス中スポットのチェックイン有効範囲を表示
                    if selectedSpotId == spot.id, spot.hasValidCoordinate {
                        MapCircle(
                            center: CLLocationCoordinate2D(latitude: spot.latitude, longitude: spot.longitude),
                            radius: spot.recognitionRadiusMeters ?? course.recognitionRadiusMeters
                        )
                        .foregroundStyle(Color.indigo.opacity(0.08))
                        .stroke(Color.indigo.opacity(0.5), lineWidth: 1.5)
                    }
                }
            }

            // 現在地ピン
            if let coord = userLocation {
                Annotation("", coordinate: coord, anchor: .center) {
                    ZStack {
                        Circle()
                            .fill(.blue.opacity(0.15))
                            .frame(width: 26, height: 26)
                        Circle()
                            .fill(.blue)
                            .frame(width: 14, height: 14)
                            .overlay(Circle().stroke(.white, lineWidth: 2))
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
            locationButton
                .padding([.trailing, .bottom], 12)
        }
    }

    // MARK: - 進捗ストリップ（地図とリストの間に固定表示）

    private var progressStrip: some View {
        HStack(spacing: 8) {
            if course.isCompleted {
                Label(L.Course.completed, systemImage: "checkmark.seal.fill")
                    .font(.caption.bold())
                    .foregroundStyle(.indigo)
            } else {
                Text(L.Course.spotProgress(course.checkedInCount, course.totalSpotCount))
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                ProgressView(value: Double(course.checkedInCount), total: Double(course.totalSpotCount))
                    .tint(.indigo)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    // MARK: - 現在地ボタン（地図右下）

    private var locationButton: some View {
        Button {
            Task { await fetchUserLocation(zoomTo: true) }
        } label: {
            ZStack {
                Circle()
                    .fill(.regularMaterial)
                    .frame(width: 36, height: 36)
                    .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
                if isFetchingLocation {
                    ProgressView().controlSize(.small)
                } else {
                    Image(systemName: userLocation != nil ? "location.fill" : "location")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(userLocation != nil ? Color.blue : Color.secondary)
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - スポットリスト

    /// グローバルスポット番号（全セクション横断、地図ピンと対応）
    private var globalSpotIndex: [UUID: Int] {
        Dictionary(uniqueKeysWithValues: course.spots.enumerated().map { ($1.id, $0) })
    }

    private var spotListArea: some View {
        VStack(spacing: 0) {
            // ソートヘッダー
            HStack(spacing: 8) {
                SortChip(label: L.Course.sortDefault, isSelected: !sortByDistance) {
                    sortByDistance = false
                }
                SortChip(label: L.Course.sortDistance, isSelected: sortByDistance) {
                    sortByDistance = true
                }
                .disabled(userLocation == nil)
                .opacity(userLocation == nil ? 0.4 : 1)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            Divider()

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 0) {
                        let indexMap = globalSpotIndex
                        if sortByDistance {
                            // 距離順フラットリスト（セクション無視）
                            let sorted = distanceSortedSpots
                            ForEach(sorted, id: \.spot.id) { item in
                                SpotListRowView(
                                    spot: item.spot,
                                    orderNumber: (indexMap[item.spot.id] ?? 0) + 1,
                                    isSelected: selectedSpotId == item.spot.id,
                                    distance: item.distance
                                )
                                .id(item.spot.id)
                                .onTapGesture { focusSpot(item.spot) }

                                if item.spot.id != sorted.last?.spot.id {
                                    Divider().padding(.leading, 52)
                                }
                            }
                        } else {
                            // デフォルト: セクション別
                            ForEach(course.sections) { section in
                                if section.hasName {
                                    CourseSectionHeaderView(section: section)
                                }
                                ForEach(section.spots) { spot in
                                    let distance: Double? = userLocation.map { loc in
                                        CLLocation(latitude: loc.latitude, longitude: loc.longitude)
                                            .distance(from: CLLocation(latitude: spot.latitude, longitude: spot.longitude))
                                    }
                                    SpotListRowView(
                                        spot: spot,
                                        orderNumber: (indexMap[spot.id] ?? 0) + 1,
                                        isSelected: selectedSpotId == spot.id,
                                        distance: distance
                                    )
                                    .id(spot.id)
                                    .onTapGesture { focusSpot(spot) }

                                    if spot.id != section.spots.last?.id {
                                        Divider().padding(.leading, 52)
                                    }
                                }
                                if section.id != course.sections.last?.id {
                                    Divider()
                                }
                            }
                        }
                    }
                }
                .onChange(of: selectedSpotId) { _, newId in
                    if let id = newId {
                        withAnimation { proxy.scrollTo(id, anchor: .top) }
                    }
                }
                .task {
                    guard let id = selectedSpotId else { return }
                    try? await Task.sleep(nanoseconds: 150_000_000)
                    withAnimation { proxy.scrollTo(id, anchor: .top) }
                }
            }
        }
    }

    /// 距離順にソートしたスポット一覧
    private var distanceSortedSpots: [(spot: CourseSpot, distance: Double?)] {
        course.spots.map { spot in
            let distance: Double? = userLocation.map { loc in
                CLLocation(latitude: loc.latitude, longitude: loc.longitude)
                    .distance(from: CLLocation(latitude: spot.latitude, longitude: spot.longitude))
            }
            return (spot, distance)
        }
        .sorted {
            ($0.distance ?? .infinity) < ($1.distance ?? .infinity)
        }
    }

    // MARK: - データ再取得

    private func reloadCourse() {
        if let updated = try? AppContainer.shared.courseRepo.fetch(id: courseId) {
            course = updated
        }
    }

    // MARK: - 現在地取得

    @MainActor
    private func fetchUserLocation(zoomTo: Bool) async {
        guard !isFetchingLocation else { return }
        isFetchingLocation = true
        defer { isFetchingLocation = false }
        do {
            let service = DefaultLocationService()
            let (location, _) = try await service.requestOneShotLocation(
                accuracy: kCLLocationAccuracyHundredMeters,
                timeout: 8.0
            )
            userLocation = location.coordinate
            if zoomTo {
                withAnimation(.easeInOut(duration: 0.5)) {
                    cameraPosition = .region(MKCoordinateRegion(
                        center: location.coordinate,
                        span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
                    ))
                }
            }
        } catch {
            Logger.warning("現在地取得失敗: \(error)")
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
                // 不正な座標の場合は選択状態だけ更新してカメラ移動はしない
                guard spot.hasValidCoordinate else { return }
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
        let spots = spots.filter { $0.hasValidCoordinate }
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

// MARK: - ソートチップ

private struct SortChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.caption.weight(isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? Color.white : Color.primary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(isSelected ? Color.indigo : Color.secondary.opacity(0.12), in: Capsule())
        }
        .buttonStyle(.plain)
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
    var distance: Double? = nil

    private var distanceText: String? {
        guard let d = distance else { return nil }
        return d < 1000 ? String(format: "%.0fm", d) : String(format: "%.1fkm", d / 1000)
    }

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

                if let text = distanceText {
                    Text(text)
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
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
            // 住所・訪問日（アイコン幅を固定してインデントを揃える）
            let iconWidth: CGFloat = 14
            HStack(alignment: .top, spacing: 6) {
                Image(systemName: "mappin.circle")
                    .font(.caption)
                    .frame(width: iconWidth)
                Text(spot.address ?? L.Course.noAddress)
                    .font(.caption)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(spot.address != nil ? Color.secondary : Color.secondary.opacity(0.5))
            .padding(.leading, 60)
            .padding(.trailing, 16)

            if let date = spot.firstCheckedInAt {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "calendar.circle")
                        .font(.caption)
                        .frame(width: iconWidth)
                    Text(L.Course.visitedOn(date.formatted(date: .long, time: .omitted)))
                        .font(.caption)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .foregroundStyle(Color.indigo)
                .padding(.leading, 60)
                .padding(.trailing, 16)
            } else {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "calendar.circle")
                        .font(.caption)
                        .frame(width: iconWidth)
                    Text(L.Course.notVisited)
                        .font(.caption)
                }
                .foregroundStyle(Color.secondary)
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
                VStack(alignment: .leading, spacing: 0) {
                    // カバー画像
                    if let urlStr = course.coverImageUrl, let url = URL(string: urlStr) {
                        AsyncImage(url: url) { phase in
                            if case .success(let image) = phase {
                                image
                                    .resizable()
                                    .scaledToFill()
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 200)
                                    .clipped()
                            } else {
                                Color.indigo.opacity(0.15)
                                    .frame(height: 200)
                            }
                        }
                    }

                    // 概要テキスト
                    if let summary = course.summary {
                        Text(summary)
                            .font(.body)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                    }
                }
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
