import SwiftData
import SwiftUI

struct GarageView: View {
    enum SortOption: String, CaseIterable, Identifiable {
        case updated = "Recently Updated"
        case makeModel = "Make / Model"
        case year = "Year"
        case mileage = "Mileage"

        var id: String { rawValue }
    }

    @EnvironmentObject private var entitlementStore: EntitlementStore
    @EnvironmentObject private var paywallCoordinator: PaywallCoordinator
    @Query(sort: \Vehicle.updatedAt, order: .reverse) private var vehicles: [Vehicle]

    @State private var searchText = ""
    @State private var sortOption: SortOption = .updated
    @State private var showingVehicleForm = false

    private var filteredVehicles: [Vehicle] {
        let searched = vehicles.filter { vehicle in
            guard !searchText.isEmpty else { return true }
            let haystack = [vehicle.make, vehicle.model, vehicle.licensePlate].joined(separator: " ").lowercased()
            return haystack.contains(searchText.lowercased())
        }

        switch sortOption {
        case .updated:
            return searched.sorted { $0.updatedAt > $1.updatedAt }
        case .makeModel:
            return searched.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        case .year:
            return searched.sorted { $0.year > $1.year }
        case .mileage:
            return searched.sorted { $0.currentMileage > $1.currentMileage }
        }
    }

    var body: some View {
        ZStack {
            PremiumScreenBackground()

            if filteredVehicles.isEmpty {
                ScrollView(showsIndicators: false) {
                    ContentUnavailableView {
                        Label(vehicles.isEmpty ? "Start your garage" : "No vehicles found", systemImage: "car.fill")
                    } description: {
                        Text(vehicles.isEmpty ? "Add your first car and keep service history, receipts and reminders in one place." : "Try a different search or sorting option.")
                    } actions: {
                        Button(vehicles.isEmpty ? "Add Vehicle" : "Create Vehicle") {
                            addVehicleTapped()
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
                    ForEach(filteredVehicles) { vehicle in
                        NavigationLink {
                            VehicleDetailView(vehicle: vehicle)
                        } label: {
                            VehicleRowCard(vehicle: vehicle)
                        }
                        .listRowBackground(Color.clear)
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
        }
        .navigationTitle("Garage")
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $searchText, prompt: "Make, model or plate")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Menu {
                    Picker("Sort", selection: $sortOption) {
                        ForEach(SortOption.allCases) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                } label: {
                    Image(systemName: "arrow.up.arrow.down.circle")
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    addVehicleTapped()
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingVehicleForm) {
            NavigationStack {
                VehicleFormView()
            }
        }
    }

    private func addVehicleTapped() {
        if entitlementStore.canAddVehicle(existingCount: vehicles.count) {
            showingVehicleForm = true
        } else {
            paywallCoordinator.present(.secondVehicle)
        }
    }
}