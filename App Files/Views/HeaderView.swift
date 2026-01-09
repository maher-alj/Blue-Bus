import SwiftUI

struct HeaderView: View {
    @Environment(\.colorScheme) var colorScheme
    
    @Binding var Stop : Stop?
    
    @EnvironmentObject var database : Database
    
    
    var body: some View {
        if let currentStop = Stop {
            
//            VStack(spacing:5) {
                VStack(alignment: .leading, spacing: 8) {
                    
                    HStack(alignment: .top){
                        Text(currentStop.stop_name)
                            .font(.title2)
                            .lineLimit(1)
                            .fontWeight(.semibold)
                            .minimumScaleFactor(0.5)
                        
                        Spacer()
                        
                        Button{
                            print("clicked x button")
                            Stop = nil
                        } label: {
                            ZStack{
                                Image(systemName: "multiply.circle.fill")
                                    .symbolRenderingMode(.palette)
                                    .foregroundStyle(Color(.systemGray),Color(.systemGray5))
                                    
                            }.font(.title2)
                        }.buttonStyle(.plain)
                    }
                   
                    Text("\(currentStop.stop_id)")
                        .font(.caption2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        
                }
                .frame(height:50)
                .padding()
                .foregroundColor(colorScheme == .dark ? .black : .white)
                .background(Color.accentColor)
                .cornerRadius(8)
                .shadow(radius: 4)
                .padding(.horizontal)
            .padding(.top)
                
//                HStack{
//                    Text("Bus")
//                    Spacer()
//                    Text("Travelling to")
//                    Spacer()
//                    Text("Arrives in")
//                }
//                .padding(.horizontal,10)
//                .padding(.vertical,5)
//                .background(Color(.systemGroupedBackground))
//                .cornerRadius(8)
//                .padding(.horizontal)
         
                
//            }
            
        }
    }
}

//#Preview{
//    HeaderView(Stop: .constant(Stop(stop_id: "123456789", stop_name: "Maroubra", stop_lat: 0, stop_lon: 0, location_type: "", parent_station: "", wheelchair_boarding: "", platform_code: "")), detent2: .constant(.medium)).environmentObject(Database())
//}
    


