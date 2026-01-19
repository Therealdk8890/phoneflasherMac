import SwiftUI
import AppKit

struct ContentView: View {
    @StateObject private var model = PhoneFlasherModel()
    @State private var showWipeAlert = false

    var body: some View {
        TabView {
            setupView
                .tabItem { Text("Setup") }
            flashView
                .tabItem { Text("Flash") }
            logsView
                .tabItem { Text("Logs") }
        }
        .frame(minWidth: 900, minHeight: 650)
    }

    private var setupView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                GroupBox(label: Text("Platform Tools")) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Download and extract ADB/Fastboot to the local tools folder.")
                            .font(.subheadline)
                        HStack {
                            Button("Download Platform Tools") {
                                model.downloadPlatformTools()
                            }
                            Button("Open Tools Folder") {
                                model.openToolsFolder()
                            }
                        }
                    }
                    .padding(8)
                }

                GroupBox(label: Text("Vendor Tools (Optional)")) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("macOS does not require USB drivers for ADB/Fastboot. Vendor tools are optional.")
                            .font(.subheadline)
                        Button("Download All Vendor Tools") {
                            model.downloadAllVendorTools()
                        }

                        ForEach(model.vendorTools) { tool in
                            HStack {
                                Text(tool.name)
                                    .frame(width: 280, alignment: .leading)
                                Button("Download") {
                                    model.downloadVendorTool(tool)
                                }
                                Button("Open Folder") {
                                    model.openVendorFolder(tool)
                                }
                                Button("Open Vendor Page") {
                                    model.openVendorPage(tool)
                                }
                            }
                        }
                    }
                    .padding(8)
                }
            }
            .padding(16)
        }
    }

    private var flashView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                GroupBox(label: Text("Device Status")) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Button("Refresh Devices") {
                                model.refreshDevices()
                            }
                            Button("Reboot to Bootloader") {
                                model.rebootBootloader()
                            }
                            Button("Reboot to System") {
                                model.rebootSystem()
                            }
                            Button("Fastboot Reboot") {
                                model.fastbootReboot()
                            }
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("ADB: \(model.adbStatus)")
                            Text("Fastboot: \(model.fastbootStatus)")
                        }
                        .font(.subheadline)
                    }
                    .padding(8)
                }

                GroupBox(label: Text("Flash Images")) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Select image files to flash with fastboot. Only selected slots will be flashed.")
                            .font(.subheadline)

                        imageRow(label: "Boot image", path: $model.bootImage)
                        imageRow(label: "Recovery image", path: $model.recoveryImage)
                        imageRow(label: "System image", path: $model.systemImage)
                        imageRow(label: "Vendor image", path: $model.vendorImage)

                        HStack {
                            Button("Flash Selected") {
                                model.flashSelected()
                            }
                            Button("Wipe Data") {
                                showWipeAlert = true
                            }
                        }

                        Text("Warning: Flashing can brick your device. Always use brand-specific firmware.")
                            .foregroundColor(.orange)
                            .font(.subheadline)
                    }
                    .padding(8)
                }
            }
            .padding(16)
        }
        .alert("Wipe Data", isPresented: $showWipeAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Wipe", role: .destructive) {
                model.fastbootWipe()
            }
        } message: {
            Text("This will wipe user data. Continue?")
        }
    }

    private var logsView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 4) {
                ForEach(Array(model.logLines.enumerated()), id: \.offset) { _, line in
                    Text(line)
                        .font(.system(.body, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(16)
        }
    }

    private func imageRow(label: String, path: Binding<String>) -> some View {
        HStack {
            Text(label)
                .frame(width: 120, alignment: .leading)
            TextField("", text: path)
                .textFieldStyle(.roundedBorder)
            Button("Browse") {
                pickFile { selected in
                    path.wrappedValue = selected
                }
            }
        }
    }

    private func pickFile(_ handler: @escaping (String) -> Void) {
        let panel = NSOpenPanel()
        panel.title = "Select image"
        panel.allowedFileTypes = ["img"]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        if panel.runModal() == .OK, let url = panel.url {
            handler(url.path)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
