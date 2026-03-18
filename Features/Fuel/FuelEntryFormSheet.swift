import SwiftData
import SwiftUI

struct FuelEntryFormSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let vehicle: Vehicle
    private let entry: FuelEntry?

    @State private var date: Date
    @State private var mileage: String
    @State private var liters: String
    @State private var pricePerLiter: String
    @State private var totalCost: String
    @State private var station: String
    @State private var notes: String
    @State private var isFullTank: Bool
    @State private var isSaving = false

    init(vehicle: Vehicle, entry: FuelEntry? = nil) {
        self.vehicle = vehicle
        self.entry = entry
        _date = State(initialValue: entry?.date ?? .now)
        _mileage = State(initialValue: entry.map { String($0.mileage) } ?? String(vehicle.currentMileage))
        _liters = State(initialValue: entry.map { String(format: "%.2f", $0.liters) } ?? "")
        _pricePerLiter = State(initialValue: entry.map { String(format: "%.3f", $0.pricePerLiter) } ?? "")
        _totalCost = State(initialValue: entry.map { String(format: "%.2f", $0.totalCost) } ?? "")
        _station = State(initialValue: entry?.station ?? "")
        _notes = State(initialValue: entry?.notes ?? "")
        _isFullTank = State(initialValue: entry?.isFullTank ?? true)
    }

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            Form {
                Section {
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                    TextField("Mileage (km)", text: $mileage)
                        .keyboardType(.numberPad)
                } header: {
                    Text("Fill-up Info").foregroundStyle(AppTheme.secondaryText)
                }
                .listRowBackground(AppTheme.surface)

                Section {
                    HStack {
                        TextField("Liters", text: $liters)
                            .keyboardType(.decimalPad)
                            .onChange(of: liters) { _, newVal in
                                autoCalculateTotalCost(from: newVal, perLiter: pricePerLiter)
                            }
                        Text("L").foregroundStyle(AppTheme.secondaryText)
                    }
                    HStack {
                        TextField("Price per liter", text: $pricePerLiter)
                            .keyboardType(.decimalPad)
                            .onChange(of: pricePerLiter) { _, newVal in
                                autoCalculateTotalCost(from: liters, perLiter: newVal)
                            }
                        Text(vehicle.currencyCode + "/L").foregroundStyle(AppTheme.secondaryText)
                    }
                    HStack {
                        TextField("Total cost", text: $totalCost)
                            .keyboardType(.decimalPad)
                        Text(vehicle.currencyCode).foregroundStyle(AppTheme.secondaryText)
                    }
                    Toggle("Full tank", isOn: $isFullTank)
                } header: {
                    Text("Fuel").foregroundStyle(AppTheme.secondaryText)
                }
                .listRowBackground(AppTheme.surface)

                Section {
                    TextField("Station / Location", text: $station)
                    TextField("Notes (optional)", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                } header: {
                    Text("Additional").foregroundStyle(AppTheme.secondaryText)
                }
                .listRowBackground(AppTheme.surface)
            }
            .scrollContentBackground(.hidden)
            .foregroundStyle(AppTheme.primaryText)
        }
        .navigationTitle(entry == nil ? "Add Fuel" : "Edit Fuel")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(isSaving ? "Saving..." : "Save") {
                    save()
                }
                .disabled(isSaving || !isValid)
            }
        }
    }

    private var isValid: Bool {
        Int(mileage) != nil && Double(liters.replacingOccurrences(of: ",", with: ".")) != nil
    }

    private func autoCalculateTotalCost(from litersStr: String, perLiter: String) {
        let l = Double(litersStr.replacingOccurrences(of: ",", with: ".")) ?? 0
        let p = Double(perLiter.replacingOccurrences(of: ",", with: ".")) ?? 0
        if l > 0, p > 0 {
            totalCost = String(format: "%.2f", l * p)
        }
    }

    private func save() {
        guard let mileageValue = Int(mileage),
              let litersValue = Double(liters.replacingOccurrences(of: ",", with: ".")) else { return }

        let ppl = Double(pricePerLiter.replacingOccurrences(of: ",", with: ".")) ?? 0
        let cost = Double(totalCost.replacingOccurrences(of: ",", with: ".")) ?? (litersValue * ppl)

        isSaving = true
        if let entry {
            entry.date = date
            entry.mileage = mileageValue
            entry.liters = litersValue
            entry.pricePerLiter = ppl
            entry.totalCost = cost
            entry.station = station.trimmingCharacters(in: .whitespacesAndNewlines)
            entry.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
            entry.isFullTank = isFullTank
        } else {
            let newEntry = FuelEntry(
                vehicle: vehicle,
                date: date,
                mileage: mileageValue,
                liters: litersValue,
                pricePerLiter: ppl,
                totalCost: cost,
                currencyCode: vehicle.currencyCode,
                station: station.trimmingCharacters(in: .whitespacesAndNewlines),
                notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
                isFullTank: isFullTank
            )
            modelContext.insert(newEntry)
            vehicle.currentMileage = max(vehicle.currentMileage, mileageValue)
            vehicle.updatedAt = .now
        }
        try? modelContext.save()
        Haptics.success()
        dismiss()
    }
}
