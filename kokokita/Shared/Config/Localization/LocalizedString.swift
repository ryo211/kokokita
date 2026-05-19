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
        static let showOptions = localized("common.showOptions")
        static let hideOptions = localized("common.hideOptions")
    }

    // MARK: - Visit Edit
    enum VisitEdit {
        static let titlePlaceholder = localized("visit.edit.titlePlaceholder")
        static let memoPlaceholder = localized("visit.edit.memoPlaceholder")
        static let editSection = localized("visit.edit.editSection")
        static let basicInfoSection = localized("visit.edit.basicInfoSection")
        static let taxonomySection = localized("visit.edit.taxonomySection")
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
        static let recordDateTime = localized("visit.edit.recordDateTime")
        static let copyFromOtherVisit = localized("visit.edit.copyFromOtherVisit")
        static let selectVisitToCopy = localized("visit.edit.selectVisitToCopy")
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
        static let itemsCount = localized("home.itemsCount")
        static let switchToMap = localized("home.switchToMap")
        static let switchToList = localized("home.switchToList")
        static let modeList = localized("home.modeList")
        static let modeMap = localized("home.modeMap")
        static let modeCalendar = localized("home.modeCalendar")
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
        static let deleteVisitTitle = localized("detail.deleteVisitTitle")
        static let deleteVisitMessage = localized("detail.deleteVisitMessage")
        static let nearbyPastRecords = localized("detail.nearbyPastRecords")
        static let sameGroupRecords = localized("detail.sameGroupRecords")
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
        static let records = localized("tab.records")
        static let menu = localized("tab.menu")
        static let kokokita = localized("tab.kokokita")
        static let course = localized("tab.course")
        static let modePilgrimage = localized("tab.modePilgrimage")
        static let modeRecord = localized("tab.modeRecord")
        static let myList = localized("tab.myList")
        static let create = localized("tab.create")
        static let spotList = localized("tab.spotList")
    }

    // MARK: - My List（マイリスト）
    enum MyList {
        static let title = localized("myList.title")
        static let emptyTitle = localized("myList.emptyTitle")
        static let emptyDescription = localized("myList.emptyDescription")
        static let newCourseButton = localized("myList.newCourseButton")
        static let deleteConfirmTitle = localized("myList.deleteConfirmTitle")
        static let deleteConfirmMessage = localized("myList.deleteConfirmMessage")
        static func spotsCount(_ count: Int) -> String { String(format: localized("myList.spotsCount"), count) }
    }

    // MARK: - Course Editor（コース作成・編集）
    enum CourseEditor {
        static let createTitle = localized("courseEditor.createTitle")
        static let editTitle = localized("courseEditor.editTitle")
        static let titlePlaceholder = localized("courseEditor.titlePlaceholder")
        static let summaryPlaceholder = localized("courseEditor.summaryPlaceholder")
        static let settingsSection = localized("courseEditor.settingsSection")
        static let coverImage = localized("courseEditor.coverImage")
        static let recognitionRadius = localized("courseEditor.recognitionRadius")
        static let recognitionRadiusInfo = localized("courseEditor.recognitionRadiusInfo")
        static func recognitionRadiusValue(_ meters: Int) -> String { String(format: localized("courseEditor.recognitionRadiusValue"), meters) }
        static let allowRetroactive = localized("courseEditor.allowRetroactive")
        static let spotsSection = localized("courseEditor.spotsSection")
        static let addSpot = localized("courseEditor.addSpot")
        static let unsavedChangesTitle = localized("courseEditor.unsavedChangesTitle")
        static let unsavedChangesMessage = localized("courseEditor.unsavedChangesMessage")
        static let discard = localized("courseEditor.discard")
        static let noSpotsMessage = localized("courseEditor.noSpotsMessage")
        static let unnamedSpot = localized("courseEditor.unnamedSpot")
        static let cancelChangesMessage = localized("courseEditor.cancelChangesMessage")
    }

    // MARK: - Spot Editor（スポット作成・編集）
    enum SpotEditor {
        static let createTitle = localized("spotEditor.createTitle")
        static let editTitle = localized("spotEditor.editTitle")
        static let nameLabel = localized("spotEditor.nameLabel")
        static let namePlaceholder = localized("spotEditor.namePlaceholder")
        static let descriptionLabel = localized("spotEditor.descriptionLabel")
        static let descriptionPlaceholder = localized("spotEditor.descriptionPlaceholder")
        static let image = localized("spotEditor.image")
        static let recognitionRadius = localized("spotEditor.recognitionRadius")
        static let recognitionRadiusInfo = localized("spotEditor.recognitionRadiusInfo")
        static let useCourseDefault = localized("spotEditor.useCoursDefault")
        static let addButton = localized("spotEditor.addButton")
        static let saveButton = localized("spotEditor.saveButton")
        static let noCoordinateWarning = localized("spotEditor.noCoordinateWarning")
        static let modeSearch = localized("spotEditor.modeSearch")
        static let modeMap = localized("spotEditor.modeMap")
        static let modePhoto = localized("spotEditor.modePhoto")
        static let modeRecord = localized("spotEditor.modeRecord")
        static let noExifLocation = localized("spotEditor.noExifLocation")
        static let selectLocation = localized("spotEditor.selectLocation")
        static let searchPlaceholder = localized("spotEditor.searchPlaceholder")
        static let detailsSettings = localized("spotEditor.detailsSettings")
        static let nameRequired = localized("spotEditor.nameRequired")
        static let locationRequired = localized("spotEditor.locationRequired")
        static let importFromPhoto = localized("spotEditor.importFromPhoto")
        static let nearbyPlaces = localized("spotEditor.nearbyPlaces")
        static let noLocationSelected = localized("spotEditor.noLocationSelected")
        static let importButton = localized("spotEditor.importButton")
        static let enterCoordinates = localized("spotEditor.enterCoordinates")
        static let coordinateInputTitle = localized("spotEditor.coordinateInputTitle")
        static let latitude = localized("spotEditor.latitude")
        static let longitude = localized("spotEditor.longitude")
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
        static let relatedVisitsHeader = localized("label.relatedVisitsHeader")
    }

    // MARK: - Label Color
    enum LabelColor {
        static let sectionTitle = localized("labelColor.sectionTitle")
        static let noColor = localized("labelColor.noColor")
        static let red = localized("labelColor.red")
        static let orange = localized("labelColor.orange")
        static let amber = localized("labelColor.amber")
        static let green = localized("labelColor.green")
        static let teal = localized("labelColor.teal")
        static let cyan = localized("labelColor.cyan")
        static let blue = localized("labelColor.blue")
        static let indigo = localized("labelColor.indigo")
        static let purple = localized("labelColor.purple")
        static let pink = localized("labelColor.pink")
        static let brown = localized("labelColor.brown")
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
        static let relatedVisitsHeader = localized("group.relatedVisitsHeader")
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
        static let relatedVisitsHeader = localized("member.relatedVisitsHeader")
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
        static let adDisplay = localized("settings.adDisplay")
        static let adDisplayDescription = localized("settings.adDisplayDescription")
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
        static let acquiringLocation = localized("location.acquiringLocation")
        static let pleaseWait = localized("location.pleaseWait")
        static let permissionRequired = localized("location.permissionRequired")
        static let permissionMessage = localized("location.permissionMessage")
        static let acquisitionFailed = localized("location.acquisitionFailed")
        static let openSettings = localized("location.openSettings")
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

    // MARK: - Confirmation Sheet
    enum Confirmation {
        static let enterInfo = localized("confirmation.enterInfo")
        static let viewDetail = localized("confirmation.viewDetail")
        static let deleteRecord = localized("confirmation.deleteRecord")
        static let recordedLocation = localized("confirmation.recordedLocation")
        static let loadingPOI = localized("confirmation.loadingPOI")
        static let noInternet = localized("confirmation.noInternet")
        static let noPOIFound = localized("confirmation.noPOIFound")
        static let selectFacility = localized("confirmation.selectFacility")
        static let deleteConfirmTitle = localized("confirmation.deleteConfirmTitle")
        static let deleteConfirmMessage = localized("confirmation.deleteConfirmMessage")
        static let recentVisitsHeader = localized("confirmation.recentVisitsHeader")
        static let nearbyPlacesHeader = localized("confirmation.nearbyPlacesHeader")
    }

    // MARK: - New Home Screen
    enum NewHome {
        static let title = localized("newhome.title")
        static let recordLocation = localized("newhome.recordLocation")
        static let recentRecords = localized("newhome.recentRecords")
        static let viewAllRecords = localized("newhome.viewAllRecords")
        static let noRecentRecords = localized("newhome.noRecentRecords")
    }

    // MARK: - Settings Sheet
    enum SettingsSheet {
        static let title = localized("settingssheet.title")
        static let resetAll = localized("settingssheet.resetAll")
        static let followOnX = localized("settingssheet.followOnX")
        static let support = localized("settingssheet.support")
        static let reviewApp = localized("settingssheet.reviewApp")
        static let developerTools = localized("settingssheet.developerTools")
        static let version = localized("settingssheet.version")
    }

    // MARK: - Course Screen
    enum Course {
        static let title = localized("course.title")
        static let comingSoon = localized("course.comingSoon")
        static let description = localized("course.description")
        static let listTitle = localized("course.listTitle")
        static let emptyTitle = localized("course.emptyTitle")
        static let emptyDescription = localized("course.emptyDescription")
        static let enable = localized("course.enable")
        static let disable = localized("course.disable")
        static let enableToggle = localized("course.enableToggle")
        static let settingsSection = localized("course.settingsSection")
        static let spotsCount = localized("course.spotsCount")
        static let spotsSection = localized("course.spotsSection")
        static let progress = localized("course.progress")
        static let completed = localized("course.completed")
        static let typePilgrimage = localized("course.type.pilgrimage")
        static let typeStampRally = localized("course.type.stampRally")
        static let typeMyList = localized("course.type.myList")
        static let categoryHistoryCulture  = localized("course.category.history_culture")
        static let categoryNature          = localized("course.category.nature")
        static let categoryArtEntertainment = localized("course.category.art_entertainment")
        static let categoryMovieDrama      = localized("course.category.movie_drama")
        static let categoryTravelSightseeing = localized("course.category.travel_sightseeing")
        static let categoryAnime           = localized("course.category.anime")
        static let categoryUserCreated     = localized("course.category.user_created")
        static let newBadge = localized("course.newBadge")
        static let achieved = localized("course.achieved")
        static let notVisited = localized("course.notVisited")
        static let noAddress = localized("course.noAddress")
        static func visitedOn(_ dateString: String) -> String { String(format: localized("course.visitedOn"), dateString) }
        static let spotProgressLabel = localized("course.spotProgressLabel")
        static func spotProgress(_ checked: Int, _ total: Int) -> String { String(format: localized("course.spotProgress"), checked, total) }
        static func updatedAt(_ dateString: String) -> String { String(format: localized("course.updatedAt"), dateString) }
        static let sortNearby = localized("course.sort.nearby")
        static let sortDefault  = localized("course.sort.default")
        static let sortDistance = localized("course.sort.distance")
    }

    // MARK: - Course Store（コースダウンロード）
    enum CourseStore {
        static let title = localized("courseStore.title")
        static let emptyTitle = localized("courseStore.emptyTitle")
        static let emptyDescription = localized("courseStore.emptyDescription")
        static let downloadButton = localized("courseStore.downloadButton")
        static let downloadedBadge = localized("courseStore.downloadedBadge")
        static let updateButton = localized("courseStore.updateButton")
        static func spotCount(_ count: Int) -> String { String(format: localized("courseStore.spotCount"), count) }
        static let filterNew = localized("courseStore.filter.new")
        static let filterAvailable = localized("courseStore.filter.available")
        static let filterInstalled = localized("courseStore.filter.installed")
        static let filterAll = localized("courseStore.filter.all")
    }

    // MARK: - Manual Entry (後付け記録)
    enum ManualEntry {
        static let title = localized("manualEntry.title")
        static let editTitle = localized("manualEntry.editTitle")
        static let badge = localized("manualEntry.badge")
        static let importFromPhoto = localized("manualEntry.importFromPhoto")
        static let importFromPhotoWithDateTime = localized("manualEntry.importFromPhotoWithDateTime")
        static let importedFromPhotoLabel = localized("manualEntry.importedFromPhotoLabel")
        static let searchLocation = localized("manualEntry.searchLocation")
        static let tapOnMap = localized("manualEntry.tapOnMap")
        static let dateTime = localized("manualEntry.dateTime")
        static let noExifData = localized("manualEntry.noExifData")
        static let futureDateNotAllowed = localized("manualEntry.futureDateNotAllowed")
        static let locationRequired = localized("manualEntry.locationRequired")
        static let selectLocationMethod = localized("manualEntry.selectLocationMethod")
        static let locationFromPhoto = localized("manualEntry.locationFromPhoto")
        static let setDateTime = localized("manualEntry.setDateTime")
        static let setLocation = localized("manualEntry.setLocation")
        static let noLocationInPhoto = localized("manualEntry.noLocationInPhoto")
        static let noDateInPhoto = localized("manualEntry.noDateInPhoto")
        static let photoImported = localized("manualEntry.photoImported")
        static let addManualEntry = localized("manualEntry.addManualEntry")
        static let useThisLocation = localized("manualEntry.useThisLocation")
        // ステップ関連
        static let step1Title = localized("manualEntry.step1Title")
        static let step2Title = localized("manualEntry.step2Title")
        static let next = localized("manualEntry.next")
        static let back = localized("manualEntry.back")
        static let saveAndSkipDetails = localized("manualEntry.saveAndSkipDetails")
        static let photoImportHint = localized("manualEntry.photoImportHint")
        static let closeSearch = localized("manualEntry.closeSearch")
        static let searchFieldPlaceholder = localized("manualEntry.searchFieldPlaceholder")
        static let infoSheetTitle = localized("manualEntry.infoSheetTitle")
        static let infoSheetPoint1 = localized("manualEntry.infoSheetPoint1")
        static let infoSheetPoint2 = localized("manualEntry.infoSheetPoint2")
        static let infoSheetPoint3 = localized("manualEntry.infoSheetPoint3")
    }

    // MARK: - Location Picker
    enum LocationPicker {
        static let currentLocation = localized("locationPicker.currentLocation")
        static let placeNamePlaceholder = localized("locationPicker.placeNamePlaceholder")
        static let findNearbySpots = localized("locationPicker.findNearbySpots")
        static let nearbySpots = localized("locationPicker.nearbySpots")
        static let searchPlaceholder = localized("locationPicker.searchPlaceholder")
        static let noResults = localized("locationPicker.noResults")
        static let photoImportDescription = localized("locationPicker.photoImportDescription")
    }

    // MARK: - Record Badge
    enum RecordBadge {
        static let explanationTitle = localized("recordBadge.explanationTitle")
        static let verifiedTitle = localized("recordBadge.verifiedTitle")
        static let verifiedDescription = localized("recordBadge.verifiedDescription")
        static let manualTitle = localized("recordBadge.manualTitle")
        static let manualDescription = localized("recordBadge.manualDescription")
    }

    // MARK: - Mode Selection
    enum ModeSelection {
        static let title = localized("modeSelection.title")
        static let subtitle = localized("modeSelection.subtitle")
        static let pilgrimageTitle = localized("modeSelection.pilgrimageTitle")
        static let pilgrimageDescription = localized("modeSelection.pilgrimageDescription")
        static let recordTitle = localized("modeSelection.recordTitle")
        static let recordDescription = localized("modeSelection.recordDescription")
        static let canChangeInSettings = localized("modeSelection.canChangeInSettings")
        static let appModeSection = localized("modeSelection.appModeSection")
        static let switchToRecord = localized("modeSelection.switchToRecord")
        static let switchToPilgrimage = localized("modeSelection.switchToPilgrimage")
    }

    // MARK: - Pilgrimage Home
    enum PilgrimageHome {
        static let navTitle = localized("pilgrimageHome.navTitle")
        static let howToUseButton = localized("pilgrimageHome.howToUseButton")
        static let howToUseTitle = localized("pilgrimageHome.howToUseTitle")
        static let heroTitle = localized("pilgrimageHome.heroTitle")
        static let heroDescription = localized("pilgrimageHome.heroDescription")
        static let viewCourses = localized("pilgrimageHome.viewCourses")
        static let coursesTitle = localized("pilgrimageHome.coursesTitle")
        static let seeAll = localized("pilgrimageHome.seeAll")
        static let nearbyTitle = localized("pilgrimageHome.nearbyTitle")
        static let nearbyTabShort = localized("pilgrimageHome.nearbyTabShort")
        static let nearbyRefresh = localized("pilgrimageHome.nearbyRefresh")
        static let noNearbySpots = localized("pilgrimageHome.noNearbySpots")
        static let locationUnavailable = localized("pilgrimageHome.locationUnavailable")
        static let recentTitle = localized("pilgrimageHome.recentTitle")
        static let recentTabShort = localized("pilgrimageHome.recentTabShort")
        static let noRecentAchievements = localized("pilgrimageHome.noRecentAchievements")
        static func progressFormat(_ checked: Int, _ total: Int) -> String { String(format: localized("pilgrimageHome.progressFormat"), checked, total) }
        static func distanceMeter(_ meters: Int) -> String { String(format: localized("pilgrimageHome.distanceMeter"), meters) }
        static func distanceFormatted(_ meters: Double) -> String {
            meters >= 1000
                ? String(format: "%.1fkm", meters / 1000)
                : "\(Int(meters))m"
        }
    }

    // MARK: - SpotList（スポット一覧画面）
    enum SpotList {
        static let title = localized("spotList.title")
        static let locationUnavailable = localized("spotList.locationUnavailable")
        static let noSpots = localized("spotList.noSpots")
    }

    // MARK: - TaxonomyList（タクソノミー一覧ソート）
    enum TaxonomyList {
        static let sortNewest = localized("taxonomyList.sortNewest")
        static let sortCount  = localized("taxonomyList.sortCount")
    }

    // MARK: - Spot Panel List
    enum SpotPanelList {
        static let displayLimitSuffix = localized("spotPanelList.displayLimitSuffix")
        static let displayLimitAll    = localized("spotPanelList.displayLimitAll")
        static let favoritesTitle     = localized("spotPanelList.favoritesTitle")
        static let favoritesTabShort  = localized("spotPanelList.favoritesTabShort")
        static let noFavorites        = localized("spotPanelList.noFavorites")
        static let noFavoritesShort   = localized("spotPanelList.noFavoritesShort")
    }

    // MARK: - CheckIn Result
    enum CheckIn {
        static let resultTitle = localized("checkIn.resultTitle")
        static let resultSubtitle = localized("checkIn.resultSubtitle")
        static let stampAcquired = localized("checkIn.stampAcquired")
        static let courseAllClear = localized("checkIn.courseAllClear")
        static let distanceFormat = localized("checkIn.distanceFormat")
        static let retroactiveTitle = localized("checkIn.retroactiveTitle")
        static let retroactiveSubtitle = localized("checkIn.retroactiveSubtitle")
        static let retroactiveDateSuffix = localized("checkIn.retroactiveDateSuffix")
    }

    // MARK: - Helper
    private static func localized(_ key: String, comment: String = "") -> String {
        NSLocalizedString(key, comment: comment)
    }
}
