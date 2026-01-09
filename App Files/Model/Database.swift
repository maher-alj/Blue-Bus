import Foundation
import RealmSwift
import MapKit
import FirebaseStorage
import Firebase
import SwiftUI

class Database: ObservableObject {
    
    @AppStorage("firstLaunch") var isFirstLaunch: Bool = true
    
    static let shared = Database()
    var currentRegion: MKCoordinateRegion?
    let locationManager = LocationManager.shared
    @Published var stopsInRegion = [Stop]()
    @Published var closestStops : [Stop]?
    @Published var isSavingData = false
    let cityManager = CityManager.shared
    
    private let distanceRadius: CLLocationDistance = 200

    
    static var config = Realm.Configuration.defaultConfiguration
    
    init() {
        
        print("Started init database class")
        var config = Realm.Configuration.defaultConfiguration
            config.fileURL!.deleteLastPathComponent()
        if let name = cityManager.selectedCity?.id {
            config.fileURL!.appendPathComponent("\(name).realm")
        }
        Database.config = config
        print("Realm config: \(config)")
        locationManager.delegate = self
        print("finished init database class")
    }
    
    static func setRealmConfig(to cityId: String){
        
        Database.config = Realm.Configuration.defaultConfiguration
        Database.config.fileURL!.deleteLastPathComponent()
        Database.config.fileURL!.appendPathComponent("\(cityId).realm")
        print("Set realm config to: \(Realm.Configuration.defaultConfiguration.fileURL!)")
        
    }
    
    

 
    func retrieveStops(stopIDs: [String]) -> [Stop]? {
        
        let realm = try! Realm(configuration: Database.config)
        let retrievedStops = realm.objects(StopToSave.self).filter("_id IN %@", stopIDs)
        // Create a dictionary to map stop IDs to their corresponding StopToSave objects
        let stopToSaveDict = Dictionary(uniqueKeysWithValues: retrievedStops.map { ($0._id, $0) })
        // Create an array of Stop objects with the same order as the input stopIDs
        return stopIDs.compactMap { stopID in
            if let stopToSave = stopToSaveDict[stopID] {
                return Stop(
                    stop_id: stopToSave._id,
                    stop_name: stopToSave.stop_name,
                    stop_lat: stopToSave.stop_lat,
                    stop_lon: stopToSave.stop_lon,
                    location_type: stopToSave.location_type,
                    parent_station: stopToSave.parent_station,
                    wheelchair_boarding: stopToSave.wheelchair_boarding,
                    platform_code: stopToSave.platform_code
                )
            } else {
                return nil
            }
        }
    }
    
    func retrieveTrip(tripID: String) -> Trip? {
        
        let trip_id = tripID.components(separatedBy: "_").first
        
        let realm = try! Realm(configuration: Database.config)
        let retrievedTrips = realm.objects(TripToSave.self).filter("_id BEGINSWITH %@", trip_id!)
        
        if let tripToSave = retrievedTrips.first {
            return Trip(
                route_id: tripToSave.route_id,
                service_id: tripToSave.service_id,
                trip_id: tripToSave._id,
                shape_id: tripToSave.shape_id,
                trip_headsign: tripToSave.trip_headsign,
                direction_id: tripToSave.direction_id,
                block_id: tripToSave.block_id,
                wheelchair_accessible: tripToSave.wheelchair_accessible,
                route_direction: tripToSave.route_direction,
                trip_note: tripToSave.trip_note
                //                bikes_allowed: tripToSave.bikes_allowed
            )
        } else {
            print("Trip ID not found:", tripID)
            return nil
        }
    }
    
    
    func retrieveTrips() -> [Trip]? {
        
        let realm = try! Realm(configuration: Database.config)
        let retrievedTrips = realm.objects(TripToSave.self)
        
        return Array(retrievedTrips).map { tripToSave in
            return Trip(
                route_id: tripToSave.route_id,
                service_id: tripToSave.service_id,
                trip_id: tripToSave._id,
                shape_id: tripToSave.shape_id,
                trip_headsign: tripToSave.trip_headsign,
                direction_id: tripToSave.direction_id,
                block_id: tripToSave.block_id,
                wheelchair_accessible: tripToSave.wheelchair_accessible,
                route_direction: tripToSave.route_direction,
                trip_note: tripToSave.trip_note
                //                bikes_allowed: tripToSave.bikes_allowed
            )
        }
    }
    
    func retrieveRoutes(routeID: String) -> Route? {
        
        let components = routeID.components(separatedBy: "_")
        let realm = try! Realm(configuration: Database.config)
        if let agency_id = components.first, let busNumber = components.last{
            let retrievedRoutes = realm.objects(RouteToSave.self).filter("agency_id == %@ AND route_short_name == %@", agency_id, busNumber)
            
            if let routeToSave = retrievedRoutes.first {
                return Route(route_id: routeToSave._id, agency_id: routeToSave.agency_id, route_short_name: routeToSave.route_short_name, route_long_name: routeToSave.route_long_name, route_desc: routeToSave.route_desc, route_type: routeToSave.route_type, route_color: routeToSave.route_color, route_text_color: routeToSave.route_text_color)
            }
            else {
                print("Route not found", routeID)
                return nil
            }
        } else {
            print("Route not found", routeID)
            return nil
        }
    }
    
    func retrieveRoutes() -> [Route]? {
        
        let realm = try! Realm(configuration: Database.config)
        let retrievedRoutes = realm.objects(RouteToSave.self)
        
        return Array(retrievedRoutes).map { routeToSave in
            return Route(route_id: routeToSave._id, agency_id: routeToSave.agency_id, route_short_name: routeToSave.route_short_name, route_long_name: routeToSave.route_long_name, route_desc: routeToSave.route_desc, route_type: routeToSave.route_type, route_color: routeToSave.route_color, route_text_color: routeToSave.route_text_color)
        }
    }
    
    func stopsExist() -> Bool {
        do {
            let realm = try Realm(configuration: Database.config)
            let stopCount = realm.objects(StopToSave.self).count
            return stopCount > 0
        } catch {
            print("Error initializing Realm: \(error.localizedDescription)")
            return false
        }
    }
    
    func routesExist() -> Bool {
        let realm = try! Realm(configuration: Database.config)
        let stopCount = realm.objects(RouteToSave.self).count
        return stopCount > 0
    }
    
    func tripsExist() -> Bool {
        do {
            let realm = try Realm(configuration: Database.config)
            let tripCount = realm.objects(TripToSave.self).count
            return tripCount > 0
        } catch {
            print("Error initializing Realm: \(error.localizedDescription)")
            return false
        }
    }
    
    func deleteData() {
        let realm = try! Realm(configuration: Database.config)
        try! realm.write {
            realm.deleteAll()
        }
    }
    
    @MainActor
    func getStopsInCurrentRegion() async -> [Stop] {
        var stops = [Stop]()
        
        do {
            let realm = try await Realm(configuration: Database.config)
            print("Getting stops in the current region")
            
            if let currentRegion = self.currentRegion {
                let minLat = currentRegion.center.latitude - currentRegion.span.latitudeDelta
                let maxLat = currentRegion.center.latitude + currentRegion.span.latitudeDelta
                let minLon = currentRegion.center.longitude - currentRegion.span.longitudeDelta
                let maxLon = currentRegion.center.longitude + currentRegion.span.longitudeDelta

                let stopToSaveResults = realm.objects(StopToSave.self).where {
                    $0.stop_lat >= minLat && $0.stop_lat <= maxLat &&
                    $0.stop_lon >= minLon && $0.stop_lon <= maxLon
                }
                
                stops = stopToSaveResults.map { stopToSave in
                    Stop(
                        stop_id: stopToSave._id,
                        stop_name: stopToSave.stop_name,
                        stop_lat: stopToSave.stop_lat,
                        stop_lon: stopToSave.stop_lon,
                        location_type: stopToSave.location_type,
                        parent_station: stopToSave.parent_station,
                        wheelchair_boarding: stopToSave.wheelchair_boarding,
                        platform_code: stopToSave.platform_code
                    )
                }
                
                // Apply city-specific filtering
                stops = CityManager.filterStops(stops, for: cityManager.selectedCity)
            }
        } catch {
            print(error.localizedDescription)
        }
        
        return stops
    }

    
    func findClosestStops() {
        
        print("Started looking for closest stops")
        
        DispatchQueue.global(qos: .background).async{
            guard let currentLocation = self.locationManager.location else {
                print("Current location not available.")
                return
            }
            
            do {
                let realm = try Realm(configuration: Database.config)
                let closestStops = realm.objects(StopToSave.self).filter { stop in
                    let stopLocation = CLLocation(latitude: stop.stop_lat, longitude: stop.stop_lon)
                    let distance = CLLocation(latitude: currentLocation.latitude, longitude: currentLocation.longitude).distance(from: stopLocation)
                    return distance <= self.distanceRadius
                }
                
                var stops: [Stop] = []
                for stopToSave in closestStops {
                    let stop = Stop(stop_id: stopToSave._id, stop_name: stopToSave.stop_name, stop_lat: stopToSave.stop_lat, stop_lon: stopToSave.stop_lon, location_type: stopToSave.location_type, parent_station: stopToSave.parent_station, wheelchair_boarding: stopToSave.wheelchair_boarding, platform_code: stopToSave.platform_code)
                    stops.append(stop)
                }
                
                let stopsArray = stops
                DispatchQueue.main.async {
                    print("Found closest stops")
                    self.closestStops = stopsArray
                }
            } catch {
                print("Error initializing Realm: \(error.localizedDescription)")
            }
        }
    }

    func readAndStoreTrips(fileName: String, city: City2) {
        // Get reference to Realm database
        
        Database.setRealmConfig(to: city.id)
        
        do {
            DispatchQueue.main.async{
                Database.shared.isSavingData = true
            }
            let type = fileName.components(separatedBy: "_")[1]
            guard type == "trips" else {
                return
            }
            
            let realm = try Realm(configuration: Database.config)
            
            // Get reference to the trips.json file in the document directory
            guard let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
                print("Document directory not found.")
                return
            }
            
            let jsonFilePath = documentDirectory.appendingPathComponent("\(fileName)")
            print("JSON file path: \(jsonFilePath.path)")
            
            // Check if the file exists in the document directory
            guard FileManager.default.fileExists(atPath: jsonFilePath.path) else {
                print("trips.json file not found in document directory.")
                return
            }
            // Read contents of the JSON file
            do {
                let jsonData = try Data(contentsOf: jsonFilePath)
                let tripsArray = try JSONSerialization.jsonObject(with: jsonData, options: []) as! [[String: String]]
                // Store trips data in Realm
                do {
                    try realm.write {
                        for tripDict in tripsArray {
                            let trip = TripToSave()
                            trip.route_id = tripDict["route_id"] ?? ""
                            trip.service_id = tripDict["service_id"] ?? ""
                            trip._id = tripDict["trip_id"] ?? ""
                            trip.shape_id = tripDict["shape_id"] ?? ""
                            trip.trip_headsign = tripDict["trip_headsign"] ?? ""
                            trip.direction_id = tripDict["direction_id"] ?? ""
                            trip.block_id = tripDict["block_id"] ?? ""
                            trip.wheelchair_accessible = tripDict["wheelchair_accessible"] ?? ""
                            trip.trip_note = tripDict["trip_note"] ?? ""
                            trip.route_direction = tripDict["route_direction"] ?? ""
                            realm.add(trip)
                        }
                    }
                    DispatchQueue.main.async{
                        Database.shared.isSavingData = false
                        self.isFirstLaunch = false 
                    }
                    print("Trips data stored in Realm.")
                } catch {
                    print("Error writing to Realm: \(error.localizedDescription)")
                }
            } catch {
                print("Error reading or parsing trips.json: \(error.localizedDescription)")
            }
        } catch {
            print("Error initializing Realm: \(error.localizedDescription)")
        }
    }
    
    func readAndStoreStops(fileName: String, city: City2) {
        
        Database.setRealmConfig(to: city.id)
        // Get reference to Realm database
        do {
            let type = fileName.components(separatedBy: "_")[1]
            guard type == "stops" else {
                return
            }
            
            let realm = try Realm(configuration: Database.config)
            
            guard let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
                print("Document directory not found.")
                return
            }
            
            let jsonFilePath = documentDirectory.appendingPathComponent("\(fileName)")
            print("JSON file path: \(jsonFilePath.path)")
            
            // Check if the file exists in the document directory
            guard FileManager.default.fileExists(atPath: jsonFilePath.path) else {
                print("stops.json file not found in document directory.")
                return
            }
            
            // Read contents of the JSON file
            do {
                let jsonData = try Data(contentsOf: jsonFilePath)
                let stopsArray = try JSONSerialization.jsonObject(with: jsonData, options: []) as! [[String: String]]
                
                // Store stops data in Realm
                do {
                    try realm.write {
                        for stopDict in stopsArray {
                            let stop = StopToSave()
                            stop._id = stopDict["stop_id"] ?? ""
                            stop.stop_name = stopDict["stop_name"] ?? ""
                            stop.stop_lat = Double(stopDict["stop_lat"] ?? "") ?? 0.0
                            stop.stop_lon = Double(stopDict["stop_lon"] ?? "") ?? 0.0
                            stop.parent_station = stopDict["parent_station"] ?? ""
                            stop.wheelchair_boarding = stopDict["wheelchair_boarding"] ?? ""
                            realm.add(stop)
                        }
                    }
                    print("Stops data stored in Realm.")
                } catch {
                    print("Error writing to Realm: \(error.localizedDescription)")
                }
            } catch {
                print("Error reading or parsing stops.json: \(error.localizedDescription)")
            }
        } catch {
            print("Error initializing Realm: \(error.localizedDescription)")
        }
    }
}

extension Database: LocationManagerDelegate {
    func didUpdateLocation() {
        print("Location did update in the delegate")
//        self.findClosestStops()
    }
}













