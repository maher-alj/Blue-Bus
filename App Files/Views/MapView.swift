//
//  MapView.swift
//  BusStop
//
//  Created by Maher Al Fatuhi Al Jundi on 11/6/2023.
//

import SwiftUI
import MapKit

struct MapView: View {
    @Environment(\.colorScheme) var colorScheme
    
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var database: Database
    @EnvironmentObject var api: GTFSAPI
    @EnvironmentObject var Firebase: FirebaseManager
    
    @Binding var selectedStop: Stop?
    @Binding var isSheetPresented2: Bool
    
    @State var detent : PresentationDetent = .small
    
    @State var visibleStops = [Stop]()
    @State var span = 0.01
    var locationSpan = 0.005
    @State var tripEvents = [Event]()
    @State private var currentLocation: CLLocationCoordinate2D?
    @State var region : MKCoordinateRegion?
    
    @State var detentSize: CGSize = CGSize(width: 100, height: 100)
    @State var routeRect : MKMapRect?
    @State var currentSpan = 0.006
    @State var route : MKRoute?
    
    @State private var cameraPosition: MapCameraPosition = .region(.sydney)
    @State private var cameraPosition2: MapCameraPosition = .automatic
    @State var currentMapRect : MKMapRect?
    @State var showMessage = false
    @Namespace var mapScope
    @State var pointsCoordinates = [CLLocationCoordinate2D]()
    
    @State var newRegion: MKCoordinateRegion?
    @State var isDetailView: Bool = false
    @State var selectedEvent: Event?
    @State var vehiclePositions = [VehiculePostion]()
    @State var isBouncing = false
    @State var fromHeight = CGFloat(0)
    let highPriorityQueue = DispatchQueue(label: "com.example.highPriority", qos: .userInteractive)
    
    var accentColor = Color(red: 0, green: 166/255, blue: 229/255)
    
    let stroke = StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round,dash: [10, 50])
    let stroke2 = StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .bevel)
    // A computed property that returns only the stops that are inside the map camera
    
    var body: some View {
        
        GeometryReader { geometry in
            
            Map(position: $cameraPosition ,interactionModes: [.pan,.zoom], scope: mapScope){
                
                if isDetailView{
                    MapPolyline(coordinates: pointsCoordinates)
                        .stroke(accentColor, style: stroke2)
                    ForEach(vehiclePositions, id: \.id){position in
                        
                        if let busNumber = selectedEvent?.busNumber{
                            //
                            Annotation(busNumber, coordinate: position.vehiclePosition){
                                
                                Image(systemName: "bus")
                                    .font(.system(size: 15)) // Adjust the size as needed
                                    .padding(6)
                                    .background(Circle().fill(.regularMaterial))
                                    .overlay(Circle().stroke(accentColor, lineWidth: 2))
                                    .symbolEffect(.bounce.down, value: isBouncing)
                                    .font(.largeTitle)
                                    .onAppear{
                                        timer()
                                    }
                            }
                        }
                    }
                    ForEach(tripEvents, id: \.id){event in
                        if let stopName = event.stopName, let stopCoord = event.stopCoordinates{
                            Annotation(currentSpan <= span ? stopName : "", coordinate: stopCoord){
                                if event.stopNumber == selectedEvent?.stopNumber || event.stopNumber == tripEvents.last?.stopNumber {
                                    ZStack{
                                        Circle()
                                            .fill(accentColor)
                                            .stroke(colorScheme == .dark ? .black : .white, lineWidth: 2)
                                            .frame(width: geometry.size.width * 0.03)
                                        VStack(spacing:0){
                                            Text(event.stopNumber == selectedEvent?.stopNumber ? "From here" : "Last stop")
                                                .padding(8)
                                                .font(.caption)
                                                .background(.regularMaterial)
                                                .cornerRadius(6)
                                            Image(systemName: "arrowtriangle.down.fill")
                                                .foregroundStyle(.regularMaterial)
                                        }
                                        
                                        .offset(y: -fromHeight)
                                        .background(
                                            GeometryReader { proxy in
                                                Color.clear // we just want the reader to get triggered, so let's use an empty color
                                                    .onChange(of: proxy.size.height){
                                                        fromHeight = proxy.size.height/2
                                                    }
                                                    .onAppear{
                                                        fromHeight = proxy.size.height/2
                                                    }
                                            })
                                    }
                                } else {
                                    Circle()
                                        .fill(accentColor)
                                        .stroke(colorScheme == .dark ? .black : .white, lineWidth: 2)
                                        .frame(width: geometry.size.width * 0.03)
                                }
                            }
                        }
                    }
                } else {
                    ForEach(visibleStops, id: \.stop_id){stop in
                        Annotation(currentSpan < 0.007 ? stop.stop_name : "", coordinate: stop.coordinates){
                            MarkerView(selectedStop: $selectedStop, isSheetPresented2: $isSheetPresented2, stop: stop)
                                .frame(width: geometry.size.width * 0.06)
                        }
                    }
                }
                UserAnnotation()
            }
            .onChange(of: selectedStop){
                print("Stop change in MapView")
            }
            .overlay(alignment: .topTrailing){
                VStack{
//                    MapUserLocationButton(scope: mapScope)
                    Button{
                        if let userLocation = currentLocation {
                            
                            let center = CLLocationCoordinate2D(latitude: userLocation.latitude, longitude: userLocation.longitude)
                            let span = MKCoordinateSpan(latitudeDelta: locationSpan, longitudeDelta: locationSpan)
                            let newRegion = MKCoordinateRegion(center: center, span: span)
                            withAnimation{
                                cameraPosition = .region(newRegion)
                            }
                            
//                            locationManager.startUpdatingLocation()
                            
                            DispatchQueue.global(qos: .background).async{
                               database.findClosestStops()
                            }
                        }
                    
                    } label:{
                        Image(systemName: "location")
                    }
                    .padding(15)
                    .background(.ultraThickMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 15))
                    .padding(15)
                    .shadow(color: .black.opacity(0.3), radius: 3)
                        
                }
            }
            
            .overlay(alignment: .top){
                VStack{
                    if showMessage {
                        Text("\( Image(systemName:"plus.magnifyingglass")) Zoom to select a stop")
                            .font(.caption)
                            .fontWeight(.medium)
                            .padding()
                            .background(.ultraThickMaterial)
                            .clipShape(Capsule())
                            .transition(.move(edge: .top))
                    }
                }
                .opacity(showMessage ? 1 : 0)
            }
            
            .mapControlVisibility(.hidden)
            .onAppear{
                detentSize = CGSize(width: geometry.size.width, height: geometry.size.width)
                
            }
            
            .onMapCameraChange(frequency: .onEnd) {mapCameraUpdateContext in
                
                let currentRegion = mapCameraUpdateContext.region
                region = currentRegion
                database.currentRegion = currentRegion
                currentSpan = currentRegion.span.longitudeDelta
                
                withAnimation(.bouncy){
                    if currentSpan > span && !isDetailView {
                        showMessage = true
                    } else {
                        showMessage = false
                    }
                }
                
                if currentSpan > span {
                    DispatchQueue.main.async{
                        visibleStops = []
                    }
                    //                    } else if region != nil {
                } else {
                    Task{
                        let stops = await database.getStopsInCurrentRegion()
                        DispatchQueue.main.async{
                            visibleStops = stops
                        }
                    }
                }
            }
            .mapScope(mapScope)
            .mapStyle(.standard(pointsOfInterest: .excludingAll))
            .onChange(of: currentLocation){
                print("location in mapkit has updated")
            }
            
            .onChange(of: visibleStops){
                print("Number of visible Stops: \(visibleStops.count)")
            }
            .onReceive(locationManager.$location) { location in
                // Update the currentLocation state property
                
                if self.currentLocation == nil {
                    if let userLocation = location {
                        
                        let center = CLLocationCoordinate2D(latitude: userLocation.latitude, longitude: userLocation.longitude)
                        let span = MKCoordinateSpan(latitudeDelta: locationSpan, longitudeDelta: locationSpan)
                        let newRegion = MKCoordinateRegion(center: center, span: span)
                        
                        withAnimation{
                            DispatchQueue.main.async{
                                currentLocation = userLocation
                                cameraPosition = .region(newRegion)
                            }
                        }
                    }
                }
                self.currentLocation = location
            }
            
            .onReceive(api.$GTFSPosition){ _ in
                let positions = api.getVehiculePosition(events: tripEvents)
                DispatchQueue.main.async{
                    withAnimation{
                        self.vehiclePositions = positions
                    }
                }
            }
            .onChange(of: tripEvents){
                let positions = api.getVehiculePosition(events: tripEvents)
                DispatchQueue.main.async{
                    self.vehiclePositions = positions
                }
            }
            .onReceive(ParameterManager.shared.$detentSize){size in
                detentSize = size
            }
            .onReceive(ParameterManager.shared.$detent){ detent in
                self.detent = detent
            }
            .onChange(of: detent){
                if isDetailView {
                    if let region = api.getRouteRect(detent: detent, events: pointsCoordinates){
                        DispatchQueue.main.async{
                            visibleStops = []
                            self.region = region
                            withAnimation(.easeOut){
                                cameraPosition = .region(region)}
                        }
                    }
                }
            }
            .onReceive(ParameterManager.shared.$isDetailView){ isDetailView in
                self.isDetailView = isDetailView
            }
            .onReceive(ParameterManager.shared.$selectedEvent){event in
                selectedEvent = event
            }
            .onReceive(Firebase.$coordinates){ coordinates in
                withAnimation{
                    pointsCoordinates = coordinates
                }
                if let region = api.getRouteRect(detent: detent, events: pointsCoordinates){
                    DispatchQueue.main.async{
                        visibleStops = []
                        self.region = region
                        withAnimation(.easeOut){
                            cameraPosition = .region(region)}
                    }
                }
            }
            
            .onChange(of:isDetailView){
                
                    if !isDetailView{
                        DispatchQueue.main.async{
                            pointsCoordinates = []
                            tripEvents = []
                            api.selectedTripEvents = []
                        }
                        if currentSpan <= span {
                            Task{
                                let stops = await database.getStopsInCurrentRegion()
                                DispatchQueue.main.async{
                                    visibleStops = stops
                                }
                            }
                        }
                    } else {
                        
                        if let selectedEvent = selectedEvent{
                            Task{
                                let events = await api.getTripEvents(trip_id: selectedEvent.tripID)
                                tripEvents = events
                                    Firebase.readCoordinates(shape_id: selectedEvent.shape_id ?? "")
                                    DispatchQueue.main.async{
                                        api.selectedTripEvents = events
                                    }
                            }
                        }
                    }
            }
        }.onAppear{
            print("MapView appeared")
        }
    }
        
    func timer() {
        
        Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { timer in
            withAnimation{
                isBouncing.toggle()
            }
            
            if !isDetailView {
                timer.invalidate()
            }
        }
    }
        
}

struct MarkerView: View {
    @Binding var selectedStop: Stop?
    @Binding var isSheetPresented2: Bool
    @State var parameter =  ParameterManager.shared
    
    var stop: Stop
    var body: some View {
        
        Image("BusIcon")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .onTapGesture {
                print("Tap gesture, stop selected: \(stop)")
                selectedStop = stop
            }
    }
}

class PreviewEvent {
    
    let event = Event(tripID: "", routeID: "", busNumber: "396", headsign: "City Circular Quayyyyyyyyyyyyyyyy", direction_id: "0", arrivalTime: "3 min", stopNumber: "12345", stopName: "Maroubra SLSC Maroubra fkiref frekiojjjjjjjjjjj frekio frekoi ", arrivalDate: Date(timeIntervalSinceNow: 1234), stop_latitude: 0, stop_longitude: 0)
    let event2 = Event(tripID: "", routeID: "", busNumber: "396", headsign: "City Circular Quayyyyyyyyyyy", direction_id: "0", arrivalTime: "3 min", stopNumber: "12345", stopName: "Maroubra ", arrivalDate: Date(timeIntervalSinceNow: 1234), stop_latitude: 0, stop_longitude: 0)
    
    
}

extension MKCoordinateRegion {
    // To know if region contains another region
    
    var maxLongitude: CLLocationDegrees {
        center.longitude + span.longitudeDelta / 2
    }

    var minLongitude: CLLocationDegrees {
        center.longitude - span.longitudeDelta / 2
    }

    var maxLatitude: CLLocationDegrees {
        center.latitude + span.latitudeDelta / 2
    }

    var minLatitude: CLLocationDegrees {
        center.latitude - span.latitudeDelta / 2
    }

    func contains(_ other: MKCoordinateRegion) -> Bool {
        maxLongitude >= other.maxLongitude && minLongitude <= other.minLongitude && maxLatitude >= other.maxLatitude && minLatitude <= other.minLatitude
    }
}


extension CLLocationCoordinate2D: @retroactive Equatable {}
extension CLLocationCoordinate2D: @retroactive Hashable {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        return lhs.latitude == rhs.latitude && lhs.longitude == rhs.longitude
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(latitude)
        hasher.combine(longitude)
    }
}


extension MKCoordinateRegion {
    
    static let sydney = MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: -33.881465, longitude: 151.209900), span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1))
    
    static let melbourne = MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: -37.813661, longitude: 144.963018), span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1))
    
    static let nancy = MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 48.683331, longitude: 6.2), span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1))
    
}
