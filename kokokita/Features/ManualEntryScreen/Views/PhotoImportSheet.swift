import SwiftUI
import PhotosUI
import CoreLocation

/// 写真から日時・場所を取り込むシート
struct PhotoImportSheet: View {
    @Environment(\.dismiss) private var dismiss

    // 結果のバインディング
    @Binding var latitude: Double?
    @Binding var longitude: Double?
    @Binding var addressLine: String?
    @Binding var timestamp: Date

    /// true の場合、取り込んだ日時を結果に表示し説明文にも日時を含める（後付け記録用）
    var showsTimestamp: Bool = false
    /// テーマカラー（後付け記録: .orange / スポット作成: .indigo）
    var tintColor: Color = .indigo

    // 写真追加のコールバック
    let onPhotoAdded: (UIImage) -> Void

    // ローカル状態
    @State private var photoSelection: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var extractedCoordinate: CLLocationCoordinate2D?
    @State private var extractedTimestamp: Date?
    @State private var isProcessing = false
    @State private var errorMessage: String?

    // 逆ジオコーディング
    private let geocoder = CLGeocoder()

    private var hasExtractedData: Bool {
        extractedCoordinate != nil
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // 説明テキスト（後付け記録用は日時も取り込む旨を表示）
                Text(showsTimestamp ? L.ManualEntry.photoImportHint : L.LocationPicker.photoImportDescription)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                // 写真選択ボタン
                PhotosPicker(
                    selection: $photoSelection,
                    matching: .images,
                    photoLibrary: .shared()
                ) {
                    if let image = selectedImage {
                        // 選択された写真のプレビュー
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 200, height: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(tintColor, lineWidth: 2)
                            )
                    } else {
                        // 未選択時のプレースホルダー
                        VStack(spacing: 12) {
                            Image(systemName: "photo.on.rectangle.angled")
                                .font(.system(size: 48))
                                .foregroundStyle(tintColor)

                            Text(L.ManualEntry.importFromPhoto)
                                .font(.headline)
                                .foregroundStyle(.primary)
                        }
                        .frame(width: 200, height: 200)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }

                if isProcessing {
                    ProgressView()
                        .padding()
                }

                // 抽出結果の表示
                if hasExtractedData {
                    extractedDataView
                }

                // エラーメッセージ
                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                Spacer()

                // 適用ボタン
                if hasExtractedData {
                    Button {
                        applyExtractedData()
                    } label: {
                        Text(L.Common.done)
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(tintColor)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
            .navigationTitle(L.ManualEntry.importFromPhoto)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L.Common.cancel) { dismiss() }
                }
            }
            .onChange(of: photoSelection) { handlePhotoSelection($1) }
        }
    }

    // MARK: - Extracted Data View

    private var extractedDataView: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 位置情報（住所または座標を表示）
            if let coord = extractedCoordinate {
                HStack(alignment: .top) {
                    Image(systemName: "mappin.circle.fill")
                        .foregroundStyle(tintColor)
                        .font(.title3)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(L.ManualEntry.setLocation)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if let addr = addressLine, !addr.isEmpty {
                            Text(addr)
                                .font(.subheadline)
                        } else {
                            Text(String(format: "%.5f, %.5f", coord.latitude, coord.longitude))
                                .font(.subheadline.monospacedDigit())
                        }
                    }
                    Spacer()
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(tintColor)
                }
            }

            // 日時（後付け記録モードのみ表示）
            if showsTimestamp, let ts = extractedTimestamp {
                Divider()
                HStack(alignment: .top) {
                    Image(systemName: "calendar.circle.fill")
                        .foregroundStyle(tintColor)
                        .font(.title3)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(L.ManualEntry.setDateTime)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(ts.formatted(.dateTime.year().month().day().hour().minute()))
                            .font(.subheadline)
                    }
                    Spacer()
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(tintColor)
                }
            } else if showsTimestamp && extractedTimestamp == nil && extractedCoordinate != nil {
                // 位置情報はあるが日時がない場合の注記
                Divider()
                HStack(spacing: 6) {
                    Image(systemName: "calendar.badge.exclamationmark")
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                    Text(L.ManualEntry.noDateInPhoto)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    // MARK: - Actions

    private func handlePhotoSelection(_ item: PhotosPickerItem?) {
        guard let item = item else { return }

        isProcessing = true
        errorMessage = nil
        extractedCoordinate = nil
        extractedTimestamp = nil
        selectedImage = nil

        Task {
            defer { isProcessing = false }

            // 画像を読み込み
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                selectedImage = image
            }

            // EXIFデータを抽出
            let exifData = await ExifEffects.extractExifDataFromPhotosPickerItem(item)

            extractedCoordinate = exifData.coordinate
            extractedTimestamp = exifData.timestamp

            // 住所を逆ジオコーディング
            if let coord = exifData.coordinate {
                await reverseGeocode(coordinate: coord)
            }

            // 位置情報が取得できなかった場合のエラーメッセージ
            if extractedCoordinate == nil {
                errorMessage = L.ManualEntry.noLocationInPhoto
            }

            photoSelection = nil
        }
    }

    private func reverseGeocode(coordinate: CLLocationCoordinate2D) async {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)

        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            if let pm = placemarks.first {
                addressLine = formatPlacemark(pm)
            }
        } catch {
            // エラーは無視
        }
    }

    private func applyExtractedData() {
        // 位置情報を設定
        if let coord = extractedCoordinate {
            latitude = coord.latitude
            longitude = coord.longitude
        }

        // 日時を設定（未来でない場合のみ）
        if let ts = extractedTimestamp, ts <= Date() {
            timestamp = ts
        }

        // 写真を追加
        if let image = selectedImage {
            onPhotoAdded(image)
        }

        dismiss()
    }

    private func formatPlacemark(_ placemark: CLPlacemark) -> String? {
        var components: [String] = []
        if let admin = placemark.administrativeArea { components.append(admin) }
        if let locality = placemark.locality { components.append(locality) }
        if let subLocality = placemark.subLocality { components.append(subLocality) }
        if let thoroughfare = placemark.thoroughfare { components.append(thoroughfare) }
        if let subThoroughfare = placemark.subThoroughfare { components.append(subThoroughfare) }
        return components.isEmpty ? nil : components.joined()
    }
}

// MARK: - Preview

#Preview {
    @Previewable @State var lat: Double? = nil
    @Previewable @State var lon: Double? = nil
    @Previewable @State var address: String? = nil
    @Previewable @State var time: Date = Date()

    PhotoImportSheet(
        latitude: $lat,
        longitude: $lon,
        addressLine: $address,
        timestamp: $time
    ) { image in
        print("Photo added: \(image)")
    }
}
