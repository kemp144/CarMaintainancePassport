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
    @State private var linkedServiceEntryID: UUID?
    @State private var linkedServiceDate: Date?
    @State private var linkedServiceMileage: Int?
    @State private var validationMessage: String?
    @State private var showingValidationAlert = false
    @State private var notificationInfoMessage: String?

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
        _linkedServiceEntryID = State(initialValue: reminder?.linkedServiceEntryID ?? linkedService?.id)
        _linkedServiceDate = State(initialValue: reminder?.linkedServiceDate ?? linkedService?.date)
        _linkedServiceMileage = State(initialValue: reminder?.linkedServiceMileage ?? linkedService?.mileage)
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

                    Toggle(
                        entitlementStore.canUseMileageReminders() ? "Set mileage" : "Set mileage (Pro)",
                        isOn: Binding(
                            get: { includesMileage },
                            set: { newValue in
                                if newValue && !entitlementStore.canUseMileageReminders() {
                                    paywallCoordinator.present(.advancedReminders)
                                } else {
                                    includesMileage = newValue
                                }
                            }
                        )
                    )
                    
                    if includesMileage {
                        HStack {
                            Text("Mileage due")
                                .foregroundStyle(AppTheme.primaryText)
                            Spacer()
                            HStack(spacing: 4) {
                                TextField("0", text: $mileageDue)
                                    .keyboardType(.numberPad)
                                    .multilineTextAlignment(.trailing)
                                    .frame(minWidth: 60)
                                Text(UnitSettings.currentDistanceUnit.shortTitle)
                                    .foregroundStyle(AppTheme.secondaryText)
                            }
                        }

                        if !includesDate {
                            Text("Mileage-only reminders are tracked inside the app. Add a due date too if you want a notification.")
                                .font(.caption)
                                .foregroundStyle(AppTheme.tertiaryText)
                        }
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
        .alert("Couldn’t save reminder", isPresented: $showingValidationAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(validationMessage ?? "Please review the entered values.")
        }
        .alert(
            "Notifications Off",
            isPresented: Binding(
                get: { notificationInfoMessage != nil },
                set: { newValue in
                    if !newValue { notificationInfoMessage = nil }
                }
            )
        ) {
            Button("OK", role: .cancel) {
                notificationInfoMessage = nil
                dismiss()
            }
        } message: {
            Text(notificationInfoMessage ?? "")
        }
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

        guard includesDate || includesMileage else {
            validationMessage = "Add at least a due date or a mileage trigger."
            showingValidationAlert = true
            return
        }

        guard !includesMileage || entitlementStore.canUseMileageReminders() else {
            paywallCoordinator.present(.advancedReminders)
            return
        }

        let parsedMileageDue = includesMileage ? UnitFormatter.parseDistance(mileageDue) : nil
        if includesMileage && parsedMileageDue == nil {
            validationMessage = "Mileage due isn’t a valid number."
            showingValidationAlert = true
            return
        }

        let activeReminder: ReminderItem
        if let reminder {
            reminder.vehicle = vehicle
            reminder.serviceEntry = linkedService
            reminder.linkedServiceEntryID = linkedServiceEntryID ?? linkedService?.id
            reminder.linkedServiceDate = linkedServiceDate ?? linkedService?.date
            reminder.linkedServiceMileage = linkedServiceMileage ?? linkedService?.mileage
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
                linkedServiceEntryID: linkedServiceEntryID ?? linkedService?.id,
                linkedServiceDate: linkedServiceDate ?? linkedService?.date,
                linkedServiceMileage: linkedServiceMileage ?? linkedService?.mileage,
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
            let outcome = await NotificationService.shared.schedule(for: activeReminder, vehicleName: vehicle.title)
            activeReminder.notificationIdentifier = outcome.identifier

            if let message = notificationMessage(for: outcome) {
                notificationInfoMessage = message
            }
        }

        vehicle.updatedAt = .now
        do {
            try modelContext.save()
            Haptics.success()
        } catch {
            Haptics.error()
            return
        }

        if notificationInfoMessage == nil {
            dismiss()
        }
    }

    private func notificationMessage(for outcome: NotificationService.ScheduleOutcome) -> String? {
        switch outcome {
        case .permissionDenied:
            return "Reminder saved, but notifications are currently disabled for Car Maintenance Passport. You can enable them in Settings anytime."
        case .schedulingFailed:
            return "Reminder saved, but the notification couldn’t be scheduled. Please try again."
        default:
            return nil
        }
    }
}
