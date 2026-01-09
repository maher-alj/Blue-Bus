import Foundation
import CoreLocation
import MapKit
import SwiftUI

class LocationManager: NSObject, ObservableObject {
    
    @Published var location: CLLocationCoordinate2D?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var closestCity: City?
    @Published var locationFound = false
    let locationManager = CLLocationManager()
    static let shared = LocationManager()
    
    weak var delegate: LocationManagerDelegate?

    override init() {
        super.init()
        print("Initiating Location Manager")
        locationManager.delegate = self
        locationManager.desiredAccuracy = 15
    
    }
    
    func requestAuthorization() {
        locationManager.requestWhenInUseAuthorization()
    }
    
    func startUpdatingLocation(){
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
    }

    let cities = [
        City(id: "2",
             name: "toulouse",
             country: "france",
             coordinates: CLLocation(latitude: 43.599998, longitude: 1.43333),
             postal: "31000",
             realtime: true,
             urls: ["bus":"https://api.tisseo.fr/v2/stops_schedules.json"],
             apiKey: "ff6ba1b2-92a1-4782-a4ec-c537001d55a2"),
        City(id: "1", name: "sydney",
             country: "australia",
             coordinates: CLLocation(latitude: -33.865143, longitude: 151.209900),
             postal: "2000",
             realtime: true,
             urls: [
                "bus": "https://api.transport.nsw.gov.au/v1/gtfs/realtime/buses",
                "lightrail_cbdandsoutheast":"https://api.transport.nsw.gov.au/v1/gtfs/realtime/lightrail/cbdandsoutheast",
                "lightrail_innerwest":"https://api.transport.nsw.gov.au/v1/gtfs/realtime/lightrail/innerwest",
                "bus_position":"https://api.transport.nsw.gov.au/v1/gtfs/vehiclepos/buses"
             ],
             apiKey: """
             apikey eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJqdGkiOiJoLVIwZFhZYmFxeS1JcUtUcHlWMFZNVDg5QWFEMEFkdXRQX05DNE5KNnhNIiwiaWF0IjoxNzE3MzQ1ODg4fQ.j8JcPtqCeGy6EV8qUDQUie9XR07jjkeAiSxJRBibx-U
             """)
    ]
    
}

extension LocationManager: CLLocationManagerDelegate {
    
    private func checkAuthorization() {
        switch locationManager.authorizationStatus {
        case .notDetermined:
            // Don't need to change authorizationStatus here
            break
        case .restricted, .denied:
            authorizationStatus = locationManager.authorizationStatus
        case .authorizedAlways, .authorizedWhenInUse:
            authorizationStatus = locationManager.authorizationStatus
        @unknown default:
            break
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        checkAuthorization()
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print(error.localizedDescription)
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        
        location = locations.first?.coordinate
        self.delegate?.didUpdateLocation()
    }
}

extension MKCoordinateRegion {
    static func defaultRegion() -> MKCoordinateRegion {
        .sydney
    }

    func getBinding() -> Binding<MKCoordinateRegion>? {
        return Binding<MKCoordinateRegion>(.constant(self))
    }
}

protocol LocationManagerDelegate: AnyObject {
    func didUpdateLocation()
}
