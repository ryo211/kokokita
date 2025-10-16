//
//  Protocols.swift
//  kokokita
//
//  Created by 橋本遼 on 2025/09/20.
//

import Foundation
import CoreLocation

protocol VisitRepository {
    func create(visit: Visit, details: VisitDetails) throws
    func updateDetails(id: UUID, transform: (inout VisitDetails) -> Void) throws
    func delete(id: UUID) throws
    func fetchAll(
        filterLabel: UUID?,
        filterGroup: UUID?,
        titleQuery: String?,          // 追加
        dateFrom: Date?,              // 追加（startOfDay推奨）
        dateToExclusive: Date?        // 追加（endOfDayの翌日00:00を入れるとバグりにくい）
    ) throws -> [VisitAggregate]
    func get(by id: UUID) throws -> VisitAggregate?
    func deleteAllVisits() throws
}

protocol TaxonomyRepository {
    func allLabels() throws -> [LabelTag]
    func allGroups() throws -> [GroupTag]
    func allMembers() throws -> [MemberTag]
    func upsertLabel(name: String) throws -> LabelTag
    func upsertGroup(name: String) throws -> GroupTag
    func upsertMember(name: String) throws -> MemberTag
    func renameLabel(id: UUID, newName: String) throws
    func deleteLabel(id: UUID) throws
    func renameGroup(id: UUID, newName: String) throws
    func deleteGroup(id: UUID) throws
    func renameMember(id: UUID, newName: String) throws
    func deleteMember(id: UUID) throws
    func createLabel(name: String) throws -> UUID
    func createGroup(name: String) throws -> UUID
    func createMember(name: String) throws -> UUID
}

protocol LocationService {
    func requestOneShotLocation() async throws -> (CLLocation, LocationSourceFlags)
}

protocol PlaceLookupService {
    func nearbyPOI(center: CLLocationCoordinate2D, radius: CLLocationDistance) async throws -> [PlacePOI]
}

protocol IntegrityService {
    func signImmutablePayload(
        id: UUID,
        timestampUTC: Date,
        lat: Double,
        lon: Double,
        acc: Double?,
        flags: LocationSourceFlags
    ) throws -> Visit.Integrity
    func verify(visit: Visit) -> Bool
}
