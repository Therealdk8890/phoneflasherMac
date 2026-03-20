import SwiftUI
import AppKit

struct FlashView: View {
    @ObservedObject var model: PhoneFlasherModel
    @ObservedObject var store: StoreKitManager
    @State private var showWipeAlert = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                deviceStatusSection
                Divider()
                flashImagesSection
            }
            .padding(24)
        }
        .alert("Wipe Data", isPresented: $showWipeAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Wipe", role: .destructive) {
                model.fastbootWipe()
            }
        } message: {
            Text("This will erase all user data on the device. This action cannot be undone.")
        }
    }

    // MARK: - Device Status

    private var deviceStatusSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Device Status", systemImage: "iphone.gen3")
                .font(.title2)
                .fontWeight(.semibold)

            // Status cards
            HStack(spacing: 16) {
                statusCard(
                    title: "ADB",
                    status: model.adbStatus,
                    detail: model.adbDeviceInfo,
                    isConnected: model.adbStatus == "Connected",
                    icon: "terminal"
                )
                statusCard(
                    title: "Fastboot",
                    status: model.fastbootStatus,
                    detail: model.fastbootDeviceInfo,
                    isConnected: model.fastbootStatus == "Connected",
                    icon: "bolt"
                )
            }

            // Action buttons
            HStack(spacing: 12) {
                Button {
                    model.refreshDevices()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.borderedProminent)

                Button {
                    model.rebootBootloader()
                } label: {
                    Label("Bootloader", systemImage: "arrow.counterclockwise")
                }
                .buttonStyle(.bordered)

                Button {
                    model.rebootSystem()
                } label: {
                    Label("System", systemImage: "arrow.clockwise.circle")
                }
                .buttonStyle(.bordered)

                Button {
                    model.fastbootReboot()
                } label: {
                    Label("Fastboot Reboot", systemImage: "bolt.circle")
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private func statusCard(title: String, status: String, detail: String, isConnected: Bool, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(isConnected ? .green : .secondary)
                Text(title)
                    .font(.headline)
                Spacer()
                Circle()
                    .fill(isConnected ? Color.green : Color.secondary.opacity(0.3))
                    .frame(width: 10, height: 10)
            }

            Text(status)
                .font(.subheadline)
                .foregroundColor(isConnected ? .primary : .secondary)

            if !detail.isEmpty {
                Text(detail)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isConnected ? Color.green.opacity(0.06) : Color.secondary.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isConnected ? Color.green.opacity(0.2) : Color.secondary.opacity(0.1), lineWidth: 1)
        )
    }

    // MARK: - Flash Images

    private var flashImagesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("Flash Images", systemImage: "bolt.fill")
                    .font(.title2)
                    .fontWeight(.semibold)

                Spacer()

                if !store.isProUnlocked {
                    Label("Pro", systemImage: "lock.fill")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(Color.orange.opacity(0.15))
                        )
                        .foregroundColor(.orange)
                }
            }

            if store.isProUnlocked {
                Text("Select image files to flash. Only selected slots will be flashed.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                imageRow(label: "Boot", icon: "cpu", path: $model.bootImage)
                imageRow(label: "Recovery", icon: "arrow.uturn.backward.circle", path: $model.recoveryImage)
                imageRow(label: "System", icon: "internaldrive", path: $model.systemImage)
                imageRow(label: "Vendor", icon: "shippingbox", path: $model.vendorImage)

                if model.isFlashing {
                    VStack(alignment: .leading, spacing: 6) {
                        ProgressView(value: model.flashProgress)
                            .progressViewStyle(.linear)
                        Text("Flashing... \(Int(model.flashProgress * 100))%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }

                // Action buttons
                HStack(spacing: 12) {
                    Button {
                        model.flashSelected()
                    } label: {
                        Label(
                            model.selectedImageCount > 0
                                ? "Flash \(model.selectedImageCount) Image\(model.selectedImageCount == 1 ? "" : "s")"
                                : "Flash Selected",
                            systemImage: "bolt.fill"
                        )
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(model.selectedImageCount == 0 || model.isFlashing)

                    Button(role: .destructive) {
                        showWipeAlert = true
                    } label: {
                        Label("Wipe Data", systemImage: "trash")
                    }
                    .buttonStyle(.bordered)
                }

                // Warning
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("Flashing can brick your device. Always use firmware specific to your model.")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.orange.opacity(0.08))
                )
            } else {
                flashLockedView
            }
        }
    }

    private func imageRow(label: String, icon: String, path: Binding<String>) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.accentColor)
                .frame(width: 24)

            Text(label)
                .font(.body)
                .fontWeight(.medium)
                .frame(width: 80, alignment: .leading)

            TextField("No image selected", text: path)
                .textFieldStyle(.roundedBorder)

            Button {
                pickFile { selected in
                    path.wrappedValue = selected
                }
            } label: {
                Label("Browse", systemImage: "folder")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            if !path.wrappedValue.isEmpty {
                Button {
                    path.wrappedValue = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.secondary.opacity(0.04))
        )
    }

    private var flashLockedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.shield")
                .font(.system(size: 40))
                .foregroundColor(.secondary)

            Text("Upgrade to Pro to Flash Images")
                .font(.headline)

            Text("Flashing firmware requires PhoneFlasher Pro. Upgrade to unlock full flashing capabilities.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.secondary.opacity(0.04))
        )
    }

    private func pickFile(_ handler: @escaping (String) -> Void) {
        let panel = NSOpenPanel()
        panel.title = "Select firmware image"
        panel.allowedContentTypes = [.data]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        if panel.runModal() == .OK, let url = panel.url {
            handler(url.path)
        }
    }
}
