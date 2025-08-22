import SwiftUI

struct PasscodeSetupView: View {
    @Binding var passcode: String
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var isSettingPasscode = false
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "lock.shield")
                    .font(.system(size: 50))
                    .foregroundColor(.blue)
                
                Text("Set Shield Management Passcode")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("This passcode will protect shield settings from unauthorized access")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // Passcode Display
            HStack(spacing: 12) {
                ForEach(0..<4, id: \.self) { index in
                    Circle()
                        .fill(index < passcode.count ? Color.blue : Color.gray.opacity(0.3))
                        .frame(width: 20, height: 20)
                        .overlay(
                            Text(index < passcode.count ? "•" : "")
                                .font(.title2)
                                .foregroundColor(.white)
                        )
                }
            }
            .padding(.vertical, 20)
            
            // Instructions
            Text("Enter a 4-digit passcode")
                .font(.caption)
                .foregroundColor(.secondary)
            
            // Numeric Keypad
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 15) {
                ForEach(1...9, id: \.self) { number in
                    NumberButton(number: "\(number)") {
                        addDigit("\(number)")
                    }
                }
                
                // Bottom row: Clear, 0, Delete
                Button("Clear") {
                    clearPasscode()
                }
                .buttonStyle(NumberButtonStyle())
                .foregroundColor(.red)
                
                NumberButton(number: "0") {
                    addDigit("0")
                }
                
                Button("⌫") {
                    deleteLastDigit()
                }
                .buttonStyle(NumberButtonStyle())
                .foregroundColor(.orange)
            }
            .padding(.horizontal, 40)
            
            // Set Passcode Button
            Button("Set Passcode") {
                setPasscode()
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(passcode.count != 4 || isSettingPasscode)
            .padding(.top, 20)
            
            if isSettingPasscode {
                ProgressView("Setting passcode...")
                    .padding(.top, 10)
            }
        }
        .padding()
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func addDigit(_ digit: String) {
        guard passcode.count < 4 else { return }
        passcode += digit
    }
    
    private func deleteLastDigit() {
        guard !passcode.isEmpty else { return }
        passcode.removeLast()
    }
    
    private func clearPasscode() {
        passcode = ""
    }
    
    private func setPasscode() {
        guard passcode.count == 4 else { return }
        
        isSettingPasscode = true
        
        Task {
            do {
                try await PasscodeManager.shared.setPasscode(passcode)
                isSettingPasscode = false
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showingError = true
                    isSettingPasscode = false
                }
            }
        }
    }
}

struct NumberButton: View {
    let number: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(number)
                .font(.title)
                .fontWeight(.medium)
                .frame(width: 70, height: 70)
                .background(Color.blue.opacity(0.1))
                .foregroundColor(.blue)
                .clipShape(Circle())
        }
        .buttonStyle(NumberButtonStyle())
    }
}

struct NumberButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.blue)
            .cornerRadius(10)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

#if DEBUG
struct PasscodeSetupView_Previews: PreviewProvider {
    static var previews: some View {
        PasscodeSetupView(passcode: .constant(""))
    }
}
#endif
