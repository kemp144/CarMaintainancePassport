import SwiftData
import SwiftUI

struct ReminderFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
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
        _mileageDue = State(initialValue: reminder?.mileageDue.map(String.init) ?? "")
        _timing = State(initialValue: reminder?.notificationTiming ?? .sevenDaysBefore)
        _isEnabled = State(initialValue: reminder?.isEnabled ?? true)
    }

    var body: some View {
        ZStack {
            PremiumScreenBackground()

            Form {
                Section("Vehicle") {
                    Picker("Vehicle", selection: $selectedVehicleID) {
                        ForEach(vehicles) { vehicle in
                            Text(vehicle.title).tag(Optional(vehicle.id))
                        }
                    }
                    .disabled(initialVehicle != nil)
                }

                Section("Reminder") {
                    Picker("Type", selection: $type) {
                        ForEach(ReminderType.allCases) { type in
                            Text(type.title).tag(type)
                        }
                    }
                    TextField("Title", text: $title)
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(3...5)
                }

                Section("Due") {
                    Toggle("Set due date", isOn: $includesDate)
                    if includesDate {
                        DatePicker("Date", selection: $dateDue, displayedComponents: .date)
                        Picker("Notification", selection: $timing) {
                            ForEach(NotificationTiming.allCases) { timing in
                                Text(timing.title).tag(timing)
                            }
                        }
                    }

                    Toggle("Set mileage", isOn: $includesMileage)
                    if includesMileage {
                        TextField("Mileage due", text: $mileageDue)
                            .keyboardType(.numberPad)
                    }

                    Toggle("Enable reminder", isOn: $isEnabled)
                }
            }
            .scrollContentBackground(.hidden)
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

        let activeReminder: ReminderItem
        if let reminder {
            reminder.vehicle = vehicle
            reminder.serviceEntry = linkedService
            reminder.type = type
            reminder.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
            reminder.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
            reminder.dateDue = includesDate ? dateDue : nil
            reminder.mileageDue = includesMileage ? Int(mileageDue) : nil
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
                mileageDue: includesMileage ? Int(mileageDue) : nil,
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