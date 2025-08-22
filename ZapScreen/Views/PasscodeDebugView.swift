import SwiftUI

struct PasscodeDebugView: View {
    @StateObject private var passcodeManager = PasscodeManager.shared
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Passcode Debug Info")
                .font(.title2)
                .fontWeight(.bold)
            
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Passcode Enabled:")
                    Spacer()
                    Text(passcodeManager.isPasscodeEnabled ? "Yes" : "No")
                        .foregroundColor(passcodeManager.isPasscodeEnabled ? .green : .red)
                }
                
                HStack {
                    Text("Device Locked:")
                    Spacer()
                    Text(passcodeManager.isLocked ? "Yes" : "No")
                        .foregroundColor(passcodeManager.isLocked ? .red : .green)
                }
                
                HStack {
                    Text("Remaining Attempts:")
                    Spacer()
                    Text("\(passcodeManager.remainingAttempts)")
                }
                
                if let lockoutUntil = passcodeManager.lockoutUntil {
                    HStack {
                        Text("Lockout Until:")
                        Spacer()
                        Text(lockoutUntil, style: .time)
                            .foregroundColor(.orange)
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(8)
            
            VStack(spacing: 10) {
                Button("Force Lock Device") {
                    passcodeManager.forceLockDevice()
                }
                .buttonStyle(.borderedProminent)
                .foregroundColor(.red)
                
                Button("Unlock Device") {
                    passcodeManager.unlockDevice()
                }
                .buttonStyle(.borderedProminent)
                .foregroundColor(.green)
                
                Button("Reset Passcode") {
                    Task {
                        try? await passcodeManager.resetPasscode()
                    }
                }
                .buttonStyle(.bordered)
                .foregroundColor(.orange)
            }
            
            Spacer()
        }
        .padding()
        .navigationTitle("Passcode Debug")
    }
}

#if DEBUG
struct PasscodeDebugView_Previews: PreviewProvider {
    static var previews: some View {
        PasscodeDebugView()
    }
}
#endif
