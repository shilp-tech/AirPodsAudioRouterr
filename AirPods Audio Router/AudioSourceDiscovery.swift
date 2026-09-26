import AppKit
import CoreAudio

/// Read-only snapshots of HAL audio clients. Does not create taps or start I/O.
enum AudioSourceDiscovery {
    static func sources() throws -> [AudioSourceInfo] {
        try AudioHardwareSystem.shared.processes.map { process in
            var issues: [String] = []
            // A process may exit between enumeration and these property reads.
            func read<T>(_ label: String, _ query: () throws -> T) -> T? {
                do { return try query() }
                catch {
                    issues.append("\(label): \(error.localizedDescription)")
                    return nil
                }
            }

            let pid = read("PID") { try process.pid }
            let bundleID = nonempty(read("Bundle ID") { try process.bundleID } ?? nil)
            let active = read("Output activity") { try process.isRunningOutput }
            let runningApp = pid.flatMap { NSRunningApplication(processIdentifier: $0) }
            // Use only a direct PID match. Never infer a website or a helper's parent app.
            let name = nonempty(runningApp?.localizedName)
                ?? nonempty(try? process.name)
                ?? bundleID
                ?? pid.map { "Process \($0)" }
                ?? "Audio process \(process.id)"

            let outputs = read("Output devices") {
                try outputDeviceIDs(for: process).map { id in
                    let device = AudioHardwareDevice(id: id)
                    let name = (try? device.name) ?? "Unnamed device"
                    let rate = try? device.nominalSampleRate
                    let channels = try? device.outputStreamConfiguration.reduce(0) {
                        $0 + Int($1.mNumberChannels)
                    }
                    let rateText = rate.flatMap { value -> String? in
                        guard value.isFinite, value > 0 else { return nil }
                        return "\(value.formatted()) Hz nominal"
                    } ?? "rate unavailable"
                    let channelText = channels.map { "\($0) output channels" }
                        ?? "channels unavailable"
                    return "\(name) (ID \(id)): \(channelText), \(rateText)"
                }
            }

            return AudioSourceInfo(
                id: process.id, name: name, processID: pid, bundleID: bundleID,
                isRunningOutput: active, outputDevices: outputs, issues: issues
            )
        }.sorted {
            let comparison = $0.name.localizedStandardCompare($1.name)
            return comparison == .orderedSame ? $0.id < $1.id : comparison == .orderedAscending
        }
    }

    private static func nonempty(_ value: String?) -> String? {
        guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        return value
    }

    private static func outputDeviceIDs(for process: AudioHardwareProcess) throws -> [AudioObjectID] {
        // Explicit output scope avoids presenting input devices as playback destinations.
        let address = AudioObjectPropertyAddress(
            mSelector: kAudioProcessPropertyDevices,
            mScope: kAudioObjectPropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        let data = try process.propertyData(address: address)
        let stride = MemoryLayout<AudioObjectID>.stride
        guard data.count.isMultiple(of: stride) else {
            throw NSError(domain: "AudioSourceDiscovery", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Unexpected output-device list size."])
        }
        return data.withUnsafeBytes { bytes in
            Swift.stride(from: 0, to: data.count, by: stride).map {
                bytes.loadUnaligned(fromByteOffset: $0, as: AudioObjectID.self)
            }
        }
    }
}
