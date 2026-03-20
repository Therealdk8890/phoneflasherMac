import SwiftUI

struct SettingsView: View {
    @ObservedObject var store: StoreKitManager
    @AppStorage("autoRefreshDevices") private var autoRefreshDevices = false
    @AppStorage("showFlashWarnings") private var showFlashWarnings = true
    @AppStorage("logLevel") private var logLevel = "all"

    var body: some View {
        TabView {
            generalSettings
                .tabItem {
                    Label("General", systemImage: "gear")
                }

            proSettings
                .tabItem {
                    Label("Pro", systemImage: "star")
                }

            aboutView
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .frame(width: 480, height: 360)
    }

    // MARK: - General

    private var generalSettings: some View {
        Form {
            Section {
                Toggle("Auto-refresh device status", isOn: $autoRefreshDevices)
                Toggle("Show flash warnings", isOn: $showFlashWarnings)
            } header: {
                Text("Device")
            }

            Section {
                Picker("Log level", selection: $logLevel) {
                    Text("All").tag("all")
                    Text("Warnings & Errors").tag("warnings")
                    Text("Errors Only").tag("errors")
                }
                .pickerStyle(.segmented)
            } header: {
                Text("Logging")
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    // MARK: - Pro

    private var proSettings: some View {
        VStack(spacing: 20) {
            if store.isProUnlocked {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.green)

                    Text("PhoneFlasher Pro Active")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text("Thank you for your purchase! All Pro features are unlocked.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "star.circle")
                        .font(.system(size: 48))
                        .foregroundColor(.orange)

                    Text("PhoneFlasher Free")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text("Upgrade to Pro to unlock flashing, vendor tools, and log export.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)

                    if let product = store.proProduct {
                        Button("Upgrade for \(product.displayPrice)") {
                            Task { _ = await store.purchase(product) }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                    }

                    Button("Restore Purchases") {
                        Task { await store.restorePurchases() }
                    }
                    .buttonStyle(.plain)
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    // MARK: - About

    private var aboutView: some View {
        VStack(spacing: 16) {
            Image(systemName: "bolt.shield.fill")
                .font(.system(size: 48))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Text("PhoneFlasher Mac")
                .font(.title2)
                .fontWeight(.bold)

            Text("Version 1.0.0")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Text("by Daniel Kissel")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Divider()
                .frame(width: 200)

            Text("ADB/Fastboot flasher for Samsung, Pixel, LG, and OnePlus devices.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)

            HStack(spacing: 20) {
                Link("Privacy Policy", destination: URL(string: "https://example.com/privacy")!)
                    .font(.caption)
                Link("Terms of Use", destination: URL(string: "https://example.com/terms")!)
                    .font(.caption)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}
