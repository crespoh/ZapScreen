import SwiftUI

struct RemoteUnLockView: View {
    @State private var isSending = false
    @State private var sendResult: String?
    @State private var selectedTimeOption: TimeOption = .tenMinutes
    @State private var customMinutes: String = ""
    @State private var showCustomTimeInput = false
    
    @AppStorage("selectedRole", store: UserDefaults(suiteName: "group.com.ntt.ZapScreen.data")) 
    private var selectedRole: String?
    
    enum TimeOption: CaseIterable {
        case fiveMinutes, tenMinutes, fifteenMinutes, twentyMinutes, thirtyMinutes, fortyFiveMinutes, oneHour, custom
        
        var displayText: String {
            switch self {
            case .fiveMinutes: return "5 minutes"
            case .tenMinutes: return "10 minutes"
            case .fifteenMinutes: return "15 minutes"
            case .twentyMinutes: return "20 minutes"
            case .thirtyMinutes: return "30 minutes"
            case .fortyFiveMinutes: return "45 minutes"
            case .oneHour: return "1 hour"
            case .custom: return "Custom"
            }
        }
        
        var minutes: Int? {
            switch self {
            case .fiveMinutes: return 5
            case .tenMinutes: return 10
            case .fifteenMinutes: return 15
            case .twentyMinutes: return 20
            case .thirtyMinutes: return 30
            case .fortyFiveMinutes: return 45
            case .oneHour: return 60
            case .custom: return nil
            }
        }
    }
    
    private var selectedMinutes: Int {
        if selectedTimeOption == .custom {
            return Int(customMinutes) ?? 10
        }
        return selectedTimeOption.minutes ?? 10
    }
    
    private var buttonText: String {
        if selectedTimeOption == .custom {
            let minutes = Int(customMinutes) ?? 10
            return "UnLock Child's App for \(minutes) mins"
        }
        return "UnLock Child's App for \(selectedTimeOption.displayText)"
    }
    
    var body: some View {
        VStack(spacing: 24) {
            Text("Remote UnLock Control")
                .font(.largeTitle)
                .padding(.top)
            
            Text("Send a unlock command to your child's device. This will unlock the app your child requested.")
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            // Time Selection Section
            VStack(alignment: .leading, spacing: 16) {
                Text("Select Unlock Duration")
                    .font(.headline)
                    .padding(.horizontal)
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                    ForEach(TimeOption.allCases, id: \.self) { option in
                        TimeOptionButton(
                            option: option,
                            isSelected: selectedTimeOption == option,
                            action: {
                                selectedTimeOption = option
                                showCustomTimeInput = option == .custom
                                if option != .custom {
                                    customMinutes = ""
                                }
                            }
                        )
                    }
                }
                .padding(.horizontal)
                
                // Custom Time Input
                if showCustomTimeInput {
                    CustomTimeInputView(
                        customMinutes: $customMinutes,
                        selectedMinutes: selectedMinutes
                    )
                    .padding(.horizontal)
                }
            }
            
            // Unlock Button
            Button(action: {
                Task {
                    await sendUnLockCommand()
                }
            }) {
                HStack {
                    if isSending { 
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                    Text(buttonText)
                }
                .frame(maxWidth: .infinity)
                .padding()
            }
            .disabled(isSending || (selectedTimeOption == .custom && customMinutes.isEmpty))
            .buttonStyle(.borderedProminent)
            .padding(.horizontal)
            
            // Result Message
            if let sendResult = sendResult {
                Text(sendResult)
                    .foregroundColor(sendResult.contains("success") ? .green : .red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            Spacer()
        }
        .padding()
    }
    
    private func sendUnLockCommand() async {
        isSending = true
        sendResult = nil
        
        let groupDefaults = UserDefaults(suiteName: "group.com.ntt.ZapScreen.data")
        guard let childDeviceId = groupDefaults?.string(forKey: "ZapChildDeviceId"),
              let bundleIdentifier = groupDefaults?.string(forKey: "ZapLastUnlockedBundleIdentifier") else {
            sendResult = "Missing child device or app info."
            isSending = false
            return
        }
        
        await SupabaseManager.shared.sendUnLockCommand(
            to: childDeviceId, 
            bundleIdentifier: bundleIdentifier, 
            time: selectedMinutes
        ) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    sendResult = "UnLock command sent successfully for \(selectedMinutes) minutes."
                case .failure(let error):
                    sendResult = "Failed to send Unlock command: \(error.localizedDescription)"
                }
                isSending = false
            }
        }
    }
}

// MARK: - Supporting Views

struct TimeOptionButton: View {
    let option: RemoteUnLockView.TimeOption
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(option.displayText)
                .font(.system(.body, design: .rounded))
                .fontWeight(.medium)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(isSelected ? Color.accentColor : Color(.systemGray6))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(10)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct CustomTimeInputView: View {
    @Binding var customMinutes: String
    let selectedMinutes: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Custom Duration (minutes)")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            HStack {
                TextField("Enter minutes", text: $customMinutes)
                    .keyboardType(.numberPad)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                Text("minutes")
                    .foregroundColor(.secondary)
            }
            
            if !customMinutes.isEmpty {
                Text("Will unlock for \(selectedMinutes) minutes")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

#Preview {
    RemoteUnLockView()
}
