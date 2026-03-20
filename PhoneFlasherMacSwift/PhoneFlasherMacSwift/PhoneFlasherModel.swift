import Foundation
import AppKit
import Combine

// MARK: - Vendor Tool

enum VendorToolType: String, Codable {
    case dmg
    case url
}

struct VendorTool: Identifiable {
    let id: String
    let name: String
    let type: VendorToolType
    let urls: [String]
    let fallbackURL: String
    let icon: String

    var displayName: String {
        name.replacingOccurrences(of: " (optional)", with: "")
            .replacingOccurrences(of: " (no driver required)", with: "")
    }
}

// MARK: - Download State

enum DownloadState: Equatable {
    case idle
    case downloading(progress: Double)
    case extracting
    case completed
    case failed(String)

    var isActive: Bool {
        switch self {
        case .downloading, .extracting: return true
        default: return false
        }
    }
}

// MARK: - Log Entry

struct LogEntry: Identifiable {
    let id = UUID()
    let timestamp: Date
    let message: String
    let level: LogLevel

    enum LogLevel {
        case info
        case success
        case warning
        case error

        var icon: String {
            switch self {
            case .info: return "info.circle"
            case .success: return "checkmark.circle"
            case .warning: return "exclamationmark.triangle"
            case .error: return "xmark.circle"
            }
        }

        var colorName: String {
            switch self {
            case .info: return "secondary"
            case .success: return "green"
            case .warning: return "orange"
            case .error: return "red"
            }
        }
    }

    var formattedTimestamp: String {
        Self.formatter.string(from: timestamp)
    }

    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f
    }()
}

// MARK: - Phone Flasher Model

final class PhoneFlasherModel: ObservableObject {
    // MARK: Published State

    @Published var adbStatus = "Not checked"
    @Published var fastbootStatus = "Not checked"
    @Published var adbDeviceInfo = ""
    @Published var fastbootDeviceInfo = ""
    @Published var isDeviceConnected = false

    @Published var bootImage = ""
    @Published var recoveryImage = ""
    @Published var systemImage = ""
    @Published var vendorImage = ""

    @Published var logEntries: [LogEntry] = []
    @Published var logSearchText = ""

    @Published var platformToolsState: DownloadState = .idle
    @Published var vendorToolStates: [String: DownloadState] = [:]

    @Published var isFlashing = false
    @Published var flashProgress: Double = 0

    @Published var hasCompletedOnboarding: Bool {
        didSet {
            UserDefaults.standard.set(hasCompletedOnboarding, forKey: "hasCompletedOnboarding")
        }
    }

    var filteredLogEntries: [LogEntry] {
        if logSearchText.isEmpty {
            return logEntries
        }
        return logEntries.filter {
            $0.message.localizedCaseInsensitiveContains(logSearchText)
        }
    }

    let vendorTools: [VendorTool] = [
        VendorTool(
            id: "samsung",
            name: "Samsung Smart Switch (optional)",
            type: .dmg,
            urls: [
                "https://downloadcenter.samsung.com/content/SW/201702/20170201105409656/SmartSwitch4Mac.dmg"
            ],
            fallbackURL: "https://www.samsung.com/us/support/owners/app/smart-switch",
            icon: "iphone.gen2"
        ),
        VendorTool(
            id: "lg",
            name: "LG Bridge (optional)",
            type: .dmg,
            urls: [
                "https://lgbridge-file.lge.com/LGBridge_1.2.0.dmg"
            ],
            fallbackURL: "https://www.lg.com/us/support/help-library/lg-bridge-downloads-20150771211485",
            icon: "iphone"
        ),
        VendorTool(
            id: "oneplus",
            name: "OnePlus Support (optional)",
            type: .url,
            urls: [],
            fallbackURL: "https://www.oneplus.com/support/softwareupgrade",
            icon: "arrow.down.circle"
        ),
        VendorTool(
            id: "pixel",
            name: "Google Pixel (no driver required)",
            type: .url,
            urls: [],
            fallbackURL: "https://developers.google.com/android/images",
            icon: "sparkle"
        )
    ]

    // MARK: Private

    private let fileManager = FileManager.default
    private let platformToolsURL = "https://dl.google.com/android/repository/platform-tools-latest-darwin.zip"

    // MARK: Init

    init() {
        hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        ensureDirs()
    }

    // MARK: - Platform Tools

    var platformToolsInstalled: Bool {
        adbPathExists && fastbootPathExists
    }

    func downloadPlatformTools() {
        guard !platformToolsState.isActive else { return }
        runAsync {
            self.ensureDirs()
            self.updatePlatformToolsState(.downloading(progress: 0))
            self.log("Downloading platform-tools...", level: .info)

            let zipURL = self.platformToolsZipURL
            let success = self.downloadFileWithProgress(
                from: self.platformToolsURL,
                to: zipURL
            ) { progress in
                self.updatePlatformToolsState(.downloading(progress: progress))
            }

            guard success else {
                self.log("Failed to download platform-tools.", level: .error)
                self.updatePlatformToolsState(.failed("Download failed"))
                return
            }

            self.updatePlatformToolsState(.extracting)
            self.log("Extracting platform-tools...", level: .info)

            if self.unzip(zipURL, to: self.toolsDir) {
                self.ensureExecutable()
                self.log("Platform-tools installed successfully.", level: .success)
                self.updatePlatformToolsState(.completed)
            } else {
                self.log("Failed to extract platform-tools.", level: .error)
                self.updatePlatformToolsState(.failed("Extraction failed"))
            }
        }
    }

    // MARK: - Vendor Tools

    func downloadAllVendorTools() {
        runAsync {
            for tool in self.vendorTools {
                self._downloadVendorTool(tool)
            }
        }
    }

    func downloadVendorTool(_ tool: VendorTool) {
        runAsync {
            self._downloadVendorTool(tool)
        }
    }

    private func _downloadVendorTool(_ tool: VendorTool) {
        ensureDirs()
        guard !tool.urls.isEmpty else {
            log("No direct download for \(tool.displayName). Opening vendor page.", level: .info)
            openVendorPage(tool)
            return
        }

        updateVendorToolState(tool.id, state: .downloading(progress: 0))
        let destination = vendorFileURL(for: tool)

        var success = false
        for urlString in tool.urls {
            success = downloadFileWithProgress(from: urlString, to: destination) { progress in
                self.updateVendorToolState(tool.id, state: .downloading(progress: progress))
            }
            if success { break }
            log("Retrying next URL for \(tool.displayName)...", level: .warning)
        }

        if success {
            log("Saved \(tool.displayName) installer.", level: .success)
            updateVendorToolState(tool.id, state: .completed)
        } else {
            log("Failed to download \(tool.displayName). Opening vendor page.", level: .warning)
            updateVendorToolState(tool.id, state: .failed("Download failed"))
            openVendorPage(tool)
        }
    }

    // MARK: - Folder / Page Actions

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
            log("Invalid vendor URL for \(tool.displayName).", level: .error)
            return
        }
        DispatchQueue.main.async {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Device Management

    func refreshDevices() {
        runAsync {
            let adbOutput = self.adbPathExists ? self.runCommand([self.adbPath.path, "devices"]) : ""
            let fastbootOutput = self.fastbootPathExists ? self.runCommand([self.fastbootPath.path, "devices"]) : ""

            let adbConnected = adbOutput.contains("\tdevice")
            let fastbootConnected = !fastbootOutput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && fastbootOutput.contains("\t")

            let adbStatus = adbConnected ? "Connected" : "No device"
            let fastbootStatus = fastbootConnected ? "Connected" : "No device"

            let adbInfo = adbConnected ? self.parseDeviceInfo(adbOutput) : ""
            let fastbootInfo = fastbootConnected ? self.parseDeviceInfo(fastbootOutput) : ""

            DispatchQueue.main.async {
                self.adbStatus = adbStatus
                self.fastbootStatus = fastbootStatus
                self.adbDeviceInfo = adbInfo
                self.fastbootDeviceInfo = fastbootInfo
                self.isDeviceConnected = adbConnected || fastbootConnected
            }

            if !self.adbPathExists || !self.fastbootPathExists {
                self.log("Platform-tools not installed. Download them in Setup.", level: .warning)
            } else {
                self.log("Refreshed device status.", level: .info)
            }
        }
    }

    func rebootBootloader() {
        runAsync {
            self.log("Rebooting device to bootloader...", level: .info)
            self.adbCommand(["reboot", "bootloader"])
        }
    }

    func rebootSystem() {
        runAsync {
            self.log("Rebooting device to system...", level: .info)
            self.adbCommand(["reboot"])
        }
    }

    func fastbootReboot() {
        runAsync {
            self.log("Rebooting device via fastboot...", level: .info)
            self.fastbootCommand(["reboot"])
        }
    }

    func fastbootWipe() {
        runAsync {
            self.log("Wiping user data...", level: .warning)
            self.fastbootCommand(["-w"])
        }
    }

    // MARK: - Flashing

    func flashSelected() {
        let selections = [
            ("boot", bootImage),
            ("recovery", recoveryImage),
            ("system", systemImage),
            ("vendor", vendorImage)
        ].filter { !$0.1.trimmingCharacters(in: .whitespaces).isEmpty }

        guard !selections.isEmpty else {
            log("Select at least one image to flash.", level: .warning)
            return
        }

        runAsync {
            DispatchQueue.main.async {
                self.isFlashing = true
                self.flashProgress = 0
            }

            var failedPartitions: [String] = []

            for (index, (partition, path)) in selections.enumerated() {
                self.log("Flashing \(partition) from \(path)...", level: .info)
                let success = self.fastbootCommand(["flash", partition, path])

                if !success {
                    failedPartitions.append(partition)
                    self.log("Failed to flash \(partition). Stopping flash sequence.", level: .error)
                    break
                }

                DispatchQueue.main.async {
                    self.flashProgress = Double(index + 1) / Double(selections.count)
                }
            }

            if failedPartitions.isEmpty {
                self.log("Flash sequence complete.", level: .success)
            } else {
                self.log("Flash sequence failed. Failed partitions: \(failedPartitions.joined(separator: ", "))", level: .error)
            }

            DispatchQueue.main.async {
                self.isFlashing = false
                self.flashProgress = failedPartitions.isEmpty ? 1.0 : 0.0
            }
        }
    }

    var selectedImageCount: Int {
        [bootImage, recoveryImage, systemImage, vendorImage]
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            .count
    }

    // MARK: - Logging

    func log(_ message: String, level: LogEntry.LogLevel = .info) {
        let entry = LogEntry(timestamp: Date(), message: message, level: level)
        DispatchQueue.main.async {
            self.logEntries.append(entry)
        }
    }

    func clearLogs() {
        DispatchQueue.main.async {
            self.logEntries.removeAll()
        }
    }

    func exportLogs() -> String {
        logEntries.map { "[\($0.formattedTimestamp)] \($0.message)" }
            .joined(separator: "\n")
    }

    // MARK: - Private Paths

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

    // MARK: - Private Helpers

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
        for dir in [baseDir, toolsDir, vendorDir, downloadsDir] {
            ensureDirectory(dir)
        }
    }

    private func ensureDirectory(_ url: URL) {
        if !fileManager.fileExists(atPath: url.path) {
            try? fileManager.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
        }
    }

    private func parseDeviceInfo(_ output: String) -> String {
        let lines = output.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.contains("\t") && !trimmed.hasPrefix("List") {
                return trimmed.components(separatedBy: "\t").first ?? ""
            }
        }
        return ""
    }

    private func updatePlatformToolsState(_ state: DownloadState) {
        DispatchQueue.main.async {
            self.platformToolsState = state
        }
    }

    private func updateVendorToolState(_ id: String, state: DownloadState) {
        DispatchQueue.main.async {
            self.vendorToolStates[id] = state
        }
    }

    private func runAsync(_ work: @escaping () -> Void) {
        DispatchQueue.global(qos: .userInitiated).async(execute: work)
    }

    // MARK: - Download with Progress

    private func downloadFileWithProgress(
        from urlString: String,
        to destination: URL,
        onProgress: @escaping (Double) -> Void
    ) -> Bool {
        guard let url = URL(string: urlString) else {
            log("Invalid URL: \(urlString)", level: .error)
            return false
        }

        let semaphore = DispatchSemaphore(value: 0)
        var success = false
        var errorMessage: String?

        let delegate = DownloadDelegate(
            destination: destination,
            fileManager: fileManager,
            onProgress: onProgress,
            onComplete: { result in
                switch result {
                case .success:
                    success = true
                case .failure(let error):
                    errorMessage = error.localizedDescription
                }
                semaphore.signal()
            }
        )

        let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
        let task = session.downloadTask(with: url)
        task.resume()

        _ = semaphore.wait(timeout: .now() + 300)
        session.finishTasksAndInvalidate()

        if !success {
            log("Download failed: \(url.absoluteString)\(errorMessage.map { " (\($0))" } ?? "")", level: .error)
        }

        return success
    }

    // MARK: - Unzip

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
            log("Unzip failed: \(error.localizedDescription)", level: .error)
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

    // MARK: - Command Execution

    private func adbCommand(_ args: [String]) {
        guard adbPathExists else {
            log("ADB not found. Download platform-tools first.", level: .error)
            return
        }
        _ = runCommand([adbPath.path] + args)
    }

    @discardableResult
    private func fastbootCommand(_ args: [String]) -> Bool {
        guard fastbootPathExists else {
            log("Fastboot not found. Download platform-tools first.", level: .error)
            return false
        }
        return runCommandWithStatus([fastbootPath.path] + args)
    }

    private func runCommand(_ command: [String]) -> String {
        guard let executable = command.first else { return "" }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = Array(command.dropFirst())

        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = outputPipe

        log("Running: \(command.joined(separator: " "))", level: .info)

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            log("Command failed: \(error.localizedDescription)", level: .error)
            return ""
        }

        let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            log(trimmed, level: .info)
        }
        return trimmed
    }

    private func runCommandWithStatus(_ command: [String]) -> Bool {
        guard let executable = command.first else { return false }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = Array(command.dropFirst())

        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = outputPipe

        log("Running: \(command.joined(separator: " "))", level: .info)

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            log("Command failed: \(error.localizedDescription)", level: .error)
            return false
        }

        let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            log(trimmed, level: process.terminationStatus == 0 ? .info : .error)
        }
        return process.terminationStatus == 0
    }

    private func openFolder(_ url: URL) {
        DispatchQueue.main.async {
            NSWorkspace.shared.open(url)
        }
    }
}

// MARK: - Download Delegate

private final class DownloadDelegate: NSObject, URLSessionDownloadDelegate {
    private let destination: URL
    private let fileManager: FileManager
    private let onProgress: (Double) -> Void
    private let onComplete: (Result<Void, DownloadDelegateError>) -> Void

    init(
        destination: URL,
        fileManager: FileManager,
        onProgress: @escaping (Double) -> Void,
        onComplete: @escaping (Result<Void, DownloadDelegateError>) -> Void
    ) {
        self.destination = destination
        self.fileManager = fileManager
        self.onProgress = onProgress
        self.onComplete = onComplete
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        do {
            if fileManager.fileExists(atPath: destination.path) {
                try fileManager.removeItem(at: destination)
            }
            try fileManager.moveItem(at: location, to: destination)
            onComplete(.success(()))
        } catch {
            onComplete(.failure(DownloadDelegateError(message: error.localizedDescription)))
        }
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        guard totalBytesExpectedToWrite > 0 else { return }
        let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        onProgress(progress)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            onComplete(.failure(DownloadDelegateError(message: error.localizedDescription)))
        }
    }
}

struct DownloadDelegateError: Error, LocalizedError {
    let message: String
    var errorDescription: String? { message }
}
