import SwiftUI

struct RemoteLockView: View {
    @State private var isSending = false
    @State private var sendResult: String?
    @AppStorage("selectedRole") private var selectedRole: String?
    
    var body: some View {
        VStack(spacing: 24) {
            Text("Remote Lock Control")
                .font(.largeTitle)
                .padding(.top)
            Text("Send a lock command to your child's device. This will lock the app your child has unlocked.")
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Button(action: sendLockCommand) {
                HStack {
                    if isSending { ProgressView() }
                    Text("Lock Child's App")
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
    
    private func sendLockCommand() {
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
        ZapScreenManager.shared.sendLockCommand(to: childDeviceId, bundleIdentifier: bundleIdentifier) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    sendResult = "Lock command sent successfully."
                case .failure(let error):
                    sendResult = "Failed to send lock command: \(error.localizedDescription)"
                }
                isSending = false
            }
        }
    }
}

#Preview {
    RemoteLockView()
}
