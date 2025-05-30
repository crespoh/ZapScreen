import SwiftUI

struct RemoteUnLockView: View {
    @State private var isSending = false
    @State private var sendResult: String?
    @AppStorage("selectedRole", store: UserDefaults(suiteName: "group.com.ntt.ZapScreen.data")) private var selectedRole: String?
    
    var body: some View {
        VStack(spacing: 24) {
            Text("Remote UnLock Control")
                .font(.largeTitle)
                .padding(.top)
            Text("Send a unlock command to your child's device. This will unlock the app your child requested.")
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Button(action: {
                    Task {
                        await sendUnLockCommand()
                    }
            }) {
                HStack {
                    if isSending { ProgressView() }
                    Text("UnLock Child's App for 2 mins")
                }
            }
            .disabled(isSending)
            .buttonStyle(.borderedProminent)
            if let sendResult = sendResult {
                Text(sendResult)
                    .foregroundColor(sendResult.contains("success") ? .green : .red)
            }
            Spacer()
        }
        .padding()
    }
    
    private func sendUnLockCommand() async {
        isSending = true
        sendResult = nil
        // Fetch child device ID and bundleIdentifier as needed
        let groupDefaults = UserDefaults(suiteName: "group.com.ntt.ZapScreen.data")
        guard let childDeviceId = groupDefaults?.string(forKey: "ZapChildDeviceId"),
              let bundleIdentifier = groupDefaults?.string(forKey: "ZapLastUnlockedBundleIdentifier") else {
            sendResult = "Missing child device or app info."
            isSending = false
            return
        }
        await SupabaseManager.shared.sendUnLockCommand(to: childDeviceId, bundleIdentifier: bundleIdentifier, time: 2) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    sendResult = "UnLock command sent successfully."
                case .failure(let error):
                    sendResult = "Failed to send Unlock command: \(error.localizedDescription)"
                }
                isSending = false
            }
        }

    }
}

#Preview {
    RemoteUnLockView()
}
