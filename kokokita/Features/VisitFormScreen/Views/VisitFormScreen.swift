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
        initialLocationData: initialLocationData
      ))
  }

  var body: some View {
    VisitEditScreen(vm: vm, mode: .create) {
      dismiss()
    }
    .presentationDetents([.large])
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
  }
}
