import SwiftUI
import AppKit

// MARK: - Navigation Item

enum NavigationItem: String, CaseIterable, Identifiable {
    case setup = "Setup"
    case flash = "Flash"
    case logs = "Logs"
    case upgrade = "Upgrade"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .setup: return "wrench.and.screwdriver"
        case .flash: return "bolt.fill"
        case .logs: return "doc.text"
        case .upgrade: return "star.fill"
        }
    }
}

// MARK: - Content View

struct ContentView: View {
    @StateObject private var model = PhoneFlasherModel()
    @EnvironmentObject var store: StoreKitManager
    @State private var selection: NavigationItem? = .setup
    @State private var showPaywall = false
    @AppStorage("autoRefreshDevices") private var autoRefreshDevices = false
    @State private var refreshTimer: Timer?

    var body: some View {
        if !model.hasCompletedOnboarding {
            OnboardingView(hasCompletedOnboarding: $model.hasCompletedOnboarding)
        } else {
            NavigationSplitView {
                sidebarContent
            } detail: {
                detailContent
            }
            .frame(minWidth: 960, minHeight: 680)
            .sheet(isPresented: $showPaywall) {
                PaywallView(store: store)
            }
            .toolbar {
                toolbarContent
            }
            .onAppear { startAutoRefreshIfNeeded() }
            .onChange(of: autoRefreshDevices) { _ in startAutoRefreshIfNeeded() }
        }
    }

    private func startAutoRefreshIfNeeded() {
        refreshTimer?.invalidate()
        refreshTimer = nil
        guard autoRefreshDevices else { return }
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { _ in
            model.refreshDevices()
        }
    }

    // MARK: - Sidebar

    private var sidebarContent: some View {
        List(selection: $selection) {
            Section("Tools") {
                NavigationLink(value: NavigationItem.setup) {
                    Label(NavigationItem.setup.rawValue, systemImage: NavigationItem.setup.icon)
                }

                NavigationLink(value: NavigationItem.flash) {
                    Label {
                        HStack {
                            Text(NavigationItem.flash.rawValue)
                            Spacer()
                            if !store.isProUnlocked {
                                Image(systemName: "lock.fill")
                                    .font(.caption2)
                                    .foregroundColor(.orange)
                            }
                        }
                    } icon: {
                        Image(systemName: NavigationItem.flash.icon)
                    }
                }
            }

            Section("Info") {
                NavigationLink(value: NavigationItem.logs) {
                    Label {
                        HStack {
                            Text(NavigationItem.logs.rawValue)
                            Spacer()
                            if model.logEntries.count > 0 {
                                Text("\(model.logEntries.count)")
                                    .font(.caption2)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(
                                        Capsule()
                                            .fill(Color.secondary.opacity(0.15))
                                    )
                                    .foregroundColor(.secondary)
                            }
                        }
                    } icon: {
                        Image(systemName: NavigationItem.logs.icon)
                    }
                }
            }

            if !store.isProUnlocked {
                Section {
                    Button {
                        showPaywall = true
                    } label: {
                        Label {
                            Text("Upgrade to Pro")
                                .foregroundColor(.primary)
                        } icon: {
                            Image(systemName: "star.fill")
                                .foregroundColor(.orange)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }

            // Device status in sidebar footer
            Section("Device") {
                HStack(spacing: 8) {
                    Circle()
                        .fill(model.isDeviceConnected ? Color.green : Color.secondary.opacity(0.3))
                        .frame(width: 8, height: 8)
                    Text(model.isDeviceConnected ? "Connected" : "No device")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .listStyle(.sidebar)
        .frame(minWidth: 200)
    }

    // MARK: - Detail

    @ViewBuilder
    private var detailContent: some View {
        switch selection {
        case .setup:
            SetupView(model: model, store: store)
        case .flash:
            FlashView(model: model, store: store)
        case .logs:
            LogsView(model: model, store: store)
        case .upgrade:
            PaywallView(store: store)
        case .none:
            SetupView(model: model, store: store)
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .automatic) {
            Button {
                model.refreshDevices()
            } label: {
                Label("Refresh Devices", systemImage: "arrow.clockwise")
            }
            .help("Refresh device status")
        }

        ToolbarItem(placement: .automatic) {
            HStack(spacing: 6) {
                Circle()
                    .fill(model.isDeviceConnected ? Color.green : Color.secondary.opacity(0.3))
                    .frame(width: 8, height: 8)
                Text(model.isDeviceConnected ? "Device Connected" : "No Device")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(StoreKitManager())
    }
}
