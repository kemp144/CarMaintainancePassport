import SwiftData
import SwiftUI

struct ReminderFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var entitlementStore: EntitlementStore
    @EnvironmentObject private var paywallCoordinator: PaywallCoordinator
    @Query(sort: \Vehicle.updatedAt, order: .reverse) private var vehicles: [Vehicle]

    private let reminder: ReminderItem?
    private let linkedService: ServiceEntry?
    private let initialVehicle: Vehicle?

    @State private var selectedVehicleID: UUID?
    @State private var type: ReminderType
    @State private var title: String
    @State private var notes: String
    @State private var includesDate: Bool
    @State private var dateDue: Date
    @State private var includesMileage: Bool
    @State private var mileageDue: String
    @State private var timing: NotificationTiming
    @State private var isEnabled: Bool

    init(vehicle: Vehicle? = nil, linkedService: ServiceEntry? = nil, reminder: ReminderItem? = nil) {
        self.reminder = reminder
        self.linkedService = linkedService ?? reminder?.serviceEntry
        self.initialVehicle = vehicle ?? reminder?.vehicle ?? linkedService?.vehicle
        _selectedVehicleID = State(initialValue: (vehicle ?? reminder?.vehicle ?? linkedService?.vehicle)?.id)
        _type = State(initialValue: reminder?.type ?? linkedService.map { ReminderType(serviceType: $0.serviceType) } ?? .inspection)
        _title = State(initialValue: reminder?.title ?? linkedService.map { "\($0.displayTitle) due" } ?? "")
        _notes = State(initialValue: reminder?.notes ?? "")
        _includesDate = State(initialValue: reminder?.dateDue != nil || linkedService != nil)
        _dateDue = State(initialValue: reminder?.dateDue ?? Calendar.current.date(byAdding: .month, value: 12, to: linkedService?.date ?? .now) ?? .now)
        _includesMileage = State(initialValue: reminder?.mileageDue != nil)
        _mileageDue = State(initialValue: reminder?.mileageDue.map { UnitFormatter.distanceValue(Double($0)) } ?? "")
        _timing = State(initialValue: reminder?.notificationTiming ?? .sevenDaysBefore)
        _isEnabled = State(initialValue: reminder?.isEnabled ?? true)
    }

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            Form {
                Section {
                    Picker("Vehicle", selection: $selectedVehicleID) {
                        ForEach(vehicles) { vehicle in
                            Text(vehicle.title).tag(Optional(vehicle.id))
                        }
                    }
                    .disabled(initialVehicle != nil)
                } header: {
                    Text("Vehicle").foregroundStyle(AppTheme.secondaryText)
                }
                .listRowBackground(AppTheme.surface)

                Section {
                    Picker("Type", selection: $type) {
                        ForEach(ReminderType.allCases) { type in
                            Text(type.title).tag(type)
                        }
                    }
                    TextField("Title", text: $title)
                    TextField("Notes (Optional)", text: $notes, axis: .vertical)
                        .lineLimit(3...5)
                } header: {
                    Text("Reminder Details").foregroundStyle(AppTheme.secondaryText)
                }
                .listRowBackground(AppTheme.surface)

                Section {
                    Toggle("Set due date", isOn: $includesDate)
                    if includesDate {
                        DatePicker("Date", selection: $dateDue, displayedComponents: .date)
                        Picker("Notification", selection: $timing) {
                            ForEach(NotificationTiming.allCases) { timing in
                                Text(timing.title).tag(timing)
                            }
                        }
                    }

                    HStack {
                        Toggle("Set mileage (Pro)", isOn: $includesMileage)
                            .onChange(of: includesMileage) { newValue in
                                if newValue && !entitlementStore.canUseAdvancedReminders() {
                                    includesMileage = false
                                    paywallCoordinator.present(.advancedReminders)
                                }
                            }
                    }
                    
                    if includesMileage {
                        TextField("Mileage due (\(UnitSettings.currentDistanceUnit.shortTitle))", text: $mileageDue)
                            .keyboardType(.numberPad)
                    }

                    Toggle("Enable reminder", isOn: $isEnabled)
                } header: {
                    Text("Triggers").foregroundStyle(AppTheme.secondaryText)
                }
                .listRowBackground(AppTheme.surface)
            }
            .scrollContentBackground(.hidden)
            .foregroundStyle(AppTheme.primaryText)
        }
        .navigationTitle(reminder == nil ? "Add Reminder" : "Edit Reminder")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    Task { await saveReminder() }
                }
                .disabled(selectedVehicle == nil || title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    private var selectedVehicle: Vehicle? {
        vehicles.first(where: { $0.id == selectedVehicleID }) ?? initialVehicle
    }

    private func saveReminder() async {
        guard let vehicle = selectedVehicle else { return }
        let parsedMileageDue = includesMileage ? UnitFormatter.parseDistance(mileageDue) : nil
        if includesMileage && parsedMileageDue == nil { return }

        let activeReminder: ReminderItem
        if let reminder {
            reminder.vehicle = vehicle
            reminder.serviceEntry = linkedService
            reminder.type = type
            reminder.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
            reminder.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
            reminder.dateDue = includesDate ? dateDue : nil
            reminder.mileageDue = parsedMileageDue
            reminder.notificationTiming = timing
            reminder.isEnabled = isEnabled
            reminder.updatedAt = .now
            activeReminder = reminder
        } else {
            let newReminder = ReminderItem(
                vehicle: vehicle,
                serviceEntry: linkedService,
                type: type,
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
                dateDue: includesDate ? dateDue : nil,
                mileageDue: parsedMileageDue,
                notificationTiming: timing,
                isEnabled: isEnabled
            )
            modelContext.insert(newReminder)
            activeReminder = newReminder
        }

        if !isEnabled || !includesDate {
            NotificationService.shared.cancel(identifier: activeReminder.notificationIdentifier)
            activeReminder.notificationIdentifier = nil
        } else {
            activeReminder.notificationIdentifier = await NotificationService.shared.schedule(for: activeReminder, vehicleName: vehicle.title)
        }

        vehicle.updatedAt = .now
        try? modelContext.save()
        Haptics.success()
        dismiss()
    }
}
