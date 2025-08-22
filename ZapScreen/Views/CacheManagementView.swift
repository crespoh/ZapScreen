import SwiftUI

struct CacheManagementView: View {
    @StateObject private var performanceService = PerformanceOptimizationService.shared
    @State private var showingClearAllAlert = false
    @State private var showingClearShieldAlert = false
    @State private var showingClearIconsAlert = false
    @State private var isRefreshing = false
    
    var body: some View {
        List {
            Section("Cache Overview") {
                let stats = performanceService.getCacheStatistics()
                
                HStack {
                    Image(systemName: "shield.lefthalf.filled")
                        .foregroundColor(.blue)
                    Text("Shield Settings")
                    Spacer()
                    Text("\(stats.shieldSettingsCount)")
                        .foregroundColor(.blue)
                        .font(.headline)
                }
                
                HStack {
                    Image(systemName: "person.2")
                        .foregroundColor(.green)
                    Text("Child Summaries")
                    Spacer()
                    Text("\(stats.childSummariesCount)")
                        .foregroundColor(.green)
                        .font(.headline)
                }
                
                HStack {
                    Image(systemName: "photo")
                        .foregroundColor(.orange)
                    Text("App Icons")
                    Spacer()
                    Text("\(stats.appIconsCount)")
                        .foregroundColor(.orange)
                        .font(.headline)
                }
                
                HStack {
                    Image(systemName: "clock")
                        .foregroundColor(.purple)
                    Text("Timestamps")
                    Spacer()
                    Text("\(stats.timestampsCount)")
                        .foregroundColor(.purple)
                        .font(.headline)
                }
                
                HStack {
                    Image(systemName: "memorychip")
                        .foregroundColor(.red)
                    Text("Total Cache Size")
                    Spacer()
                    Text("\(stats.cacheSize)")
                        .foregroundColor(.red)
                        .font(.headline)
                }
            }
            
            Section("Cache Operations") {
                Button(action: {
                    showingClearShieldAlert = true
                }) {
                    HStack {
                        Image(systemName: "shield.slash")
                            .foregroundColor(.blue)
                        Text("Clear Shield Settings Cache")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                }
                .foregroundColor(.primary)
                
                Button(action: {
                    showingClearIconsAlert = true
                }) {
                    HStack {
                        Image(systemName: "photo.slash")
                            .foregroundColor(.orange)
                        Text("Clear App Icons Cache")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                }
                .foregroundColor(.primary)
                
                Button(action: {
                    showingClearAllAlert = true
                }) {
                    HStack {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                        Text("Clear All Caches")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                }
                .foregroundColor(.primary)
            }
            
            Section("Cache Management") {
                Button(action: {
                    refreshCache()
                }) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(.green)
                        Text("Refresh Cache")
                        Spacer()
                        if isRefreshing {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                    }
                }
                .foregroundColor(.primary)
                .disabled(isRefreshing)
                
                Button(action: {
                    performanceService.refreshEssentialCaches()
                }) {
                    HStack {
                        Image(systemName: "star")
                            .foregroundColor(.yellow)
                        Text("Refresh Essential Caches")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                }
                .foregroundColor(.primary)
            }
            
            Section("Cache Information") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Cache data improves app performance by storing frequently accessed information in memory.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("Caches are automatically managed and will be cleared when memory is low.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("Clearing caches may temporarily slow down the app until data is reloaded.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle("Cache Management")
        .refreshable {
            await refreshCacheAsync()
        }
        .alert("Clear Shield Settings Cache", isPresented: $showingClearShieldAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Clear", role: .destructive) {
                performanceService.clearShieldSettingsCache()
            }
        } message: {
            Text("This will clear all cached shield settings data. The app will need to reload this information from the server.")
        }
        .alert("Clear App Icons Cache", isPresented: $showingClearIconsAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Clear", role: .destructive) {
                performanceService.clearAppIconCache()
            }
        } message: {
            Text("This will clear all cached app icons. Icons will be reloaded as needed.")
        }
        .alert("Clear All Caches", isPresented: $showingClearAllAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Clear All", role: .destructive) {
                performanceService.clearAllCaches()
            }
        } message: {
            Text("This will clear all cached data. The app will need to reload all information from the server, which may temporarily slow down performance.")
        }
    }
    
    private func refreshCache() {
        isRefreshing = true
        
        // Simulate cache refresh
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            isRefreshing = false
        }
    }
    
    private func refreshCacheAsync() async {
        await MainActor.run {
            isRefreshing = true
        }
        
        // Simulate async cache refresh
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        await MainActor.run {
            isRefreshing = false
        }
    }
}

#if DEBUG
struct CacheManagementView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            CacheManagementView()
        }
    }
}
#endif
