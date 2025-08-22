import SwiftUI

struct FamilyDashboardView: View {
    @StateObject private var viewModel = FamilyDashboardViewModel()
    @State private var showingChildSelector = false
    @State private var selectedChild: SupabaseChildDevice?
    @State private var showingQRScanner = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 8) {
                    Text("Family Dashboard")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Overview of all children's activity")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding()
                
                // Content
                if viewModel.isLoading {
                    Spacer()
                    ProgressView("Loading family data...")
                    Spacer()
                } else if viewModel.children.isEmpty {
                    Spacer()
                    VStack(spacing: 16) {
                        Image(systemName: "person.3")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        
                        Text("No Children Registered")
                            .font(.headline)
                        
                        Text("No child devices have been registered yet.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        Button("Add Child Device") {
                            showingQRScanner = true
                            print("Add child device tapped - navigating to QR scanner")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                    Spacer()
                } else {
                    ScrollView {
                        VStack(spacing: 20) {
                            // Family Summary Card
                            familySummaryCard
                            
                            // Children List
                            childrenList
                        }
                        .padding()
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Select Child") {
                        showingChildSelector = true
                    }
                }
            }
            .refreshable {
                viewModel.loadFamilySummary()
            }
        }
        .sheet(isPresented: $showingChildSelector) {
            ChildSelectorView(selectedChild: $selectedChild)
        }
        .sheet(isPresented: $showingQRScanner) {
            QRCodeScannerView()
        }
        .onAppear {
            viewModel.loadFamilySummary()
        }
    }
    
    // MARK: - Family Summary Card
    private var familySummaryCard: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundColor(.accentColor)
                Text("Family Overview")
                    .font(.headline)
                Spacer()
            }
            
            HStack(spacing: 20) {
                summaryItem(
                    title: "Children",
                    value: "\(viewModel.children.count)",
                    icon: "person.2.fill",
                    color: .blue
                )
                
                summaryItem(
                    title: "Total Apps",
                    value: "\(viewModel.totalApps)",
                    icon: "app.fill",
                    color: .green
                )
                
                summaryItem(
                    title: "Total Time",
                    value: "\(viewModel.totalMinutes)min",
                    icon: "clock.fill",
                    color: .orange
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        )
    }
    
    // MARK: - Children List
    private var childrenList: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Children")
                    .font(.headline)
                Spacer()
            }
            
            ForEach(viewModel.children) { child in
                childCard(child)
            }
        }
    }
    
    // MARK: - Child Card
    private func childCard(_ child: SupabaseChildDevice) -> some View {
        VStack(spacing: 12) {
            HStack {
                // Child Avatar
                Circle()
                    .fill(Color.accentColor.opacity(0.2))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Text(String(child.child_name.prefix(1)).uppercased())
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.accentColor)
                    )
                
                // Child Info
                VStack(alignment: .leading, spacing: 2) {
                    Text(child.child_name)
                        .font(.headline)
                    
                    Text(child.device_name)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Registration Date
                if let createdDate = child.createdAtDate {
                    Text("Registered \(createdDate, style: .relative)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Device Info
            HStack(spacing: 20) {
                statItem(title: "Device ID", value: String(child.device_id.prefix(8)))
                statItem(title: "Status", value: "Active")
                statItem(title: "Type", value: "Child Device")
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }
    
    // MARK: - Helper Views
    private func summaryItem(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
    
    private func statItem(title: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.headline)
                .fontWeight(.semibold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Family Dashboard ViewModel
class FamilyDashboardViewModel: ObservableObject {
    @Published var familySummary: [SupabaseFamilySummary] = []
    @Published var children: [SupabaseChildDevice] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    var totalApps: Int {
        familySummary.reduce(0) { $0 + $1.total_apps }
    }
    
    var totalMinutes: Int {
        familySummary.reduce(0) { $0 + $1.total_minutes }
    }
    
    func loadFamilySummary() {
        isLoading = true
        errorMessage = nil
        
                        Task {
                    do {
                        // First, get the list of registered children (regardless of usage)
                        print("[FamilyDashboardViewModel] Calling getChildrenForParent()...")
                        let registeredChildren = try await SupabaseManager.shared.getChildrenForParent()
                        print("[FamilyDashboardViewModel] Loaded \(registeredChildren.count) registered children")
                        
                        // Then, get usage statistics for those children
                        print("[FamilyDashboardViewModel] Calling getFamilySummary()...")
                        let summary = try await SupabaseManager.shared.getFamilySummary()
                        print("[FamilyDashboardViewModel] Loaded \(summary.count) children with usage statistics")
                        
                        await MainActor.run {
                            self.children = registeredChildren
                            self.familySummary = summary
                            self.isLoading = false
                            
                            // Debug: Show what we got
                            print("[FamilyDashboardViewModel] Registered children:")
                            for child in registeredChildren {
                                print("[FamilyDashboardViewModel] - \(child.child_name) (\(child.device_name))")
                            }
                            
                            print("[FamilyDashboardViewModel] Children with usage:")
                            for child in summary {
                                print("[FamilyDashboardViewModel] - \(child.child_name): Apps: \(child.total_apps), Requests: \(child.total_requests)")
                            }
                        }
                    } catch {
                        await MainActor.run {
                            self.errorMessage = error.localizedDescription
                            self.isLoading = false
                        }
                        print("[FamilyDashboardViewModel] Failed to load family data: \(error)")
                    }
                }
    }
}

// MARK: - Preview
struct FamilyDashboardView_Previews: PreviewProvider {
    static var previews: some View {
        FamilyDashboardView()
    }
}
