//
//  AboutView.swift
//  BusStop
//
//  Created by Maher Al Jundi on 30/6/2023.
//

import SwiftUI
import StoreKit
import CoreLocation

//#Preview{
//    SettingsView(isSettingsPresented: .constant(true))
//}

struct SettingsView: View {
    
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.openURL) private var openURL
    @EnvironmentObject var locationManager: LocationManager
    
    @Binding var isSettingsPresented: Bool
    @State var isActive = false
    @State var selectedCity : City2?
    @EnvironmentObject var cityManager: CityManager
    
    var body: some View {
        
        NavigationStack{
            VStack{
                
                List{
                    Section(header: Text("City")){
                        if cityManager.selectedCity != nil {
                            Picker("Change city", selection: $selectedCity) {
                                ForEach(cityManager.cities, id: \.id) { city in
                                    if city.realtime {
                                        Text("\(city.name.capitalized), \(city.country.capitalized)")
                                            .tag(city as City2?)  // Use the entire city object as the tag
                                    }
                                }
                            }
                        }
                    }
                    
                    .onChange(of: selectedCity) {
                        if let selectedCity = selectedCity {
                            cityManager.saveCityToUserDefaults(city: selectedCity, key: "selectedCity") // Update userCity when selection changes
                        }
                    }
                    
                    Section(header: Text("Feedback")) {
                        NavigationLink{
                            EmailView()
                        } label: {
                            Text("Email us")
                        }
                        Button {
                            if let url = URL(string: "https://apps.apple.com/us/app/blue-bus/id6503663861") {
                                            openURL(url)
                                        }
                        } label: {
                            Text("\(Image(systemName:"star")) Rate on the App Store")
                        }
                        
                    }
                    
                    Section(header: Text("Credits")) {
                        NavigationLink{
                            CreditsView()
                                .navigationTitle("Data sources")
                        } label: {
                            Text("Data sources")
                        }
                    }
                    
                    Section(header: Text("Legal notice")) {
                        NavigationLink{
                            PrivacyPolicyView()
                                .navigationTitle("Privacy policy")
                        } label: {
                            Text("Privacy policy")
                        }
                    }
                    
                }
                .navigationTitle("Settings")
                VStack{
                    Image(colorScheme == .dark ? "WhiteLogo" : "BlackLogo")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 200)
                    
                    Text("App Version: \(Bundle.main.appVersion)")
                    Text("Build Version: \(Bundle.main.buildVersion)")
                }
                .font(.caption2).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }
            .onAppear{
                if let city = cityManager.selectedCity {
                    selectedCity = city
                }
            }
            .background(Color(.systemGroupedBackground))
        }
    }
    
   
      
        
    
}



struct EmailView: View {
    
    var body: some View {
        
        VStack {
            List{
                Section(header: Text("Long press to copy")) {
                    HStack {
                        Text("Email")
                        Spacer()
                        Text("aljundi.maher.dev@gmail.com").textSelection(.enabled)
                    }
                }
            }
        }
    }
}

struct CreditsView: View {
    
    var body: some View {
        
        
        List{
            Section{
                Text("Sydney buses network, temporary buses, school buses")
                    .font(.title2)
                    .fontWeight(.bold)
                
                
                VStack(spacing:10){
                    Text("Realtime information is provided by Transport for NSW APIs:")
                    Text("\"Public Transport - Realtime Trip Updates\" \n\"Public Transport - Realtime Vehicle Positions\"\n\"Public Transport - Timetables - For Realtime \"")
                        .font(.caption)
                }
                    .foregroundColor(.secondary)
            }
        }
    }
    
}




struct RatingAlertCode: View {
    
    @Environment(\.requestReview) var requestReview
    
    var body: some View {
        
        Button("Leave a review") {
            
        }
        
    }
}

//struct AboutView_Previews: PreviewProvider {
//    static var previews: some View {
//        AboutView(isSheetPresented: .constant(true), selectedView: .constant("About"))
//    }
//}


//struct AboutView_Previews: PreviewProvider {
//    
//    static var previews: some View {
//        SettingsView(isSettingsPresented: .constant(true), selectedCity: .constant()
//    }
//    
//}

struct PrivacyPolicyView: View {
    
    var body: some View {

            VStack(alignment: .leading,spacing: 16) {
                    
                List{
                    Section{
                        Text("We do not collect any personal information using Blue Stop")
                            .font(.title2)
                            .fontWeight(.bold)
                        Text("We do not collect, use, save, or have access to any of your personal data used in Blue Stop. Individual settings relating to the Blue Stop app are not personal and are stored only on your device. You are asked to provide access to your location, but this is only to find stops near you. Location data is only used on your device. We do not have access to your location information or any other personal information.")
                            .foregroundStyle(.secondary)
                    }
                }
            }.multilineTextAlignment(.leading)
    }
}

struct PrivacyPolicyView_Previews: PreviewProvider {
    static var previews: some View {
        CreditsView()
    }
}


struct WelcomeView: View {
    
    @State var scale = 0.8
    
    var body: some View {
        
        VStack {
            Image(systemName: "bus")
                .font(.system(size: 100))
                .scaleEffect(scale)
                .foregroundColor(Color(.systemCyan))
                .onAppear {
                    let baseAnimation = Animation.easeInOut(duration: 2)
                    let repeated = baseAnimation.repeatForever(autoreverses: true)
                    
                    withAnimation(repeated) {
                        scale = 1
                    }
                }
            
            //                .rotationEffect(Angle(degrees: isLoading ? 360 : 0))
            
            
            
            
            Text("Loading")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            
        }
        
        
    }
    
}
