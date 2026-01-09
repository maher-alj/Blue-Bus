//
//  GTFSAPI.swift
//  BusStop
//
//  Created by Maher Al Fatuhi Al Jundi on 5/6/2023.
//
import Foundation
import SwiftUI
import RealmSwift
import CoreLocation
import Combine
import MapKit
import ActivityKit
import Observation




class GTFSAPI: ObservableObject {
    
    @Published var GTFSdata: TransitRealtime_FeedMessage?
    @Published var GTFSEntities: [TransitRealtime_FeedEntity]?
    @Published var GTFSPosition: TransitRealtime_FeedMessage?
    @Published var GTFSLightRailData: TransitRealtime_FeedMessage?
    @Published var sortedNearbyData : [[[[[Event]]]]]?
    @Published var sortedStopData : [Event]?
    @Published var activityEvents : [Event]?
    @Published var selectedTripEvents : [Event]?
    @Published var selectedTripCoordinates = [CLLocationCoordinate2D]()
    @Published var isFetching = false
    @Published var isFetching2 = false
    
    private let distanceRadius: CLLocationDistance = 200
    
    let locationManager = LocationManager.shared
    let firebase = FirebaseManager(cityManager: CityManager())
    private let database: Database
    //    let flexSyncConfig = realmApp.currentUser!.flexibleSyncConfiguration()
  

    init(database: Database) {
        self.database = database
    }
   
    
    private var timer: Timer?
    
    func startTimer(for city: City2) {
        
        // Create and schedule the timer to fetch data every 30 seconds
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) {_ in
            self.fetchTransitData(for: city) // Call the supporting function
        }
        
        // Fetch data immediately on starting the timer
        self.fetchTransitData(for: city)
    }
    
    func stopTimer() {
        // Stop and invalidate the timer
        timer?.invalidate()
        timer = nil
    }
    
    //For Sydney
    func fetchTransitData(for city: City2) {
        // Call the async function without awaiting
        Task {
            
            let busData = try await self.fetchTransitMessage(for: city, dataType: "bus")
            let busPosition = try await self.fetchTransitMessage(for: city, dataType: "bus_position")
            
            if let busEntity = busData?.entity{

                let entity = busEntity
                DispatchQueue.main.async{
                    self.GTFSEntities = entity
                    self.GTFSPosition = busPosition
                }
            }
        }
    }
    
    func fetchTransitMessage(for city: City2, dataType: String) async throws -> TransitRealtime_FeedMessage? {
        print("\(Date()) Fetching \(dataType) real-time data for \(city.name)...")
        
        // Safely retrieve the URL string for the given dataType
        guard let urlString = city.urls[dataType], let url = URL(string: urlString) else {
            print("Invalid URL for \(dataType) in \(city.name).")
            throw FetchError.invalidURL
        }
        
        // Ensure the API key is valid
        guard let apiKey = city.apiKey, !apiKey.isEmpty else {
            print("Missing or invalid API key for \(city.name).")
            throw FetchError.missingAPIKey
        }
        
        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "Authorization")
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            
            do {
                let message = try TransitRealtime_FeedMessage(serializedData: data)
                print("\(dataType) data fetched successfully for \(city.name).")
                return message
            } catch {
                print("Error parsing \(dataType) data for \(city.name): \(error.localizedDescription)")
                throw FetchError.parsingError(error)
            }
        } catch {
            print("Error fetching \(dataType) data for \(city.name): \(error.localizedDescription)")
            throw FetchError.networkError(error)
        }
    }
    
    enum FetchError: Error {
        case invalidURL
        case missingAPIKey
        case networkError(Error)
        case parsingError(Error)
    }
    
    func filterSortData(currentStop: Stop) async -> [Event]? {
        
        //        guard let gtfsData = GTFSdata, let lightRailData = GTFSLightRailData else {
        //            return [] // Return an empty array if GTFSdata or GTFSLightRailData is nil
        //        }
        guard let mergedEntities = GTFSEntities else {
            return nil // Return an empty array if GTFSdata or GTFSLightRailData is nil
        }
        var events: [Event] = [Event]()
        
        let stopID = currentStop.stop_id
        let calendar = Calendar.current
        let currentDate = Date()
    
        let filteredEntities = mergedEntities.filter { entity in
            entity.tripUpdate.stopTimeUpdate.contains { $0.stopID == stopID }
        }
        
        print("there are that many stop time updates: \(filteredEntities.count)")
        for entity in filteredEntities {
            
            let tripUpdate = entity.tripUpdate
            let tripID = tripUpdate.trip.tripID
            var stopTimeUpdates = tripUpdate.stopTimeUpdate
            let routeID = entity.tripUpdate.trip.routeID
            let busNumber = routeID.components(separatedBy: "_").last ?? ""
            // We only keep the stopTimeUpdates that are scheduled for the current stop
            stopTimeUpdates = stopTimeUpdates.filter { stopTimeUpdate in
                stopTimeUpdate.stopID == stopID && [0,1,5].contains(stopTimeUpdate.scheduleRelationship.rawValue)
            }
            // And for this stopTimeUpdate
            
            for stopTimeUpdate in stopTimeUpdates {
                // So in here, we have the stopTimeUpdate of a specific bus for a specific bus stop
                // Later on in the loop, another stopTimeUpdate for the same bus but another trip might come up
                var busDirection = ""
                var directionID = ""
                var shape_id = ""
               
                let trip = database.retrieveTrip(tripID: entity.tripUpdate.trip.tripID)
                busDirection = trip?.trip_headsign ?? "Unknown"
                directionID = trip?.direction_id ?? ""
                shape_id = trip?.shape_id ?? ""
              
                let arrivalDate = Date(timeIntervalSince1970: TimeInterval(stopTimeUpdate.departure.time))
                // Get the difference in minutes
                let diffString = calendar.dateComponents([.minute], from: currentDate, to: arrivalDate).minute
                if arrivalDate >= Date(timeIntervalSinceNow: 0) {
                    let event = Event(tripID: tripID, routeID: routeID, busNumber: busNumber, headsign: busDirection, direction_id: directionID, arrivalTime: "\(diffString!) min", stopNumber: stopTimeUpdate.stopID, stopName: currentStop.stop_name, arrivalDate: arrivalDate, shape_id: shape_id,stop_latitude: nil, stop_longitude: nil)
                    events.append(event)
                }
            }
        }
        let sortedEvents = events.sorted { entity1, entity2 in
            let arrivalTime1 = entity1.arrivalDate
            let arrivalTime2 = entity2.arrivalDate
            return arrivalTime1 < arrivalTime2
        }
        DispatchQueue.main.async{
            self.isFetching = false
        }
        
        return sortedEvents
    }
    
    func filterSortDatas2(closestStops: [Stop]) async -> [[[[[Event]]]]] {
        
        // Ensure `GTFSEntities` contains data; otherwise, return an empty array
        guard let GTFSEntities = GTFSEntities else {
            print("Returned empty sorted data because couldn't find GTFS Data")
            return []
        }
        
        let mergedEntities = GTFSEntities // Use available GTFS data
        var eventsByBusNumberAndStopID: [[[[[Event]]]]] = [] // Final structured output
        var eventsDict: [String: [String: [String: [String: [Event]]]]] = [:] // Temporary hierarchical data structure
        
        let calendar = Calendar.current // To calculate time differences
        let currentDate = Date() // Current time for comparisons
        
        // Iterate through each stop in the user's vicinity
        for currentStop in closestStops {
            let stopID = currentStop.stop_id
            var events: [Event] = [] // Events collected for this stop
            let stopLocation = CLLocation(latitude: currentStop.stop_lat, longitude: currentStop.stop_lon) // Stop's location
            var distance: CLLocationDistance?
            var stringDistance: String?
            
            // Calculate distance to user's location
            if let userLocation = locationManager.location {
                distance = CLLocation(latitude: userLocation.latitude, longitude: userLocation.longitude).distance(from: stopLocation)
                stringDistance = distanceString(distance: distance!) // Format distance as string
            } else {
                print("Couldn't determine distance to user")
            }
            
            // Process each GTFS entity (trip updates)
            for entity in mergedEntities {
                let tripUpdate = entity.tripUpdate
                let tripID = tripUpdate.trip.tripID
                let routeID = tripUpdate.trip.routeID
                let stopTimeUpdates = tripUpdate.stopTimeUpdate
                
                // Process stop time updates for the current trip
                for stopTimeUpdate in stopTimeUpdates {
                    // Only process updates for the current stop and valid schedule relationships
                    if stopID == stopTimeUpdate.stopID && [0, 1, 5].contains(stopTimeUpdate.scheduleRelationship.rawValue) {
                        
                        var busDirection = ""
                        var directionID = ""
                        var shape_id = ""
                        let busNumber = routeID.components(separatedBy: "_").last! // Extract bus number
                        
                        // Retrieve trip details from the database
                        let trip = database.retrieveTrip(tripID: entity.tripUpdate.trip.tripID)
                        busDirection = trip?.trip_headsign ?? "Unavailable" // Bus direction (headsign)
                        shape_id = trip?.shape_id ?? "Unavailable" // Shape ID
                        directionID = trip?.direction_id ?? "Unavailable" // Direction ID
                        
                        // Convert departure time to `Date`
                        let departureDate = Date(timeIntervalSince1970: TimeInterval(stopTimeUpdate.departure.time))
                        let diffString = calendar.dateComponents([.minute], from: currentDate, to: departureDate).minute
                        
                        // Only include future departures
                        if departureDate >= Date() {
                            let event = Event(
                                tripID: tripID,
                                routeID: routeID,
                                busNumber: busNumber,
                                headsign: busDirection,
                                direction_id: directionID,
                                arrivalTime: "\(diffString!) min", // Time until arrival
                                stopNumber: stopTimeUpdate.stopID,
                                stopName: currentStop.stop_name,
                                arrivalDate: departureDate,
                                distance: distance,
                                stringDistance: stringDistance,
                                shape_id: shape_id,
                                stop_latitude: nil,
                                stop_longitude: nil
                            )
                            events.append(event)
                        }
                    }
                }
            }
            
            // Sort events by arrival time
            let sortedEvents = events.sorted { $0.arrivalDate < $1.arrivalDate }
            
            // Insert events into the hierarchical dictionary
            for event in sortedEvents {
                guard let routeDict = eventsDict[event.routeID] else {
                    eventsDict[event.routeID] = [event.direction_id: [event.stopNumber: [event.headsign: [event]]]]
                    continue
                }
                
                guard let directionDict = routeDict[event.direction_id] else {
                    eventsDict[event.routeID]?[event.direction_id] = [event.stopNumber: [event.headsign: [event]]]
                    continue
                }
                
                guard let stopDict = directionDict[event.stopNumber] else {
                    eventsDict[event.routeID]?[event.direction_id]?[event.stopNumber] = [event.headsign: [event]]
                    continue
                }
                
                guard stopDict[event.headsign] != nil else {
                    eventsDict[event.routeID]?[event.direction_id]?[event.stopNumber]?[event.headsign] = [event]
                    continue
                }
                
                eventsDict[event.routeID]?[event.direction_id]?[event.stopNumber]?[event.headsign]?.append(event)
            }
        }
        
        // Convert dictionary to nested array
        for (_, busNumberDict) in eventsDict {
            var busNumberArray: [[[[Event]]]] = []
            
            for (_, directionDict) in busNumberDict {
                var directionArray: [[[Event]]] = []
                
                for (_, headsignDict) in directionDict {
                    var headsignArray: [[Event]] = []
                    
                    for (_, eventArray) in headsignDict {
                        headsignArray.append(eventArray)
                    }
                    directionArray.append(headsignArray)
                }
                busNumberArray.append(directionArray)
            }
            
            // Sort by proximity to user
            busNumberArray.sort { stopArray1, stopArray2 in
                if let firstEvent1 = stopArray1.first?.first?.first, let firstEvent2 = stopArray2.first?.first?.first {
                    return firstEvent1.distance ?? 0 < firstEvent2.distance ?? 0
                }
                return false
            }
            eventsByBusNumberAndStopID.append(busNumberArray)
        }
        
        // Sort by distance and arrival time
        eventsByBusNumberAndStopID.sort { busNumberArray1, busNumberArray2 in
            if let firstEvent1 = busNumberArray1.first?.first?.first?.first,
               let firstEvent2 = busNumberArray2.first?.first?.first?.first {
                if firstEvent1.distance ?? 0 == firstEvent2.distance ?? 0 {
                    return firstEvent1.arrivalDate < firstEvent2.arrivalDate
                } else {
                    return firstEvent1.distance ?? 0 < firstEvent2.distance ?? 0
                }
            } else {
                return false
            }
        }
        
        return eventsByBusNumberAndStopID
    }

    
    
    
    func distanceString(distance: CLLocationDistance) -> String {
        let distanceInMeters = Measurement(value: distance, unit: UnitLength.meters)
        let formatter = MeasurementFormatter()
        formatter.unitStyle = .medium
        formatter.unitOptions = .providedUnit
        formatter.numberFormatter.maximumFractionDigits = 0
        
        return formatter.string(from: distanceInMeters)
    }
    
    
    func getTripEvents(trip_id: String) async  -> [Event] {
        
        guard let mergedEntities = self.GTFSEntities else {
            print("Returned empty sorted data because could't find GTFS Data")
            return [] // Return an empty array if GTFSdata or GTFSLightRailData is nil
        }
        
        
        var events = [Event]()
        
        for entity in mergedEntities {
            
            if entity.tripUpdate.trip.tripID == trip_id {
                
                let tripUpdate = entity.tripUpdate
                let tripID = tripUpdate.trip.tripID
                let routeID = tripUpdate.trip.routeID
                let stopTimeUpdates = tripUpdate.stopTimeUpdate
                
                // And for this stopTimeUpdate
                for stopTimeUpdate in stopTimeUpdates {
                    // So in here, we have the stopTimeUpdate of a specific bus for a specific bus stop
                    // Later on in the loop, another stopTimeUpdate for the same bus but another trip might come up
                    // 0 = scheduled, 1 = added, 5 = replacement
                    if  [0,1,5].contains(stopTimeUpdate.scheduleRelationship.rawValue){
                        
                        let busNumber = ""
                        var busDirection = ""
                        var directionID = ""
                        var stopName = ""
                        var stop_lat = 0.0
                        var stop_long = 0.0
                        var shape_id = ""
                        
                      
                        if let stop =  database.retrieveStops(stopIDs: [stopTimeUpdate.stopID])?.first {
                            stopName = stop.stop_name
                            stop_lat = stop.stop_lat
                            stop_long = stop.stop_lon
                        }
                        
                        if let trip = database.retrieveTrip(tripID:entity.tripUpdate.trip.tripID){
                            busDirection = trip.trip_headsign
                            shape_id = trip.shape_id
                            directionID = trip.direction_id
                        }
                        
                        let currentDate = Date()
                        let calendar = Calendar.current
                        let departureDate = Date(timeIntervalSince1970: TimeInterval(stopTimeUpdate.departure.time))
                        // Get the difference in minutes
                        let diffString = calendar.dateComponents([.minute], from: currentDate, to: departureDate).minute
                        
                        if departureDate >= Date(timeIntervalSinceNow: 0) {
                            let event = Event(tripID: tripID, routeID: routeID, busNumber: busNumber, headsign: busDirection, direction_id: directionID, arrivalTime: "\(diffString!) min", stopNumber: stopTimeUpdate.stopID, stopName: stopName, arrivalDate: departureDate,shape_id: shape_id, stop_latitude: stop_lat, stop_longitude: stop_long)
                            // So events is an array of events from the same bus stop
                            events.append(event)
                        }
                        
                    }
                }
            }
            
        }
        // We sort the events with distance by both distance and arrival date
        let sortedEvents = events.sorted { event1, event2 in
            return event1.arrivalDate < event2.arrivalDate
        }
        return sortedEvents
    }
    func getTripCoordinates(events: [Event]) -> [CLLocationCoordinate2D] {
        
        var coordinates = [CLLocationCoordinate2D]()
        
        for event in events{
            if let latitude = event.stop_latitude, let longitude = event.stop_longitude {
                let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
                coordinates.append(coordinate)
            }
        }
        return coordinates
    }
    
    func getRouteRect(detent: PresentationDetent, events: [CLLocationCoordinate2D]) -> MKCoordinateRegion? {
        
        if let coord1 = events.first, let coord2 = events.last{
            let x1 = coord1.latitude
            let y1 = coord1.longitude
            let x2 = coord2.latitude
            let y2 = coord2.longitude
            
            let latitudeDelta = abs(x2-x1)*3.3
            let longitudeDelta = abs(y2-y1)*1.4
            let centerLatitude : CGFloat
            
            if detent == .small {
                centerLatitude = (x1+x2)/2
            } else {
                centerLatitude = (x1+x2)/2 - max(longitudeDelta*0.5,latitudeDelta*0.25)
            }
            
            let centerLongitude = (y1+y2)/2
            
            let center = CLLocationCoordinate2D(latitude: centerLatitude , longitude: centerLongitude )
            
            return MKCoordinateRegion(center: center, span: MKCoordinateSpan(latitudeDelta: latitudeDelta, longitudeDelta: longitudeDelta))
        } else {
            return nil
            
        }
    }
    
    func getVehiculePosition(events: [Event]) -> [VehiculePostion] {
        
        guard let gtfsPosition = self.GTFSPosition else {
            print("Returned empty sorted data because could't find GTFS Data")
            return [] // Return an empty array if GTFSdata or GTFSLightRailData is nil
        }
        
        var trips = [String]()
        for event in events {
            trips.append(event.tripID)
        }
        
        let mergedEntities = gtfsPosition.entity
        var positions = [VehiculePostion]()
        
        for entity in mergedEntities {
            
            let trip = entity.vehicle.trip
            let position = entity.vehicle.position
            
            if trips.contains(trip.tripID) && [0,1,5].contains(trip.scheduleRelationship.rawValue) {
                let id = entity.vehicle.vehicle.id
                let tripID = trip.tripID
                let routeID = trip.routeID
                let latitude = position.latitude
                let longitude = position.longitude
                let timestamp = entity.vehicle.timestamp
                positions.append(VehiculePostion(id: id, trip: tripID, route: routeID, latitude: latitude, longitude: longitude, timestamp: timestamp))
            }
        }
        return positions
    }

    func fetchEvents(for stop: Stop) async throws -> [Event] {
        // Construct the API URL
        print("Fetching a stop data in Toulouse")
        
        let apiKey = "ff6ba1b2-92a1-4782-a4ec-c537001d55a2"
        let baseURL = "https://api.tisseo.fr/v2/stops_schedules.json"
        guard let url = URL(string: "\(baseURL)?stopPointId=\(stop.stop_id)&key=\(apiKey)") else {
            throw URLError(.badURL)
        }
        
        // Perform the API request
        let (data, _) = try await URLSession.shared.data(from: url)
        
        // Parse the JSON response
        guard let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
              let departures = json["departures"] as? [String: Any],
              let departureArray = departures["departure"] as? [[String: Any]] else {
            throw NSError(domain: "Invalid JSON structure", code: 0, userInfo: nil)
        }
        
        print("Parsed JSON: \(json)") // Debugging
        
        var events: [Event] = []
        let calendar = Calendar.current
        let currentDate = Date()
        
        // Iterate through departures to extract event data
        for departure in departureArray {
            guard let line = departure["line"] as? [String: Any],
                  let destinationArray = departure["destination"] as? [[String: Any]],
                  let destination = destinationArray.first, // Ensure we only take the first destination
                  let dateTimeString = departure["dateTime"] as? String else { continue }
            
            let routeID = line["id"] as? String ?? ""
            let headsign = destination["name"] as? String ?? ""
            let busNumber = line["shortName"] as? String ?? ""
            
            // Convert dateTime string to Date using custom DateFormatter
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss" // Matches the expected date format
            guard let arrivalDate = dateFormatter.date(from: dateTimeString) else {
                print("Invalid date format for \(dateTimeString)")
                continue
            }

            // Calculate the time difference in minutes
            let diffInMinutes = calendar.dateComponents([.minute], from: currentDate, to: arrivalDate).minute ?? 0
            
            // Create an Event object
            let event = Event(
                tripID: "", // You can extract or modify this field if necessary from the data
                routeID: routeID,
                busNumber: busNumber,
                headsign: headsign,
                direction_id: "", // Add appropriate data for direction if needed
                arrivalTime: "\(diffInMinutes) min",  // Display the time remaining in minutes
                stopNumber: stop.stop_id,
                stopName: stop.stop_name,
                arrivalDate: arrivalDate,
                distance: nil,
                stringDistance: nil,
                shape_id: "", // Add shape_id or extract from data if needed
                stop_latitude: stop.stop_lat,
                stop_longitude: stop.stop_lon
            )
            
            events.append(event)
        }
        
        print("Events for this stop: \(events)")
        return events
    }
}


