import SwiftUI
import FamilyControls

struct ChildView: View {
    @StateObject private var settings = AppSettings()
    @State private var selectedTimeOption: TimeInterval = 600 // Default 10 minutes
    @State private var showingTimeRequest = false
    
    private var appUsageItems: [(app: String, minutesLeft: Int)] {
        settings.timeLimits.map { (app: $0.key, minutesLeft: Int($0.value / 60)) }
    }
    
    private var earningAppItems: [(description: String, rate: Int)] {
        Array(arrayLiteral: settings.earningApps.applicationTokens).map { token in
            (description: token.description, rate: Int(settings.earningRates[token.description] ?? 0))
        }
    }
    
    var body: some View {
        NavigationView {
            VStack {
                // Current time usage and limits
                List {
                    Section(header: Text("App Usage")) {
                        ForEach(appUsageItems, id: \.app) { item in
                            HStack {
                                Text(item.app)
                                Spacer()
                                Text("\(item.minutesLeft) minutes left")
                            }
                        }
                    }
                    
                    Section(header: Text("Earning Apps")) {
                        ForEach(earningAppItems, id: \.description) { item in
                            HStack {
                                Text(item.description)
                                Spacer()
                                Text("Earns \(item.rate) minutes")
                            }
                        }
                    }
                }
                
                // Time request button
                Button(action: {
                    showingTimeRequest = true
                }) {
                    Text("Request More Time")
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .padding()
            }
            .navigationTitle("My Screen Time")
            .sheet(isPresented: $showingTimeRequest) {
                TimeRequestView(selectedTimeOption: $selectedTimeOption)
            }
        }
    }
}

struct TimeRequestView: View {
    @Binding var selectedTimeOption: TimeInterval
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Select Additional Time")) {
                    Picker("Time", selection: $selectedTimeOption) {
                        Text("10 minutes").tag(TimeInterval(600))
                        Text("20 minutes").tag(TimeInterval(1200))
                        Text("30 minutes").tag(TimeInterval(1800))
                    }
                    .pickerStyle(.segmented)
                }
                
                Button("Send Request") {
                    // Send time request to parent
                    dismiss()
                }
            }
            .navigationTitle("Request Time")
            .navigationBarItems(trailing: Button("Cancel") {
                dismiss()
            })
        }
    }
} 