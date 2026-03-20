import re

with open("Features/Garage/VehicleAnalyticsView.swift", "r") as f:
    code = f.read()

# 1. Reduce compact stat card height further
# In InsightTile, adjust padding and spacing when compact
insight_tile_old = """struct InsightTile: View {
    let title: String
    let state: MetricState<String>
    let icon: String
    var compact: Bool = false
    
    var body: some View {
        SurfaceCard(padding: compact ? 12 : 16) {
            VStack(alignment: .leading, spacing: compact ? 6 : 8) {"""
insight_tile_new = """struct InsightTile: View {
    let title: String
    let state: MetricState<String>
    let icon: String
    var compact: Bool = false
    
    var body: some View {
        SurfaceCard(padding: compact ? 10 : 16) {
            VStack(alignment: .leading, spacing: compact ? 4 : 8) {"""
code = code.replace(insight_tile_old, insight_tile_new)

# In InsightTile, adjust frame minHeight
insight_tile_frame_old = """.frame(maxWidth: .infinity, alignment: .leading)
            .frame(minHeight: compact ? 42 : 72, alignment: .topLeading)"""
insight_tile_frame_new = """.frame(maxWidth: .infinity, alignment: .leading)
            .frame(minHeight: compact ? 36 : 72, alignment: .topLeading)"""
code = code.replace(insight_tile_frame_old, insight_tile_frame_new)

# Reduce font sizes slightly for the state values when compact
insight_tile_value_old = """.font(.system(size: compact ? 16 : 17, weight: .bold))"""
insight_tile_value_new = """.font(.system(size: compact ? 15 : 17, weight: .bold))"""
code = code.replace(insight_tile_value_old, insight_tile_value_new)


# 2. Reduce padding in medium info cards (InsightMessageCard)
insight_message_old = """struct InsightMessageCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let message: String
    var messageColor: Color = AppTheme.secondaryText

    var body: some View {
        SurfaceCard(padding: 14) {
            HStack(alignment: .center, spacing: 14) {
                ZStack {
                    Circle()
                        .fill(AppTheme.surfaceSecondary)
                        .frame(width: 40, height: 40)"""
insight_message_new = """struct InsightMessageCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let message: String
    var messageColor: Color = AppTheme.secondaryText

    var body: some View {
        SurfaceCard(padding: 12) {
            HStack(alignment: .center, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(AppTheme.surfaceSecondary)
                        .frame(width: 36, height: 36)"""
code = code.replace(insight_message_old, insight_message_new)


# 3. Tighten footer/help text sections
# In DataConfidenceFootnote (actually I see this is just a Text or HStack, let's fix it where it is used)
# Many footers are text directly in the view
footnote_old_1 = """.font(.footnote)
                        .foregroundStyle(AppTheme.tertiaryText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)"""
footnote_new_1 = """.font(.caption2)
                        .foregroundStyle(AppTheme.tertiaryText)
                        .multilineTextAlignment(.center)
                        .lineSpacing(-1)
                        .padding(.horizontal, 16)
                        .padding(.top, -4)"""
code = code.replace(footnote_old_1, footnote_new_1)

# Fuel footnote
footnote_old_2 = """.font(.footnote)
                    .foregroundStyle(AppTheme.tertiaryText)
                    .fixedSize(horizontal: false, vertical: true)"""
footnote_new_2 = """.font(.caption2)
                    .foregroundStyle(AppTheme.tertiaryText)
                    .lineSpacing(-1)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, -2)"""
code = code.replace(footnote_old_2, footnote_new_2)


# 4. Densify row-based cards
# Basic Tracking / Resale Checklist / Garage Snapshot
basic_tracking_old = """                        VStack(spacing: 10) {
                            AnalyticsRow(title: "Oil Change", state: viewModel.daysSinceLastOilChange)"""
basic_tracking_new = """                        VStack(spacing: 8) {
                            AnalyticsRow(title: "Oil Change", state: viewModel.daysSinceLastOilChange)"""
code = code.replace(basic_tracking_old, basic_tracking_new)

analytics_row_old = """        }
        .padding(.vertical, 2)"""
analytics_row_new = """        }
        .padding(.vertical, 0)"""
code = code.replace(analytics_row_old, analytics_row_new)

checklist_card_old = """                        VStack(spacing: 10) {
                            ChecklistItem(title: "Detailed service history", isComplete: viewModel.serviceRecordCount > 3)"""
checklist_card_new = """                        VStack(spacing: 8) {
                            ChecklistItem(title: "Detailed service history", isComplete: viewModel.serviceRecordCount > 3)"""
code = code.replace(checklist_card_old, checklist_card_new)

garage_snap_old = """                        AnalyticsDetailRow(
                            title: "Top vehicle by total cost",
                            value: viewModel.garageTopVehicleSummary ?? "Add more tracked costs to compare your garage."
                        )
                        Divider().overlay(AppTheme.separator)
                        AnalyticsDetailRow(
                            title: "Highest fuel spend",
                            value: viewModel.garageHighestFuelSpendSummary ?? "Log fuel across vehicles to compare spend."
                        )
                        Divider().overlay(AppTheme.separator)
                        AnalyticsDetailRow(
                            title: "Latest serviced vehicle",
                            value: viewModel.garageLatestServiceSummary ?? "Add service records to build a garage timeline."
                        )"""
garage_snap_new = """                        AnalyticsDetailRow(
                            title: "Top vehicle by total cost",
                            value: viewModel.garageTopVehicleSummary ?? "Add more tracked costs to compare your garage."
                        )
                        Divider().overlay(AppTheme.separator)
                        AnalyticsDetailRow(
                            title: "Highest fuel spend",
                            value: viewModel.garageHighestFuelSpendSummary ?? "Log fuel across vehicles to compare spend."
                        )
                        Divider().overlay(AppTheme.separator)
                        AnalyticsDetailRow(
                            title: "Latest serviced vehicle",
                            value: viewModel.garageLatestServiceSummary ?? "Add service records to build a garage timeline."
                        )""" # the row padding is what makes this dense, handled by AnalyticsDetailRow
# code.replace(garage_snap_old, garage_snap_new)

analytics_detail_row_old = """        }
        .padding(.vertical, 2)
    }
}"""
analytics_detail_row_new = """        }
        .padding(.vertical, 0)
    }
}"""
code = code.replace(analytics_detail_row_old, analytics_detail_row_new)


# 5. Chart Cards balance
# In Spending by Year
chart_year_old = """.frame(height: 160)"""
chart_year_new = """.frame(height: 140)"""
code = code.replace(chart_year_old, chart_year_new)

# In Breakdown by Category
chart_cat_old = """.frame(height: 180)"""
chart_cat_new = """.frame(height: 160)"""
code = code.replace(chart_cat_old, chart_cat_new)


# Ensure card headers (like "Basic Tracking") have less bottom space
section_header_old = """                    VStack(alignment: .leading, spacing: 12) {
                        Text("Basic Tracking")
                            .font(.headline.weight(.semibold))"""
section_header_new = """                    VStack(alignment: .leading, spacing: 10) {
                        Text("Basic Tracking")
                            .font(.headline.weight(.semibold))"""
code = code.replace(section_header_old, section_header_new)

garage_header_old = """                    VStack(alignment: .leading, spacing: 12) {
                        Text("Garage Snapshot")
                            .font(.headline.weight(.semibold))"""
garage_header_new = """                    VStack(alignment: .leading, spacing: 10) {
                        Text("Garage Snapshot")
                            .font(.headline.weight(.semibold))"""
code = code.replace(garage_header_old, garage_header_new)

resale_header_old = """                    VStack(alignment: .leading, spacing: 12) {
                        Text("Resale Checklist")
                            .font(.headline.weight(.semibold))"""
resale_header_new = """                    VStack(alignment: .leading, spacing: 10) {
                        Text("Resale Checklist")
                            .font(.headline.weight(.semibold))"""
code = code.replace(resale_header_old, resale_header_new)

# Also fix the vertical spacing of the lists
list_spacing_old = """                                        .padding(.vertical, 8)

                                        if index < viewModel.spendingByCategory.count - 1 {"""
list_spacing_new = """                                        .padding(.vertical, 6)

                                        if index < viewModel.spendingByCategory.count - 1 {"""
code = code.replace(list_spacing_old, list_spacing_new)

list_spacing2_old = """                                        .padding(.vertical, 8)

                                        if index < viewModel.costPerKmByVehicle.count - 1 {"""
list_spacing2_new = """                                        .padding(.vertical, 6)

                                        if index < viewModel.costPerKmByVehicle.count - 1 {"""
code = code.replace(list_spacing2_old, list_spacing2_new)


with open("Features/Garage/VehicleAnalyticsView.swift", "w") as f:
    f.write(code)

