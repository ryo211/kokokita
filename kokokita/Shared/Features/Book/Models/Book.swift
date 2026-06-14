import SwiftUI

struct Book: Identifiable, Equatable {
    let id: UUID
    var name: String
    var colorId: String?
    var createdAt: Date
    var sortOrder: Int

    var color: Color {
        LabelColorId.from(colorId)?.color ?? Color(.systemBlue)
    }

    static let defaultColorId = LabelColorId.blue.rawValue
}
