//
//  MinimalDeviceListView.swift
//  ZapScreen
//
//  Created by tongteknai on 20/5/25.
//

import Foundation
import SwiftUI

struct MinimalDevice: Identifiable {
    let id: String
    let name: String
}

struct MinimalDeviceListView: View {
    @State private var devices: [MinimalDevice] = [
        MinimalDevice(id: "1", name: "iPhone 12"),
        MinimalDevice(id: "2", name: "iPad Pro"),
        MinimalDevice(id: "3", name: "MacBook Air")
    ]
    
    var body: some View {
        NavigationView {
            List {
                ForEach(devices) { device in
                    Text(device.name)
                }
                .onDelete(perform: deleteDevice)
            }
            .navigationTitle("Devices")
            .toolbar {
                EditButton() // Allows toggling delete mode
            }
        }
    }
    
    private func deleteDevice(at offsets: IndexSet) {
        devices.remove(atOffsets: offsets)
    }
}

struct MinimalDeviceListView_Previews: PreviewProvider {
    static var previews: some View {
        MinimalDeviceListView()
    }
}