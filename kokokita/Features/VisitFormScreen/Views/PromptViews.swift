import SwiftUI
import CoreLocation

struct PostKokokitaPromptSheet: View {
    @Binding var locationData: LocationData  // ← `let`から`@Binding`に変更
    let onQuickSave: () -> Void
    let onOpenEditor: () -> Void
    let onOpenPOI: () -> Void
    let onCancel: () -> Void

    private var timestamp: Date? { locationData.timestamp }
    private var addressText: String? { locationData.address }
    private var latitude: Double { locationData.latitude }
    private var longitude: Double { locationData.longitude }
    private var canSave: Bool { latitude != 0 || longitude != 0 }
    
    // 1%の確率でレア画像を表示
    private var logoImageName: String {
        Double.random(in: 0..<1) < 0.01 ? "kokokita_irodori" : "kokokita_irodori_blue"
    }

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 16) {
                // 見出し
                HStack(spacing: 10) {
                    Image(logoImageName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 42, height: 42)
                    Text(L.Location.kokokitaCompleted)
                        .font(.system(size: 24, weight: .semibold, design: .rounded))
                        .tracking(1.2)  // 文字間隔を広げる
                        .foregroundColor(.accentColor)
                }
                .padding(.top, 8)

                // 最低限の情報（小さく）
                VStack(spacing: 4) {
                    Text(formattedTimestamp)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    if let addr = addressText, !addr.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(addr)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .padding(.horizontal, 16)
                    }
                }
             
                // マップ（相対サイズ: 画面の55% = iPhone 12 miniと同じサイズ感）
                if latitude != 0 || longitude != 0 {
                    MapPreview(
                        lat: latitude,
                        lon: longitude,
                        showCoordinateOverlay: true,
                        decimals: 5
                    )
                    .frame(height: max(200, min(500, geometry.size.height * 0.55)))
                } else {
                    Text(L.Location.noLocationData)
                        .foregroundStyle(.secondary)
                }
                
                // 3つの選択肢（同列）
                HStack(spacing: 12) {
                    actionButton(
                        primary: true,
                        systemImage: "checkmark.circle.fill",
                        title: L.Prompt.saveAsIsTitle,
                        subtitle: L.Prompt.saveAsIsSubtitle,
                        isDisabled: !canSave,
                        action: onQuickSave
                    )

                    actionButton(
                        primary: false,
                        systemImage: "square.and.pencil",
                        title: L.Prompt.enterInfoTitle,
                        subtitle: L.Prompt.enterInfoSubtitle,
                        action: onOpenEditor
                    )

                    actionButton(
                        primary: false,
                        systemImage: "building.2.crop.circle",
                        title: L.Prompt.kokokamoTitle,
                        subtitle: L.Prompt.kokokamoSubtitle,
                        action: onOpenPOI
                    )
                }
                .frame(height: 120)  // ボタン(80) + 説明(32) + spacing(4) + 余裕(4)
                .padding(.horizontal, 8)


                Spacer(minLength: 8)
            }
            .padding()
        }
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.regularMaterial)
        )
        .presentationDragIndicator(.visible)
    }
    
    private var formattedTimestamp: String {
        guard let ts = timestamp else { return "-" }
        return ts.kokokitaVisitString
    }
    
    @ViewBuilder
    private func actionButton(
        primary: Bool,
        systemImage: String,
        title: String,
        subtitle: String,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        VStack(spacing: 4) {
            // ボタン本体を固定高さにして位置を揃える（アイコンを上に配置、タイトルは改行可能）
            let content = VStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.title2)
                    .frame(height: 28)  // アイコンの高さを固定
                Text(title)
                    .font(.subheadline.bold())
                    .lineLimit(2)  // 2行まで改行可能にして「そのまま保存」を2行表示
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)  // タイトル改行対応のため高さを拡大

            // ★ Button は"必ず1つだけ"作る
            if #available(iOS 15.0, *) {
                if primary {
                    Button(action: action) { content }
                        .buttonStyle(BorderedProminentButtonStyle())
                        .controlSize(.large)
                        .buttonBorderShape(.roundedRectangle(radius: 14))
                        .disabled(isDisabled)
                } else {
                    Button(action: action) { content }
                        .buttonStyle(BorderedButtonStyle())
                        .controlSize(.large)
                        .buttonBorderShape(.roundedRectangle(radius: 14))
                        .disabled(isDisabled)
                }
            } else {
                // フォールバック（旧OS向け）
                Button(action: action) { content }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(primary ? Color.accentColor : Color.clear)
                    .foregroundColor(primary ? .white : .accentColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.accentColor, lineWidth: primary ? 0 : 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .disabled(isDisabled)
            }

            // 説明文を固定高さの領域に配置（改行されてもボタンの位置に影響しない）
            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(height: 32, alignment: .top)  // 固定高さで説明文用の領域を確保
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - PostKokokitaConfirmationSheet

/// ココキタ保存後の確認シート
/// 保存直後に表示され、周辺施設の自動検索と編集・削除の選択肢を提供
struct PostKokokitaConfirmationSheet: View {
    let visitId: UUID
    let onEnterInfo: (UUID) -> Void
    let onDelete: (UUID) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var visit: VisitAggregate?
    @State private var poiState: POISearchState = .idle
    @State private var showDeleteConfirm = false
    @State private var selectedCategory: KKCategory? = nil

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
                        .padding(.top, 8)

                    // 基本情報（日付・住所）
                    if let visit = visit {
                        basicInfo(visit: visit)
                    }

                    // 地図（高さを抑える）
                    if let visit = visit {
                        mapSection(visit: visit, maxHeight: geometry.size.height * 0.3)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 12)

                // ココカモセクション
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

                    // カテゴリフィルタ
                    if case .success(let pois) = poiState, !pois.isEmpty {
                        HStack(spacing: 12) {
                            ForEach(KKCategory.allCases) { cat in
                                let isOn = (selectedCategory == cat)
                                Button {
                                    #if os(iOS)
                                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                                    #endif
                                    selectedCategory = isOn ? nil : cat
                                } label: {
                                    VStack(spacing: 4) {
                                        Image(systemName: cat.symbolBase + (isOn ? ".fill" : ""))
                                            .font(.body)
                                            .foregroundStyle(isOn ? Color.white : Color.primary)
                                            .padding(6)
                                            .background(
                                                Circle()
                                                    .fill(isOn ? cat.highlightColor : Color(.systemGray5))
                                            )
                                            .shadow(color: isOn ? cat.highlightColor.opacity(0.3) : .clear,
                                                    radius: isOn ? 6 : 0, x: 0, y: 2)

                                        Text(cat.localizedName)
                                            .font(.caption2)
                                            .foregroundStyle(isOn ? cat.highlightColor : .secondary)
                                    }
                                }
                                .buttonStyle(.plain)
                                .animation(.easeOut(duration: 0.15), value: isOn)
                            }
                            Spacer(minLength: 0)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 8)

                // スクロール可能なココカモセクション
                kokokamoScrollSection
                    .frame(maxHeight: .infinity)

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
        .alert(L.Confirmation.deleteConfirmTitle, isPresented: $showDeleteConfirm) {
            Button(L.Common.delete, role: .destructive) {
                onDelete(visitId)
                dismiss()
            }
            Button(L.Common.cancel, role: .cancel) {}
        } message: {
            Text(L.Confirmation.deleteConfirmMessage)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 10) {
            Image(logoImageName)
                .resizable()
                .scaledToFit()
                .frame(width: 42, height: 42)
            Text(L.Location.kokokitaCompleted)
                .font(.system(size: 24, weight: .semibold, design: .rounded))
                .tracking(1.2)
                .foregroundColor(.accentColor)
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
                let filteredPois = filterPOIs(pois)
                if filteredPois.isEmpty {
                    emptyPOIView
                } else {
                    ScrollView {
                        poiListView(pois: filteredPois)
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

    private func poiListView(pois: [PlacePOI]) -> some View {
        VStack(spacing: 8) {
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
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Bottom Buttons

    private var bottomButtons: some View {
        VStack(spacing: 0) {
            Divider()

            HStack(spacing: 12) {
                // 情報を入力ボタン
                Button {
                    onEnterInfo(visitId)
                } label: {
                    Text(L.Confirmation.enterInfo)
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                // 削除ボタン
                Button {
                    showDeleteConfirm = true
                } label: {
                    Text(L.Confirmation.deleteRecord)
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .tint(.red)
            }
            .padding()
        }
        .background(.ultraThinMaterial)
    }

    // MARK: - POI Filtering

    private func filterPOIs(_ pois: [PlacePOI]) -> [PlacePOI] {
        guard let category = selectedCategory else {
            return pois
        }
        return pois.filter { $0.kkCategory == category }
    }

    // MARK: - Data Loading & POI Search

    @MainActor
    private func loadVisitAndSearchPOI() async {
        // Visit情報を読み込み
        let repo = AppContainer.shared.repo
        do {
            if let loadedVisit = try repo.get(by: visitId) {
                self.visit = loadedVisit

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
}

// MARK: - POI Search State

private enum POISearchState {
    case idle
    case loading
    case success([PlacePOI])
    case noInternet
    case error(String)
}
