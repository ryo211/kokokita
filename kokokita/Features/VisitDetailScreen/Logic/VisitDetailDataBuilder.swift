import Foundation
import CoreLocation

/// VisitAggregate から VisitDetailData への変換、共有テキスト生成などの純粋関数
enum VisitDetailDataBuilder {

    /// VisitAggregate を VisitDetailData に変換する
    static func toDetailData(
        _ agg: VisitAggregate,
        labelOptions: [LabelTag],
        groupOptions: [GroupTag],
        memberOptions: [MemberTag]
    ) -> VisitDetailData {
        let title: String = {
            let t = agg.details.title?.trimmingCharacters(in: .whitespacesAndNewlines)
            if let t, !t.isEmpty { return t }
            if let f = agg.details.facilityName, !f.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return f }
            return L.Home.noTitle
        }()

        let labels: [String] = agg.details.labelIds.compactMap { id in
            labelOptions.first(where: { $0.id == id })?.name
        }
        let group: String? = agg.details.groupId.flatMap { id in
            groupOptions.first(where: { $0.id == id })?.name
        }
        let members: [String] = agg.details.memberIds.compactMap { id in
            memberOptions.first(where: { $0.id == id })?.name
        }

        let coord: CLLocationCoordinate2D? = {
            let lat = agg.visit.latitude
            let lon = agg.visit.longitude
            if lat == 0 && lon == 0 { return nil }
            return CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }()

        let facility: FacilityInfo? = {
            guard let name = agg.details.facilityName else { return nil }
            return FacilityInfo(
                name: name,
                address: agg.details.facilityAddress,
                phone: nil
            )
        }()

        return VisitDetailData(
            title: title,
            labels: labels,
            group: group,
            members: members,
            timestamp: agg.visit.timestampUTC,
            address: agg.details.resolvedAddress,
            coordinate: coord,
            memo: agg.details.comment,
            facility: facility,
            facilityCategory: agg.details.facilityCategory,
            photoPaths: agg.details.photoPaths,
            isManualEntry: agg.visit.isManualEntry
        )
    }

    /// 共有用テキストを生成する
    static func shareText(data: VisitDetailData) -> String {
        var lines: [String] = []
        lines.append("【\(L.App.name)】")
        lines.append(data.title.ifBlank(L.Home.noTitle))
        lines.append(data.timestamp.kokokitaVisitString)
        return lines.joined(separator: "\n")
    }
}
