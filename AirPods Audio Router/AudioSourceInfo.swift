import Foundation

/// HAL process identity and metadata, not a captured application audio stream.
struct AudioSourceInfo: Identifiable {
    let id: UInt32
    let name: String
    let processID: Int32?
    let bundleID: String?
    let isRunningOutput: Bool?
    let outputDevices: [String]?
    let issues: [String]

    var outputStatus: String {
        switch isRunningOutput {
        case true: return "Active output I/O (audibility not measured)"
        case false: return "No active output I/O"
        case nil: return "Unavailable"
        }
    }
}
