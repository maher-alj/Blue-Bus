//
//  BusCard.swift
//  BusStop
//
//  Created by Maher Al Fatuhi Al Jundi on 28/5/2023.
//

import SwiftUI
import CoreLocation
import Foundation
import ActivityKit


#Preview{
    BusCard(event: PreviewEvent().event)
}

struct BusCard: View {
    
    let event: Event
    @State var activity : Activity<DeliveryAttributes>?

    @State private var isShowingWiFi = true
    @State private var isHourglassAnimating = true
    @State var isSelected = false
    @State var activityStatus = false
    @State var activityState : ActivityState?


    var body: some View {
        
        HStack(spacing: 0){
            HStack{
                Text(event.busNumber)
                    .font(.title2)
                    .fontWeight(.bold)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                if activityState == .active{
                    Image(systemName: "bolt.fill")
                        .symbolEffect(.pulse,isActive: isShowingWiFi)
                }
                Spacer()
            }.frame(width: 80)
            HStack{
                Text(event.headsign)
                    .minimumScaleFactor(0.5)
                    .multilineTextAlignment(.leading)
                Spacer()
            }
            Spacer()
            HStack(spacing: 0){
                Spacer()
                
                Text(event.arrivalTime)
                    .font(.title2)
                    .minimumScaleFactor(0.5).padding(.horizontal,0)
                
                Image(systemName: "wifi")
                    .symbolEffect(.variableColor.iterative, options: .speed(0.5),isActive: isShowingWiFi)
                    .font(.caption)
                    .rotationEffect(Angle(degrees: 45))
                    .foregroundColor(.blue)
                    .offset(y:-15)
            }
            .lineLimit(1).frame(width: 100)
        }
        .frame(height:50)
        //        .swipeActions(edge: .leading) {
        //            if activityState != .active {
        //                Button{
        //                    liveActivityManager.startActivity(event: event)
        //                    getActivity()
        //                } label: {
        //                    Text("Start Live Activity")
        //                        .multilineTextAlignment(.leading)
        //                }
        //                .tint(.green)
        //            } else {
        //                Button{
        //                    Task{
        //                        await liveActivityManager.endActivity(event: event)
        //                    }
        //                } label: {
        //                    Text("End Live Activity").multilineTextAlignment(.leading)
        //                }
        //                .tint(.red)
        //            }
        //        }
        
        .onChange(of: activity?.activityState){
            Task {
                if let activity = activity {
                    for await state in activity.activityStateUpdates {
                        activityState = state
                    }
                }
            }
        }
        .onAppear{
            getActivity()
        }
        
    }
    func timer() {
        
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            isHourglassAnimating.toggle()
        }
    }
    
    func getActivity() {
        activity = Activity<DeliveryAttributes>.activities.first(where: {$0.attributes.trip == event.tripID && $0.attributes.stopNumber == event.stopNumber})
    }
}



struct BigBusCard: View, Identifiable {
    @Environment(\.colorScheme) var colorScheme
    
    var id =  UUID()
    var events: [[[[Event]]]] // One Route, containing one or two directions, multiple stops, multiple headsigns each
    
    @State private var isShowingWiFi = true
    @State var selectedDirection = false
    
    var direction: Int {
      switch selectedDirection {
      case false : return 0
      case true: return 1
      }
    }
    
    
    var body: some View {
        
        VStack(spacing:14){
            
            let firstEvent = events[0][0][0][0]
            let event = events[direction][0][0][0]
            HStack{
                        Text(firstEvent.busNumber)
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(colorScheme == .dark ? .white : .black)
                        
                        if events.count > 1 {
                            Button {
                                withAnimation {
                                    selectedDirection.toggle()
                                }
                            } label: {
                                Image(systemName: "arrow.left.arrow.right")
                            }
                        }
                        Spacer()
            }
            
            DirectionView(events: events[direction])
            
            HStack {
                Image("BusIcon")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                
                HStack {
                    Text(event.stopName!)
                    Spacer()
                    Text(event.stringDistance ?? "")
                }
                
                Spacer()
            }
                .foregroundColor(.secondary)
                .frame(height: 20)
                .minimumScaleFactor(0.5)
            
            
        }.padding(14)
    }
}


struct DirectionView: View {
    
    let events: [[[Event]]]
    @State var activityState : ActivityState?
    
    var body: some View{
        
        VStack(spacing: 10) {
          // The first stop is the closest stop
            if let closestStopEvents = events.first{
                
                ForEach(closestStopEvents, id: \.first?.headsign){ headsign in
                    if let event = headsign.first {
                            NavigationLink{
                                EventDetailView(event: event)
                            } label: {
                                HeadsignRow(events: headsign)
                            }
                            
                    }
                }
            }
        }
    }
}

struct HeadsignRow : View{

    @State private var isShowingWiFi = true
    @Environment(\.colorScheme) var colorScheme
    let events: [Event]
    @State var activityState : ActivityState?

    
    var body: some View {
        
        let event1 = events[0]
    
        HStack(alignment: .center) {
                    HStack {
                        Image(systemName: "arrow.forward.circle")
                        
                        Text(event1.headsign).multilineTextAlignment(.leading)
                    }
                    Spacer()
                   
                    VStack {
                        HStack(spacing: 0) {
                            Spacer()
                            Text(event1.arrivalTime)
                            
                            Image(systemName: "wifi")
                                .symbolEffect(.variableColor.iterative, options: .speed(0.5),isActive: isShowingWiFi)
                                .font(.caption)
                                .rotationEffect(Angle(degrees: 45))
                                .foregroundColor(.blue)
                                .offset(y:-15)
                            
                        }
                        
                        HStack(spacing: 0) {
                            Spacer()
                            if events.count > 1 {
                                Text(events[1].arrivalTime)
                            }
                            if events.count > 2 {
                                Text(", \(events[2].arrivalTime)")
                            }
                        }
                        .font(.caption)
                        .fontWeight(.semibold)
                    }
                        .frame(width: 120)
            
                Image(systemName: "chevron.right").font(.footnote).fontWeight(.bold).foregroundColor(Color(.systemGray2))
                }
        .swipeActions(edge: .leading) {
            if activityState != .active {
                Button{
                   
                } label: {
                    Text("Start Live Activity")
                        .multilineTextAlignment(.leading)
                }
                .tint(.green)
            } else {
                Button{
                    
                } label: {
                    Text("End Live Activity").multilineTextAlignment(.leading)
                }
                .tint(.red)
            }
        }
                .foregroundColor(colorScheme == .dark ? .white : .black)

    }
}




//#Preview {
//    BusCard(event:  PreviewEvent().event, activityContent: <#Activity<DeliveryAttributes>#>)
//}

