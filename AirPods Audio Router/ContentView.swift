//
//  ContentView.swift
//  AirPods Audio Router
//
//  Created by Shilp Patel on 9/25/26.
//

import SwiftUI

struct ContentView: View {
    @State private var devices: [AudioDeviceInfo] = []
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("AirPodsAudioRouter")
                .font(.largeTitle.bold())
            Text("Audio Devices")
                .font(.title2)

            if let errorMessage {
                ContentUnavailableView {
                    Label("Unable to Read Audio Devices", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(errorMessage)
                }
            } else if devices.isEmpty {
                ContentUnavailableView("No Audio Devices", systemImage: "speaker.slash",
                                       description: Text("Connect an audio device and click Refresh."))
            } else {
                List(devices) { device in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(device.name)
                            .font(.headline)
                            .textSelection(.enabled)
                        Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 4) {
                            GridRow {
                                Text("Direction")
                                Text(device.direction)
                            }
                            GridRow {
                                Text("Input channels")
                                Text(device.inputChannels.map { String($0) } ?? "Unavailable")
                            }
                            GridRow {
                                Text("Output channels")
                                Text(device.outputChannels.map { String($0) } ?? "Unavailable")
                            }
                            GridRow {
                                Text("Sample rate (nominal)")
                                Text(device.sampleRateDescription)
                            }
                            GridRow {
                                Text("Default input")
                                Text(device.isDefaultInput ? "Yes" : "No")
                            }
                            GridRow {
                                Text("Default output")
                                Text(device.isDefaultOutput ? "Yes" : "No")
                            }
                            GridRow {
                                Text("Transport")
                                Text(device.transport)
                            }
                        }
                        .font(.callout)
                    }
                    .padding(.vertical, 8)
                }
            }

            Button("Refresh", systemImage: "arrow.clockwise", action: refresh)
                .keyboardShortcut("r", modifiers: .command)
        }
        .padding(24)
        .frame(minWidth: 560, idealWidth: 640, minHeight: 480, idealHeight: 700)
        .onAppear(perform: refresh)
    }

    private func refresh() {
        do {
            devices = try AudioDeviceDiscovery.devices()
            errorMessage = nil
        } catch {
            devices = []
            errorMessage = "\(error.localizedDescription) Try Refresh to read the devices again."
        }
    }
}

#Preview {
    ContentView()
}
