import SwiftUI
import Foundation

struct EditView: View {
    let aggregate: VisitAggregate
    var onSaved: () -> Void = {}

    @Environment(\.dismiss) private var dismiss
    @State private var vm = VisitFormStore(
        loc: AppContainer.shared.loc,
        poi: AppContainer.shared.poi,
        integ: AppContainer.shared.integ,
        repo: AppContainer.shared.repo
    )

    @State private var initialized = false

    var body: some View {
        VisitEditScreen(
            vm: vm,
            mode: .edit(id: aggregate.id, onSaved: onSaved),
            onClose: { dismiss() },
            showsCloseButton: false,
            needsBottomSafePadding: true
        )
        .task {
            guard !initialized else { return }
            initialized = true
            vm.loadExisting(aggregate)        // 既存データをVMに読み込み
            vm.labelIds = Set(aggregate.details.labelIds) // 念のため正規化
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }
}
