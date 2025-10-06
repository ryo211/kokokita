import SwiftUI
import Foundation

struct CreateView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var vm = CreateEditViewModel(
        loc: AppContainer.shared.loc,
        poi: AppContainer.shared.poi,
        integ: AppContainer.shared.integ,
        repo: AppContainer.shared.repo
    )

    var body: some View {
        VisitEditScreen(vm: vm, mode: .create) {
            dismiss()
        }
        .presentationDetents([.large])
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }
}
