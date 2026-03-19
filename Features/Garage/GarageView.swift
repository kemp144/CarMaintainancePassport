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
            let haystack = [
                vehicle.make,
                vehicle.model,
                vehicle.licensePlate,
                vehicle.vin,
                String(vehicle.year),
                String(vehicle.currentMileage),
                vehicle.notes,
                vehicle.sortedServices.map { $0.displayTitle }.joined(separator: " "),
                vehicle.sortedReminders.map { $0.title }.joined(separator: " ")
            ].joined(separator: " ").lowercased()
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
                        VStack(alignment: .leading, spacing: 6) {
                            Text("My Garage")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundStyle(AppTheme.primaryText)

                            Text(vehicles.isEmpty ? "Add your first vehicle to get started" : "\(vehicles.count) \(vehicles.count == 1 ? "vehicle" : "vehicles")")
                                .font(.subheadline)
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
                            .padding(.top, 14)
                    }
                }
                .padding(.horizontal, AppTheme.Spacing.pageEdge)
                .padding(.top, AppTheme.Spacing.headerTop)
                .padding(.bottom, AppTheme.Spacing.headerBottom)
                .background(AppTheme.heroGradient)

                // Content
                ScrollView(showsIndicators: false) {
                    if filteredVehicles.isEmpty {
                        if vehicles.isEmpty {
                            EmptyStateCard(
                                icon: "car.fill",
                                title: "Start your garage",
                                message: "Add your first car to track services, reminders, fuel, and documents in one calm place.",
                                actionTitle: "Add Vehicle"
                            ) {
                                addVehicleTapped()
                            }
                            .padding(AppTheme.Spacing.pageEdge)
                        } else {
                            ContentUnavailableView {
                                Label("No vehicles found", systemImage: "magnifyingglass")
                            } description: {
                                Text("Try a different search or sorting option.")
                            }
                            .padding(.top, 40)
                        }
                    } else {
                        LazyVStack(spacing: 14) {
                            ForEach(filteredVehicles) { vehicle in
                                NavigationLink {
                                    VehicleDetailView(vehicle: vehicle)
                                } label: {
                                    VehicleRowCard(vehicle: vehicle)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, AppTheme.Spacing.pageEdge)
                        .padding(.top, 6)
                        .padding(.bottom, 120) // Space for FAB and TabBar
                    }
                }
            }

            if !vehicles.isEmpty {
                FloatingAddButton {
                    addVehicleTapped()
                }
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
