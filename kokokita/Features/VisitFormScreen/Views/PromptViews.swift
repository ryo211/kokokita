import SwiftUI
import CoreLocation

// MARK: - PostKokokitaConfirmationSheet

/// ココキタ保存後の確認シート
/// 保存直後に表示され、記録完了を「ハンコを押す」演出で伝えつつ、
/// 周辺施設・近くの過去記録を候補チップとして提示する
///
/// 誤記録の削除はゴミ箱機能（記録一覧からの通常の削除操作）でカバーされるため、
/// このシート自体に削除アクションは置かない。右上の閉じるボタンはスワイプ同様、単に閉じるだけ
struct PostKokokitaConfirmationSheet: View {
    let visitId: UUID
    let onEnterInfo: (UUID) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var visit: VisitAggregate?
    @State private var poiState: POISearchState = .idle
    @State private var nearbyVisits: [VisitAggregate] = []
    @State private var selectedPOICategory: KKCategory? = nil

    // 1%の確率でレア画像を表示
    private var stampImageName: String {
        Double.random(in: 0..<1) < 0.01 ? "kokokita_irodori" : "kokokita_irodori_blue"
    }

    // 候補行（以前の記録／周辺の施設）の表示段数
    private var candidateRowCount: Int {
        var count = 0
        if !nearbyVisits.isEmpty { count += 1 }
        switch poiState {
        case .success(let pois) where !pois.isEmpty: count += 1
        case .loading: count += 1
        default: break
        }
        return count
    }

    // 候補行の段数ごとに固定の高さを持たせる（0件/1種類/2種類の3パターン）
    // 行を1つ増やすごとの増分は「行ラベル+チップ」約62pt、2段目以降は段間スペース12ptが加わる分やや大きくなる
    // 周辺の施設行はカテゴリ絞り込みアイコン分だけラベル行が少し高くなるため、その分も見込む
    private var sheetHeight: CGFloat {
        switch candidateRowCount {
        case 0: return 460
        case 1: return 530
        default: return 600
        }
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 0) {
                VStack(spacing: 14) {
                    RecordStampView(imageName: stampImageName)
                        .padding(.top, 24)

                    VStack(spacing: 6) {
                        Text(L.Confirmation.recordedLocation)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(.primary)

                        if let visit {
                            basicInfo(visit: visit)
                        }
                    }

                    if let visit {
                        mapSection(visit: visit)
                    }

                    candidatesSection
                }
                .padding(.horizontal)

                Spacer(minLength: 0)

                ctaButton
            }
            .frame(maxHeight: .infinity)

            closeButton
        }
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.regularMaterial)
        )
        .presentationDetents([.height(sheetHeight)])
        .presentationDragIndicator(.visible)
        .animation(.easeInOut(duration: 0.25), value: candidateRowCount)
        .task {
            await loadVisitAndSearchPOI()
        }
    }

    // MARK: - Close Button

    private var closeButton: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 30, height: 30)
                .background(Color(.systemGray6), in: Circle())
        }
        .buttonStyle(.plain)
        .padding(.top, 16)
        .padding(.trailing, 16)
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

    private func mapSection(visit: VisitAggregate) -> some View {
        MapPreview(
            lat: visit.visit.latitude,
            lon: visit.visit.longitude,
            showCoordinateOverlay: false,
            cornerRadius: 20,
            pulsing: true,
            openMapButtonStyle: .icon
        )
        .frame(height: 150)
    }

    // MARK: - Candidates（以前の記録 / 周辺の施設を行で分ける）

    @ViewBuilder
    private var candidatesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !nearbyVisits.isEmpty {
                candidateRow(
                    label: L.Confirmation.pastVisitsLabel,
                    items: nearbyVisits.map(CandidateItem.pastVisit)
                )
            }

            switch poiState {
            case .success(let pois) where !pois.isEmpty:
                nearbyPlacesRow(pois: pois)
            case .loading:
                VStack(alignment: .leading, spacing: 8) {
                    Text(L.Confirmation.nearbyPlacesLabel)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                        .padding(.leading, 2)

                    HStack(spacing: 8) {
                        ProgressView()
                        Text(L.Confirmation.loadingPOI)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            default:
                EmptyView()
            }
        }
    }

    private func candidateRow(label: String, items: [CandidateItem]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
                .padding(.leading, 2)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(items) { item in
                        candidateChip(item)
                    }
                }
            }
        }
    }

    // 周辺の施設のみ、ココカモと同じ3カテゴリでの絞り込みをラベル行に添える
    private func nearbyPlacesRow(pois: [PlacePOI]) -> some View {
        let filtered = filteredPOIs(pois)
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(L.Confirmation.nearbyPlacesLabel)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                    .padding(.leading, 2)
                Spacer(minLength: 0)
                poiCategoryFilterBar
            }

            if filtered.isEmpty {
                Text(L.Confirmation.noPOIFound)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 9)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(filtered.map(CandidateItem.poi)) { item in
                            candidateChip(item)
                        }
                    }
                }
            }
        }
    }

    private var poiCategoryFilterBar: some View {
        HStack(spacing: 6) {
            ForEach(KKCategory.allCases) { category in
                let isOn = selectedPOICategory == category
                Button {
                    withAnimation(.easeOut(duration: 0.15)) {
                        selectedPOICategory = isOn ? nil : category
                    }
                } label: {
                    Image(systemName: category.symbolBase + (isOn ? ".fill" : ""))
                        .font(.caption2)
                        .foregroundStyle(isOn ? Color.white : Color.secondary)
                        .frame(width: 22, height: 22)
                        .background(
                            Circle().fill(isOn ? category.highlightColor : Color(.systemGray6))
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(category.localizedName))
            }
        }
    }

    private func filteredPOIs(_ pois: [PlacePOI]) -> [PlacePOI] {
        guard let selectedPOICategory else { return pois }
        return pois.filter { $0.kkCategory == selectedPOICategory }
    }

    private func candidateChip(_ item: CandidateItem) -> some View {
        Button {
            switch item {
            case .pastVisit(let pastVisit):
                applyPastVisitAndOpenEditor(pastVisit)
            case .poi(let poi):
                applyPOIAndOpenEditor(poi)
            }
        } label: {
            HStack(spacing: 7) {
                switch item {
                case .pastVisit:
                    // 以前の記録は一目でわかるようアクセントカラーの時計アイコンにする
                    Image(systemName: item.iconName)
                        .font(.subheadline)
                        .foregroundStyle(Color.accentColor)
                case .poi:
                    Image(systemName: item.iconName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Text(item.displayName)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
                    .opacity(0.4)
            }
            .padding(.leading, 14)
            .padding(.trailing, 10)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(chipBackground(for: item))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(chipBorder(for: item), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.08), radius: 5, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }

    // 背景がregularMaterialのシート上でも埋もれないよう、種別ごとに濃淡を変える
    private func chipBackground(for item: CandidateItem) -> AnyShapeStyle {
        switch item {
        case .pastVisit:
            return AnyShapeStyle(Color.accentColor.opacity(0.14))
        case .poi:
            return AnyShapeStyle(Color(.systemBackground))
        }
    }

    private func chipBorder(for item: CandidateItem) -> AnyShapeStyle {
        switch item {
        case .pastVisit:
            return AnyShapeStyle(Color.accentColor.opacity(0.4))
        case .poi:
            return AnyShapeStyle(Color.primary.opacity(0.1))
        }
    }

    // MARK: - CTA（「情報を入力」単独ボタン。Liquid Glass）

    private var ctaButton: some View {
        VStack(spacing: 0) {
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
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 14)
        }
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

// MARK: - Candidate Item（近くの過去記録 / 周辺施設を統合した候補チップのモデル）

private enum CandidateItem: Identifiable {
    case pastVisit(VisitAggregate)
    case poi(PlacePOI)

    var id: String {
        switch self {
        case .pastVisit(let visit): return "visit-\(visit.visit.id)"
        case .poi(let poi): return "poi-\(poi.id)"
        }
    }

    var displayName: String {
        switch self {
        case .pastVisit(let visit):
            if let title = visit.details.title, !title.isEmpty {
                return title
            } else if let facilityName = visit.details.facilityName, !facilityName.isEmpty {
                return facilityName
            } else {
                return L.Home.noTitle
            }
        case .poi(let poi):
            return poi.name
        }
    }

    var iconName: String {
        switch self {
        case .pastVisit: return "clock.arrow.circlepath"
        case .poi: return "building.2"
        }
    }
}

// MARK: - Record Stamp View（記録完了の「ハンコ」演出）

/// 記録完了時に一度だけ再生される、ハンコを押すような着地アニメーション付きのスタンプ
private struct RecordStampView: View {
    let imageName: String
    @State private var animateIn = false

    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(Color.accentColor.opacity(0.55), style: StrokeStyle(lineWidth: 2.5, dash: [3, 2.5]))
            Circle()
                .strokeBorder(Color.accentColor.opacity(0.35), lineWidth: 1.5)
                .padding(6)
            Image(imageName)
                .resizable()
                .scaledToFit()
                .frame(width: 36, height: 36)
        }
        .frame(width: 74, height: 74)
        .scaleEffect(animateIn ? 1.0 : 2.1)
        .rotationEffect(.degrees(animateIn ? 0 : -14))
        .opacity(animateIn ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.62)) {
                animateIn = true
            }
        }
    }
}

// MARK: - POI Search State

private enum POISearchState: Equatable {
    case idle
    case loading
    case success([PlacePOI])
    case noInternet
    case error(String)
}
