import re

with open("Features/Garage/VehicleAnalyticsView.swift", "r") as f:
    code = f.read()

insight_tile_old = """struct InsightTile: View {
    let title: String
    let state: MetricState<String>
    let icon: String
    var compact: Bool = false
    
    var body: some View {
        SurfaceCard(padding: compact ? 12 : 16) {
            VStack(alignment: .leading, spacing: compact ? 6 : 8) {
                HStack(spacing: 5) {
                    Image(systemName: icon)
                        .font(.system(size: compact ? 12 : 13))
                        .foregroundStyle(AppTheme.accent)
                    Text(title)
                        .font(.system(size: compact ? 10 : 11, weight: .medium))
                        .foregroundStyle(AppTheme.secondaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
                
                switch state {
                case .ready(let value):
                    Text(value)
                        .font(.system(size: compact ? 16 : 17, weight: .bold))
                        .foregroundStyle(AppTheme.primaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                case .notEnoughHistory(let msg):
                    Text(msg)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(AppTheme.tertiaryText)
                        .lineLimit(compact ? 1 : 2)
                        .minimumScaleFactor(0.8)
                case .neverRecorded:
                    Text("No recent record")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(AppTheme.tertiaryText)
                case .incompleteRecord:
                    Text("Estimate — log more history")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(AppTheme.tertiaryText)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(minHeight: compact ? 42 : 72, alignment: .topLeading)
        }
    }
}"""

insight_tile_fallback_old = """struct InsightTile: View {
    let title: String
    let state: MetricState<String>
    let icon: String
    
    var body: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: icon)
                        .font(.system(size: 13))
                        .foregroundStyle(AppTheme.accent)
                    Text(title)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(AppTheme.secondaryText)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                }
                
                switch state {
                case .ready(let value):
                    Text(value)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(AppTheme.primaryText)
                        .lineLimit(2)
                        .minimumScaleFactor(0.5)
                case .notEnoughHistory(let msg):
                    Text(msg)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(AppTheme.tertiaryText)
                        .lineLimit(2)
                case .neverRecorded:
                    Text("No recent record")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(AppTheme.tertiaryText)
                case .incompleteRecord:
                    Text("Estimate — log more history")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(AppTheme.tertiaryText)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(minHeight: 72, alignment: .topLeading)
        }
    }
}"""

insight_tile_new = """struct InsightTile: View {
    let title: String
    let state: MetricState<String>
    let icon: String
    var compact: Bool = false
    
    var body: some View {
        SurfaceCard(padding: compact ? 12 : 16) {
            VStack(alignment: .leading, spacing: compact ? 6 : 8) {
                HStack(spacing: 5) {
                    Image(systemName: icon)
                        .font(.system(size: compact ? 12 : 13))
                        .foregroundStyle(AppTheme.accent)
                    Text(title)
                        .font(.system(size: compact ? 10 : 11, weight: .medium))
                        .foregroundStyle(AppTheme.secondaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
                
                switch state {
                case .ready(let value):
                    Text(value)
                        .font(.system(size: compact ? 16 : 17, weight: .bold))
                        .foregroundStyle(AppTheme.primaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                case .notEnoughHistory(let msg):
                    Text(msg)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(AppTheme.tertiaryText)
                        .lineLimit(compact ? 1 : 2)
                        .minimumScaleFactor(0.8)
                case .neverRecorded:
                    Text("No recent record")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(AppTheme.tertiaryText)
                case .incompleteRecord:
                    Text("Estimate — log more history")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(AppTheme.tertiaryText)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(minHeight: compact ? 42 : 72, alignment: .topLeading)
        }
    }
}"""

insight_message_card = """
struct InsightMessageCard: View {
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
                        .frame(width: 40, height: 40)
                    Image(systemName: icon)
                        .foregroundStyle(iconColor)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.primaryText)
                    
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(messageColor)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
        }
    }
}
"""

if insight_tile_fallback_old in code:
    code = code.replace(insight_tile_fallback_old, insight_tile_new + insight_message_card)
elif insight_tile_old in code:
    # If the compact tile is already there but InsightMessageCard isn't, just inject it
    if "struct InsightMessageCard" not in code:
        code = code.replace(insight_tile_old, insight_tile_old + insight_message_card)


# Finance Tab Updates
finance_old = """                HStack(spacing: 12) {
                    InsightTile(title: "This Year", state: .ready(AppFormatters.currency(viewModel.thisYearSpend, code: vehicle.currencyCode)), icon: "calendar")
                    InsightTile(title: "Last 12 Months", state: .ready(AppFormatters.currency(viewModel.last12MonthsSpend, code: vehicle.currencyCode)), icon: "clock.arrow.circlepath")
                }"""
finance_new = """                HStack(spacing: 10) {
                    InsightTile(title: "This Year", state: .ready(AppFormatters.currency(viewModel.thisYearSpend, code: vehicle.currencyCode)), icon: "calendar", compact: true)
                    InsightTile(title: "Last 12 Months", state: .ready(AppFormatters.currency(viewModel.last12MonthsSpend, code: vehicle.currencyCode)), icon: "clock.arrow.circlepath", compact: true)
                }"""
code = code.replace(finance_old, finance_new)

finance_forecast_old = """                SurfaceCard(tier: .primary) {
                    VStack(alignment: .leading, spacing: 12) {"""
finance_forecast_new = """                SurfaceCard(tier: .primary, padding: 16) {
                    VStack(alignment: .leading, spacing: 12) {"""
code = code.replace(finance_forecast_old, finance_forecast_new)

finance_hero_old = """                SurfaceCard(tier: .primary) {
                    VStack(alignment: .leading, spacing: 6) {"""
finance_hero_new = """                SurfaceCard(tier: .primary, padding: 20) {
                    VStack(alignment: .leading, spacing: 6) {"""
code = code.replace(finance_hero_old, finance_hero_new)

finance_trend_old = """                    SurfaceCard {
                        HStack(alignment: .top, spacing: 14) {
                            ZStack {
                                Circle()
                                    .fill(AppTheme.surfaceSecondary)
                                    .frame(width: 40, height: 40)
                                Image(systemName: viewModel.spendTrend90Days > 0 ? "chart.line.uptrend.xyaxis" : "chart.line.downtrend.xyaxis")
                                    .foregroundStyle(viewModel.spendTrend90Days > 0 ? Color.orange : AppTheme.accent)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text("90-Day Trend")
                                    .font(.headline.weight(.semibold))
                                    .foregroundStyle(AppTheme.primaryText)

                                Text(viewModel.financialSpendTrendText)
                                    .font(.subheadline)
                                    .foregroundStyle(AppTheme.secondaryText)
                            }
                            Spacer()
                        }
                    }"""
finance_trend_new = """                    InsightMessageCard(icon: viewModel.spendTrend90Days > 0 ? "chart.line.uptrend.xyaxis" : "chart.line.downtrend.xyaxis", iconColor: viewModel.spendTrend90Days > 0 ? Color.orange : AppTheme.accent, title: "90-Day Trend", message: viewModel.financialSpendTrendText)"""
code = code.replace(finance_trend_old, finance_trend_new)


# Service Tab Updates
service_hero_old = """                SurfaceCard {
                    HStack(alignment: .top, spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(AppTheme.surfaceSecondary)
                                .frame(width: 40, height: 40)
                            Image(systemName: "wrench.and.screwdriver.fill")
                                .foregroundStyle(viewModel.overdueMaintenanceCount > 0 ? Color.red : AppTheme.accent)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Service Health")
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(AppTheme.primaryText)
                            
                            Text(viewModel.maintenanceHealthText)
                                .font(.subheadline)
                                .foregroundStyle(viewModel.overdueMaintenanceCount > 0 ? Color.red : AppTheme.secondaryText)
                        }
                        Spacer()
                    }
                }"""
service_hero_new = """                InsightMessageCard(
                    icon: "wrench.and.screwdriver.fill",
                    iconColor: viewModel.overdueMaintenanceCount > 0 ? Color.red : AppTheme.accent,
                    title: "Service Health",
                    message: viewModel.maintenanceHealthText,
                    messageColor: viewModel.overdueMaintenanceCount > 0 ? Color.red : AppTheme.secondaryText
                )"""
code = code.replace(service_hero_old, service_hero_new)

service_stats_old = """                HStack(spacing: 12) {
                    InsightTile(title: "Due Soon", state: .ready("\(viewModel.upcomingMaintenanceCount)"), icon: "clock.badge.exclamationmark.fill")
                    InsightTile(title: "Overdue", state: .ready("\(viewModel.overdueMaintenanceCount)"), icon: "exclamationmark.circle.fill")
                }"""
service_stats_new = """                HStack(spacing: 10) {
                    InsightTile(title: "Due Soon", state: .ready("\(viewModel.upcomingMaintenanceCount)"), icon: "clock.badge.exclamationmark.fill", compact: true)
                    InsightTile(title: "Overdue", state: .ready("\(viewModel.overdueMaintenanceCount)"), icon: "exclamationmark.circle.fill", compact: true)
                }"""
code = code.replace(service_stats_old, service_stats_new)

service_basic_old = """                SurfaceCard(tier: .primary) {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Basic Tracking")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(AppTheme.primaryText)
                        
                        VStack(spacing: 12) {"""
service_basic_new = """                SurfaceCard(tier: .primary, padding: 16) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Basic Tracking")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(AppTheme.primaryText)
                        
                        VStack(spacing: 10) {"""
code = code.replace(service_basic_old, service_basic_new)

service_pro_old = """                    HStack(spacing: 12) {
                        InsightTile(title: "Average Interval", state: viewModel.averageServiceIntervalDays, icon: "clock.arrow.2.circlepath")
                        InsightTile(title: "Highest Cost Category", state: viewModel.mostExpensiveMaintenanceCategory, icon: "exclamationmark.triangle.fill")
                    }"""
service_pro_new = """                    HStack(spacing: 10) {
                        InsightTile(title: "Average Interval", state: viewModel.averageServiceIntervalDays, icon: "clock.arrow.2.circlepath", compact: true)
                        InsightTile(title: "Highest Cost Category", state: viewModel.mostExpensiveMaintenanceCategory, icon: "exclamationmark.triangle.fill", compact: true)
                    }"""
code = code.replace(service_pro_old, service_pro_new)


# Fuel Tab Updates
fuel_hero_old = """                SurfaceCard {
                    HStack(alignment: .top, spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(AppTheme.surfaceSecondary)
                                .frame(width: 40, height: 40)
                            Image(systemName: "fuelpump.fill")
                                .foregroundStyle(AppTheme.accent)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Fuel Snapshot")
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(AppTheme.primaryText)
                            
                            Text(viewModel.fuelSpendTrendText)
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer()
                    }
                }"""
fuel_hero_new = """                InsightMessageCard(
                    icon: "fuelpump.fill",
                    iconColor: AppTheme.accent,
                    title: "Fuel Snapshot",
                    message: viewModel.fuelSpendTrendText
                )"""
code = code.replace(fuel_hero_old, fuel_hero_new)

fuel_stats_old = """                HStack(spacing: 12) {
                    InsightTile(title: "Average Fuel Price", state: viewModel.averageFuelPrice, icon: "dollarsign.circle")
                    InsightTile(title: "Recent Avg (Last 3 cycles)", state: viewModel.recentAverageConsumption, icon: "gauge.medium")
                }"""
fuel_stats_new = """                HStack(spacing: 10) {
                    InsightTile(title: "Average Fuel Price", state: viewModel.averageFuelPrice, icon: "dollarsign.circle", compact: true)
                    InsightTile(title: "Recent Avg", state: viewModel.recentAverageConsumption, icon: "gauge.medium", compact: true)
                }"""
code = code.replace(fuel_stats_old, fuel_stats_new)

fuel_pro_old = """                    HStack(spacing: 12) {
                        InsightTile(title: "All-Time Avg", state: viewModel.allTimeAverageConsumption, icon: "chart.line.uptrend.xyaxis")
                        InsightTile(title: "Fuel Cost / 100 km", state: viewModel.costPer100Km, icon: "road.lanes")
                    }"""
fuel_pro_new = """                    HStack(spacing: 10) {
                        InsightTile(title: "All-Time Avg", state: viewModel.allTimeAverageConsumption, icon: "chart.line.uptrend.xyaxis", compact: true)
                        InsightTile(title: "Fuel Cost / 100 km", state: viewModel.costPer100Km, icon: "road.lanes", compact: true)
                    }"""
code = code.replace(fuel_pro_old, fuel_pro_new)


# Resale Tab Updates
resale_hero_old = """                SurfaceCard(tier: .primary) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Buyer-Ready Status")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(AppTheme.primaryText)
                            
                        HStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .stroke(AppTheme.surfaceSecondary, lineWidth: 8)
                                    .frame(width: 80, height: 80)
                                
                                Circle()
                                    .trim(from: 0, to: CGFloat(viewModel.resaleReadinessScore) / 100.0)
                                    .stroke(viewModel.resaleReadinessColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                                    .frame(width: 80, height: 80)
                                    .rotationEffect(.degrees(-90))
                                    
                                Text("\(viewModel.resaleReadinessScore)%")
                                    .font(.system(size: 20, weight: .bold))"""
resale_hero_new = """                SurfaceCard(tier: .primary, padding: 20) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Buyer-Ready Status")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(AppTheme.primaryText)
                            
                        HStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .stroke(AppTheme.surfaceSecondary, lineWidth: 8)
                                    .frame(width: 72, height: 72)
                                
                                Circle()
                                    .trim(from: 0, to: CGFloat(viewModel.resaleReadinessScore) / 100.0)
                                    .stroke(viewModel.resaleReadinessColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                                    .frame(width: 72, height: 72)
                                    .rotationEffect(.degrees(-90))
                                    
                                Text("\(viewModel.resaleReadinessScore)%")
                                    .font(.system(size: 18, weight: .bold))"""
code = code.replace(resale_hero_old, resale_hero_new)

resale_stats_old = """                HStack(spacing: 12) {
                    InsightTile(title: "Service Records", state: .ready("\(viewModel.serviceRecordCount)"), icon: "doc.text.fill")
                    InsightTile(title: "Receipt Coverage", state: .ready(String(format: "%.0f%%", viewModel.receiptCoveragePercentage)), icon: "paperclip")
                }"""
resale_stats_new = """                HStack(spacing: 10) {
                    InsightTile(title: "Service Records", state: .ready("\(viewModel.serviceRecordCount)"), icon: "doc.text.fill", compact: true)
                    InsightTile(title: "Receipt Coverage", state: .ready(String(format: "%.0f%%", viewModel.receiptCoveragePercentage)), icon: "paperclip", compact: true)
                }"""
code = code.replace(resale_stats_old, resale_stats_new)

resale_list_old = """                SurfaceCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Resale Checklist")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(AppTheme.primaryText)
                            
                        ChecklistItem(title: "Detailed service history", isComplete: viewModel.serviceRecordCount > 3)
                        ChecklistItem(title: "Supporting receipt coverage", isComplete: viewModel.receiptCoveragePercentage > 70)
                        ChecklistItem(title: "Documents in Vault", isComplete: viewModel.vaultDocumentCount > 0)
                    }
                }"""
resale_list_new = """                SurfaceCard(padding: 16) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Resale Checklist")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(AppTheme.primaryText)
                            
                        VStack(spacing: 10) {
                            ChecklistItem(title: "Detailed service history", isComplete: viewModel.serviceRecordCount > 3)
                            ChecklistItem(title: "Supporting receipt coverage", isComplete: viewModel.receiptCoveragePercentage > 70)
                            ChecklistItem(title: "Documents in Vault", isComplete: viewModel.vaultDocumentCount > 0)
                        }
                    }
                }"""
code = code.replace(resale_list_old, resale_list_new)

resale_pro_old = """                    HStack(spacing: 12) {
                        InsightTile(title: "Buyer Support Docs", state: .ready("\(viewModel.buyerSupportDocumentCount)"), icon: "text.book.closed.fill")
                        InsightTile(title: "Documents in Vault", state: .ready("\(viewModel.vaultDocumentCount)"), icon: "doc.on.doc.fill")
                    }"""
resale_pro_new = """                    HStack(spacing: 10) {
                        InsightTile(title: "Buyer Support Docs", state: .ready("\(viewModel.buyerSupportDocumentCount)"), icon: "text.book.closed.fill", compact: true)
                        InsightTile(title: "Documents in Vault", state: .ready("\(viewModel.vaultDocumentCount)"), icon: "doc.on.doc.fill", compact: true)
                    }"""
code = code.replace(resale_pro_old, resale_pro_new)


# Garage Tab Updates
garage_hero_old = """                SurfaceCard {
                    HStack(alignment: .top, spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(AppTheme.surfaceSecondary)
                                .frame(width: 40, height: 40)
                            Image(systemName: "car.2.fill")
                                .foregroundStyle(AppTheme.accent)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Garage Intelligence")
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(AppTheme.primaryText)
                            
                            Text(viewModel.garageIntelligenceText)
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.secondaryText)
                        }
                        Spacer()
                    }
                }"""
garage_hero_new = """                InsightMessageCard(
                    icon: "car.2.fill",
                    iconColor: AppTheme.accent,
                    title: "Garage Intelligence",
                    message: viewModel.garageIntelligenceText
                )"""
code = code.replace(garage_hero_old, garage_hero_new)

garage_stats_old = """                HStack(spacing: 12) {
                    InsightTile(title: "Vehicles in Garage", state: .ready("\(viewModel.garageVehicleCount)"), icon: "car.2.fill")
                    InsightTile(title: "Garage Spend This Year", state: .ready(AppFormatters.currency(viewModel.garageTotalSpendThisYear, code: vehicle.currencyCode)), icon: "calendar")
                }"""
garage_stats_new = """                HStack(spacing: 10) {
                    InsightTile(title: "Vehicles", state: .ready("\(viewModel.garageVehicleCount)"), icon: "car.2.fill", compact: true)
                    InsightTile(title: "Garage Spend This Year", state: .ready(AppFormatters.currency(viewModel.garageTotalSpendThisYear, code: vehicle.currencyCode)), icon: "calendar", compact: true)
                }"""
code = code.replace(garage_stats_old, garage_stats_new)


# Update ScrollView content padding in VehicleAnalyticsView
scroll_padding_old = """                    .padding(AppTheme.Spacing.pageEdge)
                    .padding(.bottom, 40)"""
scroll_padding_new = """                    .padding(AppTheme.Spacing.pageEdge)
                    .padding(.top, 4)
                    .padding(.bottom, 40)"""
code = code.replace(scroll_padding_old, scroll_padding_new)


with open("Features/Garage/VehicleAnalyticsView.swift", "w") as f:
    f.write(code)

