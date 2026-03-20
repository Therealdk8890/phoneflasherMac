import SwiftUI

struct SetupView: View {
    @ObservedObject var model: PhoneFlasherModel
    @ObservedObject var store: StoreKitManager

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Platform Tools Section
                platformToolsSection

                Divider()

                // Vendor Tools Section
                vendorToolsSection
            }
            .padding(24)
        }
    }

    // MARK: - Platform Tools

    private var platformToolsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Platform Tools", systemImage: "wrench.and.screwdriver")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Download and extract Google ADB & Fastboot to get started.")
                .font(.subheadline)
                .foregroundColor(.secondary)

            // Status indicator
            HStack(spacing: 12) {
                Image(systemName: model.platformToolsInstalled ? "checkmark.circle.fill" : "xmark.circle")
                    .foregroundColor(model.platformToolsInstalled ? .green : .secondary)
                    .font(.title3)

                VStack(alignment: .leading, spacing: 2) {
                    Text(model.platformToolsInstalled ? "Platform Tools Installed" : "Platform Tools Not Installed")
                        .font(.headline)
                    Text(model.platformToolsInstalled
                        ? "ADB and Fastboot are ready to use."
                        : "Download platform tools to get started.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(model.platformToolsInstalled
                        ? Color.green.opacity(0.08)
                        : Color.secondary.opacity(0.08))
            )

            // Download progress
            if case .downloading(let progress) = model.platformToolsState {
                VStack(alignment: .leading, spacing: 6) {
                    ProgressView(value: progress)
                        .progressViewStyle(.linear)
                    Text("Downloading... \(Int(progress * 100))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else if case .extracting = model.platformToolsState {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Extracting...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Action buttons
            HStack(spacing: 12) {
                Button {
                    model.downloadPlatformTools()
                } label: {
                    Label("Download Platform Tools", systemImage: "arrow.down.circle")
                }
                .buttonStyle(.borderedProminent)
                .disabled(model.platformToolsState.isActive)

                Button {
                    model.openToolsFolder()
                } label: {
                    Label("Open Tools Folder", systemImage: "folder")
                }
                .buttonStyle(.bordered)
            }
        }
    }

    // MARK: - Vendor Tools

    private var vendorToolsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("Vendor Tools", systemImage: "shippingbox")
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

            Text("macOS does not require USB drivers. Vendor tools are optional utilities.")
                .font(.subheadline)
                .foregroundColor(.secondary)

            if store.isProUnlocked {
                Button {
                    model.downloadAllVendorTools()
                } label: {
                    Label("Download All Vendor Tools", systemImage: "arrow.down.circle")
                }
                .buttonStyle(.bordered)

                ForEach(model.vendorTools) { tool in
                    vendorToolRow(tool)
                }
            } else {
                vendorToolsLockedView
            }
        }
    }

    private func vendorToolRow(_ tool: VendorTool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: tool.icon)
                .font(.title3)
                .foregroundColor(.accentColor)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(tool.displayName)
                    .font(.body)
                    .fontWeight(.medium)

                if let state = model.vendorToolStates[tool.id] {
                    vendorToolStateLabel(state)
                }
            }

            Spacer()

            if case .downloading(let progress) = model.vendorToolStates[tool.id] {
                ProgressView(value: progress)
                    .progressViewStyle(.linear)
                    .frame(width: 80)
            }

            Button("Download") {
                model.downloadVendorTool(tool)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(model.vendorToolStates[tool.id]?.isActive == true)

            Button {
                model.openVendorFolder(tool)
            } label: {
                Image(systemName: "folder")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Button {
                model.openVendorPage(tool)
            } label: {
                Image(systemName: "safari")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.secondary.opacity(0.04))
        )
    }

    @ViewBuilder
    private func vendorToolStateLabel(_ state: DownloadState) -> some View {
        switch state {
        case .completed:
            Text("Installed")
                .font(.caption)
                .foregroundColor(.green)
        case .failed(let msg):
            Text(msg)
                .font(.caption)
                .foregroundColor(.red)
        case .downloading:
            Text("Downloading...")
                .font(.caption)
                .foregroundColor(.blue)
        default:
            EmptyView()
        }
    }

    private var vendorToolsLockedView: some View {
        VStack(spacing: 16) {
            ForEach(model.vendorTools) { tool in
                HStack(spacing: 12) {
                    Image(systemName: tool.icon)
                        .font(.title3)
                        .foregroundColor(.secondary)
                        .frame(width: 28)

                    Text(tool.displayName)
                        .font(.body)
                        .foregroundColor(.secondary)

                    Spacer()

                    Button {
                        model.openVendorPage(tool)
                    } label: {
                        Image(systemName: "safari")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.secondary.opacity(0.04))
                )
            }

            Text("Upgrade to Pro to download vendor tools directly.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}
