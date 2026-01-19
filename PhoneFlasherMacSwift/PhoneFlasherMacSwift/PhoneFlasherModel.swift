import Foundation
import AppKit

enum VendorToolType {
    case dmg
    case url
}

struct VendorTool: Identifiable {
    let id: String
    let name: String
    let type: VendorToolType
    let urls: [String]
    let fallbackURL: String
}

final class PhoneFlasherModel: ObservableObject {
    @Published var adbStatus = "Not checked"
    @Published var fastbootStatus = "Not checked"
    @Published var bootImage = ""
    @Published var recoveryImage = ""
    @Published var systemImage = ""
    @Published var vendorImage = ""
    @Published var logLines: [String] = []

    let vendorTools: [VendorTool] = [
        VendorTool(
            id: "samsung",
            name: "Samsung Smart Switch (optional)",
            type: .dmg,
            urls: [
                "https://downloadcenter.samsung.com/content/SW/201702/20170201105409656/SmartSwitch4Mac.dmg"
            ],
            fallbackURL: "https://www.samsung.com/us/support/owners/app/smart-switch"
        ),
        VendorTool(
            id: "lg",
            name: "LG Bridge (optional)",
            type: .dmg,
            urls: [
                "https://lgbridge-file.lge.com/LGBridge_1.2.0.dmg"
            ],
            fallbackURL: "https://www.lg.com/us/support/help-library/lg-bridge-downloads-20150771211485"
        ),
        VendorTool(
            id: "oneplus",
            name: "OnePlus Support (optional)",
            type: .url,
            urls: [],
            fallbackURL: "https://www.oneplus.com/support/softwareupgrade"
        ),
        VendorTool(
            id: "pixel",
            name: "Google Pixel (no driver required)",
            type: .url,
            urls: [],
            fallbackURL: "https://developers.google.com/android/images"
        )
    ]

    private let fileManager = FileManager.default
    private let platformToolsURL = "https://dl.google.com/android/repository/platform-tools-latest-darwin.zip"

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()

    init() {
        ensureDirs()
    }

    func downloadPlatformTools() {
        runAsync {
            self.ensureDirs()
            self.log("Downloading platform-tools...")
            let zipURL = self.platformToolsZipURL
            let success = self.downloadFirstAvailable([self.platformToolsURL], to: zipURL)
            guard success else {
                self.log("Failed to download platform-tools.")
                return
            }
            self.log("Extracting platform-tools...")
            if self.unzip(zipURL, to: self.toolsDir) {
                self.ensureExecutable()
                self.log("Platform-tools extracted.")
            } else {
                self.log("Failed to extract platform-tools.")
            }
        }
    }

    func downloadAllVendorTools() {
        runAsync {
            for tool in self.vendorTools {
                self.downloadVendorTool(tool)
            }
        }
    }

    func downloadVendorTool(_ tool: VendorTool) {
        runAsync {
            self.ensureDirs()
            guard !tool.urls.isEmpty else {
                self.log("No direct download for \(tool.name). Opening vendor page.")
                self.openVendorPage(tool)
                return
            }

            let destination = self.vendorFileURL(for: tool)
            let success = self.downloadFirstAvailable(tool.urls, to: destination)
            if success {
                self.log("Saved \(tool.name) installer.")
            } else {
                self.log("Failed to download \(tool.name). Opening vendor page.")
                self.openVendorPage(tool)
            }
        }
    }

    func openToolsFolder() {
        openFolder(toolsDir)
    }

    func openVendorFolder(_ tool: VendorTool) {
        let folder = vendorFolderURL(for: tool)
        ensureDirectory(folder)
        openFolder(folder)
    }

    func openVendorPage(_ tool: VendorTool) {
        guard let url = URL(string: tool.fallbackURL) else {
            log("Invalid vendor URL for \(tool.name).")
            return
        }
        DispatchQueue.main.async {
            NSWorkspace.shared.open(url)
        }
    }

    func refreshDevices() {
        runAsync {
            let adbOutput = self.adbPathExists ? self.runCommand([self.adbPath.path, "devices"]) : ""
            let fastbootOutput = self.fastbootPathExists ? self.runCommand([self.fastbootPath.path, "devices"]) : ""

            let adbStatus = adbOutput.contains("\tdevice") ? "Device connected" : "No device"
            let fastbootStatus = fastbootOutput.isEmpty ? "No device" : "Device connected"

            self.updateStatus(adbStatus: adbStatus, fastbootStatus: fastbootStatus)

            if !self.adbPathExists || !self.fastbootPathExists {
                self.log("Platform-tools not installed. Download them in Setup.")
            } else {
                self.log("Refreshed device status.")
            }
        }
    }

    func rebootBootloader() {
        runAsync { self.adbCommand(["reboot", "bootloader"]) }
    }

    func rebootSystem() {
        runAsync { self.adbCommand(["reboot"]) }
    }

    func fastbootReboot() {
        runAsync { self.fastbootCommand(["reboot"]) }
    }

    func fastbootWipe() {
        runAsync { self.fastbootCommand(["-w"]) }
    }

    func flashSelected() {
        let selections = [
            ("boot", bootImage),
            ("recovery", recoveryImage),
            ("system", systemImage),
            ("vendor", vendorImage)
        ].filter { !$0.1.trimmingCharacters(in: .whitespaces).isEmpty }

        guard !selections.isEmpty else {
            log("Select at least one image to flash.")
            return
        }

        runAsync {
            for (partition, path) in selections {
                self.log("Flashing \(partition) from \(path)...")
                self.fastbootCommand(["flash", partition, path])
            }
            self.log("Flash sequence complete.")
        }
    }

    private var baseDir: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return appSupport.appendingPathComponent("PhoneFlasherMac", isDirectory: true)
    }

    private var toolsDir: URL {
        baseDir.appendingPathComponent("tools", isDirectory: true)
    }

    private var vendorDir: URL {
        baseDir.appendingPathComponent("vendor", isDirectory: true)
    }

    private var downloadsDir: URL {
        baseDir.appendingPathComponent("downloads", isDirectory: true)
    }

    private var platformToolsZipURL: URL {
        downloadsDir.appendingPathComponent("platform-tools-latest-darwin.zip")
    }

    private var adbPath: URL {
        toolsDir.appendingPathComponent("platform-tools/adb")
    }

    private var fastbootPath: URL {
        toolsDir.appendingPathComponent("platform-tools/fastboot")
    }

    private var adbPathExists: Bool {
        fileManager.fileExists(atPath: adbPath.path)
    }

    private var fastbootPathExists: Bool {
        fileManager.fileExists(atPath: fastbootPath.path)
    }

    private func vendorFolderURL(for tool: VendorTool) -> URL {
        vendorDir.appendingPathComponent(tool.id, isDirectory: true)
    }

    private func vendorFileURL(for tool: VendorTool) -> URL {
        let folder = vendorFolderURL(for: tool)
        ensureDirectory(folder)
        let ext = tool.type == .dmg ? "dmg" : "pkg"
        return folder.appendingPathComponent("\(tool.id).\(ext)")
    }

    private func ensureDirs() {
        ensureDirectory(baseDir)
        ensureDirectory(toolsDir)
        ensureDirectory(vendorDir)
        ensureDirectory(downloadsDir)
    }

    private func ensureDirectory(_ url: URL) {
        if !fileManager.fileExists(atPath: url.path) {
            try? fileManager.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
        }
    }

    private func log(_ message: String) {
        let timestamp = Self.timeFormatter.string(from: Date())
        DispatchQueue.main.async {
            self.logLines.append("[\(timestamp)] \(message)")
        }
    }

    private func updateStatus(adbStatus: String, fastbootStatus: String) {
        DispatchQueue.main.async {
            self.adbStatus = adbStatus
            self.fastbootStatus = fastbootStatus
        }
    }

    private func runAsync(_ work: @escaping () -> Void) {
        DispatchQueue.global(qos: .userInitiated).async(execute: work)
    }

    private func downloadFirstAvailable(_ urls: [String], to destination: URL) -> Bool {
        for urlString in urls {
            guard let url = URL(string: urlString) else {
                log("Invalid URL: \(urlString)")
                continue
            }
            if downloadFile(from: url, to: destination) {
                return true
            }
        }
        return false
    }

    private func downloadFile(from url: URL, to destination: URL) -> Bool {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        let session = URLSession(configuration: configuration)

        let semaphore = DispatchSemaphore(value: 0)
        var success = false
        var errorMessage: String?

        let task = session.downloadTask(with: url) { tempURL, _, error in
            defer { semaphore.signal() }
            if let error = error {
                errorMessage = error.localizedDescription
                return
            }
            guard let tempURL = tempURL else {
                errorMessage = "Download returned empty data"
                return
            }

            do {
                if self.fileManager.fileExists(atPath: destination.path) {
                    try self.fileManager.removeItem(at: destination)
                }
                try self.fileManager.moveItem(at: tempURL, to: destination)
                success = true
            } catch {
                errorMessage = error.localizedDescription
            }
        }

        task.resume()
        _ = semaphore.wait(timeout: .now() + 300)

        if !success {
            log("Download failed: \(url.absoluteString)\(errorMessage.map { " (\($0))" } ?? "")")
        }

        return success
    }

    private func unzip(_ zipURL: URL, to destination: URL) -> Bool {
        ensureDirectory(destination)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-o", zipURL.path, "-d", destination.path]

        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            log("Unzip failed: \(error.localizedDescription)")
            return false
        }
    }

    private func ensureExecutable() {
        for tool in [adbPath, fastbootPath] {
            guard fileManager.fileExists(atPath: tool.path) else { continue }
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/chmod")
            process.arguments = ["+x", tool.path]
            try? process.run()
            process.waitUntilExit()
        }
    }

    private func adbCommand(_ args: [String]) {
        guard adbPathExists else {
            log("ADB not found. Download platform-tools first.")
            return
        }
        _ = runCommand([adbPath.path] + args)
    }

    private func fastbootCommand(_ args: [String]) {
        guard fastbootPathExists else {
            log("Fastboot not found. Download platform-tools first.")
            return
        }
        _ = runCommand([fastbootPath.path] + args)
    }

    private func runCommand(_ command: [String]) -> String {
        guard let executable = command.first else { return "" }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = Array(command.dropFirst())

        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = outputPipe

        log("Running: \(command.joined(separator: " "))")

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            log("Command failed: \(error.localizedDescription)")
            return ""
        }

        let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            log(trimmed)
        }
        return trimmed
    }

    private func openFolder(_ url: URL) {
        DispatchQueue.main.async {
            NSWorkspace.shared.open(url)
        }
    }
}
