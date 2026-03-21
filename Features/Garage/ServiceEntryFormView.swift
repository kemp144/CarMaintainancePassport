import PhotosUI
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct ServiceEntryFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var entitlementStore: EntitlementStore
    @EnvironmentObject private var paywallCoordinator: PaywallCoordinator
    @Query private var attachments: [AttachmentRecord]
    @Query private var documents: [DocumentRecord]
    @Query(sort: \ReminderItem.updatedAt, order: .reverse) private var reminders: [ReminderItem]
    @Query(sort: \Vehicle.updatedAt, order: .reverse) private var vehicles: [Vehicle]

    private let entry: ServiceEntry?
    private let initialVehicle: Vehicle?

    @State private var selectedVehicleID: UUID?
    @State private var date: Date
    @State private var mileage: String
    @State private var serviceType: ServiceType
    @State private var customServiceTypeName: String
    @State private var category: EntryCategory
    @State private var price: String
    @State private var currencyCode: String
    @State private var workshopName: String
    @State private var notes: String
    @State private var isImportant: Bool
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var draftAttachments: [DraftAttachment] = []
    @State private var removedAttachmentIDs: Set<UUID> = []
    @State private var showingPDFImporter = false
    @State private var showingCamera = false
    @State private var isSaving = false
    @State private var savedEntryForReminder: ServiceEntry?
    @State private var showingReminderSuggestion = false
    @State private var showingCustomReminder = false
    @State private var validationMessage: String?
    @State private var showingValidationAlert = false
    @State private var notificationInfoMessage: String?

    init(vehicle: Vehicle? = nil, entry: ServiceEntry? = nil) {
        self.entry = entry
        self.initialVehicle = vehicle ?? entry?.vehicle
        _selectedVehicleID = State(initialValue: (vehicle ?? entry?.vehicle)?.id)
        _date = State(initialValue: entry?.date ?? .now)
        _mileage = State(initialValue: entry.map { UnitFormatter.distanceValue(Double($0.mileage)) } ?? vehicle.map { UnitFormatter.distanceValue(Double($0.currentMileage)) } ?? "")
        _serviceType = State(initialValue: entry?.serviceType ?? .oilChange)
        _customServiceTypeName = State(initialValue: entry?.customServiceTypeName ?? "")
        _category = State(initialValue: entry?.category ?? (entry?.serviceType.defaultCategory ?? .maintenance))
        _price = State(initialValue: UnitFormatter.decimalInputString(entry?.price == 0 ? nil : entry?.price))
        _currencyCode = State(initialValue: entry?.currencyCode ?? vehicle?.currencyCode ?? CurrencyPreset.suggested().rawValue)
        _workshopName = State(initialValue: entry?.workshopName ?? "")
        _notes = State(initialValue: entry?.notes ?? "")
        _isImportant = State(initialValue: entry?.isImportant ?? false)
        _draftAttachments = State(initialValue: [])
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
                    Picker("Type", selection: Binding(
                        get: { serviceType },
                        set: { newType in
                            serviceType = newType
                            if entry == nil {
                                category = newType.defaultCategory
                            }
                        }
                    )) {
                        ForEach(ServiceType.allCases) { type in
                            Text(type.title).tag(type)
                        }
                    }

                    if serviceType == .custom {
                        TextField("Custom service name", text: $customServiceTypeName)
                    }

                    Picker("Category", selection: $category) {
                        ForEach(EntryCategory.allCases) { category in
                            Text(category.title).tag(category)
                        }
                    }

                    DatePicker("Date", selection: $date, displayedComponents: .date)

                    HStack {
                        Text("Odometer")
                            .foregroundStyle(AppTheme.primaryText)
                        Spacer()
                        HStack(spacing: 4) {
                            TextField("0", text: $mileage)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .frame(minWidth: 60)
                            Text(UnitSettings.currentDistanceUnit.shortTitle)
                                .foregroundStyle(AppTheme.secondaryText)
                        }
                    }
                } header: {
                    Text("Service").foregroundStyle(AppTheme.secondaryText)
                }
                .listRowBackground(AppTheme.surface)

                Section {
                    HStack {
                        Text("Cost")
                            .foregroundStyle(AppTheme.primaryText)
                        Spacer()
                        HStack(spacing: 4) {
                            TextField("0", text: $price)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(minWidth: 60)
                            Picker("", selection: $currencyCode) {
                                ForEach(CurrencyPreset.allCases) { preset in
                                    Text(preset.rawValue).tag(preset.rawValue)
                                }
                            }
                            .pickerStyle(.menu)
                            .labelsHidden()
                            .tint(AppTheme.secondaryText)
                        }
                    }
                } header: {
                    Text("Cost").foregroundStyle(AppTheme.secondaryText)
                }
                .listRowBackground(AppTheme.surface)

                Section {
                    TextField("Workshop", text: $workshopName)

                    TextField("Notes (optional)", text: $notes, axis: .vertical)
                        .lineLimit(3...7)
                } header: {
                    Text("Details").foregroundStyle(AppTheme.secondaryText)
                }
                .listRowBackground(AppTheme.surface)

                Section {
                    Button {
                        showingCamera = true
                    } label: {
                        Label("Take photo", systemImage: "camera")
                    }

                    PhotosPicker(selection: $selectedPhotoItems, maxSelectionCount: 5, matching: .images) {
                        Label("Add photos", systemImage: "photo.on.rectangle.angled")
                    }

                    Button {
                        showingPDFImporter = true
                    } label: {
                        Label("Import PDF", systemImage: "doc.badge.plus")
                    }

                    if let entry {
                        ForEach(entry.attachments.filter { !removedAttachmentIDs.contains($0.id) }.sorted(by: { $0.createdAt > $1.createdAt })) { attachment in
                            HStack {
                                Label(attachment.filename, systemImage: attachment.type.icon)
                                    .foregroundStyle(AppTheme.primaryText)
                                Spacer()
                                Button(role: .destructive) {
                                    removedAttachmentIDs.insert(attachment.id)
                                } label: {
                                    Image(systemName: "trash")
                                }
                            }
                        }
                    }

                    ForEach(draftAttachments) { item in
                        Label(item.filename, systemImage: item.type.icon)
                            .foregroundStyle(AppTheme.secondaryText)
                    }
                } header: {
                    Text("Attachments (Optional)").foregroundStyle(AppTheme.secondaryText)
                }
                .listRowBackground(AppTheme.surface)
            }
            .scrollContentBackground(.hidden)
            .foregroundStyle(AppTheme.primaryText)
        }
        .navigationTitle(entry == nil ? "Add Service" : "Edit Service")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(isSaving ? "Saving..." : "Save") {
                    Task { await saveEntry() }
                }
                .disabled(isSaving || selectedVehicle == nil || UnitFormatter.parseDistance(mileage) == nil)
            }
        }
        .sheet(isPresented: $showingCamera) {
            CameraCaptureView { image in
                if let data = image.jpegData(compressionQuality: 0.8) {
                    draftAttachments.append(DraftAttachment(type: .image, filename: "Camera Photo \(draftAttachments.count + 1)", imageData: data, sourceURL: nil))
                }
            }
            .ignoresSafeArea()
        }
        .fileImporter(isPresented: $showingPDFImporter, allowedContentTypes: [.pdf], allowsMultipleSelection: true) { result in
            if case .success(let urls) = result {
                draftAttachments.append(contentsOf: urls.map { DraftAttachment(type: .pdf, filename: $0.lastPathComponent, imageData: nil, sourceURL: $0) })
            }
        }
        .onChange(of: selectedPhotoItems) {
            Task {
                for item in selectedPhotoItems {
                    if let data = try? await item.loadTransferable(type: Data.self) {
                        draftAttachments.append(DraftAttachment(type: .image, filename: "Photo \(draftAttachments.count + 1)", imageData: data, sourceURL: nil))
                    }
                }
                selectedPhotoItems = []
            }
        }
        .alert("Couldn’t save service entry", isPresented: $showingValidationAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(validationMessage ?? "Please review the entered values.")
        }
        .confirmationDialog("Create the next reminder?", isPresented: $showingReminderSuggestion, titleVisibility: .visible) {
            Button("12 months") {
                createSuggestedReminder(months: 12, kilometers: nil)
            }
            if entitlementStore.canUseMileageReminders() {
                Button(UnitFormatter.distance(10_000)) {
                    createSuggestedReminder(months: nil, kilometers: 10_000)
                }
            } else {
                Button("\(UnitFormatter.distance(10_000)) (Pro)") {
                    paywallCoordinator.present(.advancedReminders)
                }
            }
            Button("Custom") {
                showingCustomReminder = true
            }
            Button("Skip") {
                dismiss()
            }
        } message: {
            Text("Keep the next \(serviceType.title.lowercased()) visible before it slips.")
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
        .sheet(isPresented: $showingCustomReminder, onDismiss: {
            dismiss()
        }) {
            if let selectedVehicle, let savedEntryForReminder {
                NavigationStack {
                    ReminderFormView(vehicle: selectedVehicle, linkedService: savedEntryForReminder)
                }
            }
        }
    }

    private var selectedVehicle: Vehicle? {
        vehicles.first(where: { $0.id == selectedVehicleID }) ?? initialVehicle
    }

    private var savedDocumentCount: Int {
        attachments.count + documents.count
    }

    private func saveEntry() async {
        guard let vehicle = selectedVehicle, let mileageValue = UnitFormatter.parseDistance(mileage) else { return }
        let trimmedPrice = price.trimmingCharacters(in: .whitespacesAndNewlines)
        let parsedPrice = trimmedPrice.isEmpty ? 0 : (UnitFormatter.parseDecimal(trimmedPrice) ?? -1)
        if !trimmedPrice.isEmpty && parsedPrice < 0 {
            validationMessage = "Cost isn’t a valid number."
            showingValidationAlert = true
            return
        }
        let today = Calendar.current.startOfDay(for: .now)
        if Calendar.current.startOfDay(for: date) > today {
            validationMessage = "Service date cannot be in the future."
            showingValidationAlert = true
            return
        }

        let timelineErrors = VehicleOdometerTimelineValidator.validateServiceEntry(
            vehicle: vehicle,
            serviceID: entry?.id,
            date: date,
            mileage: mileageValue,
            createdAt: entry?.createdAt ?? .now
        )
        if let firstTimelineError = timelineErrors.first {
            validationMessage = firstTimelineError
            showingValidationAlert = true
            return
        }

        let originalEntryID = entry?.id
        let originalDate = entry?.date
        let originalMileage = entry?.mileage
        let originalReminderTitle = entry.map { "\($0.displayTitle) due" }

        let removedCount = removedAttachmentIDs.count
        let netExistingDocuments = max(0, savedDocumentCount - removedCount)
        guard entitlementStore.canAddSavedDocuments(existingCount: netExistingDocuments, addingCount: draftAttachments.count) else {
            paywallCoordinator.present(.documentVault)
            return
        }

        isSaving = true
        defer { isSaving = false }

        do {
            let targetEntry: ServiceEntry
            if let entry {
                entry.vehicle = vehicle
                entry.date = date
                entry.mileage = mileageValue
                entry.serviceType = serviceType
                entry.customServiceTypeName = customServiceTypeName.isEmpty ? nil : customServiceTypeName
                entry.category = category
                entry.price = parsedPrice
                entry.currencyCode = currencyCode.uppercased()
                entry.workshopName = workshopName.trimmingCharacters(in: .whitespacesAndNewlines)
                entry.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
                entry.isImportant = isImportant
                entry.updatedAt = .now
                targetEntry = entry
            } else {
                let newEntry = ServiceEntry(
                    vehicle: vehicle,
                    date: date,
                    mileage: mileageValue,
                    serviceType: serviceType,
                    customServiceTypeName: customServiceTypeName.isEmpty ? nil : customServiceTypeName,
                    category: category,
                    price: parsedPrice,
                    currencyCode: currencyCode.uppercased(),
                    workshopName: workshopName.trimmingCharacters(in: .whitespacesAndNewlines),
                    notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
                    isImportant: isImportant
                )
                modelContext.insert(newEntry)
                targetEntry = newEntry
            }

            VehicleMileageResolver.recalculateCurrentMileage(for: vehicle)

            try await persistDraftAttachments(for: targetEntry, vehicle: vehicle)
            purgeRemovedAttachments(from: targetEntry)
            if let originalEntryID, let originalDate, let originalMileage {
                await syncLinkedReminders(
                    for: originalEntryID,
                    updatedEntry: targetEntry,
                    originalDate: originalDate,
                    originalMileage: originalMileage,
                    originalReminderTitle: originalReminderTitle
                )
            }

            try modelContext.save()
            Haptics.success()

            if serviceType.supportsReminderSuggestion, existingSuggestedReminder(for: targetEntry) == nil {
                savedEntryForReminder = targetEntry
                showingReminderSuggestion = true
            } else {
                dismiss()
            }
        } catch {
            Haptics.error()
        }
    }

    private func syncLinkedReminders(
        for serviceEntryID: UUID,
        updatedEntry: ServiceEntry,
        originalDate: Date,
        originalMileage: Int,
        originalReminderTitle: String?
    ) async {
        let calendar = Calendar.current
        let originalServiceDate = calendar.startOfDay(for: originalDate)
        let updatedServiceDate = calendar.startOfDay(for: updatedEntry.date)
        let vehicleName = updatedEntry.vehicle?.title ?? "Vehicle"
        let generatedReminderTitle = "\(updatedEntry.displayTitle) due"
        let originalGeneratedTitle = originalReminderTitle ?? "\(updatedEntry.displayTitle) due"
        let linkedReminders = reminders.filter { reminder in
            let reminderTitle = reminder.title.trimmingCharacters(in: .whitespacesAndNewlines)
            let titleMatches = reminderTitle == generatedReminderTitle || reminderTitle == originalGeneratedTitle
            let serviceMatches = reminder.linkedServiceEntryID == serviceEntryID || reminder.serviceEntry?.id == serviceEntryID
            let vehicleMatches = reminder.vehicle?.id == updatedEntry.vehicle?.id || reminder.vehicle == nil
            let typeMatches = reminder.type == ReminderType(serviceType: updatedEntry.serviceType)
            return vehicleMatches && typeMatches && (serviceMatches || titleMatches)
        }

        guard !linkedReminders.isEmpty else { return }

        for reminder in linkedReminders {
            if reminder.linkedServiceEntryID == nil {
                reminder.linkedServiceEntryID = serviceEntryID
            }
            if reminder.linkedServiceDate == nil {
                reminder.linkedServiceDate = originalDate
            }
            if reminder.linkedServiceMileage == nil {
                reminder.linkedServiceMileage = originalMileage
            }

            var didChange = false

            if let currentDateDue = reminder.dateDue {
                let offset = calendar.dateComponents([.year, .month, .day], from: originalServiceDate, to: calendar.startOfDay(for: currentDateDue))
                if let updatedDateDue = calendar.date(byAdding: offset, to: updatedServiceDate),
                   updatedDateDue != currentDateDue {
                    reminder.dateDue = updatedDateDue
                    didChange = true
                }
            }

            if let currentMileageDue = reminder.mileageDue {
                let mileageOffset = currentMileageDue - originalMileage
                let updatedMileageDue = updatedEntry.mileage + mileageOffset
                if updatedMileageDue != currentMileageDue {
                    reminder.mileageDue = updatedMileageDue
                    didChange = true
                }
            }

            guard didChange else { continue }
            reminder.updatedAt = .now

            if reminder.isEnabled, reminder.dateDue != nil {
                NotificationService.shared.cancel(identifier: reminder.notificationIdentifier)
                reminder.notificationIdentifier = (await NotificationService.shared.schedule(for: reminder, vehicleName: vehicleName)).identifier
            } else {
                NotificationService.shared.cancel(identifier: reminder.notificationIdentifier)
                reminder.notificationIdentifier = nil
            }
        }
    }

    private func persistDraftAttachments(for entry: ServiceEntry, vehicle: Vehicle) async throws {
        guard !draftAttachments.isEmpty else { return }

        for item in draftAttachments {
            switch item.type {
            case .image:
                guard let data = item.imageData else { continue }
                let stored = try await AttachmentStorageService.shared.saveImageData(data, filename: item.filename)
                let attachment = AttachmentRecord(
                    vehicle: vehicle,
                    serviceEntry: entry,
                    type: .image,
                    filename: item.filename,
                    storageReference: stored.storageReference,
                    thumbnailReference: stored.thumbnailReference
                )
                modelContext.insert(attachment)
            case .pdf:
                guard let url = item.sourceURL else { continue }
                let reference = try await AttachmentStorageService.shared.importPDF(from: url)
                let attachment = AttachmentRecord(
                    vehicle: vehicle,
                    serviceEntry: entry,
                    type: .pdf,
                    filename: item.filename,
                    storageReference: reference
                )
                modelContext.insert(attachment)
            }
        }
        draftAttachments = []
    }

    private func purgeRemovedAttachments(from entry: ServiceEntry) {
        let attachments = entry.attachments.filter { removedAttachmentIDs.contains($0.id) }
        for attachment in attachments {
            Task {
                await AttachmentStorageService.shared.delete(reference: attachment.storageReference)
                await AttachmentStorageService.shared.delete(reference: attachment.thumbnailReference)
            }
            modelContext.delete(attachment)
        }
    }

    private func createSuggestedReminder(months: Int?, kilometers: Int?) {
        guard let vehicle = selectedVehicle, let serviceEntry = savedEntryForReminder else {
            dismiss()
            return
        }

        let dateDue = months.map { Calendar.current.date(byAdding: .month, value: $0, to: serviceEntry.date) ?? serviceEntry.date }
        let mileageDue = kilometers.map { serviceEntry.mileage + $0 }
        let matchingReminders = reminders.filter { reminder in
            reminder.vehicle?.id == vehicle.id &&
            reminder.type == ReminderType(serviceType: serviceType) &&
            (
                reminder.linkedServiceEntryID == serviceEntry.id ||
                reminder.serviceEntry?.id == serviceEntry.id ||
                reminder.title.trimmingCharacters(in: .whitespacesAndNewlines) == "\(serviceEntry.displayTitle) due"
            )
        }

        let reminder: ReminderItem
        if let existing = matchingReminders.first {
            reminder = existing
            for duplicate in matchingReminders.dropFirst() {
                modelContext.delete(duplicate)
            }
        } else {
            let newReminder = ReminderItem(
                vehicle: vehicle,
                serviceEntry: serviceEntry,
                linkedServiceEntryID: serviceEntry.id,
                linkedServiceDate: serviceEntry.date,
                linkedServiceMileage: serviceEntry.mileage,
                type: ReminderType(serviceType: serviceType),
                title: "\(serviceEntry.displayTitle) due",
                dateDue: dateDue,
                mileageDue: mileageDue,
                notificationTiming: .sevenDaysBefore,
                isEnabled: true
            )
            modelContext.insert(newReminder)
            reminder = newReminder
        }

        reminder.vehicle = vehicle
        reminder.serviceEntry = serviceEntry
        reminder.linkedServiceEntryID = serviceEntry.id
        reminder.linkedServiceDate = serviceEntry.date
        reminder.linkedServiceMileage = serviceEntry.mileage
        reminder.type = ReminderType(serviceType: serviceType)
        reminder.title = "\(serviceEntry.displayTitle) due"
        reminder.dateDue = dateDue
        reminder.mileageDue = mileageDue
        reminder.notificationTiming = .sevenDaysBefore
        reminder.isEnabled = true
        reminder.updatedAt = .now

        Task {
            NotificationService.shared.cancel(identifier: reminder.notificationIdentifier)
            let outcome = await NotificationService.shared.schedule(for: reminder, vehicleName: vehicle.title)
            reminder.notificationIdentifier = outcome.identifier
            try? modelContext.save()

            if let message = notificationMessage(for: outcome) {
                notificationInfoMessage = message
                return
            }

            dismiss()
        }
    }

    private func existingSuggestedReminder(for serviceEntry: ServiceEntry) -> ReminderItem? {
        reminders.first { reminder in
            reminder.vehicle?.id == serviceEntry.vehicle?.id &&
            reminder.type == ReminderType(serviceType: serviceEntry.serviceType) &&
            (
                reminder.linkedServiceEntryID == serviceEntry.id ||
                reminder.serviceEntry?.id == serviceEntry.id ||
                reminder.title.trimmingCharacters(in: .whitespacesAndNewlines) == "\(serviceEntry.displayTitle) due"
            )
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
