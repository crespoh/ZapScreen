import SwiftUI

struct LoginView: View {
    @AppStorage("isLoggedIn") private var isLoggedIn = false
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var errorMessage: String? = nil

    var body: some View {
        VStack(spacing: 24) {
            Text("ZapScreen Login")
                .font(.largeTitle)
                .bold()
            TextField("Username", text: $username)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .autocapitalization(.none)
                .padding(.horizontal)
            SecureField("Password", text: $password)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal)
            if let error = errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Button(action: handleLogin) {
                Text("Login")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            .padding(.horizontal)
        }
        .padding()
    }

    func handleLogin() {
        // Demo: hardcoded credentials (replace with real auth logic as needed)
        if username == "admin" && password == "password" {
            isLoggedIn = true
            errorMessage = nil
        } else {
            errorMessage = "Invalid username or password."
        }
    }
}

struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView()
    }
}
