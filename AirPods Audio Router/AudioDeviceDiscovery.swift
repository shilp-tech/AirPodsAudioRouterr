import CoreAudio

/// Uses Apple's native HAL Swift interface (available since macOS 15).
/// Only reads device properties; it never opens audio I/O or changes routing.
enum AudioDeviceDiscovery {
    static func devices() throws -> [AudioDeviceInfo] {
        let system = AudioHardwareSystem.shared
        let devices = try system.devices
        let defaultInputID = try system.defaultInputDevice?.id
        let defaultOutputID = try system.defaultOutputDevice?.id

        return devices.map { device in
            // Sum every stream's channels, not the number of streams/buffers.
            // A device can disconnect during refresh, so retain a partial row.
            let inputChannels = try? device.inputStreamConfiguration.reduce(0) {
                $0 + Int($1.mNumberChannels)
            }
            let outputChannels = try? device.outputStreamConfiguration.reduce(0) {
                $0 + Int($1.mNumberChannels)
            }

            return AudioDeviceInfo(
                id: device.id,
                name: (try? device.name) ?? "Device \(device.id) (name unavailable)",
                inputChannels: inputChannels,
                outputChannels: outputChannels,
                sampleRate: try? device.nominalSampleRate,
                isDefaultInput: device.id == defaultInputID,
                isDefaultOutput: device.id == defaultOutputID,
                transport: transportName(try? device.transportType)
            )
        }.sorted {
            let comparison = $0.name.localizedStandardCompare($1.name)
            return comparison == .orderedSame ? $0.id < $1.id : comparison == .orderedAscending
        }
    }

    private static func transportName(_ type: UInt32?) -> String {
        guard let type else { return "Unavailable" }
        switch type {
        case kAudioDeviceTransportTypeBuiltIn: return "Built-in"
        case kAudioDeviceTransportTypeBluetooth: return "Bluetooth"
        case kAudioDeviceTransportTypeBluetoothLE: return "Bluetooth LE"
        case kAudioDeviceTransportTypeVirtual: return "Virtual"
        case kAudioDeviceTransportTypeAggregate: return "Aggregate"
        case kAudioDeviceTransportTypeAutoAggregate: return "Auto Aggregate"
        case kAudioDeviceTransportTypeUSB: return "USB"
        case kAudioDeviceTransportTypePCI: return "PCI"
        case kAudioDeviceTransportTypeFireWire: return "FireWire"
        case kAudioDeviceTransportTypeHDMI: return "HDMI"
        case kAudioDeviceTransportTypeDisplayPort: return "DisplayPort"
        case kAudioDeviceTransportTypeAirPlay: return "AirPlay"
        case kAudioDeviceTransportTypeAVB: return "AVB"
        case kAudioDeviceTransportTypeThunderbolt: return "Thunderbolt"
        case kAudioDeviceTransportTypeContinuityCaptureWired: return "Continuity Capture (wired)"
        case kAudioDeviceTransportTypeContinuityCaptureWireless: return "Continuity Capture (wireless)"
        case kAudioDeviceTransportTypeUnknown: return "Unknown"
        default: return "Other (\(type))"
        }
    }
}
