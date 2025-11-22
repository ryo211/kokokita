import Foundation

/// ローカライゼーション用のキー管理と簡潔なアクセス
enum L {

    // MARK: - App
    enum App {
        static let name = localized("app.name")
    }

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
        static let create = localized("common.create")
        static let clear = localized("common.clear")
        static let share = localized("common.share")
        static let copy = localized("common.copy")
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
        static let selectMember = localized("visit.edit.selectMember")
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
        static let deleteConfirmTitle = localized("detail.deleteConfirmTitle")
        static let deleteConfirmMessage = localized("detail.deleteConfirmMessage")
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
        static let info = localized("facility.info")
        static let showInfo = localized("facility.showInfo")
        static let clearInfo = localized("facility.clearInfo")
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

    // MARK: - Label Management
    enum LabelManagement {
        static let title = localized("label.title")
        static let namePlaceholder = localized("label.namePlaceholder")
        static let createTitle = localized("label.createTitle")
        static let selectTitle = localized("label.selectTitle")
        static let emptyMessage = localized("label.emptyMessage")
        static let emptyDescription = localized("label.emptyDescription")
        static let deleteConfirm = localized("label.deleteConfirm")
        static let createAccessibility = localized("label.createAccessibility")
        static let deleteReallyConfirm = localized("label.deleteReallyConfirm")
        static let deleteFooter = localized("label.deleteFooter")
        static let duplicateName = localized("label.duplicateName")
        static let detailTitle = localized("label.detailTitle")
        static let deleteIrreversible = localized("label.deleteIrreversible")
    }

    // MARK: - Group Management
    enum GroupManagement {
        static let title = localized("group.title")
        static let namePlaceholder = localized("group.namePlaceholder")
        static let createTitle = localized("group.createTitle")
        static let selectTitle = localized("group.selectTitle")
        static let emptyMessage = localized("group.emptyMessage")
        static let emptyDescription = localized("group.emptyDescription")
        static let deleteConfirm = localized("group.deleteConfirm")
        static let createAccessibility = localized("group.createAccessibility")
        static let deleteReallyConfirm = localized("group.deleteReallyConfirm")
        static let deleteFooter = localized("group.deleteFooter")
        static let duplicateName = localized("group.duplicateName")
        static let detailTitle = localized("group.detailTitle")
        static let deleteIrreversible = localized("group.deleteIrreversible")
    }

    // MARK: - Member Management
    enum MemberManagement {
        static let title = localized("member.title")
        static let namePlaceholder = localized("member.namePlaceholder")
        static let createTitle = localized("member.createTitle")
        static let selectTitle = localized("member.selectTitle")
        static let emptyMessage = localized("member.emptyMessage")
        static let emptyDescription = localized("member.emptyDescription")
        static let deleteConfirm = localized("member.deleteConfirm")
        static let createAccessibility = localized("member.createAccessibility")
        static let deleteReallyConfirm = localized("member.deleteReallyConfirm")
        static let deleteFooter = localized("member.deleteFooter")
        static let duplicateName = localized("member.duplicateName")
        static let detailTitle = localized("member.detailTitle")
        static let deleteIrreversible = localized("member.deleteIrreversible")
    }

    // MARK: - Settings
    enum Settings {
        static let title = localized("settings.title")
        static let editLabels = localized("settings.editLabels")
        static let editGroups = localized("settings.editGroups")
        static let editMembers = localized("settings.editMembers")
        static let dataMigration = localized("settings.dataMigration")
        static let resetAll = localized("settings.resetAll")
        static let resetAllDescription = localized("settings.resetAllDescription")
        static let resetTitle = localized("settings.resetTitle")
        static let resetMessage = localized("settings.resetMessage")
        static let resetConfirmTitle = localized("settings.resetConfirmTitle")
        static let resetConfirmMessage = localized("settings.resetConfirmMessage")
        static let deleteAllButton = localized("settings.deleteAllButton")
        static let testErrorLog = localized("settings.testErrorLog")
        static let testCrash = localized("settings.testCrash")
        static let testCrashTitle = localized("settings.testCrashTitle")
        static let testCrashMessage = localized("settings.testCrashMessage")
        static let developerTest = localized("settings.developerTest")
    }

    // MARK: - Data Migration
    enum DataMigration {
        static let title = localized("migration.title")
        static let backupSection = localized("migration.backupSection")
        static let restoreSection = localized("migration.restoreSection")
        static let backupButton = localized("migration.backupButton")
        static let backupDescription = localized("migration.backupDescription")
        static let restoreButton = localized("migration.restoreButton")
        static let backupCompleteTitle = localized("migration.backupCompleteTitle")
        static let backupResultTitle = localized("migration.backupResultTitle")
        static let backupFilename = localized("migration.backupFilename")
        static let backupSize = localized("migration.backupSize")
        static let shareFile = localized("migration.shareFile")
        static let backupErrorTitle = localized("migration.backupErrorTitle")
        static let restoreCompleteTitle = localized("migration.restoreCompleteTitle")
        static let restoreCompleteMessage = localized("migration.restoreCompleteMessage")
        static let restoreErrorTitle = localized("migration.restoreErrorTitle")
        static let restoreNotPossibleTitle = localized("migration.restoreNotPossibleTitle")
        static let restoreNotPossibleMessage = localized("migration.restoreNotPossibleMessage")
        static let fileSelectError = localized("migration.fileSelectError")
        static let passwordPrompt = localized("migration.passwordPrompt")
        static let passwordIncorrect = localized("migration.passwordIncorrect")
        static let execute = localized("migration.execute")
    }

    // MARK: - Category
    enum Category {
        static let selectTitle = localized("category.selectTitle")
    }

    // MARK: - Date
    enum Date {
        static let today = localized("date.today")
        static let yesterday = localized("date.yesterday")
    }

    // MARK: - Search & Filter
    enum SearchFilter {
        static let sortOldest = localized("filter.sortOldest")
        static let sortNewest = localized("filter.sortNewest")
        static let titleOrAddressPlaceholder = localized("filter.titleOrAddressPlaceholder")
        static let filterByDate = localized("filter.filterByDate")
        static let title = localized("filter.title")
        static let sectionKeyword = localized("filter.sectionKeyword")
        static let sectionLabel = localized("filter.sectionLabel")
        static let sectionGroup = localized("filter.sectionGroup")
        static let sectionMember = localized("filter.sectionMember")
        static let sectionPeriod = localized("filter.sectionPeriod")
        static let sectionCategory = localized("filter.sectionCategory")
    }

    // MARK: - Prompt
    enum Prompt {
        static let saveAsIsTitle = localized("prompt.saveAsIsTitle")
        static let saveAsIsSubtitle = localized("prompt.saveAsIsSubtitle")
        static let enterInfoTitle = localized("prompt.enterInfoTitle")
        static let enterInfoSubtitle = localized("prompt.enterInfoSubtitle")
        static let kokokamoTitle = localized("prompt.kokokamoTitle")
        static let kokokamoSubtitle = localized("prompt.kokokamoSubtitle")
    }

    // MARK: - Location
    enum Location {
        static let acquiring = localized("location.acquiring")
        static let waiting = localized("location.waiting")
        static let noLocation = localized("location.noLocation")
        static let kokokitaCompleted = localized("location.kokokitaCompleted")
        static let noLocationData = localized("location.noLocationData")
    }

    // MARK: - Empty State
    enum EmptyState {
        static let noRecords = localized("emptyState.noRecords")
        static let noRecordsDescription = localized("emptyState.noRecordsDescription")
    }

    // MARK: - Map
    enum Map {
        static let openInApp = localized("map.openInApp")
    }

    // MARK: - Kokokamo (POI Search)
    enum Kokokamo {
        static let title = localized("kokokamo.title")
        static let searchPlaceholder = localized("kokokamo.searchPlaceholder")
        static let selected = localized("kokokamo.selected")
        static let notSelected = localized("kokokamo.notSelected")
        static let tapToSelect = localized("kokokamo.tapToSelect")
        static let tapToDeselect = localized("kokokamo.tapToDeselect")
    }

    // MARK: - Helper
    private static func localized(_ key: String, comment: String = "") -> String {
        NSLocalizedString(key, comment: comment)
    }
}
