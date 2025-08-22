import SwiftUI

struct NotificationPreferencesView: View {
    @StateObject private var notificationService = ShieldNotificationService.shared
    @State private var showingQuietHoursPicker = false
    @State private var tempQuietHoursStart = Date()
    @State private var tempQuietHoursEnd = Date()
    
    var body: some View {
        List {
            Section("Notification Types") {
                ForEach(ShieldNotificationService.NotificationType.allCases, id: \.self) { type in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(type.title)
                                .font(.headline)
                            Text(type.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Toggle("", isOn: Binding(
                            get: { notificationService.notificationPreferences.enabledTypes.contains(type) },
                            set: { _ in notificationService.toggleNotificationType(type) }
                        ))
                    }
                    .padding(.vertical, 4)
                }
            }
            
            Section("General Settings") {
                HStack {
                    Image(systemName: "speaker.wave.2")
                        .foregroundColor(.blue)
                    Text("Sound")
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { notificationService.notificationPreferences.soundEnabled },
                        set: { _ in notificationService.toggleSound() }
                    ))
                }
                
                HStack {
                    Image(systemName: "number.circle")
                        .foregroundColor(.orange)
                    Text("Badge Count")
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { notificationService.notificationPreferences.badgeEnabled },
                        set: { _ in notificationService.toggleBadge() }
                    ))
                }
                
                HStack {
                    Image(systemName: "eye")
                        .foregroundColor(.green)
                    Text("Preview Content")
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { notificationService.notificationPreferences.previewEnabled },
                        set: { _ in notificationService.togglePreview() }
                    ))
                }
            }
            
            Section("Quiet Hours") {
                HStack {
                    Image(systemName: "moon")
                        .foregroundColor(.purple)
                    Text("Enable Quiet Hours")
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { notificationService.notificationPreferences.quietHoursEnabled },
                        set: { _ in notificationService.toggleQuietHours() }
                    ))
                }
                
                if notificationService.notificationPreferences.quietHoursEnabled {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Start Time")
                            Spacer()
                            Button(notificationService.notificationPreferences.quietHoursStart.formatted(date: .omitted, time: .shortened)) {
                                tempQuietHoursStart = notificationService.notificationPreferences.quietHoursStart
                                tempQuietHoursEnd = notificationService.notificationPreferences.quietHoursEnd
                                showingQuietHoursPicker = true
                            }
                            .foregroundColor(.blue)
                        }
                        
                        HStack {
                            Text("End Time")
                            Spacer()
                            Text(notificationService.notificationPreferences.quietHoursEnd.formatted(date: .omitted, time: .shortened))
                                .foregroundColor(.secondary)
                        }
                        
                        Text("Notifications will be silenced during these hours")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 8)
                }
            }
            
            Section("Actions") {
                Button("Clear All Notifications") {
                    notificationService.clearAllNotifications()
                }
                .foregroundColor(.red)
                
                Button("Clear Delivered Notifications") {
                    notificationService.clearDeliveredNotifications()
                }
                .foregroundColor(.orange)
            }
            
            Section("Information") {
                HStack {
                    Text("Permission Status")
                    Spacer()
                    Text(notificationService.isNotificationsEnabled ? "Granted" : "Not Granted")
                        .foregroundColor(notificationService.isNotificationsEnabled ? .green : .red)
                }
                
                if !notificationService.isNotificationsEnabled {
                    Text("Enable notifications in Settings to receive shield activity updates")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("Notification Preferences")
        .sheet(isPresented: $showingQuietHoursPicker) {
            QuietHoursPickerView(
                startTime: $tempQuietHoursStart,
                endTime: $tempQuietHoursEnd,
                onSave: {
                    notificationService.updateQuietHours(start: tempQuietHoursStart, end: tempQuietHoursEnd)
                    showingQuietHoursPicker = false
                },
                onCancel: {
                    showingQuietHoursPicker = false
                }
            )
        }
    }
}

struct QuietHoursPickerView: View {
    @Binding var startTime: Date
    @Binding var endTime: Date
    let onSave: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Start Time")
                        .font(.headline)
                    DatePicker("", selection: $startTime, displayedComponents: .hourAndMinute)
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("End Time")
                        .font(.headline)
                    DatePicker("", selection: $endTime, displayedComponents: .hourAndMinute)
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Set Quiet Hours")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onCancel()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        onSave()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

#if DEBUG
struct NotificationPreferencesView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            NotificationPreferencesView()
        }
    }
}
#endif
