import SwiftUI

struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]
    let excluded: [UIActivity.ActivityType] = [
        .assignToContact, .print, .saveToCameraRoll, .addToReadingList
    ]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let vc = UIActivityViewController(activityItems: items, applicationActivities: nil)
        vc.excludedActivityTypes = excluded
        return vc
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
