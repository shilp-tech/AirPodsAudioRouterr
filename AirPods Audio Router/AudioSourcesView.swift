import SwiftUI

struct AudioSourcesView: View {
    @State private var sources: [AudioSourceInfo] = []
    @State private var errorMessage: String?
    @State private var refreshedAt: Date?

    private var activeSources: [AudioSourceInfo] {
        sources.filter { $0.isRunningOutput == true }
    }

    private var otherSources: [AudioSourceInfo] {
        sources.filter { $0.isRunningOutput != true }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("AirPodsAudioRouter").font(.largeTitle.bold())
            Text("Application Audio Sources").font(.title2)
            HStack {
                Button("Refresh", systemImage: "arrow.clockwise", action: refresh)
                if let refreshedAt {
                    Text("Updated \(refreshedAt.formatted(date: .omitted, time: .standard))")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            Text("Shows Core Audio clients, not all running apps. Active output I/O does not prove audible sound. Browser tabs and websites are not identified.")
                .font(.callout).foregroundStyle(.secondary)
            Text("Process-tap API: available. Tap creation and capture: not tested. No audio is recorded.")
                .font(.callout).foregroundStyle(.secondary)

            if let errorMessage {
                ContentUnavailableView {
                    Label("Unable to Read Audio Sources", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(errorMessage)
                }
            } else {
                List {
                    Section("Active Output I/O — \(activeSources.count)") {
                        if activeSources.isEmpty {
                            Text("No processes reported active output at this refresh. Start playback, then refresh.")
                                .foregroundStyle(.secondary)
                        }
                        ForEach(activeSources) { source in sourceRow(source) }
                    }
                    Section("Other Audio Clients — \(otherSources.count)") {
                        ForEach(otherSources) { source in sourceRow(source) }
                        if sources.isEmpty {
                            Text("Core Audio returned no audio clients.")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .padding(24)
        .frame(minWidth: 640, idealWidth: 760, minHeight: 540, idealHeight: 740)
        .onAppear(perform: refresh)
    }

    private func sourceRow(_ source: AudioSourceInfo) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(source.name).font(.headline)
            Text("PID: \(source.processID.map(String.init) ?? "Unavailable") · HAL process ID: \(source.id)")
            Text("Bundle ID: \(source.bundleID ?? "Unavailable")")
            Text(source.outputStatus)
            Text("Tap: process ID can be selected; creation/capture not tested")
            Text("Application stream format: not exposed by process discovery")
            Text("Associated output devices (device metadata, not app stream format):")
                .foregroundStyle(.secondary)
            if let outputs = source.outputDevices {
                if outputs.isEmpty { Text("None reported") }
                ForEach(outputs, id: \.self) { Text($0) }
            } else {
                Text("Unavailable")
            }
            ForEach(source.issues, id: \.self) { issue in
                Text(issue).foregroundStyle(.secondary)
            }
        }
        .font(.callout)
        .textSelection(.enabled)
        .padding(.vertical, 8)
    }

    private func refresh() {
        do {
            sources = try AudioSourceDiscovery.sources()
            errorMessage = nil
            refreshedAt = Date()
        } catch {
            sources = []
            refreshedAt = nil
            errorMessage = "\(error.localizedDescription) Try Refresh again."
        }
    }
}
