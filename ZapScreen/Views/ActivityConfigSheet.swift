import SwiftUI

struct ActivityConfigSheet: View {
    @Binding var isPresented: Bool
    var body: some View {
//        ShieldView(isPresented: $isPresented)
//            .padding()
//            .background(Color(.systemBackground))
//            .cornerRadius(20)
//            .shadow(radius: 10)
        ShieldCustomView(onDismiss: { isPresented = false })
    }
} 
