import SwiftUI

// 問い合わせカテゴリ
enum InquiryCategory: String, CaseIterable, Identifiable {
    case provideInfo = "provide_info"
    case reportError = "report_error"
    case request     = "request"
    case question    = "question"
    case other       = "other"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .provideInfo: return L.Inquiry.categoryProvideInfo
        case .reportError: return L.Inquiry.categoryReportError
        case .request:     return L.Inquiry.categoryRequest
        case .question:    return L.Inquiry.categoryQuestion
        case .other:       return L.Inquiry.categoryOther
        }
    }
}

/// スポット・コースへの問い合わせフォームシート
/// - `spotName` を省略するとコース単体への問い合わせとして扱われる
struct SpotInquirySheet: View {
    let courseName: String
    var spotName: String? = nil

    @State private var selectedCategory: InquiryCategory = .provideInfo
    @State private var content = ""
    @Environment(\.dismiss) private var dismiss

    private var isSubmitEnabled: Bool {
        !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                // 問い合わせ対象（編集不可）
                Section(L.Inquiry.sectionTarget) {
                    if let spotName {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(courseName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(spotName)
                                .font(.body)
                        }
                        .padding(.vertical, 2)
                    } else {
                        Text(courseName)
                            .font(.body)
                            .padding(.vertical, 2)
                    }
                }

                // カテゴリ
                Section(L.Inquiry.sectionCategory) {
                    Picker(L.Inquiry.sectionCategory, selection: $selectedCategory) {
                        ForEach(InquiryCategory.allCases) { cat in
                            Text(cat.displayName).tag(cat)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }

                // 内容
                Section(L.Inquiry.sectionContent) {
                    TextEditor(text: $content)
                        .frame(minHeight: 100)
                }
            }
            .navigationTitle(L.Inquiry.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(L.Common.cancel) { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 6) {
                    Button {
                        openMailer()
                    } label: {
                        Text(L.Inquiry.sendButton)
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                isSubmitEnabled ? Color.indigo : Color.indigo.opacity(0.4),
                                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                            )
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                    .disabled(!isSubmitEnabled)

                    Text(L.Inquiry.sendNote)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
                .padding(.top, 8)
                .background(Color(uiColor: .systemGroupedBackground))
            }
        }
    }

    private func openMailer() {
        let subject: String
        var bodyLines = "\(L.Inquiry.emailLabelCourse): \(courseName)"
        if let spotName {
            subject = L.Inquiry.emailSubject(courseName, spotName)
            bodyLines += "\n\(L.Inquiry.emailLabelSpot): \(spotName)"
        } else {
            subject = L.Inquiry.emailSubjectCourse(courseName)
        }
        let body = """
\(bodyLines)

[\(L.Inquiry.emailLabelCategory)]
\(selectedCategory.displayName)

[\(L.Inquiry.emailLabelContent)]
\(content)
"""
        guard
            let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
            let encodedBody = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
            let url = URL(string: "mailto:\(AppConfig.supportEmail)?subject=\(encodedSubject)&body=\(encodedBody)")
        else { return }

        UIApplication.shared.open(url)
    }
}
