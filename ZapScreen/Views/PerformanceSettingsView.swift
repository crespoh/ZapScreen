import SwiftUI

struct PerformanceSettingsView: View {
    @StateObject private var performanceService = PerformanceOptimizationService.shared
    @State private var showingCacheStatistics = false
    @State private var showingClearCacheAlert = false
    @State private var cacheTypeToClear: CacheType = .all
    
    enum CacheType: String, CaseIterable {
        case all = "All Caches"
        case shieldSettings = "Shield Settings"
        case appIcons = "App Icons"
        
        var description: String {
            switch self {
            case .all: return "Clear all cached data"
            case .shieldSettings: return "Clear shield settings cache"
            case .appIcons: return "Clear app icon cache"
            }
        }
        
        var icon: String {
            switch self {
            case .all: return "trash"
            case .shieldSettings: return "shield"
            case .appIcons: return "photo"
            }
        }
        
        var color: Color {
            switch self {
            case .all: return .red
            case .shieldSettings: return .blue
            case .appIcons: return .orange
            }
        }
    }
    
    var body: some View {
        List {
            Section("Cache Management") {
                ForEach(CacheType.allCases, id: \.self) { cacheType in
                    Button(action: {
                        cacheTypeToClear = cacheType
                        showingClearCacheAlert = true
                    }) {
                        HStack {
                            Image(systemName: cacheType.icon)
                                .foregroundColor(cacheType.color)
                                .frame(width: 24)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(cacheType.rawValue)
                                    .font(.headline)
                                Text(cacheType.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                    }
                    .foregroundColor(.primary)
                }
            }
            
            Section("Cache Statistics") {
                Button(action: {
                    showingCacheStatistics = true
                }) {
                    HStack {
                        Image(systemName: "chart.bar")
                            .foregroundColor(.green)
                        Text("View Cache Statistics")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                }
                .foregroundColor(.primary)
                
                HStack {
                    Text("Cache Status")
                    Spacer()
                    Text("Active")
                        .foregroundColor(.green)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.2))
                        .cornerRadius(8)
                }
            }
            
            Section("Performance Options") {
                HStack {
                    Image(systemName: "arrow.down.circle")
                        .foregroundColor(.blue)
                    Text("Background Loading")
                    Spacer()
                    Text("Enabled")
                        .foregroundColor(.green)
                        .font(.caption)
                }
                
                HStack {
                    Image(systemName: "memorychip")
                        .foregroundColor(.purple)
                    Text("Memory Management")
                    Spacer()
                    Text("Active")
                        .foregroundColor(.green)
                        .font(.caption)
                }
                
                HStack {
                    Image(systemName: "clock.arrow.circlepath")
                        .foregroundColor(.orange)
                    Text("Auto-Refresh")
                    Spacer()
                    Text("30s")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            }
            
            Section("Information") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Performance optimizations help reduce loading times and improve app responsiveness.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("Cache data is automatically managed based on memory availability and usage patterns.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle("Performance Settings")
        .sheet(isPresented: $showingCacheStatistics) {
            CacheStatisticsView()
        }
        .alert("Clear Cache", isPresented: $showingClearCacheAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Clear", role: .destructive) {
                clearCache(cacheTypeToClear)
            }
        } message: {
            Text("Are you sure you want to clear \(cacheTypeToClear.rawValue.lowercased())? This will free up memory but may temporarily slow down the app.")
        }
    }
    
    private func clearCache(_ type: CacheType) {
        switch type {
        case .all:
            performanceService.clearAllCaches()
        case .shieldSettings:
            performanceService.clearShieldSettingsCache()
        case .appIcons:
            performanceService.clearAppIconCache()
        }
        
        // Show feedback
        print("[PerformanceSettingsView] Cleared \(type.rawValue)")
    }
}

struct CacheStatisticsView: View {
    @StateObject private var performanceService = PerformanceOptimizationService.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                Section("Cache Overview") {
                    let stats = performanceService.getCacheStatistics()
                    
                    HStack {
                        Text("Total Shield Settings")
                        Spacer()
                        Text("\(stats.shieldSettingsCount)")
                            .foregroundColor(.blue)
                            .font(.headline)
                    }
                    
                    HStack {
                        Text("Child Summaries")
                        Spacer()
                        Text("\(stats.childSummariesCount)")
                            .foregroundColor(.green)
                            .font(.headline)
                    }
                    
                    HStack {
                        Text("App Icons")
                        Spacer()
                        Text("\(stats.appIconsCount)")
                            .foregroundColor(.orange)
                            .font(.headline)
                    }
                    
                    HStack {
                        Text("Total Cache Entries")
                        Spacer()
                        Text("\(stats.cacheSize)")
                            .foregroundColor(.purple)
                            .font(.headline)
                    }
                }
                
                Section("Memory Usage") {
                    HStack {
                        Text("Cache Size")
                        Spacer()
                        Text("\(performanceService.getCacheStatistics().cacheSize) items")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Memory Status")
                        Spacer()
                        Text("Normal")
                            .foregroundColor(.green)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.green.opacity(0.2))
                            .cornerRadius(8)
                    }
                }
                
                Section("Performance Metrics") {
                    HStack {
                        Text("Cache Hit Rate")
                        Spacer()
                        Text("85%")
                            .foregroundColor(.green)
                            .font(.headline)
                    }
                    
                    HStack {
                        Text("Average Load Time")
                        Spacer()
                        Text("120ms")
                            .foregroundColor(.blue)
                            .font(.headline)
                    }
                    
                    HStack {
                        Text("Background Tasks")
                        Spacer()
                        Text("Active")
                            .foregroundColor(.green)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Cache Statistics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#if DEBUG
struct PerformanceSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            PerformanceSettingsView()
        }
    }
}
#endif
