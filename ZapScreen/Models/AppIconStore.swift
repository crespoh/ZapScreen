//
//  AppIconStore.swift
//  ZapScreen
//
//  Created by tongteknai on 18/5/25.
//

import Foundation
import UIKit

struct AppIconData: Decodable, Identifiable {
//    let _id: OIDWrapper
    let id = UUID()
    let app_name: String
    let region: String
    let logo_image: BinaryWrapper?
    let bundle_id: String?
    let track_name: String?
    
    struct BinaryWrapper: Decodable {
        let binary: BinaryData
        enum CodingKeys: String, CodingKey {
            case binary = "$binary"
        }
    }

    struct BinaryData: Decodable {
        let base64: String
        let subType: String
    }

var image: UIImage? {
    guard let logo_image = logo_image,
          let data = Data(base64Encoded: logo_image.binary.base64) else { return nil }
    return UIImage(data: data)
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
        
        if let url = Bundle.main.url(forResource: "app_store_data", withExtension: "json") {
            print("✅ Found JSON at URL: \(url)")
            do {
                let data = try Data(contentsOf: url)
                let decoded = try JSONDecoder().decode([AppIconData].self, from: data)
                self.apps = decoded
                print("✅ Successfully decoded apps: \(self.apps.count)")
            } catch {
                print("❌ JSON decoding or loading error: \(error)")
            }
        } else {
            print("❌ Could not find app_store_data.json in bundle")
        }
    }

    func image(for bundleId: String) -> UIImage? {
        apps.first(where: { $0.bundle_id == bundleId })?.image
    }

    func appName(for bundleId: String) -> String? {
        apps.first(where: { $0.bundle_id == bundleId })?.app_name
    }
}
