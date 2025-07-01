//
//  TotalActivityView.swift
//  ZapScreenDeviceActivityReport
//
//  Created by tongteknai on 1/7/25.
//

import SwiftUI

struct TotalActivityView: View {
//    let totalActivity: String
    var activityReport: String
    
    var body: some View {
//        Text(totalActivity)
        var apps: [(type: String, user: String, name: String, time: String, timeInSeconds: TimeInterval)] {
              activityReport.split(separator: "\n").compactMap { line in
                let parts = line.split(separator: ",")
                guard parts.count == 4 else { return nil }
                let type = String(parts[0])
                let user = String(parts[1])
                let name = String(parts[2])
                let time = parts[3].replacingOccurrences(of: "Time:", with: "")
                let timeInSeconds = timeStringToSeconds(time)
                  return (type: type, user: user, name: name, time: time, timeInSeconds: timeInSeconds)
              }
            }
        
//        var apps: [(name: String, time: String, timeInSeconds: TimeInterval)] {
//              activityReport.split(separator: "\n").compactMap { line in
//                let parts = line.split(separator: ",")
//                guard parts.count == 2 else { return nil }
//                let name = String(parts[0])
//                let time = parts[1].replacingOccurrences(of: "Time:", with: "")
//                let timeInSeconds = timeStringToSeconds(time)
//                  return (name: name, time: time, timeInSeconds: timeInSeconds)
//              }
//            }

            var totalAppsTime: TimeInterval {
              timeStringToSeconds(apps.first?.time ?? "0")
            }

            List(apps, id: \.name) { app in
              HStack(alignment: .center) {
                VStack(alignment: .leading) {
                    Text(app.type).font(.headline)
                    Text(app.user).font(.headline)
                    Text(app.name).font(.headline)
                    Text(app.time).font(.subheadline).foregroundColor(.gray)
                    ProgressView(value: app.timeInSeconds / totalAppsTime)
                        .accentColor(.blue)
                        .scaleEffect(x: 1, y: 2, anchor: .center)
                }
                .padding(.vertical, 8)
              }
            }
    }
    
    func timeStringToSeconds(_ timeString: String) -> TimeInterval {
        var totalSeconds: TimeInterval = 0
        let components = timeString.split(separator: " ")
        for component in components {
          if component.hasSuffix("h"), let hours = Double(component.dropLast()) {
            totalSeconds += hours * 3600
          } else if component.hasSuffix("m"), let minutes = Double(component.dropLast()) {
            totalSeconds += minutes * 60
          } else if component.hasSuffix("s"), let seconds = Double(component.dropLast()) {
            totalSeconds += seconds
          }
        }
        return totalSeconds
      }
}

// In order to support previews for your extension's custom views, make sure its source files are
// members of your app's Xcode target as well as members of your extension's target. You can use
// Xcode's File Inspector to modify a file's Target Membership.
#Preview {
    TotalActivityView(activityReport: "1h 23m")
}
