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
        ZStack(alignment: .bottomTrailing) {
            AppTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Custom Header
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 8) { // mb-2 is spacing 8 between title and subtitle
                            Text("My Garage")
                                .font(.system(size: 30, weight: .bold)) // text-3xl is 30px
                                .foregroundStyle(AppTheme.primaryText)
                            
                            Text(vehicles.isEmpty ? "Add your first vehicle to get started" : "\(vehicles.count) \(vehicles.count == 1 ? "vehicle" : "vehicles")")
                                .font(.system(size: 16)) // base text
                                .foregroundStyle(AppTheme.secondaryText)
                        }
                        
                        Spacer()
                        
                        Menu {
                            Picker("Sort", selection: $sortOption) {
                                ForForEach(SortOption.allCases) { option in
                                    Text(option.rawValue).tag(option)
                                }
                            }
                        } label: {
                            Image(systemName: "arrow.up.arrow.down.circle.fill")
                                .font(.title2)
                                .foregroundStyle(AppTheme.tertiaryText)
                        }
                    }
                    
                    if !vehicles.isEmpty {
                        InlineSearchField(title: "Search vehicles...", text: $searchText)
                            .padding(.top, 16)
                    }
                }
                .padding(.horizontal, 24) // px-6
                .padding(.top, 48) // pt-12
                .padding(.bottom, 32) // pb-8
                .background(AppTheme.heroGradient)

                // Content
                ScrollView(showsIndicators: false) {
                    if filteredVehicles.isEmpty {
                        if vehicles.isEmpty {
                            EmptyStateCard(
                                icon: "car.fill",
                                title: "No Vehicles Yet",
                                message: "Start building your digital service logbook by adding your first vehicle.",
                                actionTitle: "Add Vehicle"
                            ) {
                                addVehicleTapped()
                            }
                            .padding(24)
                        } else {
                            ContentUnavailableView {
                                Label("No vehicles found", systemImage: "magnifyingglass")
                            } description: {
                                Text("Try a different search or sorting option.")
                            }
                            .padding(.top, 40)
                        }
                    } else {
                        LazyVStack(spacing: 16) {
                            ForEach(filteredVehicles) { vehicle in
                                NavigationLink {
                                    VehicleDetailView(vehicle: vehicle)
                                } label: {
                                    VehicleRowCard(vehicle: vehicle)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(24)
                        .padding(.bottom, 100) // Space for FAB and TabBar
                    }
                }
            }

            // FAB
            if !vehicles.isEmpty {
                Button {
                    addVehicleTapped()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 24, weight: .bold)) // w-6 h-6
                        .foregroundStyle(.white)
                        .frame(width: 56, height: 56) // w-14 h-14
                        .background(
                            Circle()
                                .fill(AppTheme.accent)
                                .shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: 4) // shadow-lg
                        )
                }
                .padding(.trailing, 24) // right-6
                .padding(.bottom, 96) // bottom-24 (roughly, considering tab bar)
            }
        }
        .navigationBarHidden(true)
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

// Helper ForEach wrapper for Picker
struct ForForEach<Data: RandomAccessCollection, ID: Hashable, Content: View>: View where Data.Element: Identifiable, Data.Element.ID == ID {
    let data: Data
    let content: (Data.Element) -> Content
    
    init(_ data: Data, @ViewBuilder content: @escaping (Data.Element) -> Content) {
        self.data = data
        self.content = content
    }
    
    var body: some View {
        ForEach(data, content: content)
    }
}