//
//  CityManager.swift
//  BlueStop
//
//  Created by Maher Al Jundi on 24/12/24.
//

import Swift
import SwiftUI

class CityManager: ObservableObject {
    @Published var selectedCity: City2?
    @Published var cities: [City2] = []
    static let shared = CityManager()

    init() {
        loadCities()
        loadPersistedCity()
    }

    func loadCities() {
        if let loadedCities = loadCitiesFromFile() {
            DispatchQueue.main.async{
                self.cities = loadedCities
            }
        }
    }

    func loadPersistedCity() {
        if let data = UserDefaults.standard.data(forKey: "selectedCity"),
           let savedCity = try? JSONDecoder().decode(City2.self, from: data) {
            selectedCity = savedCity
        }
    }
    
    func loadCitiesFromFile() -> [City2]? {
        let fileManager = FileManager.default
        let documentURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("cities.json")
        let bundleURL = Bundle.main.url(forResource: "cities", withExtension: "json") // Path to the file in the app bundle

        // Check if the file exists in the document directory
        if !fileManager.fileExists(atPath: documentURL.path) {
            print("cities.json not found in document directory. Attempting to copy from bundle...")
            
            // Copy the file from the bundle to the document directory
            do {
                if let bundleURL = bundleURL {
                    try fileManager.copyItem(at: bundleURL, to: documentURL)
                    print("cities.json successfully copied to document directory.")
                } else {
                    print("cities.json not found in app bundle.")
                    return nil
                }
            } catch {
                print("Error copying cities.json to document directory: \(error)")
                return nil
            }
        } else {
            print("cities.json found in document directory.")
        }
        // Load the file from the document directory
        do {
            let data = try Data(contentsOf: documentURL)
            let decoder = JSONDecoder()
            let cities = try decoder.decode([City2].self, from: data)
            print("cities.json successfully loaded from document directory.")
            return cities
        } catch {
            print("Error loading cities.json from document directory: \(error)")
            return nil
        }
    }

    func saveCitiesToFile(cities: [City2]) {
        let fileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("cities.json")
        
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(cities)
            try data.write(to: fileURL)
            print("Cities saved successfully to file.")
        } catch {
            print("Error saving cities to file: \(error)")
        }
    }
    
    func saveCityToUserDefaults(city: City2, key: String) {
        let encoder = JSONEncoder()
        do {
            let data = try encoder.encode(city) // Encode the City into Data
            UserDefaults.standard.set(data, forKey: key) // Save the encoded Data to UserDefaults
            print("City saved to UserDefaults.")
        } catch {
            print("Failed to encode City: \(error)")
        }
    }
    
    func updateCityGTFSDate(cityId: String, newDate: String) {
        
        let documentURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("cities.json")

        // Load the cities.json file
        do {
            // Step 1: Read data from cities.json
            let data = try Data(contentsOf: documentURL)
            var cities = try JSONDecoder().decode([City2].self, from: data)

            // Step 2: Find the city by ID and update its GTFS date
            if let index = cities.firstIndex(where: { $0.id == cityId }) {
                cities[index].gtfsDownloadDate = newDate
                print("Updated city \(cities[index].name) GTFS date to \(newDate).")
            } else {
                print("City with ID \(cityId) not found.")
                return
            }

            // Step 3: Write the updated cities array back to cities.json
            let updatedData = try JSONEncoder().encode(cities)
            try updatedData.write(to: documentURL)
            print("cities.json updated successfully.")
        } catch {
            print("Error updating cities.json: \(error)")
        }
        self.loadCities()
    }
    
    func updateCityGTFSFileName(cityId: String, newFileName: String) {
        let documentURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("cities.json")

        // Load the cities.json file
        do {
            // Step 1: Read data from cities.json
            let data = try Data(contentsOf: documentURL)
            var cities = try JSONDecoder().decode([City2].self, from: data)

            // Step 2: Find the city by ID and update its GTFS file name (which is the Realm file name)
            if let index = cities.firstIndex(where: { $0.id == cityId }) {
                cities[index].gtfsFileName = newFileName
                print("Updated city \(cities[index].name) GTFS file name to \(newFileName).")
            } else {
                print("City with ID \(cityId) not found.")
                return
            }

            // Step 3: Write the updated cities array back to cities.json
            let updatedData = try JSONEncoder().encode(cities)
            try updatedData.write(to: documentURL)
            print("cities.json updated successfully.")
        } catch {
            print("Error updating cities.json: \(error)")
        }
        
        self.loadCities()
    }

    
    func isStaticDataDownloaded(for selectedCity: City2?) -> Bool {
        // Check if a city is selected
        guard let city = selectedCity else {
            print("No city selected.")
            return false
        }
        
        // Check if the download date is not nil (data is downloaded)
        if let downloadDate = city.gtfsDownloadDate {
            print("Static data for \(city.name) has been downloaded on \(downloadDate).")
            return true
        } else {
            print("Static data for \(city.name) has not been downloaded yet.")
            return false
        }
    }
    
    static func filterStops(_ stops: [Stop], for city: City2?) -> [Stop] {
            guard let city = city else { return stops }
            switch city.name.lowercased() {
            case "toulouse":
                return stops.filter { !$0.stop_name.starts(with: "SA_") }
            default:
                return stops
            }
        }
    
}
