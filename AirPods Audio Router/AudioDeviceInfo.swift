import Foundation

/// A read-only snapshot. A nil property means Core Audio could not read it.
struct AudioDeviceInfo: Identifiable {
    let id: UInt32
    let name: String
    let inputChannels: Int?
    let outputChannels: Int?
    let sampleRate: Double?
    let isDefaultInput: Bool
    let isDefaultOutput: Bool
    let transport: String

    var direction: String {
        guard let inputChannels, let outputChannels else { return "Unavailable" }
        switch (inputChannels > 0, outputChannels > 0) {
        case (true, true): return "Input & Output"
        case (true, false): return "Input"
        case (false, true): return "Output"
        case (false, false): return "No input/output channels"
        }
    }

    var sampleRateDescription: String {
        guard let sampleRate, sampleRate.isFinite, sampleRate > 0 else {
            return "Unavailable"
        }
        return "\(sampleRate.formatted(.number.precision(.fractionLength(0...2)))) Hz"
    }
}
