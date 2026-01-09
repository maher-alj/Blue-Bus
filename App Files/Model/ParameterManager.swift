//
//  ParameterManager.swift
//  Next Bus
//
//  Created by Maher Al Jundi on 14/10/2023.
//

import Foundation
import SwiftUI


class ParameterManager: ObservableObject {
    static let shared = ParameterManager()
    
    @Published var detent: PresentationDetent = .small
    @Published var interactionDetent: PresentationDetent = .small
    @Published var detents: Set<PresentationDetent> = Set([.small,.medium,.large])
    @Published var isDetailView = false
    @Published var detentSize : CGSize = CGSize(width: 100, height: 100)
    @Published var tripEvents = [Event]() 
    @Published var selectedEvent : Event?
    @Published var username = ""
    
    
    static let event = Event(tripID: "", routeID: "", busNumber: "396", headsign: "Maroubra", direction_id: "", arrivalTime: "3 min", stopNumber: "1122233", stopName: "Maroubra", arrivalDate: Date(timeIntervalSince1970: 0), stop_latitude: 0.0, stop_longitude: 0.0)

}
