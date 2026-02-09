import SwiftUI

// MARK: - インライン表示用カレンダービュー

struct CalendarContentView: View {
    let visitsByDate: [Date: [String]]
    let aggregatesByDate: [Date: [VisitAggregate]]
    let labelMap: [UUID: String]
    let groupMap: [UUID: String]
    let memberMap: [UUID: String]
    var labelColorMap: [String: Color] = [:]
    var onTapVisit: ((VisitAggregate) -> Void)? = nil
    var onPanelVisibilityChanged: ((Bool) -> Void)? = nil

    @State private var currentMonth: Date = Date()
    @State private var selectedDate: Date? = nil
    @State private var dismissingPanelDate: Date? = nil  // スライドアウト中のパネルデータ保持用
    @State private var panelDragOffset: CGFloat = 0
    @State private var panelInsetHeight: CGFloat = 0
    @State private var monthSwipeOffset: CGFloat = 0
    @State private var isMonthTransitioning = false

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)
    private let monthSwipeThreshold: CGFloat = 50

    var body: some View {
        VStack(spacing: 0) {
            // 固定: 月選択
            monthSelector
                .padding(.horizontal)
                .padding(.vertical, 12)

            // 固定: 曜日ヘッダー
            weekdayHeader
                .padding(.horizontal)

            // カレンダーグリッド（スクロール可能）+ 記録一覧パネル（オーバーレイ）
            ZStack(alignment: .bottom) {
                ScrollViewReader { proxy in
                    ScrollView {
                        calendarGrid
                            .padding(.horizontal)
                    }
                    .scrollDisabled(!isPanelPresented)
                    .scrollIndicators(.hidden)
                    .safeAreaInset(edge: .bottom) {
                        if isPanelPresented {
                            Color.clear
                                .frame(height: panelInsetHeight)
                        }
                    }
                    .offset(x: monthSwipeOffset)
                    .simultaneousGesture(monthSwipeGesture)
                    .onChange(of: selectedDate) { _, newDate in
                        if let date = newDate {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                withAnimation {
                                    proxy.scrollTo(date, anchor: .top)
                                }
                            }
                        }
                    }
                }

                // 記録一覧パネル（選択中 or スライドアウト中に表示）
                if let date = panelDisplayDate,
                   let aggregates = aggregatesByDate[date],
                   !aggregates.isEmpty {
                    recordListPanel(date: date, aggregates: aggregates)
                        .background(PanelHeightReader())
                        .offset(y: max(0, panelDragOffset))
                }
            }
            .onPreferenceChange(PanelHeightPreferenceKey.self) { value in
                let newHeight = max(0, value - 8)
                if abs(panelInsetHeight - newHeight) > 0.5 {
                    var t = Transaction()
                    t.disablesAnimations = true
                    withTransaction(t) {
                        panelInsetHeight = newHeight
                    }
                }
            }
        }
        .onChange(of: isPanelPresented) { _, newValue in
            onPanelVisibilityChanged?(newValue)
        }
    }

    // MARK: - Month Selector

    private var monthSelector: some View {
        HStack {
            Button {
                animateMonthChange(by: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.title3)
                    .foregroundStyle(.primary)
            }
            .disabled(isMonthTransitioning)

            Spacer()

            Text(monthYearString)
                .font(.headline)

            Spacer()

            Button {
                animateMonthChange(by: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.title3)
                    .foregroundStyle(.primary)
            }
            .disabled(isMonthTransitioning)
        }
    }

    /// ボタンタップ時のスライドアニメーション付き月変更
    private func animateMonthChange(by value: Int) {
        guard !isMonthTransitioning else { return }
        let direction: CGFloat = value > 0 ? -1 : 1
        let screenWidth = UIScreen.main.bounds.width
        isMonthTransitioning = true

        withAnimation(.easeIn(duration: 0.15)) {
            monthSwipeOffset = direction * screenWidth
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            var t = Transaction()
            t.disablesAnimations = true
            withTransaction(t) {
                changeMonth(by: value)
                monthSwipeOffset = -direction * screenWidth * 0.3
            }
            withAnimation(.easeOut(duration: 0.2)) {
                monthSwipeOffset = 0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                isMonthTransitioning = false
            }
        }
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
                        .id(date)
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

    private var monthSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 20, coordinateSpace: .local)
            .onChanged { value in
                if isPanelPresented || isMonthTransitioning { return }
                let horizontal = value.translation.width
                let vertical = value.translation.height
                // 水平方向のドラッグのみ追従
                if abs(horizontal) > abs(vertical) {
                    monthSwipeOffset = horizontal * 0.4
                }
            }
            .onEnded { value in
                if isPanelPresented || isMonthTransitioning {
                    withAnimation(.easeOut(duration: 0.2)) {
                        monthSwipeOffset = 0
                    }
                    return
                }
                let horizontal = value.translation.width
                let vertical = value.translation.height
                if abs(horizontal) > abs(vertical),
                   abs(horizontal) > monthSwipeThreshold {
                    // スワイプ方向にスライドアウト → 月変更 → 反対側からスライドイン
                    let direction: CGFloat = horizontal < 0 ? -1 : 1
                    let screenWidth = UIScreen.main.bounds.width
                    isMonthTransitioning = true

                    withAnimation(.easeIn(duration: 0.15)) {
                        monthSwipeOffset = direction * screenWidth
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        // アニメーションなしで月変更＋反対側に配置
                        var t = Transaction()
                        t.disablesAnimations = true
                        withTransaction(t) {
                            changeMonth(by: horizontal < 0 ? 1 : -1)
                            monthSwipeOffset = -direction * screenWidth * 0.3
                        }
                        // スライドイン
                        withAnimation(.easeOut(duration: 0.2)) {
                            monthSwipeOffset = 0
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            isMonthTransitioning = false
                        }
                    }
                } else {
                    // しきい値未満 → 元に戻す
                    withAnimation(.easeOut(duration: 0.2)) {
                        monthSwipeOffset = 0
                    }
                }
            }
    }

    @ViewBuilder
    private func dayCell(for date: Date) -> some View {
        let hasVisits = visitsByDate[date] != nil
        let titles = visitsByDate[date] ?? []
        let isSelected = selectedDate == date
        let isToday = calendar.isDateInToday(date)

        ZStack(alignment: .topLeading) {
            // 背景（選択時はアクセントカラー）
            if isSelected {
                Color.accentColor.opacity(0.15)
            } else if isToday {
                Color.gray.opacity(0.12)
            } else {
                Color(.systemBackground)
            }

            VStack(alignment: .leading, spacing: 4) {
                // 日付
                Text("\(calendar.component(.day, from: date))")
                    .font(.caption)
                    .fontWeight(isSelected ? .bold : .regular)
                    .foregroundStyle(isSelected ? Color.accentColor : (isToday ? Color.red : Color.primary))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 2)
                    .padding(.top, 2)

                // 記録タイトル（最大3件）
                if hasVisits {
                    let aggs = aggregatesByDate[date] ?? []
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(Array(zip(titles.prefix(3), aggs.prefix(3))), id: \.0) { title, agg in
                            let entryColor = firstLabelColor(for: agg) ?? ChipKind.defaultTint
                            Text(String(title.prefix(5)))
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(Color.secondary)
                                .lineLimit(1)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 3)
                                .padding(.vertical, 1)
                                .background(
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(entryColor.opacity(isSelected ? 0.25 : 0.15))
                                )
                                .overlay {
                                    RoundedRectangle(cornerRadius: 2)
                                        .strokeBorder(entryColor.opacity(0.3), lineWidth: 0.5)
                                }
                        }

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
        .contentShape(Rectangle())
        .onTapGesture {
            guard hasVisits else { return }
            if selectedDate == date {
                dismissPanel()
            } else if selectedDate != nil {
                // 別の日付に切り替え
                withAnimation(.easeInOut(duration: 0.25)) {
                    panelDragOffset = 0
                    selectedDate = date
                }
            } else {
                // 新規選択 → スライドインで表示
                showPanel(for: date)
            }
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
        .overlay {
            if isSelected {
                Rectangle()
                    .strokeBorder(Color.accentColor.opacity(0.4), lineWidth: 1.5)
            }
        }
    }

    // MARK: - Record List Panel（オーバーレイ）

    @ViewBuilder
    private func recordListPanel(date: Date, aggregates: [VisitAggregate]) -> some View {
        VStack(spacing: 0) {
            // 固定: 日付ラベル
            HStack(spacing: 8) {
                Text(selectedDateHeaderString(date))
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Button {
                    dismissPanel()
                } label: {
                    Image(systemName: "xmark")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(6)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("閉じる")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.secondary.opacity(0.08))

            Divider()

            // スクロール可能: 記録一覧
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(aggregates) { agg in
                        VStack(spacing: 0) {
                            Button {
                                onTapVisit?(agg)
                            } label: {
                                VisitRow(
                                    agg: agg,
                                    nameResolver: { labelIds, groupId, memberIds in
                                        let labels = labelIds.compactMap { labelMap[$0] }
                                        let group = groupId.flatMap { groupMap[$0] }
                                        let members = memberIds.compactMap { memberMap[$0] }
                                        return (labels, group, members)
                                    },
                                    compact: true,
                                    labelColorMap: labelColorMap
                                )
                                .padding(.vertical, 10)
                                .padding(.horizontal, 16)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)

                            Divider()
                                .padding(.leading, 16)
                        }
                    }
                }
            }
        }
        .frame(maxHeight: UIScreen.main.bounds.height * 0.45)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.15), radius: 12, x: 0, y: -4)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    /// 訪問記録の先頭ラベル色を取得（名前順ソートで最初のラベルの色）
    private func firstLabelColor(for agg: VisitAggregate) -> Color? {
        let names = agg.details.labelIds
            .compactMap { labelMap[$0] }
            .sorted { $0.localizedCompare($1) == .orderedAscending }
        guard let firstName = names.first else { return nil }
        return labelColorMap[firstName]
    }

    // パネルをドラッグで閉じる
    private func dismissPanel() {
        let offscreen = UIScreen.main.bounds.height * 0.5
        // スライドアウト中のパネル表示を維持しつつ、ハイライトは即解除
        dismissingPanelDate = selectedDate
        selectedDate = nil
        withAnimation(.easeOut(duration: 0.25)) {
            panelDragOffset = offscreen
            panelInsetHeight = 0
        }
        // アニメーション完了後にすべてリセット
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            var t = Transaction()
            t.disablesAnimations = true
            withTransaction(t) {
                dismissingPanelDate = nil
                panelDragOffset = 0
            }
        }
    }

    // パネルをスライドインで表示する
    private func showPanel(for date: Date) {
        let offscreen = UIScreen.main.bounds.height * 0.5
        // まず画面外にパネルを配置
        var t = Transaction()
        t.disablesAnimations = true
        withTransaction(t) {
            panelDragOffset = offscreen
            selectedDate = date
        }
        // スライドインアニメーション
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
            withAnimation(.easeOut(duration: 0.3)) {
                panelDragOffset = 0
            }
        }
    }


    private func selectedDateHeaderString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "M月d日（E）"
        return formatter.string(from: date)
    }

    // MARK: - Calendar Logic

    private var daysInMonth: [Date?] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: currentMonth),
              let firstWeekday = calendar.dateComponents([.weekday], from: monthInterval.start).weekday else {
            return []
        }

        var days: [Date?] = []

        let emptyCells = (firstWeekday - calendar.firstWeekday + 7) % 7
        days.append(contentsOf: Array(repeating: nil, count: emptyCells))

        var date = monthInterval.start
        while date < monthInterval.end {
            days.append(date)
            date = calendar.date(byAdding: .day, value: 1, to: date)!
        }

        return days
    }

    private func changeMonth(by value: Int) {
        if let newMonth = calendar.date(byAdding: .month, value: value, to: currentMonth) {
            var t = Transaction()
            t.disablesAnimations = true
            withTransaction(t) {
                selectedDate = nil
                panelDragOffset = 0
                panelInsetHeight = 0
            }
            currentMonth = newMonth
        }
    }

    /// パネルに表示する日付（選択中 or スライドアウト中）
    private var panelDisplayDate: Date? {
        selectedDate ?? dismissingPanelDate
    }

    private var isPanelPresented: Bool {
        if let date = selectedDate,
           let aggregates = aggregatesByDate[date],
           !aggregates.isEmpty {
            return true
        }
        return false
    }
}

private struct PanelHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private struct PanelHeightReader: View {
    var body: some View {
        GeometryReader { proxy in
            Color.clear
                .preference(key: PanelHeightPreferenceKey.self, value: proxy.size.height)
        }
    }
}

// MARK: - シート表示用ラッパー（後方互換性維持）

struct CalendarPickerSheet: View {
    let visitsByDate: [Date: [String]]
    let onSelectDate: (Date) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            CalendarContentView(
                visitsByDate: visitsByDate,
                aggregatesByDate: [:],
                labelMap: [:],
                groupMap: [:],
                memberMap: [:]
            )
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L.Common.close) {
                        dismiss()
                    }
                }
            }
        }
    }
}
