//
//  ZapScreenDeviceActivityReport.swift
//  ZapScreenDeviceActivityReport
//
//  Created by tongteknai on 1/7/25.
//

import DeviceActivity
import SwiftUI

@main
struct ZapScreenDeviceActivityReport: DeviceActivityReportExtension {
    var body: some DeviceActivityReportScene {
        // Create a report for each DeviceActivityReport.Context that your app supports.
        TotalActivityReport { totalActivity in
            TotalActivityView(activityReport: totalActivity)
        }
        // Add more reports here...
    }
}
