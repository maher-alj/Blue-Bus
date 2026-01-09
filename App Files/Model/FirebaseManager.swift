//
//  FirebaseManager.swift
//  Blue Stop
//
//  Created by Maher Al Jundi on 17/11/2023.
//

import Foundation
import FirebaseAuth
import FirebaseDatabase
import FirebaseCore
import Firebase
import RealmSwift
import CoreLocation
import FirebaseStorage
import SwiftUI


class FirebaseManager : ObservableObject {
    
    
    @Published var coordinates: [CLLocationCoordinate2D] = []
    @Published var isDownloading = false
    @AppStorage("firstLaunch") var isFirstLaunch: Bool = true
    private var cityManager : CityManager
    
    init(cityManager: CityManager) {
        self.cityManager = cityManager
    }
    
    let db = Firestore.firestore()
    var locationManager = LocationManager.shared
        //    let url = "https://bluestop-33500-default-rtdb.asia-southeast1.firebasedatabase.app/"
    var ref = Firebase.Database.database(url:"https://bluestop-33500-default-rtdb.asia-southeast1.firebasedatabase.app/").reference()
    let database = Database.shared
   
    func readCoordinates(shape_id: String) {
        
        let shape_id = shape_id.replacingOccurrences(of: ".", with: "_")
        var result = [[String: Any]]()
        guard let city = cityManager.selectedCity else { return }
        
        let ref = Firebase.Database.database(url: "https://bluestop-33500-default-rtdb.asia-southeast1.firebasedatabase.app/")
            .reference(withPath: "\(city.name)/shapes/\(shape_id)")
        
        ref.observeSingleEvent(of: .value) { snapshot in
            // Handle the data in the snapshot
            if snapshot.exists() {
                result = snapshot.value as? [[String: Any]] ?? []
                // Process the data as needed
                // print("Item data: \(result)")
                // Convert result to CLLocationCoordinate2D array
                var coordinates: [CLLocationCoordinate2D] = []
                for newValue in result {
                    let latitude = newValue["shape_pt_lat"] as! Double
                    let longitude = newValue["shape_pt_lon"] as! Double
                    let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
                    coordinates.append(coordinate)
                }
                // Update @Published property
                DispatchQueue.main.async{
                    self.coordinates = coordinates
                }
            } else {
                print("Item does not exist")
            }
        }
    }

    func checkJsonUpdate(for selectedCity: City2) async {
        print("Checking for JSON file updates...")
        
        let storage = Storage.storage()
        let ref = storage.reference(withPath: selectedCity.name.lowercased())
        let localURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd"

        // Parse the last update date from the selected city's GTFS info
        let localFileDate = selectedCity.gtfsDownloadDate.flatMap { dateFormatter.date(from: $0) }
        if localFileDate == nil {
            print("No local GTFS date available. Downloading all files.")
        }

        do {
            // List all files in Firebase for the city's folder
            let result = try await ref.listAll()
            for item in result.items {
                let fileName = item.name
                print("Found file on Firebase: \(fileName)")
                
                // Extract the date from the file name
                let components = fileName.components(separatedBy: "_")
                guard
                    let dateComponent = components.last?.replacingOccurrences(of: ".json", with: ""),
                    let fileDate = dateFormatter.date(from: dateComponent),
                    let fileType = components.dropLast().last, // e.g., "trips" or "stops"
                    fileName.starts(with: selectedCity.name.lowercased())
                else {
                    print("Invalid or unrelated file format: \(fileName)")
                    continue
                }

                // Skip downloading if the file is already up-to-date
                if let localFileDate = localFileDate, fileDate <= localFileDate {
                    print("File \(fileName) is up-to-date. Skipping.")
                    continue
                }
                
               
                print("localFileDate: \(String(describing: localFileDate))")
                // Download the file (with proper error handling and awaiting)
                print("Downloading new file: \(fileName)")
                let jsonURL = localURL.appendingPathComponent(fileName)
                
                do {
                    _ = try await item.writeAsync(toFile: jsonURL)
                    print("File \(fileName) downloaded successfully.")
                } catch {
                    print("Failed to download file \(fileName): \(error.localizedDescription)")
                    continue // Skip further processing for this file
                }

                // Process and store the JSON in Realm
                switch fileType.lowercased() {
                case "trips":
                    database.readAndStoreTrips(fileName: fileName, city: selectedCity)
                case "stops":
                    database.readAndStoreStops(fileName: fileName, city: selectedCity)
                default:
                    print("Unrecognized file type: \(fileType). Skipping processing.")
                }

                // Update the city GTFS metadata
                cityManager.updateCityGTFSDate(cityId: selectedCity.id, newDate: dateComponent)
                cityManager.updateCityGTFSFileName(cityId: selectedCity.id, newFileName: "\(selectedCity.name)_\(dateComponent).json")
            }

            DispatchQueue.main.async {
                self.isFirstLaunch = false
                self.isDownloading = false
                print("All relevant files for \(selectedCity.name) are up-to-date.")
            }
        } catch {
            print("Error checking or downloading files: \(error.localizedDescription)")
            DispatchQueue.main.async {
                self.isDownloading = false
            }
        }
    }

    func refreshRealmConfig(for city : City2) {
        // Access the selected city from CityManager
        guard let selectedCity = cityManager.selectedCity else {
            print("No city selected. Cannot refresh Realm configuration.")
            return
        }
        
        // Fetch the Realm file name from the selected city
        let realmFileName = selectedCity.gtfsFileName ?? "defaultRealm.realm" // Fallback if the filename is not available
        
        // Set the new Realm file path (using the filename saved in cities.json)
        let realmFileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent(realmFileName)
        
        // Create a new Realm configuration with the selected city's Realm file
        let config = Realm.Configuration(fileURL: realmFileURL, deleteRealmIfMigrationNeeded: true)
        
        // Set the default configuration to the new configuration
        Realm.Configuration.defaultConfiguration = config
        
        // Reload the Realm to use the new configuration
        do {
            _ = try Realm(configuration: config)  // Forces Realm to reload the configuration
            print("Realm configuration refreshed with file: \(realmFileName)")
        } catch {
            print("Failed to refresh Realm configuration: \(error.localizedDescription)")
        }
    }


}

