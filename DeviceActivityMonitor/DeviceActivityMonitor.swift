//
//  DeviceActivityMonitor.swift
//  DeviceActivityMonitor
//
//  Created by tongteknai on 18/4/25.
//

import DeviceActivity
import SwiftUI

@main
struct DeviceActivityMonitor: DeviceActivityReportExtension {
    var body: some DeviceActivityReportScene {
        // Create a report for each DeviceActivityReport.Context that your app supports.
        TotalActivityReport { totalActivity in
            TotalActivityView(totalActivity: totalActivity)
        }
        // Add more reports here...
    }
}
