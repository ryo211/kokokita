import SwiftUI
import MapKit

/// 施設情報ボタン（共通）
/// - 編集画面でも詳細画面でも使えるように、onClear は任意
struct FacilityInfoButton: View {
    enum Mode { case readOnly, editable }

    let name: String?
    let address: String?
    let phone: String?          // 将来用（あれば表示）
    let categoryRawValue: String?  // カテゴリ
    var mode: Mode = .readOnly  // 既定は閲覧用
    var onClear: (() -> Void)?  // editable のときだけ渡す

    @State private var showPopover = false

    private var hasContent: Bool {
        let n = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let a = address?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let p = phone?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let c = categoryRawValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return !n.isEmpty || !a.isEmpty || !p.isEmpty || !c.isEmpty
    }

    var body: some View {
        Group {
            if hasContent {
                Button {
                    showPopover = true
                } label: {
                    Image(systemName: "info.circle")
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showPopover, arrowEdge: .top) {
                    FacilityInfoPopoverContent(
                        name: name,
                        address: address,
                        phone: phone,
                        categoryRawValue: categoryRawValue,
                        mode: mode,
                        onClear: {
                            onClear?()
                            showPopover = false
                        },
                        onClose: { showPopover = false }
                    )
                    .frame(maxWidth: 360)
                    .padding()
                }
                .accessibilityLabel(L.Facility.showInfo)
            }
        }
    }
}

/// ポップオーバーの中身（見た目共通）
struct FacilityInfoPopoverContent: View {
    let name: String?
    let address: String?
    let phone: String?
    let categoryRawValue: String?
    let mode: FacilityInfoButton.Mode
    let onClear: () -> Void
    let onClose: () -> Void

    private var categoryName: String? {
        guard let raw = categoryRawValue else { return nil }
        let cat = MKPointOfInterestCategory(rawValue: raw)
        return cat.localizedName
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L.Facility.info).font(.headline)

            if let n = name?.trimmingCharacters(in: .whitespacesAndNewlines), !n.isEmpty {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "building.2")
                    Text(n).font(.subheadline.bold())
//                    Spacer()
//                    CopyButton(value: n)
                }
            }

            if let cat = categoryName, !cat.isEmpty {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "tag")
                    Text(cat).font(.caption).foregroundStyle(.secondary)
                }
            }

            if let a = address?.trimmingCharacters(in: .whitespacesAndNewlines), !a.isEmpty {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "mappin.and.ellipse")
                    Text(a).font(.footnote)
//                    Spacer()
//                    CopyButton(value: a)
                }
            }

            if let p = phone?.trimmingCharacters(in: .whitespacesAndNewlines), !p.isEmpty {
                HStack(alignment: .center, spacing: 6) {
                    Image(systemName: "phone")
                    Text(p).font(.footnote)
                    Spacer()
                    CopyButton(value: p)
                }
            }

            HStack {
                if mode == .editable {
                    Button(role: .destructive, action: onClear) {
                        Label(L.Facility.clearInfo, systemImage: "trash")
                    }
                }
                Spacer()
                Button(L.Common.close, action: onClose)
            }
        }
    }
}

/// クリップボードコピー（小ボタン）
private struct CopyButton: View {
    let value: String
    @State private var copied = false

    var body: some View {
        Button {
            #if canImport(UIKit)
            UIPasteboard.general.string = value
            #endif
            copied = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { copied = false }
        } label: {
            Image(systemName: copied ? "checkmark.circle.fill" : "doc.on.doc")
                .foregroundStyle(copied ? .green : .secondary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L.Common.copy)
    }
}
