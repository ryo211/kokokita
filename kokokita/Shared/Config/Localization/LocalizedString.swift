import Foundation

/// ローカライゼーション用のキー管理と簡潔なアクセス
enum L {

    // MARK: - Common
    enum Common {
        static let ok = localized("common.ok")
        static let cancel = localized("common.cancel")
        static let close = localized("common.close")
        static let save = localized("common.save")
        static let delete = localized("common.delete")
        static let edit = localized("common.edit")
        static let done = localized("common.done")
        static let error = localized("common.error")
        static let loading = localized("common.loading")
        static let retry = localized("common.retry")
        static let notSelected = localized("common.notSelected")
    }

    // MARK: - Visit Edit
    enum VisitEdit {
        static let titlePlaceholder = localized("visit.edit.titlePlaceholder")
        static let memoPlaceholder = localized("visit.edit.memoPlaceholder")
        static let editSection = localized("visit.edit.editSection")
        static let saveButton = localized("visit.edit.saveButton")
        static let locationAcquiring = localized("visit.edit.locationAcquiring")
        static let kokokamo = localized("visit.edit.kokokamo")
        static let selectLabel = localized("visit.edit.selectLabel")
        static let selectGroup = localized("visit.edit.selectGroup")
        static let createNew = localized("visit.edit.createNew")
        static let labelName = localized("visit.edit.labelName")
        static let groupName = localized("visit.edit.groupName")
        static let createAndSelect = localized("visit.edit.createAndSelect")
        static let newLabel = localized("visit.edit.newLabel")
        static let newGroup = localized("visit.edit.newGroup")
        static let clearSelection = localized("visit.edit.clearSelection")
    }

    // MARK: - Photo
    enum Photo {
        static let photo = localized("photo.photo")
        static let camera = localized("photo.camera")
    }

    // MARK: - Home
    enum Home {
        static let title = localized("home.title")
        static let noVisits = localized("home.noVisits")
        static let filterAll = localized("home.filter.all")
        static let filterLabel = localized("home.filter.label")
        static let filterGroup = localized("home.filter.group")
        static let filterPeriod = localized("home.filter.period")
        static let searchPlaceholder = localized("home.search.placeholder")
        static let deleteConfirmTitle = localized("home.deleteConfirmTitle")
        static let deleteConfirmMessage = localized("home.deleteConfirmMessage")
        static let noTitle = localized("home.noTitle")
    }

    // MARK: - Detail
    enum Detail {
        static let share = localized("detail.share")
        static let map = localized("detail.map")
        static let accuracy = localized("detail.accuracy")
        static let coordinates = localized("detail.coordinates")
        static let timestamp = localized("detail.timestamp")
        static let labels = localized("detail.labels")
        static let group = localized("detail.group")
        static let memo = localized("detail.memo")
        static let facility = localized("detail.facility")
    }

    // MARK: - Menu
    enum Menu {
        static let title = localized("menu.title")
        static let labels = localized("menu.labels")
        static let groups = localized("menu.groups")
        static let settings = localized("menu.settings")
        static let about = localized("menu.about")
        static let resetAll = localized("menu.resetAll")
    }

    // MARK: - Error Messages
    enum Error {
        static let locationSimulated = localized("error.locationSimulated")
        static let locationDenied = localized("error.locationDenied")
        static let saveFailed = localized("error.saveFailed")
        static let loadFailed = localized("error.loadFailed")
        static let deleteFailed = localized("error.deleteFailed")
        static let poiSearchFailed = localized("error.poiSearchFailed")
        static let imageEncodeFailed = localized("error.imageEncodeFailed")
    }

    // MARK: - Facility Info
    enum Facility {
        static let name = localized("facility.name")
        static let address = localized("facility.address")
        static let phone = localized("facility.phone")
        static let clear = localized("facility.clear")
    }

    // MARK: - Period Filter
    enum Period {
        static let today = localized("period.today")
        static let yesterday = localized("period.yesterday")
        static let thisWeek = localized("period.thisWeek")
        static let lastWeek = localized("period.lastWeek")
        static let thisMonth = localized("period.thisMonth")
        static let lastMonth = localized("period.lastMonth")
        static let custom = localized("period.custom")
    }

    // MARK: - Tab Bar
    enum Tab {
        static let home = localized("tab.home")
        static let menu = localized("tab.menu")
        static let kokokita = localized("tab.kokokita")
    }

    // MARK: - Helper
    private static func localized(_ key: String, comment: String = "") -> String {
        NSLocalizedString(key, comment: comment)
    }
}
