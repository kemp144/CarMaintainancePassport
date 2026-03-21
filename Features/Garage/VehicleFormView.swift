import PhotosUI
import SwiftData
import SwiftUI

struct VehicleFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var entitlementStore: EntitlementStore
    @EnvironmentObject private var paywallCoordinator: PaywallCoordinator
    @AppStorage("settings.defaultCurrency") private var defaultCurrency = CurrencyPreset.suggested().rawValue

    private let vehicle: Vehicle?

    @State private var make: String
    @State private var model: String
    @State private var year: Int
    @State private var licensePlate: String
    @State private var currentMileage: String
    @State private var purchaseDate: Date
    @State private var hasPurchaseDate: Bool
    @State private var purchasePrice: String
    @State private var currencyCode: String
    @State private var vin: String
    @State private var notes: String
    @State private var coverReference: String?
    @State private var coverPreview: UIImage?
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var isSaving = false
    @State private var isLookingUpVIN = false
    @State private var vinLookupError: String?
    @State private var showingVINError = false
    @State private var hasEditedMileage = false

    private let initialManualMileage: Int?

    init(vehicle: Vehicle? = nil) {
        self.vehicle = vehicle
        self.initialManualMileage = vehicle.flatMap { VehicleManualMileageStore.manualMileage(for: $0) }
        _make = State(initialValue: vehicle?.make ?? "")
        _model = State(initialValue: vehicle?.model ?? "")
        _year = State(initialValue: vehicle?.year ?? Calendar.current.component(.year, from: .now))
        _licensePlate = State(initialValue: vehicle?.licensePlate ?? "")
        _currentMileage = State(initialValue: vehicle.map { UnitFormatter.distanceValue(Double($0.currentMileage)) } ?? "")
        _purchaseDate = State(initialValue: vehicle?.purchaseDate ?? .now)
        _hasPurchaseDate = State(initialValue: vehicle?.purchaseDate != nil)
        _purchasePrice = State(initialValue: vehicle?.purchasePrice.map { String(Int($0)) } ?? "")
        _currencyCode = State(initialValue: vehicle?.currencyCode ?? CurrencyPreset.suggested().rawValue)
        _vin = State(initialValue: vehicle?.vin ?? "")
        _notes = State(initialValue: vehicle?.notes ?? "")
        _coverReference = State(initialValue: vehicle?.coverImageReference)
    }

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            Form {
                Section {
                    if hasCoverImage {
                        // FILLED STATE
                        HStack(alignment: .center, spacing: 16) {
                            ZStack(alignment: .topTrailing) {
                                if let coverPreview {
                                    Image(uiImage: coverPreview)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 110, height: 84)
                                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                }

                                Button {
                                    removeCover()
                                } label: {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(.white)
                                        .padding(6)
                                        .background(Circle().fill(Color.black.opacity(0.65)))
                                }
                                .offset(x: -6, y: 6)
                                .buttonStyle(.plain)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Vehicle cover")
                                    .font(.headline)
                                    .foregroundStyle(AppTheme.primaryText)
                                
                                Text("Used on the garage card and export cover.")
                                    .font(.subheadline)
                                    .foregroundStyle(AppTheme.secondaryText)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .padding(.bottom, 2)

                                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                                    Text("Change photo")
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(AppTheme.accent)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 8)
                    } else {
                        // EMPTY STATE
                        HStack(spacing: 16) {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(AppTheme.surfaceSecondary)
                                .frame(width: 84, height: 84)
                                .overlay {
                                    Image(systemName: "photo.fill")
                                        .font(.title2)
                                        .foregroundStyle(AppTheme.tertiaryText)
                                }

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Vehicle cover")
                                    .font(.headline)
                                    .foregroundStyle(AppTheme.primaryText)
                                
                                Text("Used on the garage card and export cover.")
                                    .font(.subheadline)
                                    .foregroundStyle(AppTheme.secondaryText)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .padding(.bottom, 2)

                                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                                    Text("Add photo")
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(AppTheme.accent)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
                .listRowBackground(AppTheme.surface)

                Section {
                    TextField("Make", text: $make)
                    TextField("Model", text: $model)
                    Picker("Year", selection: $year) {
                        ForEach((1950...(Calendar.current.component(.year, from: .now) + 1)).reversed(), id: \.self) {
                            Text(String($0)).tag($0)
                        }
                    }
                    TextField("License plate", text: $licensePlate)
                    HStack {
                        Text("Current mileage")
                            .foregroundStyle(AppTheme.primaryText)
                        Spacer()
                        HStack(spacing: 4) {
                            TextField("0", text: $currentMileage)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .frame(minWidth: 60)
                            Text(UnitSettings.currentDistanceUnit.shortTitle)
                                .foregroundStyle(AppTheme.secondaryText)
                        }
                    }
                    Picker("Currency", selection: $currencyCode) {
                        ForEach(CurrencyPreset.allCases) { preset in
                            Text(preset.rawValue).tag(preset.rawValue)
                        }
                    }
                } header: {
                    Text("Vehicle").foregroundStyle(AppTheme.secondaryText)
                }
                .listRowBackground(AppTheme.surface)

                Section {
                    Toggle("Add purchase date", isOn: $hasPurchaseDate)
                    if hasPurchaseDate {
                        DatePicker("Purchase date", selection: $purchaseDate, displayedComponents: .date)
                    }
                    TextField("Purchase price", text: $purchasePrice)
                        .keyboardType(.decimalPad)
                } header: {
                    Text("Purchase Info").foregroundStyle(AppTheme.secondaryText)
                }
                .listRowBackground(AppTheme.surface)

                Section {
                    HStack {
                        TextField("VIN (17 characters)", text: $vin)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()

                        if isLookingUpVIN {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else if vin.count == 17 {
                            Button("Autofill") {
                                if entitlementStore.canUseVINLookup() {
                                    Task { await lookupVIN() }
                                } else {
                                    paywallCoordinator.present(.vinLookup)
                                }
                            }
                            .font(.caption.weight(.bold))
                            .foregroundStyle(AppTheme.accent)
                        }
                    }
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(4...8)
                } header: {
                    Text("Additional").foregroundStyle(AppTheme.secondaryText)
                }
                .listRowBackground(AppTheme.surface)
            }
            .scrollContentBackground(.hidden)
            .foregroundStyle(AppTheme.primaryText)
        }
        .alert("VIN Lookup Failed", isPresented: $showingVINError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(vinLookupError ?? "Could not fetch vehicle data.")
        }
        .navigationTitle(vehicle == nil ? "Add Vehicle" : "Edit Vehicle")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button(isSaving ? "Saving..." : "Save") {
                    Task { await saveVehicle() }
                }
                .disabled(isSaving || make.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .task {
            if let coverReference {
                coverPreview = UIImage(contentsOfFile: AttachmentStorageService.fileURL(for: coverReference).path)
            }
            if vehicle == nil {
                currencyCode = defaultCurrency
            }
        }
        .onChange(of: selectedPhotoItem) {
            Task {
                if let data = try? await selectedPhotoItem?.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    coverPreview = image
                }
            }
        }
        .onChange(of: currentMileage) {
            hasEditedMileage = true
        }
    }

    private var hasCoverImage: Bool {
        coverPreview != nil
    }

    private func removeCover() {
        coverPreview = nil
        selectedPhotoItem = nil
        coverReference = nil
    }

    private func saveVehicle() async {
        isSaving = true
        defer { isSaving = false }

        do {
            let imageReference = try await persistCoverIfNeeded()
            let now = Date()
            let trimmedMileage = currentMileage.trimmingCharacters(in: .whitespacesAndNewlines)
            let parsedManualMileage = UnitFormatter.parseDistance(currentMileage)

            if let vehicle {
                vehicle.make = make.trimmingCharacters(in: .whitespacesAndNewlines)
                vehicle.model = model.trimmingCharacters(in: .whitespacesAndNewlines)
                vehicle.year = year
                vehicle.licensePlate = licensePlate.trimmingCharacters(in: .whitespacesAndNewlines)
                vehicle.purchaseDate = hasPurchaseDate ? purchaseDate : nil
                vehicle.purchasePrice = Double(purchasePrice)
                vehicle.currencyCode = currencyCode
                vehicle.vin = vin.trimmingCharacters(in: .whitespacesAndNewlines)
                vehicle.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
                if let imageReference {
                    vehicle.coverImageReference = imageReference
                } else if coverReference == nil {
                    vehicle.coverImageReference = nil
                }

                if hasEditedMileage {
                    VehicleManualMileageStore.setManualMileage(trimmedMileage.isEmpty ? nil : parsedManualMileage, for: vehicle, at: now)
                } else if initialManualMileage != nil {
                    VehicleManualMileageStore.seedLegacyManualMileageIfNeeded(for: vehicle)
                }

                VehicleMileageResolver.recalculateCurrentMileage(for: vehicle, updateTimestamp: now)
            } else {
                let newVehicle = Vehicle(
                    make: make.trimmingCharacters(in: .whitespacesAndNewlines),
                    model: model.trimmingCharacters(in: .whitespacesAndNewlines),
                    year: year,
                    licensePlate: licensePlate.trimmingCharacters(in: .whitespacesAndNewlines),
                    currentMileage: 0,
                    purchaseDate: hasPurchaseDate ? purchaseDate : nil,
                    purchasePrice: Double(purchasePrice),
                    currencyCode: currencyCode,
                    vin: vin.trimmingCharacters(in: .whitespacesAndNewlines),
                    notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
                    coverImageReference: imageReference
                )
                modelContext.insert(newVehicle)
                VehicleManualMileageStore.setManualMileage(trimmedMileage.isEmpty ? nil : parsedManualMileage, for: newVehicle, at: now)
                VehicleMileageResolver.recalculateCurrentMileage(for: newVehicle, updateTimestamp: now)
            }

            try? modelContext.save()
            Haptics.success()
            dismiss()
        } catch {
            Haptics.error()
        }
    }

    private func persistCoverIfNeeded() async throws -> String? {
        guard let selectedPhotoItem,
              let data = try await selectedPhotoItem.loadTransferable(type: Data.self) else {
            return nil
        }

        let result = try await AttachmentStorageService.shared.saveImageData(data, filename: "vehicle-cover")
        return result.storageReference
    }

    private func lookupVIN() async {
        isLookingUpVIN = true
        defer { isLookingUpVIN = false }

        do {
            let result = try await VINLookupService.shared.lookup(vin: vin)
            if !result.make.isEmpty { make = result.make.capitalized }
            if !result.model.isEmpty { model = result.model.capitalized }
            if let y = result.year { year = y }
            Haptics.success()
        } catch {
            vinLookupError = error.localizedDescription
            showingVINError = true
            Haptics.error()
        }
    }
}
