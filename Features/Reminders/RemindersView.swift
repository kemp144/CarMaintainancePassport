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
        ZStack(alignment: .top) {
            PremiumScreenBackground()

            VStack(spacing: 0) {
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
                    List {
                        ForEach(grouped, id: \.0.id) { status, items in
                            Section(status.title) {
                                ForEach(items) { reminder in
                                    Button {
                                        editingReminder = reminder
                                    } label: {
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
                                    .buttonStyle(.plain)
                                    .listRowBackground(Color.clear)
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                }
            }
        }
        .navigationTitle("Reminders")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    showingReminderForm = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
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