import SwiftUI

/// SwiftUI view to display all key-value pairs in the group UserDefaults (read-only).
struct GroupUserDefaultsView: View {
    let userDefaults: [String: Any]

    init() {
        self.userDefaults = UserDefaultsManager.shared.allGroupUserDefaults().filter { $0.key.hasPrefix("Zap") || $0.key.hasPrefix("zap") }
    }

    var body: some View {
        NavigationView {
            List {
                if userDefaults.isEmpty {
                    Text("No values found in group UserDefaults.")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(userDefaults.sorted(by: { $0.key < $1.key }), id: \ .key) { key, value in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(key)
                                .font(.headline)
                            Text(String(describing: value))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Group UserDefaults")
        }
    }
}

#if DEBUG
struct GroupUserDefaultsView_Previews: PreviewProvider {
    static var previews: some View {
        GroupUserDefaultsView()
    }
}
#endif
