//
//  Untitled.swift
//  kokokita
//
//  Created by 橋本遼 on 2025/09/20.
//

import Foundation
import SwiftUI
import UIKit

// JST 表示用のフォーマッタ（保存はUTC、表示はJST）
extension DateFormatter {
    static let jst: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = AppConfig.dateDisplayFormat
        f.timeZone = TimeZone(identifier: "Asia/Tokyo")
        return f
    }()
}

extension Notification.Name {
    static let visitsChanged   = Notification.Name("visitsChanged")
    static let taxonomyChanged = Notification.Name("taxonomyChanged")
}

extension String {
    var ifNotBlank: String? {
        trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : self
    }
}

// 簡易DIコンテナ（Core Data 版 Repository を採用）
final class AppContainer {
    static let shared = AppContainer()

    // Repository はプロトコル型で公開（テストや差し替え容易）
    let repo: (VisitRepository & TaxonomyRepository) = CoreDataVisitRepository()

    // Services
    let loc = DefaultLocationService()
    let poi = MapKitPlaceLookupService()
    let integ = DefaultIntegrityService()

    private init() {}
}

enum AppDateFormatters {
    /// 例: 2025/10/04 (土) 21:30
    static let visitDateTime: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.calendar = Calendar(identifier: .gregorian)
        f.timeZone = .current
        f.dateFormat = "yyyy/MM/dd (E) HH:mm"
        return f
    }()
}

extension Date {
    /// ココキタの統一日時表示
    var kokokitaVisitString: String {
        AppDateFormatters.visitDateTime.string(from: self)
    }
}

@MainActor
enum ShareImageRenderer {
    /// 幅だけ与えて“高さは中身に合わせる”画像化
    static func renderWidth<V: View>(_ view: V, width: CGFloat, scale: CGFloat = 3) -> UIImage? {
        if #available(iOS 16.0, *) {
            // 高さは中身に合わせるため fixedSize を併用
            let content =
                view
                    .frame(width: width)
                    .fixedSize(horizontal: false, vertical: true) // ← ココ重要
                    .transaction { $0.disablesAnimations = true } // 画像化時にアニメ無効
                    .environment(\.colorScheme, .light)           // 任意：共有はライト固定

            let renderer = ImageRenderer(content: content)
            renderer.scale = scale
            renderer.isOpaque = false
            return renderer.uiImage
        } else {
            // iOS 15 フォールバック（UIHostingController）
            let hosting = UIHostingController(
                rootView:
                    view
                        .frame(width: width)
                        .fixedSize(horizontal: false, vertical: true)
            )
            hosting.view.backgroundColor = .clear
            hosting.view.setNeedsLayout()
            hosting.view.layoutIfNeeded()

            // AutoLayout で必要な実サイズを計測
            let target = hosting.sizeThatFits(
                in: CGSize(width: width, height: .greatestFiniteMagnitude)
            )
            hosting.view.bounds = CGRect(origin: .zero, size: target)

            let renderer = UIGraphicsImageRenderer(
                size: CGSize(width: target.width * scale, height: target.height * scale)
            )
            return renderer.image { ctx in
                ctx.cgContext.scaleBy(x: scale, y: scale)
                hosting.view.layer.render(in: ctx.cgContext)
            }
        }
    }
}

extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
    func ifBlank(_ alt: String) -> String { trimmed.isEmpty ? alt : self }
}
