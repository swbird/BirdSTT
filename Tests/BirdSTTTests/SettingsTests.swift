import Testing
import Foundation
@testable import BirdSTT

@Suite("Settings Tests")
struct SettingsTests {
    @Test("default values are correct")
    func defaultValues() {
        let defaults = UserDefaults(suiteName: "test.settings")!
        defaults.removePersistentDomain(forName: "test.settings")
        let settings = Settings(defaults: defaults)

        #expect(settings.doubaoAppId == "")
        #expect(settings.doubaoAccessToken == "")
#expect(settings.windowDismissDelay == 1.5)
    }

    @Test("persists values to UserDefaults")
    func persistsValues() {
        let defaults = UserDefaults(suiteName: "test.settings.persist")!
        defaults.removePersistentDomain(forName: "test.settings.persist")
        let settings = Settings(defaults: defaults)

        settings.doubaoAppId = "test-app-id"
        settings.doubaoAccessToken = "test-token"

        let settings2 = Settings(defaults: defaults)
        #expect(settings2.doubaoAppId == "test-app-id")
        #expect(settings2.doubaoAccessToken == "test-token")
    }

    @Test("isConfigured checks both fields")
    func isConfigured() {
        let defaults = UserDefaults(suiteName: "test.settings.configured")!
        defaults.removePersistentDomain(forName: "test.settings.configured")
        let settings = Settings(defaults: defaults)

        #expect(!settings.isConfigured)

        settings.doubaoAppId = "app"
        #expect(!settings.isConfigured)

        settings.doubaoAccessToken = "token"
        #expect(settings.isConfigured)
    }
}
