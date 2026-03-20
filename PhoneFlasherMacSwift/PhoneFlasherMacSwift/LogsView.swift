import SwiftUI
import AppKit

struct LogsView: View {
    @ObservedObject var model: PhoneFlasherModel
    @ObservedObject var store: StoreKitManager

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            logToolbar

            Divider()

            // Log content
            if model.filteredLogEntries.isEmpty {
                emptyLogsView
            } else {
                logContent
            }
        }
    }

    // MARK: - Toolbar

    private var logToolbar: some View {
        HStack(spacing: 12) {
            Label("Logs", systemImage: "doc.text")
                .font(.title2)
                .fontWeight(.semibold)

            Spacer()

            // Search
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search logs...", text: $model.logSearchText)
                    .textFieldStyle(.plain)
                    .frame(width: 180)
                if !model.logSearchText.isEmpty {
                    Button {
                        model.logSearchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.secondary.opacity(0.08))
            )

            // Export
            Button {
                exportLogs()
            } label: {
                Label("Export", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(!store.isProUnlocked || model.logEntries.isEmpty)
            .help(store.isProUnlocked ? "Export logs to file" : "Pro feature")

            // Clear
            Button {
                model.clearLogs()
            } label: {
                Label("Clear", systemImage: "trash")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(model.logEntries.isEmpty)

            Text("\(model.logEntries.count) entries")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 80, alignment: .trailing)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
    }

    // MARK: - Log Content

    private var logContent: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(model.filteredLogEntries) { entry in
                        logRow(entry)
                            .id(entry.id)
                    }
                }
                .padding(16)
            }
            .onChange(of: model.logEntries.count) { _ in
                if let lastEntry = model.filteredLogEntries.last {
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo(lastEntry.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    private func logRow(_ entry: LogEntry) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(entry.formattedTimestamp)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 64, alignment: .leading)

            Image(systemName: entry.level.icon)
                .font(.caption)
                .foregroundColor(colorForLevel(entry.level))
                .frame(width: 16)

            Text(entry.message)
                .font(.system(.body, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        }
        .padding(.vertical, 3)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(entry.level == .error ? Color.red.opacity(0.06) :
                      entry.level == .warning ? Color.orange.opacity(0.06) :
                      Color.clear)
        )
    }

    private func colorForLevel(_ level: LogEntry.LogLevel) -> Color {
        switch level {
        case .info: return .secondary
        case .success: return .green
        case .warning: return .orange
        case .error: return .red
        }
    }

    // MARK: - Empty State

    private var emptyLogsView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "doc.text")
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.4))

            Text(model.logSearchText.isEmpty ? "No Logs Yet" : "No Matching Logs")
                .font(.title3)
                .foregroundColor(.secondary)

            Text(model.logSearchText.isEmpty
                ? "Logs will appear here as you use the app."
                : "Try adjusting your search term.")
                .font(.subheadline)
                .foregroundColor(.secondary.opacity(0.7))
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Export

    private func exportLogs() {
        let panel = NSSavePanel()
        panel.title = "Export Logs"
        panel.nameFieldStringValue = "PhoneFlasher_Logs_\(dateString()).txt"
        panel.allowedContentTypes = [.plainText]

        if panel.runModal() == .OK, let url = panel.url {
            let content = model.exportLogs()
            try? content.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    private func dateString() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd_HHmmss"
        return f.string(from: Date())
    }
}
