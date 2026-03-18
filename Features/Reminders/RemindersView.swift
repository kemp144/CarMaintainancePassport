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

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            AppTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Custom Header
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Reminders")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundStyle(AppTheme.primaryText)
                            
                            let count = grouped.reduce(0) { $0 + $1.1.count }
                            Text(count == 0 ? "No reminders yet" : "\(count) \(count == 1 ? "reminder" : "reminders")")
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.secondaryText)
                        }
                        
                        Spacer()
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 20)
                .background(AppTheme.heroGradient)

                VehicleFilterScrollView(vehicles: vehicles)

                if grouped.isEmpty {
                    ScrollView(showsIndicators: false) {
                        ContentUnavailableView {
                            Label("No reminders yet", systemImage: "bell.fill")
                        } description: {
                            Text("Create reminders for inspection, oil service or registration deadlines only when they matter.")
                        } actions: {
                            Button("Add Reminder") {
                                showingReminderForm = true
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(AppTheme.accentSecondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .top)
                        .padding(.top, 20)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                } else {
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 24) {
                            ForEach(grouped, id: \.0.id) { status, items in
                                VStack(alignment: .leading, spacing: 12) {
                                    Text(status.title)
                                        .font(.headline)
                                        .foregroundStyle(AppTheme.primaryText)
                                        .padding(.horizontal, 4)
                                    
                                    LazyVStack(spacing: 16) {
                                        ForEach(items) { reminder in
                                            Button {
                                                editingReminder = reminder
                                            } label: {
                                                SurfaceCard {
                                                    HStack {
                                                        VStack(alignment: .leading, spacing: 4) {
                                                            Text(reminder.title)
                                                                .foregroundStyle(AppTheme.primaryText)
                                                            Text(reminder.vehicle?.title ?? "Unknown vehicle")
                                                                .font(.subheadline)
                                                                .foregroundStyle(AppTheme.secondaryText)
                                                            Text(reminder.dateDue.map(AppFormatters.mediumDate.string) ?? reminder.mileageDue.map(AppFormatters.mileage) ?? "Custom reminder")
                                                                .font(.caption)
                                                                .foregroundStyle(AppTheme.tertiaryText)
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
                        .padding(24)
                        .padding(.bottom, 100)
                    }
                }
            }
            
            // FAB for Reminders
            Button {
                showingReminderForm = true
            } label: {
                Image(systemName: "plus")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 64, height: 64)
                    .background(
                        Circle()
                            .fill(AppTheme.accent)
                            .shadow(color: AppTheme.accent.opacity(0.3), radius: 10, x: 0, y: 5)
                    )
            }
            .padding(.trailing, 24)
            .padding(.bottom, 100) // Above tab bar
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
}