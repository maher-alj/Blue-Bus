//
//  BusListView.swift
//  BusStop
//
//  Created by Maher Al Fatuhi Al Jundi on 5/6/2023.
import SwiftUI
import CoreLocation
import Foundation
import RealmSwift
import ActivityKit

struct BusListView: View {
    @EnvironmentObject var api : GTFSAPI
    @EnvironmentObject var database: Database
  
    @Binding var isSheetPresented: Bool
    var stop: Stop?  //Changed it from @Binding to var
    @Binding var activityEvent : Event?
    
    @State var isDetailView = false
    @State var events = [Event]()
    @State var isLoading = true
    
    
    var parameter = ParameterManager.shared

    var body: some View {
        
        //        ScrollViewReader{ proxy in
        
        VStack{
            HStack{}
                .frame(height: 75)
            ZStack {
                List(events, id: \.id) { event in
                    // Display the arrival times for each stopTimeUpdate
                    NavigationLink{
                        EventDetailView(event: event)
                    } label: {
                        BusCard(event: event)
                    }
                    .id(event.tripID)
                    .onAppear{
                        isLoading = false
                    }
                }
            }
            .onAppear{
                parameter.isDetailView = false
            }
            if isLoading {
                VStack{
                    ProgressView()
                    Spacer()
                }
            }
        }
        .background(Color(.systemGroupedBackground))
        .onReceive(api.$sortedStopData){data in
            if let data{
                events = data
            }
        }
    }
}




