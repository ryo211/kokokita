import SwiftUI
import UIKit

struct KeyboardAwareTextView: UIViewRepresentable {
    @Binding var text: String
    var placeholder: String = ""
    var minHeight: CGFloat = 100
    var font: UIFont = .preferredFont(forTextStyle: .body)
    var onDone: (() -> Void)? = nil   // 「完了」押下時に呼びたい処理があれば

    func makeUIView(context: Context) -> UITextView {
        let tv = UITextView()
        tv.delegate = context.coordinator
        tv.isScrollEnabled = true
        tv.alwaysBounceVertical = true
        tv.backgroundColor = .clear
        tv.font = font
        tv.textContainerInset = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        tv.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        // --- プレースホルダー（iOS16未満対応版） ---
        let ph = UILabel()
        ph.text = placeholder
        ph.font = font
        ph.textColor = UIColor.secondaryLabel
        ph.numberOfLines = 1
        ph.translatesAutoresizingMaskIntoConstraints = false
        ph.isUserInteractionEnabled = false
        tv.addSubview(ph)
        // textContainerLayoutGuide 使わず inset+padding で配置
        let leading = tv.textContainerInset.left + tv.textContainer.lineFragmentPadding
        let top = tv.textContainerInset.top
        let topC = ph.topAnchor.constraint(equalTo: tv.topAnchor, constant: top)
        let leadC = ph.leadingAnchor.constraint(equalTo: tv.leadingAnchor, constant: leading)
        topC.identifier = "ph_top"
        leadC.identifier = "ph_lead"
        NSLayoutConstraint.activate([topC, leadC])
        context.coordinator.placeholder = ph
        context.coordinator.placeholderTop = topC
        context.coordinator.placeholderLead = leadC
        ph.isHidden = !text.isEmpty // 初期状態

        let done = UIBarButtonItem(
            title: "完了",
            style: .done,
            target: context.coordinator,
            action: #selector(Coordinator.tapDone)
        )

        let group = UIBarButtonItemGroup(barButtonItems: [done], representativeItem: nil)
        let assistant = tv.inputAssistantItem
        assistant.allowsHidingShortcuts = false             // ← 畳まれ防止
        assistant.leadingBarButtonGroups = []               // 左は使わない
        assistant.trailingBarButtonGroups = [group]         // 右上に「完了」

        // 念のため（初回反映）
        DispatchQueue.main.async {
            tv.reloadInputViews()
        }        // --- キーボード通知（回避と追従） ---
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.keyboardWillChangeFrame(_:)),
            name: UIResponder.keyboardWillChangeFrameNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.keyboardWillHide(_:)),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )

        return tv
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }
        // フォントやインセットが変わった場合のプレースホルダー位置追従
        let leading = uiView.textContainerInset.left + uiView.textContainer.lineFragmentPadding
        let top = uiView.textContainerInset.top
        context.coordinator.placeholderTop?.constant = top
        context.coordinator.placeholderLead?.constant = leading

        // 最低高さ
        if uiView.constraints.first(where: { $0.identifier == "minH" }) == nil {
            let c = uiView.heightAnchor.constraint(greaterThanOrEqualToConstant: minHeight)
            c.identifier = "minH"
            c.isActive = true
        }

        // 編集状態とテキストに応じた表示
        let isEditing = uiView.isFirstResponder
        context.coordinator.placeholder?.isHidden = isEditing || !text.isEmpty
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: KeyboardAwareTextView
        weak var placeholder: UILabel?
        weak var placeholderTop: NSLayoutConstraint?
        weak var placeholderLead: NSLayoutConstraint?

        init(_ parent: KeyboardAwareTextView) { self.parent = parent }

        func textViewDidBeginEditing(_ textView: UITextView) {
            // フォーカスでプレースホルダーは消し、キャレット重なりを回避
            placeholder?.isHidden = true
            // カーソルを可視に
            textView.scrollRangeToVisible(textView.selectedRange)
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            // 空ならプレースホルダー再表示
            placeholder?.isHidden = !textView.text.isEmpty ? true : false
        }

        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text
            // 入力に合わせてカーソルが見えるようにスクロール
            textView.scrollRangeToVisible(textView.selectedRange)
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            textView.scrollRangeToVisible(textView.selectedRange)
        }

        @objc func tapDone() {
            // キーボード閉じる
            if let tv = placeholder?.superview as? UITextView {
                tv.resignFirstResponder()
            }
            parent.onDone?()
        }

        @objc func keyboardWillChangeFrame(_ note: Notification) {
            guard let tv = (placeholder?.superview as? UITextView),
                  let w = tv.window,
                  let info = note.userInfo,
                  let kbEnd = (info[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue
            else { return }

            let tvFrameInWindow = tv.convert(tv.bounds, to: w)
            let overlap = max(0, tvFrameInWindow.maxY - kbEnd.origin.y)

            tv.contentInset.bottom = overlap + 8
            tv.verticalScrollIndicatorInsets.bottom = overlap + 8
            tv.scrollRangeToVisible(tv.selectedRange)
        }

        @objc func keyboardWillHide(_ note: Notification) {
            guard let tv = (placeholder?.superview as? UITextView) else { return }
            tv.contentInset.bottom = 0
            tv.verticalScrollIndicatorInsets.bottom = 0
        }
    }
}
