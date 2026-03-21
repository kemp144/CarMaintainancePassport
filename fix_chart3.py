import re

with open("Features/Fuel/FuelTrackingView.swift", "r") as f:
    content = f.read()

# Fix compilation error: lineStyle does not exist on some Chart3DContent and the type of ChartContent is ambiguous
chart_old = """    @ChartContentBuilder
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
    }"""

chart_new = """    @ChartContentBuilder
    private var chartMarks: some ChartContent {
        if selectedChartMetric == .spend {
            ForEach(chartPoints) { point in
                BarMark(
                    x: .value("Date", point.date),
                    y: .value("Value", point.value)
                )
                .foregroundStyle((selectedChartPoint?.id == point.id) ? AppTheme.accent.gradient : AppTheme.accent.opacity(0.3).gradient)
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
                .symbolSize((selectedChartPoint?.id == point.id) ? 100 : 40)
            }
        }
    }

    @ChartContentBuilder
    private var chartOverlay: some ChartContent {
        if let point = selectedChartPoint {
            RuleMark(x: .value("Date", point.date))
                .foregroundStyle(AppTheme.separator)
                .lineStyle(.init(lineWidth: 1, dash: [5]))
                .annotation(position: .top, alignment: .center, spacing: 0) {
                    chartTooltip(for: point)
                }
        }
    }"""

if chart_old in content:
    content = content.replace(chart_old, chart_new)

with open("Features/Fuel/FuelTrackingView.swift", "w") as f:
    f.write(content)

