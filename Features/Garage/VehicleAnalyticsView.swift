import Charts
import SwiftUI

struct VehicleAnalyticsView: View {
    @Environment(\.dismiss) private var dismiss
    let vehicle: Vehicle
    
    private var spendingByYear: [(year: Int, amount: Double)] {
        let entries = vehicle.serviceEntries
        let grouped = Dictionary(grouping: entries) { entry in
            Calendar.current.component(.year, from: entry.date)
        }
        return grouped.map { (year: $0.key, amount: $0.value.reduce(0) { $0 + $1.price }) }
            .sorted { $0.year < $1.year }
    }
    
    private var spendingByCategory: [(category: EntryCategory, amount: Double)] {
        let entries = vehicle.serviceEntries
        let grouped = Dictionary(grouping: entries) { $0.category }
        return grouped.map { (category: $0.key, amount: $0.value.reduce(0) { $0 + $1.price }) }
            .sorted { $0.amount > $1.amount }
    }

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    // Total Summary
                    SurfaceCard(tier: .primary) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("TOTAL LIFETIME SPENT")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(AppTheme.secondaryText)

                            Text(AppFormatters.currency(vehicle.totalSpent, code: vehicle.currencyCode))
                                .font(.system(size: 30, weight: .bold))
                                .foregroundStyle(AppTheme.primaryText)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    // Yearly Chart
                    SurfaceCard(tier: .primary) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Spending by Year")
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(AppTheme.primaryText)

                            if spendingByYear.isEmpty {
                                Text("No data to display")
                                    .font(.subheadline)
                                    .foregroundStyle(AppTheme.secondaryText)
                                    .frame(height: 180)
                            } else {
                                Chart {
                                    ForEach(spendingByYear, id: \.year) { item in
                                        BarMark(
                                            x: .value("Year", String(item.year)),
                                            y: .value("Amount", item.amount)
                                        )
                                        .foregroundStyle(AppTheme.accent.gradient)
                                        .cornerRadius(4)
                                    }
                                }
                                .frame(height: 180)
                            }
                        }
                    }

                    // Category Breakdown
                    SurfaceCard(tier: .primary) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Breakdown by Category")
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(AppTheme.primaryText)

                            if spendingByCategory.isEmpty {
                                Text("No data to display")
                                    .font(.subheadline)
                                    .foregroundStyle(AppTheme.secondaryText)
                                    .frame(height: 200)
                            } else {
                                Chart {
                                    ForEach(spendingByCategory, id: \.category.id) { item in
                                        SectorMark(
                                            angle: .value("Amount", item.amount),
                                            innerRadius: .ratio(0.618),
                                            angularInset: 1.5
                                        )
                                        .foregroundStyle(by: .value("Category", item.category.title))
                                        .cornerRadius(4)
                                    }
                                }
                                .frame(height: 200)
                                .chartLegend(position: .bottom, spacing: 12)
                            }
                        }
                    }

                    // Category List
                    SurfaceCard {
                        VStack(spacing: 0) {
                            ForEach(Array(spendingByCategory.enumerated()), id: \.element.category.id) { index, item in
                                HStack {
                                    Text(item.category.title)
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(AppTheme.primaryText)
                                    Spacer()
                                    Text(AppFormatters.currency(item.amount, code: vehicle.currencyCode))
                                        .font(.subheadline.weight(.bold))
                                        .foregroundStyle(AppTheme.primaryText)
                                }
                                .padding(.vertical, 8)

                                if index < spendingByCategory.count - 1 {
                                    Divider().overlay(AppTheme.separator)
                                }
                            }
                        }
                    }
                }
                .padding(AppTheme.Spacing.pageEdge)
                .padding(.bottom, 40)
            }
        }
        .navigationTitle("Analytics")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { dismiss() }
            }
        }
    }
}
