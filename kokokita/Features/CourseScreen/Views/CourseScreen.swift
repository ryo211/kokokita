import SwiftUI

struct CourseScreen: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                Image(systemName: "map.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(.secondary)
                    .opacity(0.5)

                VStack(spacing: 12) {
                    Text(L.Course.comingSoon)
                        .font(.title2.bold())
                        .foregroundStyle(.primary)

                    Text(L.Course.description)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }

                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                LinearGradient(
                    colors: [
                        Color(.systemBackground),
                        Color(.secondarySystemBackground)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .navigationTitle(L.Course.title)
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}
