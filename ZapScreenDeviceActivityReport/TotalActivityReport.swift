//
//  TotalActivityReport.swift
//  ZapScreenDeviceActivityReport
//
//  Created by tongteknai on 1/7/25.
//

import DeviceActivity
import SwiftUI

func containsIPhone(_ name: String) -> Bool {
  return name.range(of: "iPhone", options: .caseInsensitive) != nil
}

extension DeviceActivityReport.Context {
    // If your app initializes a DeviceActivityReport with this context, then the system will use
    // your extension's corresponding DeviceActivityReportScene to render the contents of the
    // report.
    static let totalActivity = Self("Total Activity")
}

struct TotalActivityReport: DeviceActivityReportScene {
    // Define which context your scene will represent.
    let context: DeviceActivityReport.Context = .totalActivity
    
    // Define the custom configuration and the resulting view for this report.
    let content: (String) -> TotalActivityView
    
    func makeConfiguration(representing data: DeviceActivityResults<DeviceActivityData>) async -> String {
        // Reformat the data into a configuration that can be used to create
        // the report's view.
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.day, .hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        formatter.zeroFormattingBehavior = .dropAll
        
        let thisDevice = await UIDevice.current.model

//        guard let singleDeviceData = await data.first(where: { containsIPhone(String($0.device.name!)) }) else {
//         return "This device data is not available right now\n thisDevice:\(thisDevice) \n"
//       }
        
//        let totalActivityDuration = await singleDeviceData.activitySegments.reduce(0) { total, segment in
//          total + segment.totalActivityDuration
//        }

        var appNames = [String]()
//        appNames.append("\(thisDevice),Time: \(String(describing: formatter.string(from: totalActivityDuration) ?? "Total time not found"))")

        print("Start: SingleDeviceData")
        
        for await singleDeviceData in data {
            for await activitySegment in singleDeviceData.activitySegments {
                for await category in activitySegment.categories {
                    for await app in category.applications {
                        let deviceType = singleDeviceData.device.name ?? "nil"
                        let deviceUser = singleDeviceData.user.appleID ?? "nil"
                        let appName = app.application.localizedDisplayName ?? "nil"
                        let appTime = formatter.string(from: app.totalActivityDuration) ?? "No Time Found"
                        appNames.append("Type:\(deviceType), User: \(deviceUser), Name:\(appName),Time:\(appTime)")
//                        appNames.append("\(appName),Time:\(appTime)")
                        

                    }
                }
            }
        }
        
        print("End: SingleDeviceData, Apps:\(appNames.count)")


        let res = appNames.joined(separator: "\n")
        return res.isEmpty ? "No activity data" : res
        
//        let totalActivityDuration = await data.flatMap { $0.activitySegments }.reduce(0, {
//            $0 + $1.totalActivityDuration
//        })
//        return formatter.string(from: totalActivityDuration) ?? "No activity data"
    }
}
