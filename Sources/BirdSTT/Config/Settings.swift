import Foundation

final class Settings: ObservableObject {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var doubaoAppId: String {
        get { defaults.string(forKey: "doubaoAppId") ?? "" }
        set { defaults.set(newValue, forKey: "doubaoAppId"); objectWillChange.send() }
    }

    var doubaoAccessToken: String {
        get { defaults.string(forKey: "doubaoAccessToken") ?? "" }
        set { defaults.set(newValue, forKey: "doubaoAccessToken"); objectWillChange.send() }
    }

    var doubaoResourceId: String {
        get { defaults.string(forKey: "doubaoResourceId") ?? "volc.bigasr.sauc.duration" }
        set { defaults.set(newValue, forKey: "doubaoResourceId"); objectWillChange.send() }
    }

    var windowDismissDelay: Double {
        get {
            let val = defaults.double(forKey: "windowDismissDelay")
            return val > 0 ? val : 1.5
        }
        set { defaults.set(newValue, forKey: "windowDismissDelay") }
    }

    var isConfigured: Bool {
        !doubaoAppId.isEmpty && !doubaoAccessToken.isEmpty
    }
}
