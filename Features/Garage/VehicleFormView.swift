import PhotosUI
import SwiftData
import SwiftUI

struct VehicleFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @AppStorage("settings.defaultCurrency") private var defaultCurrency = CurrencyPreset.eur.rawValue

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

    init(vehicle: Vehicle? = nil) {
        self.vehicle = vehicle
        _make = State(initialValue: vehicle?.make ?? "")
        _model = State(initialValue: vehicle?.model ?? "")
        _year = State(initialValue: vehicle?.year ?? Calendar.current.component(.year, from: .now))
        _licensePlate = State(initialValue: vehicle?.licensePlate ?? "")
        _currentMileage = State(initialValue: vehicle.map { String($0.currentMileage) } ?? "")
        _purchaseDate = State(initialValue: vehicle?.purchaseDate ?? .now)
        _hasPurchaseDate = State(initialValue: vehicle?.purchaseDate != nil)
        _purchasePrice = State(initialValue: vehicle?.purchasePrice.map { String(Int($0)) } ?? "")
        _currencyCode = State(initialValue: vehicle?.currencyCode ?? CurrencyPreset.eur.rawValue)
        _vin = State(initialValue: vehicle?.vin ?? "")
        _notes = State(initialValue: vehicle?.notes ?? "")
        _coverReference = State(initialValue: vehicle?.coverImageReference)
    }

    var body: some View {
        ZStack {
            PremiumScreenBackground()

            Form {
                Section {
                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        HStack(spacing: 16) {
                            coverView

                            VStack(alignment: .leading, spacing: 6) {
                                Text("Vehicle cover")
                                    .font(.headline)
                                Text("A clean hero image for the garage card and export cover.")
                                    .font(.subheadline)
                                    .foregroundStyle(AppTheme.secondaryText)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                }

                Section("Vehicle") {
                    TextField("Make", text: $make)
                    TextField("Model", text: $model)
                    Picker("Year", selection: $year) {
                        ForEach((1950...(Calendar.current.component(.year, from: .now) + 1)).reversed(), id: \.self) {
                            Text(String($0)).tag($0)
                        }
                    }
                    TextField("License plate", text: $licensePlate)
                    TextField("Current mileage", text: $currentMileage)
                        .keyboardType(.numberPad)
                    Picker("Currency", selection: $currencyCode) {
                        ForEach(CurrencyPreset.allCases) { preset in
                            Text(preset.rawValue).tag(preset.rawValue)
                        }
                    }
                }

                Section("Purchase") {
                    Toggle("Add purchase date", isOn: $hasPurchaseDate)
                    if hasPurchaseDate {
                        DatePicker("Purchase date", selection: $purchaseDate, displayedComponents: .date)
                    }
                    TextField("Purchase price", text: $purchasePrice)
                        .keyboardType(.decimalPad)
                }

                Section("Additional") {
                    TextField("VIN", text: $vin)
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(4...8)
                }
            }
            .scrollContentBackground(.hidden)
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
    }

    private var coverView: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(AppTheme.surfaceSecondary)
            .frame(width: 94, height: 94)
            .overlay {
                if let coverPreview {
                    Image(uiImage: coverPreview)
                        .resizable()
                        .scaledToFill()
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                } else {
                    Image(systemName: "photo.fill")
                        .font(.title2)
                        .foregroundStyle(AppTheme.accentSecondary)
                }
            }
    }

    private func saveVehicle() async {
        isSaving = true
        defer { isSaving = false }

        do {
            let imageReference = try await persistCoverIfNeeded()

            if let vehicle {
                vehicle.make = make.trimmingCharacters(in: .whitespacesAndNewlines)
                vehicle.model = model.trimmingCharacters(in: .whitespacesAndNewlines)
                vehicle.year = year
                vehicle.licensePlate = licensePlate.trimmingCharacters(in: .whitespacesAndNewlines)
                vehicle.currentMileage = Int(currentMileage) ?? 0
                vehicle.purchaseDate = hasPurchaseDate ? purchaseDate : nil
                vehicle.purchasePrice = Double(purchasePrice)
                vehicle.currencyCode = currencyCode
                vehicle.vin = vin.trimmingCharacters(in: .whitespacesAndNewlines)
                vehicle.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
                vehicle.coverImageReference = imageReference ?? vehicle.coverImageReference
                vehicle.updatedAt = .now
            } else {
                let newVehicle = Vehicle(
                    make: make.trimmingCharacters(in: .whitespacesAndNewlines),
                    model: model.trimmingCharacters(in: .whitespacesAndNewlines),
                    year: year,
                    licensePlate: licensePlate.trimmingCharacters(in: .whitespacesAndNewlines),
                    currentMileage: Int(currentMileage) ?? 0,
                    purchaseDate: hasPurchaseDate ? purchaseDate : nil,
                    purchasePrice: Double(purchasePrice),
                    currencyCode: currencyCode,
                    vin: vin.trimmingCharacters(in: .whitespacesAndNewlines),
                    notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
                    coverImageReference: imageReference
                )
                modelContext.insert(newVehicle)
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
}