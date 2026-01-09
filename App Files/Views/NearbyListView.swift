import SwiftUI
import CoreLocation
import Foundation
import RealmSwift
import Observation


struct MultipleBusList: View {
    @EnvironmentObject var api : GTFSAPI
    @EnvironmentObject var database: Database
    
    @Environment(\.colorScheme) var colorScheme
    @State var isLoaded = false
    
    var body: some View {
        
        
        if let events = api.sortedNearbyData, !events.isEmpty{
            ScrollView{
                LazyVStack(spacing: 0) {
                    ForEach(events, id: \.first?.first?.first?.first?.routeID) { event in
                        VStack(spacing: 0){
                            BigBusCard(events: event)
                            
                            Divider()
                        }
                        .background(colorScheme == .dark ? Color(.systemGray5) : .white)
                    }
                    //                    .scrollContentBackground(.hidden)
                }.cornerRadius(10)
            }
            .padding()
            .onAppear{
                ParameterManager.shared.isDetailView = false
            }
        }
//        else if let events = api.sortedNearbyData, events.isEmpty{
//            VStack{
//                Spacer()
//                Text("No upcoming departures nearby").foregroundColor(.secondary)
//                ProgressView().opacity(detent == .small ? 0 : 1)
//                
//                Spacer()
//            }
        
        else if let stops = database.closestStops, stops.isEmpty {
            ScrollView{
                VStack{
                    Spacer()
                    Text("No stops nearby").foregroundColor(.secondary)
                    Spacer()}
            }
        }
        else {
            
            Spacer()
            ScrollView{
                
                    //                    Spacer()
                    //                    ProgressView()
                    
                    VStack(spacing: 0) {
                        ForEach(1..<3) {i in
                            VStack(spacing: 0){
                                BigBusCard(events: [[[[ParameterManager.event]]]])
                                    .redacted(reason: .placeholder)
                                    .allowsHitTesting(/*@START_MENU_TOKEN@*/false/*@END_MENU_TOKEN@*/)
                                    
                                Divider()
                            }
                            .background(colorScheme == .dark ? Color(.systemGray5) : .white)
                        }
                        //                    .scrollContentBackground(.hidden)
                    }
                    
                    .cornerRadius(10)
                    .transaction { transaction in
                        transaction.disablesAnimations = true
                    }
                .padding()
                //                    Spacer()
            }
            
                
        }
    }
}



