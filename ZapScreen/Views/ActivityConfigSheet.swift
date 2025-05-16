import SwiftUI

struct ActivityConfigSheet: View {
    @Binding var isPresented: Bool
    var body: some View {
        ShieldCustomView(onDismiss: { isPresented = false })
    }
} 
