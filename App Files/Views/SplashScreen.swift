//
//  SplashScreenView.swift
//  Blue Stop
//
//  Created by Maher Al Jundi on 04/05/2024.
//

import Foundation
import SwiftUI
import CoreLocation

#Preview {
    if let city = LocationManager.shared.cities.first(where: {$0.name == "sydney"}) {
        SplashScreenView()
            .environmentObject(LocationManager())
    }
}


struct SplashScreenView: View {
    @EnvironmentObject var locationManager: LocationManager
    @Environment(\.colorScheme) var colorScheme
    @AppStorage("firstLaunch") var isFirstLaunch: Bool = true
    @State private var navigateToSelectCityScreen: Bool = false

    var body: some View {
        NavigationStack {
            VStack {
                Image(colorScheme == .dark ? "WhiteLogo" : "BlackLogo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 100)
                    .foregroundColor(.black)
                
                HStack {
                    Text("Welcome to")
                    Text("Blue Bus")
                        .foregroundStyle(.accent)
                }
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .font(.largeTitle)
                .fontDesign(.rounded)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
                .padding(.bottom, 30)
                
                VStack(alignment: .leading, spacing: 30) {
                    HStack(spacing: 10) {
                        HStack(spacing: 0) {
                            Text("1 min")
                                .font(.title3)
                                .minimumScaleFactor(0.5)
                                .padding(.horizontal, 0)
                            
                            Image(systemName: "wifi")
                                .symbolEffect(.variableColor.iterative, options: .speed(1), isActive: true)
                                .font(.caption)
                                .rotationEffect(Angle(degrees: 45))
                                .foregroundColor(.blue)
                                .offset(y: -15)
                        }
                        .frame(width: 70)
                        .lineLimit(1)
                        
                        VStack(alignment: .leading) {
                            Text("Nearby departures")
                                .font(.callout)
                                .fontWeight(.semibold)
                            Text("Get real-time departures for nearby bus stops at a glance")
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    HStack(spacing: 10) {
                        ZStack(alignment: .leading) {
                            Circle()
                                .stroke(.black, lineWidth: 1)
                                .frame(height: 30)
                            Image("BusIcon")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(height: 30)
                        }
                        .frame(width: 70)
                        
                        VStack(alignment: .leading) {
                            Text("Stop departures")
                                .font(.callout)
                                .fontWeight(.semibold)
                            Text("Select a stop on the map to get real-time departures")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding()
                Spacer()
                
                Button {
                    if LocationManager.shared.authorizationStatus == .notDetermined {
                        print("Button Tapped: Requesting Authorization")
                        locationManager.requestAuthorization()
                    } else {
                        navigateToSelectCityScreen = true
                    }
                    
                } label: {
                    Text("Allow location services")
                        .padding(10)
                        .frame(minWidth: 0, maxWidth: .infinity, alignment: .center)
                        .font(.headline)
                        
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.roundedRectangle)
                .foregroundColor(.white)

            }
            
            .padding()
            .background(Color(.systemGroupedBackground))
            .onReceive(locationManager.$authorizationStatus) { newStatus in
                print("Authorization Status Changed: \(newStatus.rawValue)")
                if newStatus == .authorizedAlways || newStatus == .authorizedWhenInUse {
                    navigateToSelectCityScreen = true
                    locationManager.startUpdatingLocation()
                }
            }
            .navigationDestination(isPresented: $navigateToSelectCityScreen) {
                ChooseCityView()
                    .environmentObject(locationManager)
                    .environmentObject(CityManager())
                
            }
        }
       
    }
}

struct ChooseCityView: View {
    
    @Environment(\.colorScheme) var colorScheme
    @State private var navigateToDownloadScreen: Bool = false
    @State var selectedCity: City2? // Initialize as optional
    @EnvironmentObject var cityManager: CityManager
    
    var body: some View {
        NavigationStack {
            VStack {
                
                Image("BlackLogo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 100)
                    .foregroundColor(.black)
                    .opacity(0)
                
                HStack {
                    Text("What's your city?")
                }
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .font(.largeTitle)
                .fontDesign(.rounded)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
                .padding(.bottom, 30)
                
                if !cityManager.cities.isEmpty, selectedCity != nil {
                    Picker("Choose city", selection: $selectedCity) {
                        ForEach(cityManager.cities, id: \.id) { city in
                            if city.realtime {
                                Text("\(city.name.capitalized), \(city.country.capitalized)")
                                    .tag(city as City2?) // Use the entire city object as the tag. This Should match the type in the "selection: $SelectedCity"
                            }
                        }
                    }
                    .pickerStyle(.navigationLink)
                    .padding()
                    .background(colorScheme == .dark ? Color(.systemGray5) : .white)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                 
                } else {
                    Text("No cities available").padding()
                }
                
                Spacer()
                
                if let selectedCity = selectedCity {
                    NavigationLink(destination: DownloadScreenView(city: selectedCity)) {
                        Text("Continue")
                        
                            .font(.headline)
                            .padding(10)
                            .frame(minWidth: 0, maxWidth: .infinity, alignment: .center)
                    }
                  
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.roundedRectangle)
                } else {
                    Button("Continue") {} // Disabled when no city is selected
                        .font(.headline)
                        .padding(10)
                        .frame(minWidth: 0, maxWidth: .infinity, alignment: .center)
                        .buttonStyle(.borderedProminent)
                        .buttonBorderShape(.roundedRectangle)
                        .disabled(true)
                }
            }
            .padding()
            .onAppear{
                if selectedCity == nil {
                    selectedCity = cityManager.cities.first
                }
            }
            .navigationDestination(isPresented: $navigateToDownloadScreen) {
                if let selectedCity = selectedCity {
                    DownloadScreenView(city: selectedCity)
                }
            }
            
            .onChange(of: selectedCity) {
                if let selectedCity = selectedCity {
                    cityManager.saveCityToUserDefaults(city: selectedCity, key: "selectedCity")
                }
            }
        }
        .background(Color(.systemGroupedBackground))
    }
}



struct DownloadScreenView : View {
    
    @EnvironmentObject var firebaseManager : FirebaseManager
    @EnvironmentObject var cityManager : CityManager
    var city : City2
    @State var navigate = false
    
    var body: some View {
        
        NavigationStack{
            VStack{
                Image("BlackLogo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 100)
                    .foregroundColor(.black)
                    .opacity(0)
                    .padding(.top,40)
                
                HStack {
                    Text("Almost There!")
                }
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .font(.largeTitle)
                .fontDesign(.rounded)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
                .padding(.bottom, 30)
                
                Spacer()
                
                VStack(spacing:40){
                    Text("Downloading latest data for \(city.name.capitalized) \n This may take a minute")
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    ProgressView()
                }
                
                Spacer()
                
                .task{
                    await firebaseManager.checkJsonUpdate(for: city)  
                }
            }

            .frame(minWidth: 0, maxWidth: .infinity, alignment: .center)
            .navigationBarBackButtonHidden(true)
                .padding()
            .background(Color(.systemGroupedBackground))
            
        }
        
        
    }
}



