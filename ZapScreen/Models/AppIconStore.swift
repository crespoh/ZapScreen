//
//  AppIconStore.swift
//  ZapScreen
//
//  Created by tongteknai on 18/5/25.
//

import Foundation
import UIKit

struct AppIconData: Decodable, Identifiable {
    let id = UUID()
    let app_name: String
    let region: String?
    let logo_image: BinaryWrapper?
    let bundle_id: String?
    let track_name: String?

    struct BinaryWrapper: Decodable {
        let binary: BinaryData

        struct BinaryData: Decodable {
            let base64: String
            let subType: String?

            init(from decoder: Decoder) throws {
                // Try keyed container first (for {"base64":..., "subType":...})
                if let keyed = try? decoder.container(keyedBy: CodingKeys.self) {
                    self.base64 = try keyed.decode(String.self, forKey: .base64)
                    self.subType = try? keyed.decodeIfPresent(String.self, forKey: .subType)
                } else {
                    // Fallback to single value (for just a base64 string)
                    let single = try decoder.singleValueContainer()
                    self.base64 = try single.decode(String.self)
                    self.subType = nil
                }
            }
            enum CodingKeys: String, CodingKey {
                case base64
                case subType
            }
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.binary = try container.decode(BinaryData.self, forKey: .binary)
        }
        enum CodingKeys: String, CodingKey {
            case binary = "$binary"
        }
    }

    var image: UIImage? {
        guard let logo_image = logo_image,
              let data = Data(base64Encoded: logo_image.binary.base64) else { return nil }
        return UIImage(data: data)
    }

    enum CodingKeys: String, CodingKey {
        case app_name
        case region
        case logo_image
        case bundle_id
        case track_name
    }

}

class AppIconStore: ObservableObject {
    @Published var apps: [AppIconData] = []

    init() {
        loadAppIconData()
    }


    private func loadAppIconData() {
        // 🔍 DEBUG: Print all JSON files in the bundle
        let resources = Bundle.main.paths(forResourcesOfType: "json", inDirectory: nil)
        print("📦 Found JSON files in bundle: \(resources)")
        var loadedApps: [AppIconData] = []
        // Load main app_store_data.json
        if let url = Bundle.main.url(forResource: "app_store_data", withExtension: "json") {
            print("✅ Found app_store_data.json at URL: \(url)")
            do {
                let data = try Data(contentsOf: url)
                let decoded = try JSONDecoder().decode([AppIconData].self, from: data)
                loadedApps.append(contentsOf: decoded)
                print("✅ Successfully decoded apps: \(decoded.count)")
            } catch {
                print("❌ JSON decoding or loading error: \(error)")
            }
        } else {
            print("❌ Could not find app_store_data.json in bundle")
        }
        // Load apple_apps.json (same struct)
        if let url = Bundle.main.url(forResource: "apple_apps", withExtension: "json") {
            print("✅ Found apple_apps.json at URL: \(url)")
            do {
                let data = try Data(contentsOf: url)
                let decoded = try JSONDecoder().decode([AppIconData].self, from: data)
                loadedApps.append(contentsOf: decoded)
                print("✅ Successfully decoded apple_apps: \(decoded.count)")
            } catch {
                print("❌ JSON decoding or loading error for apple_apps.json: \(error)")
            }
        } else {
            print("⚠️ Could not find apple_apps.json in bundle")
        }
        self.apps = loadedApps
    }

    func image(for bundleId: String) -> UIImage? {
        apps.first(where: { $0.bundle_id == bundleId })?.image
    }

    func appName(for bundleId: String) -> String? {
        apps.first(where: { $0.bundle_id == bundleId })?.app_name
    }
}
