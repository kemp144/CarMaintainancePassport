import SwiftData
import SwiftUI

struct RemindersView: View {
    @Query(sort: \ReminderItem.updatedAt, order: .reverse) private var reminders: [ReminderItem]
    @Query(sort: \Vehicle.updatedAt, order: .reverse) private var vehicles: [Vehicle]
    
    @EnvironmentObject private var appState: AppState
    
    @State private var showingReminderForm = false
    @State private var editingReminder: ReminderItem?

    private var grouped: [(ReminderStatus, [ReminderItem])] {
        let orderedStatuses: [ReminderStatus] = [.overdue, .dueSoon, .upcoming, .disabled]
        return orderedStatuses.compactMap { status in
            let matching = reminders.filter { reminder in
                guard let vehicle = reminder.vehicle else { return false }
                
                if appState.showOnlyCurrentVehicle, let globalID = appState.selectedVehicleID {
                    if vehicle.id != globalID { return false }
                } else if let localID = appState.selectedVehicleID {
                    if vehicle.id != localID { return false }
                }
                
                return reminder.status(for: vehicle) == status
            }
            return matching.isEmpty ? nil : (status, matching)
        }
    }

    private var reminderSummary: some View {
        let activeReminders = grouped.reduce(0) { $0 + $1.1.count }
        let overdueCount = reminders.filter { reminder in
            guard let vehicle = reminder.vehicle else { return false }
            return reminder.status(for: vehicle) == .overdue
        }.count
        let mileageCount = reminders.filter { $0.mileageDue != nil }.count

        return SurfaceCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Reminder overview")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AppTheme.primaryText)
                    Spacer()
                    Text("Smart maintenance")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(AppTheme.secondaryText)
                }

                HStack(spacing: 12) {
                    SummaryStatTile(title: "Active", value: "\(activeReminders)", icon: "bell.fill")
                    SummaryStatTile(title: "Overdue", value: "\(overdueCount)", icon: "exclamationmark.triangle.fill")
                    SummaryStatTile(title: "Mileage", value: mileageCount == 0 ? "Pro" : "\(mileageCount)", icon: "speedometer")
                }

                Text("Date reminders are free. Mileage-based reminders require Pro.")
                    .font(.caption)
                    .foregroundStyle(AppTheme.tertiaryText)
            }
        }
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            AppTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Custom Header
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Reminders")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundStyle(AppTheme.primaryText)

                            let count = grouped.reduce(0) { $0 + $1.1.count }
                            Text(count == 0 ? "No reminders yet" : "\(count) \(count == 1 ? "reminder" : "reminders")")
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.secondaryText)
                        }

                        Spacer()
                    }
                }
                .padding(.horizontal, AppTheme.Spacing.pageEdge)
                .padding(.top, AppTheme.Spacing.headerTop)
                .padding(.bottom, AppTheme.Spacing.headerBottom)
                .background(AppTheme.heroGradient)

                VehicleFilterScrollView(vehicles: vehicles)

                if grouped.isEmpty {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 16) {
                            reminderSummary

                            EmptyStateCard(
                                icon: "bell.fill",
                                title: "Keep maintenance on schedule",
                                message: "Date reminders are free. If you want smarter mileage-based reminders, Pro adds that extra layer of protection.",
                                actionTitle: "Add Reminder"
                            ) {
                                showingReminderForm = true
                            }
                        }
                        .padding(.horizontal, AppTheme.Spacing.pageEdge)
                        .padding(.top, AppTheme.Spacing.filterToContent)
                        .padding(.bottom, 120)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                } else {
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 14) {
                            reminderSummary

                            ForEach(grouped, id: \.0.id) { status, items in
                                VStack(alignment: .leading, spacing: 10) {
                                    Text(status.title)
                                        .font(.headline)
                                        .foregroundStyle(AppTheme.primaryText)
                                        .padding(.horizontal, 4)

                                    LazyVStack(spacing: 12) {
                                        ForEach(items) { reminder in
                                            Button {
                                                editingReminder = reminder
                                            } label: {
                                                SurfaceCard {
                                                    HStack(alignment: .top) {
                                                        VStack(alignment: .leading, spacing: 4) {
                                                            Text(reminder.title)
                                                                .foregroundStyle(AppTheme.primaryText)
                                                            Text(reminder.vehicle?.title ?? "Unknown vehicle")
                                                                .font(.subheadline)
                                                                .foregroundStyle(AppTheme.secondaryText)
                                                            Text(reminderDetailText(reminder))
                                                                .font(.caption.weight(.medium))
                                                                .foregroundStyle(AppTheme.tertiaryText)
                                                            if !reminder.notes.isEmpty {
                                                                Text(reminder.notes)
                                                                    .font(.caption2)
                                                                    .foregroundStyle(AppTheme.tertiaryText)
                                                                    .lineLimit(2)
                                                            }
                                                        }
                                                        Spacer()
                                                        ReminderBadge(status: status)
                                                    }
                                                }
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(AppTheme.Spacing.pageEdge)
                        .padding(.bottom, 120)
                    }
                }
            }
            
            FloatingAddButton {
                showingReminderForm = true
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showingReminderForm) {
            NavigationStack {
                ReminderFormView()
            }
        }
        .sheet(item: $editingReminder) { reminder in
            NavigationStack {
                ReminderFormView(reminder: reminder)
            }
        }
    }

    private func reminderDetailText(_ reminder: ReminderItem) -> String {
        if let dateDue = reminder.dateDue {
            return "Due \(AppFormatters.mediumDate.string(from: dateDue))"
        }
        if let mileageDue = reminder.mileageDue {
            return "Due \(AppFormatters.mileage(mileageDue))"
        }
        return reminder.type.title
    }
}