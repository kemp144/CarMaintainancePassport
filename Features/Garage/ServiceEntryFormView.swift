import PhotosUI
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct ServiceEntryFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var entitlementStore: EntitlementStore
    @EnvironmentObject private var paywallCoordinator: PaywallCoordinator
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
    @State private var showingOCRScanner = false
    @State private var showingOCRFailureDialog = false
    @State private var showingOCRCancelDialog = false
    @State private var ocrResult: OCRService.OCRResult?
    @State private var isProcessingOCR = false
    @State private var currentReceiptDraft: ScannedReceiptDraft?
    @State private var pendingReceiptImageData: Data?
    @State private var pendingReceiptFilename: String?

    let autoStartOCR: Bool
    private let initialOCRDraft: ScannedReceiptDraft?

    init(vehicle: Vehicle? = nil, entry: ServiceEntry? = nil, autoStartOCR: Bool = false, ocrDraft: ScannedReceiptDraft? = nil) {
        self.entry = entry
        self.autoStartOCR = autoStartOCR
        self.initialOCRDraft = ocrDraft
        self.initialVehicle = vehicle ?? entry?.vehicle
        _selectedVehicleID = State(initialValue: (vehicle ?? entry?.vehicle)?.id)
        _date = State(initialValue: ocrDraft?.result.date ?? entry?.date ?? .now)
        _mileage = State(initialValue: ocrDraft?.result.mileage.map { UnitFormatter.distanceValue(Double($0)) } ?? entry.map { UnitFormatter.distanceValue(Double($0.mileage)) } ?? vehicle.map { UnitFormatter.distanceValue(Double($0.currentMileage)) } ?? "")
        _serviceType = State(initialValue: ocrDraft?.suggestedServiceType ?? entry?.serviceType ?? .oilChange)
        _customServiceTypeName = State(initialValue: entry?.customServiceTypeName ?? "")
        _category = State(initialValue: ocrDraft?.suggestedCategory ?? entry?.category ?? (entry?.serviceType.defaultCategory ?? (ocrDraft?.suggestedServiceType?.defaultCategory ?? .maintenance)))
        _price = State(initialValue: ocrDraft?.result.price.map { String(format: "%.0f", $0) } ?? (entry?.price == 0 ? "" : String(format: "%.0f", entry?.price ?? 0)))
        _currencyCode = State(initialValue: entry?.currencyCode ?? vehicle?.currencyCode ?? CurrencyPreset.eur.rawValue)
        _workshopName = State(initialValue: ocrDraft?.result.workshopName ?? ocrDraft?.result.vendorName ?? entry?.workshopName ?? "")
        _notes = State(initialValue: entry?.notes ?? "")
        _isImportant = State(initialValue: entry?.isImportant ?? false)
        _currentReceiptDraft = State(initialValue: ocrDraft)
        _pendingReceiptImageData = State(initialValue: ocrDraft?.imageData)
        _pendingReceiptFilename = State(initialValue: ocrDraft?.filename)
        _draftAttachments = State(initialValue: ocrDraft.map { [DraftAttachment(type: .image, filename: $0.filename, imageData: $0.imageData, sourceURL: nil, isReceipt: true)] } ?? [])
    }

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            Form {
                if let currentReceiptDraft {
                    Section {
                        HStack(spacing: 12) {
                            Image(systemName: "doc.text.viewfinder")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(AppTheme.accent)
                                .frame(width: 28)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Receipt scanned")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(AppTheme.primaryText)

                                Text(currentReceiptDraft.hasUsefulData ? "Review the scanned details before saving." : "The receipt is attached. Complete the fields below manually if needed.")
                                    .font(.footnote)
                                    .foregroundStyle(AppTheme.secondaryText)
                            }

                            Spacer()
                        }
                    } header: {
                        Text("Draft Review").foregroundStyle(AppTheme.secondaryText)
                    }
                    .listRowBackground(AppTheme.surface)
                }

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
                    if isProcessingOCR {
                        HStack(spacing: 10) {
                            ProgressView()
                            Text("Scanning receipt…")
                                .foregroundStyle(AppTheme.secondaryText)
                        }
                    } else {
                        Button {
                            if entitlementStore.canUseOCR() {
                                showingOCRScanner = true
                            } else {
                                paywallCoordinator.present(.ocrScan)
                            }
                        } label: {
                            Label("Scan receipt", systemImage: "doc.viewfinder")
                                .foregroundStyle(AppTheme.accent)
                        }
                    }
                } header: {
                    Text("Smart Scan").foregroundStyle(AppTheme.secondaryText)
                } footer: {
                    Text("Scan a receipt to prefill the draft, then confirm the details before saving.")
                        .foregroundStyle(AppTheme.tertiaryText)
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

                    DatePicker("Date", selection: $date, displayedComponents: .date)
                    
                    TextField("Mileage (\(UnitSettings.currentDistanceUnit.shortTitle))", text: $mileage)
                        .keyboardType(.numberPad)

                } header: {
                    Text("Service Details").foregroundStyle(AppTheme.secondaryText)
                }
                .listRowBackground(AppTheme.surface)

                Section {
                    TextField("Cost ($)", text: $price)
                        .keyboardType(.decimalPad)
                    
                    Picker("Category", selection: $category) {
                        ForEach(EntryCategory.allCases) { category in
                            Text(category.title).tag(category)
                        }
                    }
                    
                    TextField("Currency", text: $currencyCode)
                        .textInputAutocapitalization(.characters)
                    
                    TextField("Workshop", text: $workshopName)
                    
                    TextField("Notes (Optional)", text: $notes, axis: .vertical)
                        .lineLimit(3...7)
                } header: {
                    Text("Additional Info").foregroundStyle(AppTheme.secondaryText)
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
        .task {
            if autoStartOCR && entry == nil {
                if entitlementStore.canUseOCR() {
                    showingOCRScanner = true
                } else {
                    paywallCoordinator.present(.ocrScan)
                }
            }
        }
        .navigationTitle(entry == nil ? "Add Service" : "Edit Service")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    if currentReceiptDraft != nil {
                        showingOCRCancelDialog = true
                    } else {
                        dismiss()
                    }
                }
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
        .sheet(isPresented: $showingOCRScanner) {
            OCRImagePickerSheet { image in
                guard let image else { return }
                let imageData = image.jpegData(compressionQuality: 0.86)
                pendingReceiptImageData = imageData
                pendingReceiptFilename = "Receipt \(AppFormatters.receiptFilename.string(from: .now))"
                isProcessingOCR = true
                Task {
                    defer { isProcessingOCR = false }
                    do {
                        let result = try await OCRService.shared.scan(image: image)
                        ocrResult = result
                        applyScannedReceipt(result: result)
                    } catch {
                        showingOCRFailureDialog = true
                    }
                }
            }
        }
        .confirmationDialog("Receipt scanned", isPresented: $showingOCRCancelDialog, titleVisibility: .visible) {
            Button("Save Receipt Only") {
                Task { await saveReceiptOnly() }
            }
            Button("Discard Draft", role: .destructive) {
                dismiss()
            }
            Button("Keep Editing", role: .cancel) {}
        } message: {
            Text("You can save the receipt to Documents, discard the draft, or keep editing the service entry.")
        }
        .alert("Could not read the receipt", isPresented: $showingOCRFailureDialog) {
            Button("Save as Document") {
                Task { await saveReceiptOnly() }
            }
            Button("Try Again") {
                showingOCRScanner = true
            }
            Button("Continue Manually", role: .cancel) {}
        } message: {
            Text("The receipt is still available. You can save it as a document or scan again.")
        }
        .confirmationDialog("Create the next reminder?", isPresented: $showingReminderSuggestion, titleVisibility: .visible) {
            Button("12 months") {
                createSuggestedReminder(months: 12, kilometers: nil)
            }
            Button(UnitFormatter.distance(10_000)) {
                createSuggestedReminder(months: nil, kilometers: 10_000)
            }
            Button("Custom") {
                showingCustomReminder = true
            }
            Button("Not now", role: .cancel) {
                dismiss()
            }
        } message: {
            Text("Keep the next \(serviceType.title.lowercased()) visible before it slips." )
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
    private func applyScannedReceipt(result: OCRService.OCRResult) {
        if let date = result.date {
            self.date = date
        }
        if let mileage = result.mileage {
            self.mileage = String(mileage)
        }
        if let price = result.price {
            self.price = String(format: "%.0f", price)
        }
        if let workshopName = result.workshopName ?? result.vendorName, !workshopName.isEmpty {
            self.workshopName = workshopName
        }
        if let serviceType = result.suggestedServiceType {
            self.serviceType = serviceType
            self.category = result.suggestedCategory ?? serviceType.defaultCategory
        }

        if let imageData = pendingReceiptImageData, let filename = pendingReceiptFilename {
            draftAttachments.removeAll { $0.isReceipt }
            draftAttachments.insert(
                DraftAttachment(type: .image, filename: filename, imageData: imageData, sourceURL: nil, isReceipt: true),
                at: 0
            )
            currentReceiptDraft = ScannedReceiptDraft(
                imageData: imageData,
                filename: filename,
                result: result
            )
        }
    }

    private func saveReceiptOnly() async {
        guard let vehicle = selectedVehicle, let imageData = pendingReceiptImageData ?? currentReceiptDraft?.imageData else { return }
        let filename = pendingReceiptFilename ?? currentReceiptDraft?.filename ?? "Receipt"

        do {
            try await ScannedReceiptStorageService.shared.saveReceipt(
                imageData: imageData,
                filename: filename,
                vehicle: vehicle,
                in: modelContext
            )
            Haptics.success()
            dismiss()
        } catch {
            Haptics.error()
        }
    }

    private func saveEntry() async {
        guard let vehicle = selectedVehicle, let mileageValue = UnitFormatter.parseDistance(mileage) else { return }

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
                entry.price = Double(price) ?? 0
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
                    price: Double(price) ?? 0,
                    currencyCode: currencyCode.uppercased(),
                    workshopName: workshopName.trimmingCharacters(in: .whitespacesAndNewlines),
                    notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
                    isImportant: isImportant
                )
                modelContext.insert(newEntry)
                targetEntry = newEntry
            }

            vehicle.currentMileage = max(vehicle.currentMileage, mileageValue)
            vehicle.updatedAt = .now

            try await persistDraftAttachments(for: targetEntry, vehicle: vehicle)
            purgeRemovedAttachments(from: targetEntry)

            try? modelContext.save()
            Haptics.success()

            if serviceType.supportsReminderSuggestion {
                savedEntryForReminder = targetEntry
                showingReminderSuggestion = true
            } else {
                dismiss()
            }
        } catch {
            Haptics.error()
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
        let reminder = ReminderItem(
            vehicle: vehicle,
            serviceEntry: serviceEntry,
            type: ReminderType(serviceType: serviceType),
            title: "\(serviceEntry.displayTitle) due",
            dateDue: dateDue,
            mileageDue: mileageDue,
            notificationTiming: .sevenDaysBefore,
            isEnabled: true
        )
        modelContext.insert(reminder)
        Task {
            reminder.notificationIdentifier = await NotificationService.shared.schedule(for: reminder, vehicleName: vehicle.title)
            try? modelContext.save()
        }
        dismiss()
    }
}
