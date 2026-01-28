import SwiftUI

struct CalendarPickerSheet: View {
    let visitsByDate: [Date: [String]]
    let onSelectDate: (Date) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var currentMonth: Date = Date()

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // 月選択
                    monthSelector

                    // 曜日ヘッダー
                    weekdayHeader

                    // カレンダーグリッド
                    calendarGrid
                }
                .padding()
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L.Common.close) {
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Month Selector

    private var monthSelector: some View {
        HStack {
            Button {
                changeMonth(by: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.title3)
                    .foregroundStyle(.primary)
            }

            Spacer()

            Text(monthYearString)
                .font(.headline)

            Spacer()

            Button {
                changeMonth(by: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.title3)
                    .foregroundStyle(.primary)
            }
        }
        .padding(.horizontal)
    }

    private var monthYearString: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy年M月"
        return formatter.string(from: currentMonth)
    }

    // MARK: - Weekday Header

    private var weekdayHeader: some View {
        LazyVGrid(columns: columns, spacing: 0) {
            ForEach(weekdaySymbols, id: \.self) { symbol in
                Text(symbol)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 30)
            }
        }
    }

    private var weekdaySymbols: [String] {
        calendar.veryShortWeekdaySymbols
    }

    // MARK: - Calendar Grid

    private var calendarGrid: some View {
        LazyVGrid(columns: columns, spacing: 0) {
            ForEach(Array(daysInMonth.enumerated()), id: \.offset) { index, date in
                if let date = date {
                    dayCell(for: date)
                } else {
                    Color(.systemBackground)
                        .frame(height: 80)
                        .frame(maxWidth: .infinity)
                        .overlay(alignment: .trailing) {
                            Rectangle()
                                .fill(Color.secondary.opacity(0.08))
                                .frame(width: 1)
                        }
                        .overlay(alignment: .bottom) {
                            Rectangle()
                                .fill(Color.secondary.opacity(0.08))
                                .frame(height: 1)
                        }
                }
            }
        }
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(Color.secondary.opacity(0.08))
                .frame(width: 1)
        }
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.secondary.opacity(0.08))
                .frame(height: 1)
        }
    }

    @ViewBuilder
    private func dayCell(for date: Date) -> some View {
        let hasVisits = visitsByDate[date] != nil
        let titles = visitsByDate[date] ?? []

        Button {
            if hasVisits {
                onSelectDate(date)
            }
        } label: {
            ZStack(alignment: .topLeading) {
                // 固定サイズの背景
                Color(.systemBackground)

                VStack(alignment: .leading, spacing: 4) {
                    // 日付
                    Text("\(calendar.component(.day, from: date))")
                        .font(.caption)
                        .foregroundStyle(Color.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 2)
                        .padding(.top, 2)

                    // 記録タイトル（最大3件）
                    if hasVisits {
                        VStack(alignment: .leading, spacing: 2) {
                            ForEach(titles.prefix(3), id: \.self) { title in
                                Text(String(title.prefix(5)))
                                    .font(.system(size: 7))
                                    .foregroundStyle(Color.accentColor)
                                    .lineLimit(1)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 3)
                                    .padding(.vertical, 1)
                                    .background(
                                        RoundedRectangle(cornerRadius: 2)
                                            .fill(Color.accentColor.opacity(0.08))
                                    )
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 2)
                                            .strokeBorder(Color.accentColor.opacity(0.2), lineWidth: 0.5)
                                    }
                            }

                            // 残り件数表示
                            if titles.count > 3 {
                                Text("他\(titles.count - 3)件")
                                    .font(.system(size: 8))
                                    .foregroundStyle(Color.secondary.opacity(0.7))
                            }
                        }
                        .padding(.horizontal, 2)
                    }

                    Spacer()
                }
                .opacity(hasVisits ? 1.0 : 0.3)
            }
            .frame(width: nil, height: 80)
            .frame(maxWidth: .infinity)
        }
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(Color.secondary.opacity(0.08))
                .frame(width: 1)
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.secondary.opacity(0.08))
                .frame(height: 1)
        }
        .buttonStyle(.plain)
        .disabled(!hasVisits)
    }

    // MARK: - Calendar Logic

    private var daysInMonth: [Date?] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: currentMonth),
              let firstWeekday = calendar.dateComponents([.weekday], from: monthInterval.start).weekday else {
            return []
        }

        var days: [Date?] = []

        // 月初の曜日までの空セルを追加
        let emptyCells = (firstWeekday - calendar.firstWeekday + 7) % 7
        days.append(contentsOf: Array(repeating: nil, count: emptyCells))

        // 月の各日を追加
        var date = monthInterval.start
        while date < monthInterval.end {
            days.append(date)
            date = calendar.date(byAdding: .day, value: 1, to: date)!
        }

        return days
    }

    private func changeMonth(by value: Int) {
        if let newMonth = calendar.date(byAdding: .month, value: value, to: currentMonth) {
            currentMonth = newMonth
        }
    }
}
