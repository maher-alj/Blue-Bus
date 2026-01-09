//
//  EventDetailView.swift
//  Next Bus
//
//  Created by Maher Al Jundi on 21/7/2023.
//

import SwiftUI
import Foundation
import RealmSwift
import ActivityKit
import Observation


//#Preview{
//    EventDetailView(event: PreviewEvent().event)
//}

struct EventDetailView: View {
    
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var api : GTFSAPI
    
    @State var event: Event
    @State var scale = 0.8
    @State var stops = [Stop]()
    @State var i : Int = 1
    @State var isShowingWifi = true
    @State var tripEvents = [Event]()
    let database = Database.shared
    
    @State var isOn = false
    @State var isActivity = false
    
    var body: some View {
        
        VStack(spacing: 0){
            HStack{
                Text(event.busNumber)
                        .font(.title2)
                        .fontWeight(.bold)
                Spacer()
                HStack {
                    Image(systemName: "arrow.right.circle")
                    Text(event.headsign).multilineTextAlignment(.leading)
                }
                Spacer()
                HStack{
                    Text(event.arrivalTime)
                        .font(.title2)
                      
                    Image(systemName: "wifi")
                        .symbolEffect(.variableColor.iterative, options: .speed(0.5),isActive: isShowingWifi)
                        .font(.caption)
                        .rotationEffect(Angle(degrees: 45))
                        .foregroundColor(.blue)
                        .offset(y:-15)
                }
                
            }.padding(.vertical,10)
        
//            HStack{
//                Button{
//                    if !isActivity {
//                        LiveActivityManager().startActivity(event: event)
//                    } else {
//                        Task{
//                            await LiveActivityManager().endActivity(event: event)
//                        }
//                    }
//                    isActivity.toggle()
//                    toggleActivity()
//                    
//                } label: {
//                    HStack{
//                        Text(Image(systemName: isActivity ? "bolt.fill" : "bolt" )) + Text("Live Activity: ") + Text(isActivity ? "on" : "off")}
//                    .padding(7)
//                    
//                    .overlay(
//                            RoundedRectangle(cornerRadius: 40)
//                                .stroke(colorScheme == .dark ? .white : .black, lineWidth: 1)
//                        )
//                }
//                .scaleEffect(isOn ? 1.1 : 1)
//                .buttonStyle(.plain)
//                .buttonBorderShape(.capsule)
//                
//                Spacer()
//            }.padding(.bottom,20)
//            .font(.caption)
//            
//            
            Divider()
                
            ScrollView{
                //                let eventStopName = event.stopName
                let eventDate = event.arrivalDate
                
                VStack(spacing:0){
                    ForEach(tripEvents, id: \.stopNumber){stop in
                        if stop.arrivalDate >= eventDate {
                            if stop.stopNumber == tripEvents.last!.stopNumber {
                                StopRow(event: stop, isLast: true)
                            } else if stop.id == tripEvents.first?.id || stop.stopName == event.stopName{
                                StopRow(event: stop, isFirst: true)
                            } else{
                                StopRow(event: stop)
                            }
                        }
                    }
                }
            }
            
            
            
        }.padding(.horizontal)
        .onAppear{
            ParameterManager.shared.selectedEvent = event
            ParameterManager.shared.isDetailView = true
            
            if Activity<DeliveryAttributes>.activities.first(where: {$0.attributes.trip == event.tripID && $0.attributes.stopNumber == event.stopNumber}) != nil {
                isActivity = true
                isOn = true
            }
            
        }
        .onReceive(api.$selectedTripEvents){events in
            if let events = events {
                tripEvents = events
            }
        }
        .onDisappear{
            DispatchQueue.main.async{
                ParameterManager.shared.isDetailView = false
            }
            
        }
    }
    private func toggleActivity() {
        
            withAnimation {
                isOn.toggle()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation {
                    isOn.toggle() // Toggle back after 2 seconds
                }
            }
        
    }
}

//struct EventDetailView_Previews: PreviewProvider {
//    static var previews: some View {
//        EventDetailView(event: PreviewEvent().event)
//    }
//}


#Preview{
    ScrollView{
        VStack(spacing: 0){
            StopRow(event: PreviewEvent().event2, isFirst: true)
            ForEach(1...20, id: \.self){_ in
                StopRow(event: PreviewEvent().event, isFirst: false, isLast: false)
            }
            StopRow(event: PreviewEvent().event2, isLast: true)
            
            StopRow(event: PreviewEvent().event2)
            ForEach(1...20, id: \.self){_ in
                StopRow(event: PreviewEvent().event, isFirst: false, isLast: false)
            }
            StopRow(event: PreviewEvent().event2, isLast: true)
            
        }
    }
}

struct StopRow : View {
    @Environment(\.colorScheme) var colorScheme
    
    let event: Event
    var isFirst = false
    var isLast: Bool = false
    @State var date = ""
    @State var height: CGFloat = .zero
    
    var body: some View{
        
            
        HStack{
            ZStack{
                Rectangle()
                    .foregroundColor(Color.accentColor)
                    .frame(width:  5, height: height)
                    .offset(y: isFirst ? height/2.6 : 0)
                    .offset(y: isLast ? -height/2.8 : 0)
                Circle()
                    .fill(Color.accentColor)
                    .stroke(colorScheme == .dark ? Color(.systemGray5) : .white )
                    .frame(width: isFirst || isLast ? 20 : 10)
            }
            
            HStack(alignment: .top){
                Text(event.stopName ?? "Unknown")
                    .multilineTextAlignment(.leading)
                    .foregroundColor(!isFirst ? .secondary : .primary )
                Spacer()
                Text(date)
                    .foregroundColor(!isFirst ? .secondary : .primary )
            }
            .padding(.vertical)
            .background(
                GeometryReader { proxy in
                    Color.clear // we just want the reader to get triggered, so let's use an empty color
                        .onChange(of: proxy.size.height){
                            height = proxy.size.height
                        }
                        .onAppear{
                            height = proxy.size.height
                        }
                })
        }
        .padding(.leading, isFirst || isLast ? 0 : 5)
        .onAppear{
                date = dateToString(date: event.arrivalDate)
                ParameterManager.shared.selectedEvent = event
        }
        .onDisappear{
                ParameterManager.shared.selectedEvent = nil
        }
        
            
                
        
        
    }
                 
    func dateToString(date: Date) -> String {
        // Create a date formatter
        let formatter = DateFormatter()
        // Set the format to hours and minutes
        formatter.dateFormat = "h:mm"
        // Convert the date to a string and return it
        return formatter.string(from: date)
    }
    
}
