import SwiftUI
import CoreLocation

// MARK: - PostKokokitaConfirmationSheet

/// ココキタ保存後の確認シート
/// 保存直後に表示され、周辺施設の自動検索と編集・削除の選択肢を提供
struct PostKokokitaConfirmationSheet: View {
    let visitId: UUID
    let onEnterInfo: (UUID) -> Void
    let onViewDetail: (UUID) -> Void
    let onDelete: (UUID) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var visit: VisitAggregate?
    @State private var poiState: POISearchState = .idle
    @State private var nearbyVisits: [VisitAggregate] = []

    // 1%の確率でレア画像を表示
    private var logoImageName: String {
        Double.random(in: 0..<1) < 0.01 ? "kokokita_irodori" : "kokokita_irodori_blue"
    }

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // 固定ヘッダー部分（スクロールしない）
                VStack(spacing: 16) {
                    // 見出し
                    header
                        .padding(.top, 20)

                    // 基本情報（日付・住所）
                    if let visit = visit {
                        basicInfo(visit: visit)
                    }

                    // 地図
                    if let visit = visit {
                        mapSection(visit: visit, maxHeight: geometry.size.height * 0.3)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 16)

                // ココカモセクション全体（背景付き）
                VStack(spacing: 0) {
                    // ココカモセクションのヘッダー
                    VStack(alignment: .leading, spacing: 8) {
                        // ココカモセクションのタイトル
                        HStack(spacing: 6) {
                            Image(systemName: "building.2.crop.circle.fill")
                                .foregroundStyle(Color.accentColor)
                                .font(.title3)
                            Text(L.Confirmation.selectFacility)
                                .font(.headline)
                            Spacer()
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 12)
                    .padding(.bottom, 8)

                    // スクロール可能なココカモセクション
                    kokokamoScrollSection
                        .frame(maxHeight: .infinity)
                }
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(.systemGray5))
                )
                .padding(.horizontal, 8)

                // 下部ボタン（固定）
                bottomButtons
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.regularMaterial)
        )
        .presentationDragIndicator(.visible)
        .task {
            await loadVisitAndSearchPOI()
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 12) {
            // ココキタ完了ヘッダー
            HStack(spacing: 10) {
                Image(logoImageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 42, height: 42)
                Text(L.Location.kokokitaCompleted)
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                    .tracking(1.2)
                    .foregroundColor(.accentColor)
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.accentColor)
            }

            // 現在地を記録しました + 記録を見るリンク
            VStack(spacing: 4) {
                Text(L.Confirmation.recordedLocation)
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Button {
                    onViewDetail(visitId)
                } label: {
                    Text(L.Confirmation.viewDetail)
                        .font(.caption)
                        .foregroundStyle(Color.accentColor)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Basic Info

    private func basicInfo(visit: VisitAggregate) -> some View {
        VStack(spacing: 4) {
            Text(visit.visit.timestampUTC.kokokitaVisitString)
                .font(.footnote)
                .foregroundStyle(.secondary)

            if let addr = visit.details.resolvedAddress, !addr.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(addr)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .padding(.horizontal, 16)
            }
        }
    }

    // MARK: - Map

    private func mapSection(visit: VisitAggregate, maxHeight: CGFloat) -> some View {
        MapPreview(
            lat: visit.visit.latitude,
            lon: visit.visit.longitude,
            showCoordinateOverlay: true,
            decimals: 5
        )
        .frame(height: min(maxHeight, 200))
        .cornerRadius(12)
    }

    // MARK: - Kokokamo Section

    @ViewBuilder
    private var kokokamoScrollSection: some View {
        switch poiState {
        case .idle:
            EmptyView()

        case .loading:
            loadingView

        case .success(let pois):
            if pois.isEmpty {
                emptyPOIView
            } else {
                ScrollView {
                    LazyVStack(spacing: 0, pinnedViews: .sectionHeaders) {
                        poiListView(pois: pois)
                    }
                }
            }

        case .noInternet:
            noInternetView

        case .error(let message):
            errorView(message: message)
        }
    }

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text(L.Confirmation.loadingPOI)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
    }

    private var emptyPOIView: some View {
        Text(L.Confirmation.noPOIFound)
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .padding()
    }

    private var noInternetView: some View {
        VStack(spacing: 8) {
            Image(systemName: "wifi.slash")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text(L.Confirmation.noInternet)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .font(.title2)
                .foregroundStyle(.orange)
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
    }

    @ViewBuilder
    private func poiListView(pois: [PlacePOI]) -> some View {
        // 近隣の過去記録セクション
        if !nearbyVisits.isEmpty {
            Section {
                ForEach(nearbyVisits, id: \.visit.id) { pastVisit in
                    Button {
                        applyPastVisitAndOpenEditor(pastVisit)
                    } label: {
                        nearbyVisitRow(pastVisit)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal)
                }
                .padding(.vertical, 8)
            } header: {
                stickyHeader(L.Confirmation.recentVisitsHeader)
            }
        }

        // POIリストセクション
        Section {
            ForEach(pois) { poi in
                Button {
                    applyPOIAndOpenEditor(poi)
                } label: {
                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(poi.name)
                                .font(.subheadline.bold())
                                .foregroundStyle(.primary)

                            if let poiCategory = poi.poiCategory {
                                Text(poiCategory.localizedName)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            if let addr = poi.address, !addr.isEmpty {
                                Text(addr)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                }
                .buttonStyle(.plain)
                .padding(.horizontal)
            }
            .padding(.vertical, 8)
        } header: {
            stickyHeader(L.Confirmation.nearbyPlacesHeader)
        }
    }

    // MARK: - Sticky Header

    private func stickyHeader(_ text: String) -> some View {
        Text(text)
            .font(.caption.bold())
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(.systemGray5))
    }

    // MARK: - Nearby Visit Row

    private func nearbyVisitRow(_ pastVisit: VisitAggregate) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                // タイトルまたは施設名
                Text(displayName(for: pastVisit))
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)

                // 日付
                Text(pastVisit.visit.timestampUTC.kokokitaVisitString)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                // 住所
                if let addr = pastVisit.details.resolvedAddress, !addr.isEmpty {
                    Text(addr)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }

    private func displayName(for visit: VisitAggregate) -> String {
        if let title = visit.details.title, !title.isEmpty {
            return title
        } else if let facilityName = visit.details.facilityName, !facilityName.isEmpty {
            return facilityName
        } else {
            return L.Home.noTitle
        }
    }

    // MARK: - Bottom Buttons (Liquid Glass)

    private var bottomButtons: some View {
        VStack(spacing: 0) {
            Divider()

            HStack(spacing: 12) {
                // 情報を入力ボタン（Liquid Glassプライマリ）
                Button {
                    onEnterInfo(visitId)
                } label: {
                    Text(L.Confirmation.enterInfo)
                        .font(.headline)
                        .foregroundStyle(Color.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            ZStack {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color.accentColor.opacity(0.95),
                                                Color.accentColor.opacity(0.75)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .fill(
                                                LinearGradient(
                                                    colors: [
                                                        Color.white.opacity(0.25),
                                                        Color.clear
                                                    ],
                                                    startPoint: .top,
                                                    endPoint: .bottom
                                                )
                                            )
                                    }
                                    .shadow(color: Color.accentColor.opacity(0.35), radius: 8, x: 0, y: 2)
                                    .shadow(color: Color.accentColor.opacity(0.15), radius: 3, x: 0, y: 1)
                            }
                        )
                }
                .buttonStyle(.plain)

                // 削除ボタン（Liquid Glassセカンダリ、赤色強調）
                Button {
                    onDelete(visitId)
                    dismiss()
                } label: {
                    Text(L.Confirmation.deleteRecord)
                        .font(.headline)
                        .foregroundStyle(Color.red)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            ZStack {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(.ultraThinMaterial)
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .fill(
                                                LinearGradient(
                                                    colors: [
                                                        Color.white.opacity(0.12),
                                                        Color.white.opacity(0.03)
                                                    ],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                            )
                                    }
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .strokeBorder(
                                                LinearGradient(
                                                    colors: [
                                                        Color.red.opacity(0.3),
                                                        Color.red.opacity(0.1)
                                                    ],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                ),
                                                lineWidth: 1
                                            )
                                    }
                                    .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 2)
                            }
                        )
                }
                .buttonStyle(.plain)
            }
            .padding()
        }
        .background(
            // Liquid Glass背景
            ZStack {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .overlay {
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.05),
                                        Color.clear
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    }
            }
        )
    }

    // MARK: - Data Loading & POI Search

    @MainActor
    private func loadVisitAndSearchPOI() async {
        // Visit情報を読み込み
        let repo = AppContainer.shared.repo
        do {
            if let loadedVisit = try repo.get(by: visitId) {
                self.visit = loadedVisit

                // 近隣の過去記録を検索（100m以内、最大3件）
                do {
                    let nearby = try repo.fetchNearby(
                        latitude: loadedVisit.visit.latitude,
                        longitude: loadedVisit.visit.longitude,
                        radius: 100.0,
                        excludingId: visitId,
                        limit: 3
                    )
                    self.nearbyVisits = nearby
                } catch {
                    Logger.error("Failed to fetch nearby visits", error: error)
                    // エラーが発生しても続行（nearbyVisitsは空のまま）
                }

                // POI検索を開始
                await searchPOI(latitude: loadedVisit.visit.latitude, longitude: loadedVisit.visit.longitude)
            }
        } catch {
            Logger.error("Failed to load visit", error: error)
        }
    }

    @MainActor
    private func searchPOI(latitude: Double, longitude: Double) async {
        poiState = .loading

        let poiService = AppContainer.shared.poi
        let center = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)

        do {
            let pois = try await poiService.nearbyPOI(center: center, radius: AppConfig.poiSearchRadius)
            poiState = .success(pois)
        } catch {
            // ネットワークエラーかどうかを判定
            if isNetworkError(error) {
                poiState = .noInternet
            } else {
                poiState = .error(error.localizedDescription)
            }
            Logger.error("POI search failed", error: error)
        }
    }

    private func isNetworkError(_ error: Error) -> Bool {
        // NSURLErrorDomain のネットワークエラーをチェック
        let nsError = error as NSError
        return nsError.domain == NSURLErrorDomain &&
            (nsError.code == NSURLErrorNotConnectedToInternet ||
             nsError.code == NSURLErrorNetworkConnectionLost)
    }

    @MainActor
    private func applyPOIAndOpenEditor(_ poi: PlacePOI) {
        // VisitDetailsに施設情報を適用
        let repo = AppContainer.shared.repo
        do {
            try repo.updateDetails(id: visitId) { details in
                details.title = poi.name
                details.facilityName = poi.name
                details.facilityAddress = poi.address
                details.facilityCategory = poi.poiCategoryRaw
            }

            // 編集画面を開く
            onEnterInfo(visitId)
        } catch {
            Logger.error("Failed to apply POI", error: error)
        }
    }

    @MainActor
    private func applyPastVisitAndOpenEditor(_ pastVisit: VisitAggregate) {
        // 過去記録の情報を現在のvisitにコピー
        let repo = AppContainer.shared.repo
        do {
            try repo.updateDetails(id: visitId) { details in
                // タイトルと施設情報をコピー
                details.title = pastVisit.details.title
                details.facilityName = pastVisit.details.facilityName
                details.facilityAddress = pastVisit.details.facilityAddress
                details.facilityCategory = pastVisit.details.facilityCategory

                // ラベル、グループ、メンバーもコピー
                details.labelIds = pastVisit.details.labelIds
                details.groupId = pastVisit.details.groupId
                details.memberIds = pastVisit.details.memberIds

                // メモはコピーしない（新規記録として独立させる）
            }

            // 編集画面を開く
            onEnterInfo(visitId)
        } catch {
            Logger.error("Failed to apply past visit", error: error)
        }
    }
}

// MARK: - POI Search State

private enum POISearchState {
    case idle
    case loading
    case success([PlacePOI])
    case noInternet
    case error(String)
}
