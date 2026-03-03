import SwiftUI

/// ステップ進捗表示コンポーネント
struct StepIndicator: View {
    let currentStep: ManualEntryStep
    let totalSteps: Int = ManualEntryStep.allCases.count

    var body: some View {
        HStack(spacing: 16) {
            ForEach(ManualEntryStep.allCases, id: \.rawValue) { step in
                stepItem(for: step)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private func stepItem(for step: ManualEntryStep) -> some View {
        HStack(spacing: 8) {
            // ステップ番号
            ZStack {
                Circle()
                    .fill(circleColor(for: step))
                    .frame(width: 28, height: 28)

                if step.rawValue < currentStep.rawValue {
                    // 完了済み
                    Image(systemName: "checkmark")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                } else {
                    // 現在または未完了
                    Text("\(step.rawValue)")
                        .font(.caption.bold())
                        .foregroundStyle(textColor(for: step))
                }
            }

            // ステップ名
            Text(step.title)
                .font(.subheadline)
                .foregroundStyle(step == currentStep ? .primary : .secondary)
                .lineLimit(1)
        }

        // ステップ間の接続線（最後のステップ以外）
        if step != ManualEntryStep.allCases.last {
            Rectangle()
                .fill(step.rawValue < currentStep.rawValue ? Color.orange : Color(.systemGray4))
                .frame(height: 2)
                .frame(maxWidth: .infinity)
        }
    }

    private func circleColor(for step: ManualEntryStep) -> Color {
        if step.rawValue < currentStep.rawValue {
            // 完了済み
            return .orange
        } else if step == currentStep {
            // 現在のステップ
            return .orange
        } else {
            // 未完了
            return Color(.systemGray5)
        }
    }

    private func textColor(for step: ManualEntryStep) -> Color {
        if step == currentStep || step.rawValue < currentStep.rawValue {
            return .white
        } else {
            return .secondary
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 40) {
        StepIndicator(currentStep: .essentials)
        StepIndicator(currentStep: .additionalInfo)
    }
    .padding()
}
