import SwiftUI

struct ChildSelectorView: View {
    @StateObject private var viewModel = ChildSelectorViewModel()
    @Binding var selectedChild: SupabaseChildDevice?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 12) {
                    Text("Select Child")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Choose which child's statistics to view")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding()
                
                // Children List
                if viewModel.isLoading {
                    Spacer()
                    ProgressView("Loading children...")
                    Spacer()
                } else if viewModel.children.isEmpty {
                    Spacer()
                    VStack(spacing: 16) {
                        Image(systemName: "person.2.slash")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        
                        Text("No Children Found")
                            .font(.headline)
                        
                        Text("No child devices have been registered yet.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        Button("Add Child Device") {
                            // TODO: Navigate to child registration
                            print("Add child device tapped")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                    Spacer()
                } else {
                    List {
                        ForEach(viewModel.children) { child in
                            Button(action: {
                                selectedChild = child
                                dismiss()
                            }) {
                                HStack {
                                    // Child Avatar
                                    Circle()
                                        .fill(Color.accentColor.opacity(0.2))
                                        .frame(width: 50, height: 50)
                                        .overlay(
                                            Text(String(child.child_name.prefix(1)).uppercased())
                                                .font(.title2)
                                                .fontWeight(.semibold)
                                                .foregroundColor(.accentColor)
                                        )
                                    
                                    // Child Info
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(child.child_name)
                                            .font(.headline)
                                            .foregroundColor(.primary)
                                        
                                        Text(child.device_name)
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    // Selection Indicator
                                    if selectedChild?.device_id == child.device_id {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.accentColor)
                                    } else {
                                        Image(systemName: "chevron.right")
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            viewModel.loadChildren()
        }
    }
}

// MARK: - Child Selector ViewModel
class ChildSelectorViewModel: ObservableObject {
    @Published var children: [SupabaseChildDevice] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    func loadChildren() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let loadedChildren = try await SupabaseManager.shared.getChildrenForParent()
                
                await MainActor.run {
                    self.children = loadedChildren
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
                print("[ChildSelectorViewModel] Failed to load children: \(error)")
            }
        }
    }
}

// MARK: - Preview
struct ChildSelectorView_Previews: PreviewProvider {
    static var previews: some View {
        ChildSelectorView(selectedChild: .constant(nil))
    }
}
