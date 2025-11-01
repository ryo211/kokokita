import Foundation

/// 訪問記録の可変データ（メタデータ）
struct VisitDetails: Codable, Equatable {
    var title: String?
    var facilityName: String?
    var facilityAddress: String?
    var facilityCategory: String?  // MKPointOfInterestCategory.rawValue
    var comment: String?
    var labelIds: [UUID]
    var groupId: UUID?
    var memberIds: [UUID]
    var resolvedAddress: String?
    var photoPaths: [String] = []

    public init(
        title: String? = nil,
        facilityName: String? = nil,
        facilityAddress: String? = nil,
        facilityCategory: String? = nil,
        comment: String? = nil,
        labelIds: [UUID] = [],
        groupId: UUID? = nil,
        memberIds: [UUID] = [],
        resolvedAddress: String? = nil,
        photoPaths: [String] = []
    ) {
        self.title = title
        self.facilityName = facilityName
        self.facilityAddress = facilityAddress
        self.facilityCategory = facilityCategory
        self.comment = comment
        self.labelIds = labelIds
        self.groupId = groupId
        self.memberIds = memberIds
        self.resolvedAddress = resolvedAddress
        self.photoPaths = photoPaths
    }
}

/// 施設情報
struct FacilityInfo {
    let name: String?
    let address: String?
    let phone: String?
}
