//
//  Models.swift
//  kokokita
//
//  Created by 橋本遼 on 2025/09/20.
//

import Foundation

struct Visit: Identifiable, Codable, Equatable {
    let id: UUID
    let timestampUTC: Date
    let latitude: Double
    let longitude: Double
    let horizontalAccuracy: Double?
    let isSimulatedBySoftware: Bool?
    let isProducedByAccessory: Bool?
    let integrity: Integrity

    struct Integrity: Codable, Equatable {
        let algo: String
        let signatureDERBase64: String
        let publicKeyRawBase64: String
        let payloadHashHex: String
        let createdAtUTC: Date
    }
}

// Location のソースフラグ（偽装/外部アクセサリ検知）
public struct LocationSourceFlags: Codable, Equatable {
    public let isSimulatedBySoftware: Bool?
    public let isProducedByAccessory: Bool?
    public init(isSimulatedBySoftware: Bool?, isProducedByAccessory: Bool?) {
        self.isSimulatedBySoftware = isSimulatedBySoftware
        self.isProducedByAccessory = isProducedByAccessory
    }
}

// 周辺施設（POI）データ
public struct PlacePOI: Identifiable, Equatable {
    public let id: UUID
    public let name: String
    public let category: String?
    public let address: String?
    public let phone: String?
    public let poiCategoryRaw: String?
    public init(
        id: UUID = UUID(),
        name: String,
        category: String? = nil,
        address: String? = nil,
        phone: String? = nil,
        poiCategoryRaw: String? = nil
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.address = address
        self.phone = phone
        self.poiCategoryRaw = poiCategoryRaw
    }
}


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

    public init(title: String? = nil,
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

struct LabelTag: Identifiable, Codable, Equatable { let id: UUID; var name: String }
struct GroupTag: Identifiable, Codable, Equatable { let id: UUID; var name: String }
struct MemberTag: Identifiable, Codable, Equatable { let id: UUID; var name: String }

struct VisitAggregate: Identifiable, Codable, Equatable {
    let id: UUID
    let visit: Visit
    var details: VisitDetails
}

struct FacilityInfo {
    let name: String?
    let address: String?
    let phone: String?
}
