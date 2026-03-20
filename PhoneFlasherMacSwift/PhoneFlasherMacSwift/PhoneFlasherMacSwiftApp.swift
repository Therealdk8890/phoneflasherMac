import SwiftUI

@main
struct PhoneFlasherMacSwiftApp: App {
    @StateObject private var store = StoreKitManager()
    @State private var showPaywall = false

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 1060, height: 720)
        .commands {
            // App menu
            CommandGroup(replacing: .appInfo) {
                Button("About PhoneFlasher Mac") {
                    NSApplication.shared.orderFrontStandardAboutPanel(
                        options: [
                            .applicationName: "PhoneFlasher Mac",
                            .applicationVersion: "1.0.0",
                            .version: "1",
                            .credits: NSAttributedString(
                                string: "ADB/Fastboot flasher for Android devices\nby Daniel Kissel",
                                attributes: [
                                    .font: NSFont.systemFont(ofSize: 11),
                                    .foregroundColor: NSColor.secondaryLabelColor
                                ]
                            )
                        ]
                    )
                }
            }

            // Help menu
            CommandGroup(replacing: .help) {
                Link("PhoneFlasher Support",
                     destination: URL(string: "https://example.com/support")!)
                Link("Android Flash Guide",
                     destination: URL(string: "https://developers.google.com/android/images")!)
                Divider()
                Link("Privacy Policy",
                     destination: URL(string: "https://example.com/privacy")!)
            }
        }

        Settings {
            SettingsView(store: store)
        }
    }
}
