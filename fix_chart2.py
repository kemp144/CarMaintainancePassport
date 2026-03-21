import re

with open("Features/Fuel/FuelTrackingView.swift", "r") as f:
    content = f.read()

# Fix chart compiler too complex error
chart_old = """    @ViewBuilder
    private var chartContent: some View {
        Chart {
            if selectedChartMetric == .spend {
                ForEach(chartPoints) { point in
                    BarMark(
                        x: .value("Date", point.date),
                        y: .value("Value", point.value)
                    )
                    .foregroundStyle(selectedChartPoint?.id == point.id ? AppTheme.accent.gradient : AppTheme.accent.opacity(0.3).gradient)
                    .cornerRadius(6)
                }
            } else {
                ForEach(chartPoints) { point in
                    AreaMark(
                        x: .value("Date", point.date),
                        y: .value("Value", point.value)
                    )
                    .foregroundStyle(AppTheme.accent.opacity(0.14))

                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("Value", point.value)
                    )
                    .foregroundStyle(AppTheme.accent)
                    .lineStyle(.init(lineWidth: 2.5, lineCap: .round))

                    PointMark(
                        x: .value("Date", point.date),
                        y: .value("Value", point.value)
                    )
                    .foregroundStyle(AppTheme.accent)
                    .symbolSize(selectedChartPoint?.id == point.id ? 100 : 40)
                }
            }

            if let point = selectedChartPoint {
                RuleMark(x: .value("Date", point.date))
                    .foregroundStyle(AppTheme.separator)
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5]))
                    .annotation(position: .top, overflowResolution: .fit) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(AppFormatters.mediumDate.string(from: point.date))
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(AppTheme.secondaryText)
                            Text(formattedChartValue(for: point.value))
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(AppTheme.primaryText)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(AppTheme.elevatedBackground)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(AppTheme.separator, lineWidth: 1)
                        )
                        .shadow(color: Color.black.opacity(0.2), radius: 6, y: 3)
                    }
            }
        }
    }"""

chart_new = """    @ViewBuilder
    private var chartContent: some View {
        Chart {
            chartMarks
            chartOverlay
        }
    }

    @ChartContentBuilder
    private var chartMarks: some ChartContent {
        if selectedChartMetric == .spend {
            ForEach(chartPoints) { point in
                let isSelected = selectedChartPoint?.id == point.id
                BarMark(
                    x: .value("Date", point.date),
                    y: .value("Value", point.value)
                )
                .foregroundStyle(isSelected ? AppTheme.accent.gradient : AppTheme.accent.opacity(0.3).gradient)
                .cornerRadius(6)
            }
        } else {
            ForEach(chartPoints) { point in
                let isSelected = selectedChartPoint?.id == point.id
                
                AreaMark(
                    x: .value("Date", point.date),
                    y: .value("Value", point.value)
                )
                .foregroundStyle(AppTheme.accent.opacity(0.14))

                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Value", point.value)
                )
                .foregroundStyle(AppTheme.accent)
                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))

                PointMark(
                    x: .value("Date", point.date),
                    y: .value("Value", point.value)
                )
                .foregroundStyle(AppTheme.accent)
                .symbolSize(isSelected ? 100 : 40)
            }
        }
    }

    @ChartContentBuilder
    private var chartOverlay: some ChartContent {
        if let point = selectedChartPoint {
            RuleMark(x: .value("Date", point.date))
                .foregroundStyle(AppTheme.separator)
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [5]))
                .annotation(position: .top, overflowResolution: .fit) {
                    chartTooltip(for: point)
                }
        }
    }

    private func chartTooltip(for point: FuelTrendPoint) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(AppFormatters.mediumDate.string(from: point.date))
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(AppTheme.secondaryText)
            Text(formattedChartValue(for: point.value))
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(AppTheme.primaryText)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(AppTheme.elevatedBackground)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(AppTheme.separator, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.2), radius: 6, y: 3)
    }"""

if chart_old in content:
    content = content.replace(chart_old, chart_new)

with open("Features/Fuel/FuelTrackingView.swift", "w") as f:
    f.write(content)

