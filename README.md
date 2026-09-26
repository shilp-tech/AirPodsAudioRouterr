# AirPods Audio Router

We are planning to build a native macOS application called "AirPods Audio Router."

Native macOS app project investigating per-application audio capture and routing to separate stereo channels.

Current status: architecture research and the initial SwiftUI app only. Audio capture and routing are not implemented.

## Open and run in Xcode

1. Open `AirPods Audio Router.xcodeproj` from this repository.
2. Select the **AirPods Audio Router** scheme and **My Mac** destination.
3. Choose **Product → Run** (Command-R).

The current project deployment target is macOS 26.2. The intended product baseline from the research is macOS 26.0; this difference should be resolved before implementation and compatibility testing.

The project uses automatic signing. For local development, use **Sign to Run Locally** if Xcode offers it. If signing requires a development team, select your own team in the app target's **Signing & Capabilities** tab. Apple signing accounts and the GitHub repository account are separate identities.

## Development environment

See [WORKFLOW.md](WORKFLOW.md) for the shared Codex/Xcode setup and the check, commit, and push workflow. Project instructions are recorded in [AGENTS.md](AGENTS.md).

- Apple Silicon Mac
- Xcode 26.3
- Swift compiler 6.2.4 (the starter project currently uses Swift 5 language mode)
- macOS 26.2 or later for the current project settings

No third-party dependencies or virtual audio drivers are needed to build the starter app. Audio capture permissions will be configured when the capture prototype is implemented.

## Research

See [ARCHITECTURE_RESEARCH.md](ARCHITECTURE_RESEARCH.md) for the API investigation, proposed architecture, permissions, and feasibility gates. FaceTime capture and stereo behavior during Bluetooth microphone use remain unverified.

## Repository hygiene

Keep Xcode user state, build products, credentials, and signing certificates out of version control. Commit shared project settings, source files, assets, and documentation.

GitHub repository: [shilp-tech/AirPodsAudioRouterr](https://github.com/shilp-tech/AirPodsAudioRouterr).
