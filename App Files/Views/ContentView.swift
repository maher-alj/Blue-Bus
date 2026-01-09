import SwiftUI
import RealmSwift
import CoreLocation
import Foundation
import ActivityKit
import BackgroundTasks
import MapKit

struct ContentView: View {
    @Environment(\.colorScheme) var colorScheme
    
    @StateObject var parameter = ParameterManager.shared
    
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var cityManager: CityManager
    @EnvironmentObject var firebaseManager: FirebaseManager
    @EnvironmentObject var database: Database
    @EnvironmentObject var api: GTFSAPI
    @Environment(\.requestReview) var requestReview
    
    @State var isSheetPresented = true
    @State var isSheetPresented2 = false
    @State var selectedStop: Stop?
    @State var selectedView: SelectedView = .Home
    @State var detent: PresentationDetent = .small
    @State var detent2: PresentationDetent = .small
    @State var isSettingsPresented = false
    @State var activityEvent: Event?
    @State var interactionDetent: PresentationDetent = .medium
    @State var detents: Set<PresentationDetent> = Set([.small, .medium, .large])
    @State var tripEvents: [Event]?
    @State var isDetailView = false
    @State var stopEvents = [Event]()  // FIXED: Added array brackets
    @State var closestStops: [Stop] = []
    @State var scale = 1.2
    @State var userLocation: CLLocationCoordinate2D?
    @State var isCheckingUpdate = false
    @State var isSavingData = false
    @State var isDownloading = false
    @State var selectedCity: City2?  // Will be set reactively
    
    @AppStorage("launchCount") var launchCount: Int = 0
    
    var body: some View {
        Group {
            MapView(selectedStop: $selectedStop, isSheetPresented2: $isSheetPresented2)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .sheet(isPresented: $isSheetPresented, onDismiss: {
                    isDetailView = false
                }) {
                    NearbyDeparturesView
                        .presentationDetents(detents, selection: $detent)
                        .presentationBackgroundInteraction(.enabled(upThrough: interactionDetent))
                        .sheet(isPresented: $isSheetPresented2, onDismiss: {
                            print("Sheet 2 dismissed")
                            isDetailView = false
                        }) {
                            SheetView
                                .presentationDetents([.small, .medium, .large], selection: $detent2)
                                .presentationBackgroundInteraction(.enabled(upThrough: interactionDetent))
                                .interactiveDismissDisabled()
                        }
                        .sheet(isPresented: $isSettingsPresented, onDismiss: {
                            isSettingsPresented = false
                        }) {
                            SettingsView(isSettingsPresented: $isSettingsPresented)
                                .presentationDragIndicator(.visible)
                        }
                        .interactiveDismissDisabled()
                        .presentationContentInteraction(.resizes)
                }
        }
        .task {
            locationManager.startUpdatingLocation()
        }
        .onAppear {
            launchCount += 1
            print("launchCount: \(launchCount)")
            
            // Background closest stops
            DispatchQueue.global(qos: .background).async {
                database.findClosestStops()
            }
            
            // Review prompt
            if [3, 10, 20].contains(launchCount) {
                presentReview()
            }
        }
        // 🔥 FIXED: Combined receiver - starts timer directly when city publishes
        .onReceive(cityManager.$selectedCity) { city in
            DispatchQueue.main.async {  // Use this instead of MainActor.run for sync
                selectedCity = city
                print("✅ Updated state selectedCity: \(city?.name ?? "nil")")
                
                guard let city = city, city.name.lowercased() == "sydney" else { return }
                
                print("🚀 Starting timer for Sydney!")
                api.startTimer(for: city)
                
                // Firebase update (Task keeps it async)
                Task {
                    if !isCheckingUpdate {
                        isCheckingUpdate = true
                        await firebaseManager.checkJsonUpdate(for: city)
                        isCheckingUpdate = false
                    }
                }
            }
        }

        .onReceive(locationManager.$location) { loc in
            print("ContentView has received a location update")
            DispatchQueue.main.async {
                userLocation = loc
            }
        }
        .onChange(of: selectedStop) { oldStop, newStop in
            detent = .small
            print("selectedStop changed from \(String(describing: oldStop)) to \(String(describing: newStop))")
            if let newStop = newStop {
                detent2 = .medium
                isSheetPresented2 = true
                
                if let city = selectedCity {
                    Task {
                        if city.name.lowercased() == "sydney" {
                            let data = await api.filterSortData(currentStop: newStop)
                            DispatchQueue.main.async {
                                api.sortedStopData = data
                            }
                        } else if city.name.lowercased() == "toulouse" {
                            let data = try await api.fetchEvents(for: newStop)
                            DispatchQueue.main.async {
                                api.sortedStopData = data
                            }
                        }
                    }
                }
            } else {
                print("selectedStop is nil, dismissing sheet")
                isSheetPresented2 = false
                DispatchQueue.main.async {
                    api.sortedStopData = nil
                }
            }
        }
        .onReceive(api.$GTFSEntities) { data in
            print("Received GTFSdata update")
            
            if let city = selectedCity, city.name.lowercased() == "sydney" {
                Task {
                    let sortedNearbyData = await api.filterSortDatas2(closestStops: self.closestStops)
                    api.sortedNearbyData = sortedNearbyData
                    
                    if let stop = selectedStop {
                        let newData = await api.filterSortData(currentStop: stop)
                        DispatchQueue.main.async {
                            api.sortedStopData = newData
                        }
                    }
                }
            }
        }
        .onReceive(parameter.$isDetailView) { bool in
            isDetailView = bool
            if isDetailView {
                detent2 = .medium
                detent = .medium
            }
        }
        .onReceive(firebaseManager.$isDownloading) { status in
            withAnimation {
                isDownloading = status
            }
        }
        .onReceive(Database.shared.$isSavingData) { status in
            isSavingData = status
            print("isSaving: \(status)")
        }
        .onChange(of: closestStops) {
            Task {
                let sortedNearbyData = await api.filterSortDatas2(closestStops: closestStops)
                if !sortedNearbyData.isEmpty {
                    DispatchQueue.main.async {
                        print("Updating closest stops")
                        api.sortedNearbyData = sortedNearbyData
                    }
                }
            }
        }
        .onReceive(locationManager.$location) { location in
            database.findClosestStops()
        }
        .onReceive(database.$closestStops) { stops in
            if let stops = stops {
                closestStops = stops
            }
        }
        .onReceive(firebaseManager.$isDownloading) { status in
            if status == false {
                database.findClosestStops()
            }
        }
        .onChange(of: detent) {
            ParameterManager.shared.detent = detent
        }
        .environmentObject(database)
        .environmentObject(api)
        .environmentObject(locationManager)
    }
    
    // Subviews unchanged
    var NearbyDeparturesView: some View {
        NavigationStack {
            VStack(spacing: 0) {
                MenuHeaderView
                    .onAppear {
                        ParameterManager.shared.isDetailView = false
                    }
                if !isDetailView {
                    MultipleBusList()
                }
                Spacer()
            }
            .ignoresSafeArea(edges: [.bottom, .top])
            .background(Color(.systemGroupedBackground))
        }
    }
    
    var SheetView: some View {
        NavigationStack {
            BusListView(isSheetPresented: $isSheetPresented, activityEvent: $activityEvent)
                .overlay(alignment: .top) {
                    HeaderView(Stop: $selectedStop)
                }
                .background(Color(.systemGroupedBackground))
        }
    }
    
    var MenuHeaderView: some View {
        Menu {
            Button {
                selectedView = .Home
                detent = .medium
            } label: {
                Text("Nearby departures")
                Image(systemName: "location")
            }.onAppear {
                selectedView = .Home
            }
            Button {
                isSettingsPresented = true
            } label: {
                Text("Settings")
                Image(systemName: "gear")
            }
        } label: {
            HStack(spacing: 0) {
                Text("Nearby departures")
                    .font(.title).fontWeight(.bold).padding()
                Image(systemName: "chevron.down").font(.caption).fontWeight(.bold)
                Spacer()
            }
            .foregroundColor(.accentColor)
        }
    }
    
    private func presentReview() {
        Task {
            try await Task.sleep(for: .seconds(10))
            requestReview()
        }
    }
}


enum SelectedView: String, CaseIterable, Identifiable {
    case Home, Settings
    var id: Self { self }
}



struct NoLocationView: View {
    var body: some View {
        VStack(spacing: 15) {
            Image(systemName: "location.slash.circle").font(.largeTitle)
            Text("Unable to access your location. Please enable location services in your device settings").foregroundColor(.secondary).multilineTextAlignment(.center)
        }.padding()
    }
}

extension PresentationDetent {
    static let small = Self.height(150)
}

extension Bundle {
    var appVersion: String {
        return self.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }

    var buildVersion: String {
        return self.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
    }
}

#Preview {
    if let city = LocationManager.shared.cities.first {
        ContentView()
            .environmentObject(CityManager())
            .environmentObject(Database())
            .environmentObject(GTFSAPI(database: Database()))
            .environmentObject(LocationManager())
    } else {
        Text("No cities available")
    }
}

struct MessageView : View {
    
    var message : String
    
    var body: some View {
        ProgressView(message)
            .font(.callout)
            .multilineTextAlignment(.center)
            .padding(.vertical, 20)
            .padding(.horizontal, 10)
            .background(.thickMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}
