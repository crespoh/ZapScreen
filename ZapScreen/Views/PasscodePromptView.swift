import SwiftUI

struct PasscodePromptView: View {
    @StateObject private var passcodeManager = PasscodeManager.shared
    @State private var enteredPasscode = ""
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var isCheckingSupabase = false
    @State private var isValidating = false
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "lock.shield")
                    .font(.system(size: 50))
                    .foregroundColor(.red)
                
                Text("Shield Management Locked")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Enter passcode to access shield settings")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // Passcode Display
            HStack(spacing: 12) {
                ForEach(0..<4, id: \.self) { index in
                    Circle()
                        .fill(index < enteredPasscode.count ? Color.blue : Color.gray.opacity(0.3))
                        .frame(width: 20, height: 20)
                        .overlay(
                            Text(index < enteredPasscode.count ? "•" : "")
                                .font(.title2)
                                .foregroundColor(.white)
                        )
                }
            }
            .padding(.vertical, 20)
            
            // Status Messages
            if let lockoutUntil = passcodeManager.lockoutUntil {
                VStack(spacing: 4) {
                    Text("Too many failed attempts")
                        .font(.caption)
                        .foregroundColor(.red)
                    
                    Text("Try again in \(Int(lockoutUntil.timeIntervalSinceNow)) seconds")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            } else if passcodeManager.remainingAttempts < 3 {
                Text("\(passcodeManager.remainingAttempts) attempts remaining")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
            
            // Instructions
            Text("Enter 4-digit passcode")
                .font(.caption)
                .foregroundColor(.secondary)
            
            // Numeric Keypad
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 15) {
                ForEach(1...9, id: \.self) { number in
                    NumberButton(number: "\(number)") {
                        addDigit("\(number)")
                    }
                    .disabled(isLockedOut || isCheckingSupabase || isValidating)
                }
                
                // Bottom row: Clear, 0, Delete
                Button("Clear") {
                    clearPasscode()
                }
                .buttonStyle(NumberButtonStyle())
                .foregroundColor(.red)
                .disabled(isLockedOut || isCheckingSupabase || isValidating)
                
                NumberButton(number: "0") {
                    addDigit("0")
                }
                .disabled(isLockedOut || isCheckingSupabase || isValidating)
                
                Button("⌫") {
                    deleteLastDigit()
                }
                .buttonStyle(NumberButtonStyle())
                .foregroundColor(.orange)
                .disabled(isLockedOut || isCheckingSupabase || isValidating)
            }
            .padding(.horizontal, 40)
            
            // Unlock Button
            Button("Unlock") {
                validatePasscode()
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(enteredPasscode.count != 4 || isLockedOut || isCheckingSupabase || isValidating)
            .padding(.top, 20)
            
            if isCheckingSupabase {
                ProgressView("Checking for updates...")
                    .padding(.top, 10)
            }
            
            if isValidating {
                ProgressView("Validating...")
                    .padding(.top, 10)
            }
            
            // Help Text
            Text("Ask your parent to unlock this section")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 20)
        }
        .padding()
        .onAppear {
            checkSupabaseForLatestPasscode()
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private var isLockedOut: Bool {
        passcodeManager.lockoutUntil != nil && passcodeManager.lockoutUntil! > Date()
    }
    
    private func addDigit(_ digit: String) {
        guard enteredPasscode.count < 4 else { return }
        enteredPasscode += digit
    }
    
    private func deleteLastDigit() {
        guard !enteredPasscode.isEmpty else { return }
        enteredPasscode.removeLast()
    }
    
    private func clearPasscode() {
        enteredPasscode = ""
    }
    
    private func validatePasscode() {
        guard enteredPasscode.count == 4 else { return }
        
        isValidating = true
        
        let result = passcodeManager.validatePasscode(enteredPasscode)
        
        switch result {
        case .valid:
            // Passcode is correct - device will be unlocked
            isValidating = false
            enteredPasscode = ""
            
        case .invalid(let remainingAttempts):
            // Passcode is incorrect
            isValidating = false
            enteredPasscode = ""
            errorMessage = "Incorrect passcode. \(remainingAttempts) attempts remaining."
            showingError = true
            
        case .locked(let lockoutUntil):
            // Device is locked out
            isValidating = false
            enteredPasscode = ""
            errorMessage = "Device locked. Try again after \(Int(lockoutUntil.timeIntervalSinceNow)) seconds."
            showingError = true
        }
    }
    
    private func checkSupabaseForLatestPasscode() {
        Task {
            isCheckingSupabase = true
            
            do {
                let latestPasscode = await passcodeManager.checkSupabaseForLatestPasscode()
                if latestPasscode != nil {
                    // Passcode was updated from Supabase
                    print("[PasscodePromptView] Passcode updated from Supabase")
                }
            } catch {
                print("[PasscodePromptView] Failed to check Supabase: \(error)")
            }
            
            isCheckingSupabase = false
        }
    }
}

#if DEBUG
struct PasscodePromptView_Previews: PreviewProvider {
    static var previews: some View {
        PasscodePromptView()
    }
}
#endif
