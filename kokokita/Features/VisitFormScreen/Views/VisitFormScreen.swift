import Foundation
import SwiftUI

struct VisitFormScreen: View {
  let initialLocationData: LocationData
  let shouldOpenPOI: Bool

  @Environment(\.dismiss) private var dismiss
  @State private var vm: VisitFormStore

  init(initialLocationData: LocationData, shouldOpenPOI: Bool = false) {
    self.initialLocationData = initialLocationData
    self.shouldOpenPOI = shouldOpenPOI
    _vm = State(
      initialValue: VisitFormStore(
        loc: AppContainer.shared.loc,
        poi: AppContainer.shared.poi,
        integ: AppContainer.shared.integ,
        repo: AppContainer.shared.repo,
        courseRecognitionService: AppContainer.shared.courseRecognitionService,
        courseRepo: AppContainer.shared.courseRepo,
        initialLocationData: initialLocationData
      ))
  }

  var body: some View {
    VisitEditScreen(vm: vm, mode: .create) {
      dismiss()
    }
    .iPadSheetSize()
    .ignoresSafeArea(.keyboard, edges: .bottom)
    .onChange(of: vm.shouldDismiss) { _, shouldDismiss in
      if shouldDismiss {
        dismiss()
      }
    }
    .onAppear {
      // ViewModelが完全に初期化された後にPOIを開く
      vm.openPOIIfNeeded(shouldOpenPOI: shouldOpenPOI)
    }
    .sheet(isPresented: Binding(
      get: { !vm.pendingCheckInResults.isEmpty },
      set: { if !$0 { vm.pendingCheckInResults = [] } }
    ), onDismiss: {
      // チェックイン結果シートを閉じたらフォームも閉じる
      dismiss()
    }) {
      CheckInResultSheet(results: vm.pendingCheckInResults) {
        vm.pendingCheckInResults = []
      }
    }
  }
}
