import Foundation
import SwiftUI
import Combine

@MainActor
class PerformanceOptimizationService: ObservableObject {
    static let shared = PerformanceOptimizationService()
    
    // MARK: - Cache Management
    
    private var shieldSettingsCache: [String: [SupabaseShieldSetting]] = [:]
    private var childSummaryCache: [String: ChildShieldSettingsSummary] = [:]
    private var appIconCache: [String: UIImage] = [:]
    
    private let cacheExpiryInterval: TimeInterval = 300 // 5 minutes
    private var cacheTimestamps: [String: Date] = [:]
    
    // MARK: - Background Task Management
    
    private var backgroundTasks: Set<UIBackgroundTaskIdentifier> = []
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Memory Management
    
    private let maxCacheSize = 50
    private let memoryWarningThreshold = 0.8 // 80% of available memory
    
    private init() {
        setupMemoryWarningObserver()
        setupAppStateObservers()
    }
    
    // MARK: - Cache Operations
    
    func getCachedShieldSettings(for deviceId: String) -> [SupabaseShieldSetting]? {
        guard let timestamp = cacheTimestamps[deviceId],
              Date().timeIntervalSince(timestamp) < cacheExpiryInterval else {
            // Cache expired or doesn't exist
            return nil
        }
        return shieldSettingsCache[deviceId]
    }
    
    func cacheShieldSettings(_ settings: [SupabaseShieldSetting], for deviceId: String) {
        shieldSettingsCache[deviceId] = settings
        cacheTimestamps[deviceId] = Date()
        
        // Enforce cache size limit
        if shieldSettingsCache.count > maxCacheSize {
            cleanupOldestCacheEntries()
        }
    }
    
    func getCachedChildSummary(for deviceId: String) -> ChildShieldSettingsSummary? {
        guard let timestamp = cacheTimestamps["summary_\(deviceId)"],
              Date().timeIntervalSince(timestamp) < cacheExpiryInterval else {
            return nil
        }
        return childSummaryCache[deviceId]
    }
    
    func cacheChildSummary(_ summary: ChildShieldSettingsSummary, for deviceId: String) {
        childSummaryCache[deviceId] = summary
        cacheTimestamps["summary_\(deviceId)"] = Date()
    }
    
    func getCachedAppIcon(for appName: String) -> UIImage? {
        return appIconCache[appName]
    }
    
    func cacheAppIcon(_ icon: UIImage, for appName: String) {
        appIconCache[appName] = icon
        
        // Enforce cache size limit
        if appIconCache.count > maxCacheSize {
            cleanupOldestAppIcons()
        }
    }
    
    // MARK: - Background Loading
    
    func performBackgroundTask<T>(_ task: @escaping () async throws -> T, completion: @escaping (Result<T, Error>) -> Void) {
        var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
        
        backgroundTaskID = UIApplication.shared.beginBackgroundTask(withName: "ShieldSettingsBackgroundTask") { [weak self] in
            self?.endBackgroundTask(backgroundTaskID)
        }
        
        backgroundTasks.insert(backgroundTaskID)
        
        Task {
            do {
                let result = try await task()
                DispatchQueue.main.async {
                    completion(.success(result))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
            
            DispatchQueue.main.async { [weak self] in
                self?.endBackgroundTask(backgroundTaskID)
            }
        }
    }
    
    private func endBackgroundTask(_ taskID: UIBackgroundTaskIdentifier) {
        UIApplication.shared.endBackgroundTask(taskID)
        backgroundTasks.remove(taskID)
    }
    
    // MARK: - Lazy Loading
    
    func lazyLoadShieldSettings(for deviceId: String, pageSize: Int = 20) -> AnyPublisher<[SupabaseShieldSetting], Never> {
        // Check cache first
        if let cached = getCachedShieldSettings(for: deviceId) {
            return Just(cached).eraseToAnyPublisher()
        }
        
        // Load from network in background
        return Future { [weak self] promise in
            Task {
                do {
                    let settings = try await SupabaseManager.shared.getChildShieldSettings(for: deviceId)
                    DispatchQueue.main.async {
                        self?.cacheShieldSettings(settings, for: deviceId)
                        promise(.success(settings))
                    }
                } catch {
                    DispatchQueue.main.async {
                        promise(.success([]))
                    }
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    // MARK: - Prefetching
    
    func prefetchShieldSettings(for deviceIds: [String]) {
        Task {
            await withTaskGroup(of: Void.self) { group in
                for deviceId in deviceIds {
                    group.addTask {
                        do {
                            let settings = try await SupabaseManager.shared.getChildShieldSettings(for: deviceId)
                            await MainActor.run {
                                self.cacheShieldSettings(settings, for: deviceId)
                            }
                        } catch {
                            print("[PerformanceOptimizationService] Failed to prefetch settings for \(deviceId): \(error)")
                        }
                    }
                }
            }
        }
    }
    
    func prefetchAppIcons(for appNames: [String]) {
        // This would typically involve downloading app icons from the App Store
        // For now, we'll just prepare the cache structure
        for appName in appNames {
            if appIconCache[appName] == nil {
                // Placeholder for future icon loading
                print("[PerformanceOptimizationService] Prefetching icon for: \(appName)")
            }
        }
    }
    
    // MARK: - Memory Management
    
    private func setupMemoryWarningObserver() {
        NotificationCenter.default.publisher(for: UIApplication.didReceiveMemoryWarningNotification)
            .sink { [weak self] _ in
                self?.handleMemoryWarning()
            }
            .store(in: &cancellables)
    }
    
    private func handleMemoryWarning() {
        print("[PerformanceOptimizationService] Memory warning received, clearing caches")
        clearAllCaches()
    }
    
    private func setupAppStateObservers() {
        NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
            .sink { [weak self] _ in
                self?.handleAppDidEnterBackground()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .sink { [weak self] _ in
                self?.handleAppWillEnterForeground()
            }
            .store(in: &cancellables)
    }
    
    private func handleAppDidEnterBackground() {
        // Clear non-essential caches when app goes to background
        clearAppIconCache()
        cleanupExpiredCacheEntries()
    }
    
    private func handleAppWillEnterForeground() {
        // Refresh essential caches when app comes to foreground
        refreshEssentialCaches()
    }
    
    // MARK: - Cache Cleanup
    
    private func cleanupOldestCacheEntries() {
        let sortedEntries = cacheTimestamps.sorted { $0.value < $1.value }
        let entriesToRemove = sortedEntries.prefix(shieldSettingsCache.count - maxCacheSize)
        
        for entry in entriesToRemove {
            shieldSettingsCache.removeValue(forKey: entry.key)
            cacheTimestamps.removeValue(forKey: entry.key)
        }
    }
    
    private func cleanupOldestAppIcons() {
        let sortedEntries = appIconCache.keys.prefix(appIconCache.count - maxCacheSize)
        for key in sortedEntries {
            appIconCache.removeValue(forKey: key)
        }
    }
    
    private func cleanupExpiredCacheEntries() {
        let now = Date()
        let expiredKeys = cacheTimestamps.filter { now.timeIntervalSince($0.value) > cacheExpiryInterval }
        
        for key in expiredKeys.keys {
            shieldSettingsCache.removeValue(forKey: key)
            childSummaryCache.removeValue(forKey: key)
            cacheTimestamps.removeValue(forKey: key)
        }
    }
    
    // MARK: - Public Cache Management
    
    func clearAllCaches() {
        shieldSettingsCache.removeAll()
        childSummaryCache.removeAll()
        appIconCache.removeAll()
        cacheTimestamps.removeAll()
    }
    
    func clearAppIconCache() {
        appIconCache.removeAll()
    }
    
    func clearShieldSettingsCache() {
        shieldSettingsCache.removeAll()
        childSummaryCache.removeAll()
        
        // Remove related timestamps
        let keysToRemove = cacheTimestamps.keys.filter { $0.hasPrefix("summary_") || !$0.hasPrefix("summary_") }
        for key in keysToRemove {
            cacheTimestamps.removeValue(forKey: key)
        }
    }
    
    func refreshEssentialCaches() {
        // This would refresh the most important caches
        // For now, we'll just clear expired entries
        cleanupExpiredCacheEntries()
    }
    
    // MARK: - Performance Monitoring
    
    func getCacheStatistics() -> CacheStatistics {
        let totalShieldSettings = shieldSettingsCache.values.reduce(0) { $0 + $1.count }
        let totalChildSummaries = childSummaryCache.count
        let totalAppIcons = appIconCache.count
        let totalTimestamps = cacheTimestamps.count
        
        return CacheStatistics(
            shieldSettingsCount: totalShieldSettings,
            childSummariesCount: totalChildSummaries,
            appIconsCount: totalAppIcons,
            timestampsCount: totalTimestamps,
            cacheSize: shieldSettingsCache.count + childSummaryCache.count + appIconCache.count
        )
    }
    
    struct CacheStatistics {
        let shieldSettingsCount: Int
        let childSummariesCount: Int
        let appIconsCount: Int
        let timestampsCount: Int
        let cacheSize: Int
    }
    
    // MARK: - Deinitialization
    
    deinit {
        cancellables.removeAll()
        // Directly clear caches since deinit cannot be async
        shieldSettingsCache.removeAll()
        childSummaryCache.removeAll()
        appIconCache.removeAll()
        cacheTimestamps.removeAll()
    }
}
