import AppKit
import SwiftUI

final class SettingsWindowController {
    private var window: NSWindow?

    func show(settings: Settings, onSave: @escaping () -> Void) {
        if window?.isVisible == true {
            window?.makeKeyAndOrderFront(nil)
            return
        }

        let settingsView = SettingsView(settings: settings, onSave: {
            onSave()
        })

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 260),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )

        window.title = "BirdSTT Settings"
        window.center()
        window.contentView = NSHostingView(rootView: settingsView)
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)

        NSApp.activate(ignoringOtherApps: true)

        self.window = window
    }

    func close() {
        window?.close()
        window = nil
    }
}

private struct SettingsView: View {
    @ObservedObject var settings: Settings
    let onSave: () -> Void

    @State private var appId: String = ""
    @State private var accessToken: String = ""
    @State private var resourceId: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Doubao API Configuration")
                .font(.headline)

            VStack(alignment: .leading, spacing: 6) {
                Text("App ID")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                TextField("Enter your Doubao App ID", text: $appId)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Access Token")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                SecureField("Enter your Doubao Access Token", text: $accessToken)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Resource ID")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                TextField("volc.bigasr.sauc.duration", text: $resourceId)
                    .textFieldStyle(.roundedBorder)
                Text("1.0: volc.bigasr.sauc.duration  |  2.0: volc.seedasr.sauc.duration")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            HStack {
                Spacer()
                Button("Save") {
                    settings.doubaoAppId = appId
                    settings.doubaoAccessToken = accessToken
                    if !resourceId.isEmpty {
                        settings.doubaoResourceId = resourceId
                    }
                    onSave()
                }
                .buttonStyle(.borderedProminent)
                .disabled(appId.isEmpty || accessToken.isEmpty)
            }
        }
        .padding(24)
        .frame(width: 400)
        .onAppear {
            appId = settings.doubaoAppId
            accessToken = settings.doubaoAccessToken
            resourceId = settings.doubaoResourceId
        }
    }
}
