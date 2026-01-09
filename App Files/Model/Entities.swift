import Foundation
import CoreLocation
import RealmSwift
import MapKit



struct Event: Identifiable, Hashable {
    
    let id = UUID()
    let tripID: String
    let routeID: String
    let busNumber: String
    let headsign: String
    var direction_id: String
    let arrivalTime: String
    let stopNumber: String
    let stopName: String?
    let arrivalDate: Date
    var distance: CLLocationDistance?
    var stringDistance: String?
    var shape_id: String?
    let stop_latitude: Double?
    let stop_longitude: Double?
    
    var stopCoordinates: CLLocationCoordinate2D? {
        if let latitude = stop_latitude, let longitude = stop_longitude {
            return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        } else {
            return nil
        }
    }
}

struct VehiculePostion {
    
    let id: String
    let trip: String
    let route: String
    let stop: String = ""
    var latitude: Float = 0
    var longitude: Float = 0
    var timestamp: UInt64 = 0
    let bearing: Float = 0
    let speed: Float = 0
    let occupancy_status: String = ""
    let license_plate: String = ""
    let congestion_level: String = ""

    var vehiclePosition: CLLocationCoordinate2D {
        return CLLocationCoordinate2D(latitude: Double(latitude), longitude: Double(longitude))
    }
    
}

struct Trip {
    let route_id: String
    let service_id: String
    let trip_id: String
    let shape_id: String
    let trip_headsign: String
    let direction_id: String
    let block_id: String
    let wheelchair_accessible: String
    let route_direction: String
    let trip_note: String
//    let bikes_allowed: String
}

class TripToSave: Object, ObjectKeyIdentifiable {
    @Persisted(primaryKey: true) var _id: String
    @Persisted var route_id: String
    @Persisted var service_id: String
    @Persisted var shape_id: String
    @Persisted var trip_headsign: String
    @Persisted var direction_id: String
    @Persisted var block_id: String
    @Persisted var wheelchair_accessible: String
    @Persisted var route_direction: String
    @Persisted var trip_note: String
//    @Persisted var bikes_allowed: String
}

struct ShapePoint {
    let shape_id: String
    let shape_pt_lat: Double
    let shape_pt_lon: Double
    let shape_pt_sequence: Int
    let shape_dist_traveled: Double
}

class ShapeToSave: Object, ObjectKeyIdentifiable {
    @Persisted(primaryKey: true) var _id: ObjectId
    @Persisted var shape_id: String
    @Persisted var shape_pt_lat: Double
    @Persisted var shape_pt_lon: Double
    @Persisted var shape_pt_sequence: Int
    @Persisted var shape_dist_traveled: Double
}


struct Stop: Hashable {
    let stop_id: String
//    let stop_code: String?
    let stop_name: String
    let stop_lat: Double
    let stop_lon: Double
    let location_type: String
    let parent_station: String
    let wheelchair_boarding: String
//    let level_id: String?
    let platform_code: String
    var coordinates: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: stop_lat, longitude: stop_lon)
    }
    var distance: CLLocationDistance?
    
}

class StopToSave: Object, ObjectKeyIdentifiable {
    @Persisted(primaryKey: true) var _id: String
    @Persisted var stop_name: String
    @Persisted var stop_lat: Double
    @Persisted var stop_lon: Double
    @Persisted var location_type: String
    @Persisted var parent_station: String
    @Persisted var wheelchair_boarding: String
    @Persisted var platform_code: String
//    @Persisted var level_id: String
//    @Persisted var stop_code: String
}

struct Route {
    let route_id: String
    let agency_id: String
    let route_short_name: String
    let route_long_name: String
    let route_desc: String
    let route_type: String
    let route_color: String
    let route_text_color: String
    let exact_times: String = ""

}

class RouteToSave: Object, ObjectKeyIdentifiable {
    @Persisted(primaryKey: true) var _id: String
    @Persisted var agency_id: String
    @Persisted var route_short_name: String
    @Persisted var route_long_name: String
    @Persisted var route_desc: String
    @Persisted var route_type: String
    @Persisted var route_color: String
    @Persisted var route_text_color: String
    @Persisted var exact_times: String
}

struct StopTime {
    let trip_id: String
    var arrival_time: String?
    var departure_time: String?
    let stop_id: String
    var stop_sequence: String
    var stop_headsign: String?
    var pickup_type: String?
    var drop_off_type: String?
    var shape_dist_traveled: String?
    var timepoint: String?
    var stop_note: String?
}

class StopTimeToSave: Object,ObjectKeyIdentifiable {
    @Persisted var trip_id: String
    @Persisted var arrival_time: String
    @Persisted var departure_time: String?
    @Persisted var stop_id: String
    @Persisted var stop_sequence: String
    @Persisted var stop_headsign: String?
    @Persisted var pickup_type: String?
    @Persisted var drop_off_type: String?
    @Persisted var shape_dist_traveled: String?
    @Persisted var timepoint: String?
    @Persisted var stop_note: String?
}

struct City: Equatable, Hashable {
    let id: String
    let name: String
    let country: String
    let coordinates: CLLocation
    let postal: String?
//    let region: MKCoordinateRegion?
    let realtime: Bool
    let urls: [String:String]
    let apiKey: String?

}

struct City2: Codable, Equatable, Hashable {
    let id: String
    let name: String
    let country: String
    let coordinates: Coordinates
    let realtime: Bool
    let urls: [String: String]
    let apiKey: String?
    var gtfsDownloadDate: String? 
    var gtfsFileName: String?

    struct Coordinates: Codable, Equatable, Hashable {
        let latitude: Double
        let longitude: Double
    }
}
