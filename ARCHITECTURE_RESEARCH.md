# AirPods Audio Router — Architecture Research

Research date: September 25, 2026. Target: native macOS 26.0+, Apple Silicon, Swift 6.2.4.

## 1. Findings

**A driver-free prototype is technically justified using Core Audio process taps, a private aggregate device, and an explicit stereo mixing stage. The complete YouTube → Left / FaceTime → Right experience is not yet verified.** FaceTime capture, browser process attribution, and AirPods behavior during microphone use are feasibility gates, not established product capabilities.

Apple documents process taps as a way to capture one process or a group of processes, expose that capture through an aggregate device, and optionally suppress the original hardware playback. The creation API is available from macOS 14.2, so it is available on the requested macOS 26.0 baseline. [Apple: Capturing system audio with Core Audio taps](https://developer.apple.com/documentation/coreaudio/capturing-system-audio-with-core-audio-taps).

### Evidence and environment boundaries

This investigation inspected Apple documentation and the installed Apple SDK. It did **not** run audio capture, change audio settings, request recording permissions, or implement application code.

| Item | Requested environment | Locally observed evidence |
| --- | --- | --- |
| macOS | 26.0 | `sw_vers` reports 26.6.2, build 25G83 |
| Xcode | 26.3 | `xcodebuild -version` reports 26.3, build 17C529 |
| SDK | macOS 26 APIs | Selected SDK is MacOSX26.2.sdk |
| Swift | 6.2.4 | Compiler reports 6.2.4, arm64 target |
| Deployment target | 26.0 intended | Existing Xcode project currently specifies 26.2 |
| AirPods | Bluetooth, 2 output channels, 48,000 Hz | User-provided observation; not independently measured here |
| App Sandbox | Unspecified | Existing Xcode target has App Sandbox enabled |

Availability annotations in the 26.2 SDK establish which inspected APIs are declared available on 26.0; they do not substitute for runtime testing on 26.0. Apple’s live documentation can contain later or beta APIs. Recommendations below use inspected 26.x SDK declarations and do not depend on macOS 27 features. The existing project was left unchanged.

Evidence labels used below:

- **Documented:** Apple documentation or installed SDK declarations explicitly establish the capability.
- **Architecture inference:** a proposed composition of documented building blocks; not an end-to-end Apple guarantee.
- **Unverified:** application-specific or hardware-specific behavior requiring a prototype.

### Direct answers to A–G

| Question | Finding |
| --- | --- |
| **A. Capture an individual application?** | **Yes at the process/process-group level**, subject to authorization and capture eligibility. It is not a promise that every named app or every kind of content is capturable. YouTube in a browser, Spotify, and FaceTime each need compatibility tests. |
| **B. Capture multiple applications simultaneously?** | **Supported by the API model:** create independent taps and include them in an aggregate device. Use one tap per independently controlled source. A single mixdown tap containing both apps loses their separation. Actual two-source operation remains to be tested. |
| **C. Route each source to a separate AirPod?** | **Yes as stereo PCM channel routing, conditional on successful capture and genuine stereo output.** Downmix source A to mono and write it only to left; downmix source B and write it only to right. This does not address the earbuds as separate devices. |
| **D. Permissions?** | System audio recording consent plus `NSAudioCaptureUsageDescription` for process taps. Hardened Runtime and sandbox entitlements are separate concerns; see section 6. A microphone permission is only needed if this app actually captures a microphone. |
| **E. BlackHole or another driver required?** | **No for the proposed process-tap architecture.** A Core Audio aggregate device is used, but no third-party driver installation is required. |
| **F. Limitations?** | Protected content has no universal capture guarantee; FaceTime is unverified; browser tabs are not stable audio identities; Bluetooth microphone use can change audio behavior; runtime formats, latency, and permissions can change. |
| **G. Simplest realistic MVP?** | Two selected process groups → two private taps → one private aggregate containing the taps and AirPods output → explicit downmix/channel matrix → stereo playback. Start with known unprotected sources and a separate microphone for calls. |

The capture and aggregate mechanisms in this table are documented; their combination into the proposed router is an architecture inference. Detailed API evidence follows.

## 2. API/framework options

### Core Audio HAL and process discovery

The installed `AudioHardware.h` provides:

| API/property | Purpose and boundary |
| --- | --- |
| `kAudioHardwarePropertyProcessObjectList` | Enumerates audio client processes connected to the audio system, not every GUI application. |
| `kAudioHardwarePropertyTranslatePIDToProcessObject` | Translates a PID to a Core Audio process `AudioObjectID`; it may return `kAudioObjectUnknown`. A PID is not itself a tap process ID. |
| `kAudioProcessPropertyPID`, `kAudioProcessPropertyBundleID` | Identifies an audio process. Use AppKit application metadata for user-facing names/icons where attribution is available. |
| `kAudioProcessPropertyIsRunningOutput` | Indicates active output I/O/streams. It does **not** prove that nonzero samples are currently audible. |
| `kAudioProcessPropertyDevices` | Reports devices associated with a process; this is not a documented general-purpose command to redirect another app. |
| `AudioObjectAddPropertyListenerBlock` | Supports reacting to property changes instead of treating the initial list and formats as permanent. |

The Swift overlay also exposes `AudioHardwareSystem`, `AudioHardwareProcess`, `AudioHardwareTap`, and `AudioHardwareAggregateDevice`, declared available from macOS 15.0. `AudioHardwareSystem.shared.processes` and process `isRunningOutput` can simplify discovery; the lower-level C APIs remain useful for configuration and I/O. [Apple: process enumeration](https://developer.apple.com/documentation/coreaudio/audiohardwaresystem/processes); local evidence: SDK references H1 and H3 below.

For an accurate UI, distinguish **running**, **active audio I/O**, and **measured signal activity**. Peak/RMS measurement of captured buffers can establish signal activity for selected sources after permission; it cannot reliably establish why a silent buffer is silent.

### Core Audio Process Taps / CATap

The relevant entry points are `CATapDescription`, `AudioHardwareCreateProcessTap`, `AudioHardwareDestroyProcessTap`, and `kAudioTapPropertyFormat`. A description can select a process group, request mono/stereo mixdown, or restrict capture to a device stream. Query the actual format instead of assuming that every tap is stereo Float32 at 48 kHz. [Apple: CATapDescription](https://developer.apple.com/documentation/coreaudio/catapdescription); SDK H1–H2.

**macOS 26-specific additions:** `CATapDescription.bundleIDs` selects by bundle ID; `isProcessRestoreEnabled` preserves selected processes by bundle ID across exit/relaunch. Both are explicitly annotated `macos(26.0)` in the installed header. They help with lifecycle handling, but the header does not guarantee that selecting a parent app automatically captures every helper or gives browser-tab identities. Test each application’s process grouping. SDK H2.

Use `isPrivate = true` for app-owned taps. Do not confuse `isExclusive` with exclusive device access: here it means the listed processes are **excluded**, and other processes are captured. For a narrow allowlist, use inclusion semantics. SDK H2.

`muteBehavior` is crucial:

| Value | Behavior |
| --- | --- |
| `.unmuted` | Original playback and tap capture both continue. Replaying this creates a duplicate path. |
| `.muted` | Captures while suppressing the original playback. |
| `.mutedWhenTapped` | Suppresses original playback while another audio client reads the tap. |

Prefer `.mutedWhenTapped` for the prototype, with explicit teardown. It ties muting to reading, not to successful downstream playback: an active reader with a broken output can still silence the source. [Apple: CATapMuteBehavior](https://developer.apple.com/documentation/coreaudio/catapmutebehavior).

### Aggregate devices and Multi-Output devices

`AudioHardwareCreateAggregateDevice` creates an OS-managed logical device. `kAudioAggregateDeviceTapListKey` accepts multiple tap descriptions by UID; `kAudioSubTapUIDKey` identifies each tap. `kAudioAggregateDeviceIsPrivateKey` limits visibility to the creating process and makes the aggregate nonpersistent across its launches. `kAudioAggregateDeviceMainSubDeviceKey` selects the timing source; `kAudioSubTapDriftCompensationKey` enables subtap drift compensation. SDK H1.

An aggregate can combine tap inputs with a physical output device. It does not perform the application-specific left/right mix by itself: the client must read inputs and render outputs. Inspect actual input/output streams, buffer layouts, and channel assignments.

Do not blindly enable `kAudioAggregateDeviceTapAutoStartKey`: the SDK documents that this can make aggregate start wait until a tap first receives audio. A paused source must not make the future UI appear stuck. SDK H1.

A **Multi-Output Device** plays the same material through multiple physical devices. It does not isolate processes or split two applications between ears. It is unnecessary for one stereo AirPods output. [Apple: Multi-Output devices](https://support.apple.com/guide/audio-midi-setup/play-audio-through-multiple-devices-at-once-ams7c093f372/mac).

### AudioToolbox / Audio Units

AudioToolbox provides Audio Unit hosting, PCM conversion, and mixing facilities. HAL Output Audio Units support choosing a device using `kAudioOutputUnitProperty_CurrentDevice`; `kAudioOutputUnitProperty_ChannelMap` maps channels. A matrix mixer or a small explicit PCM matrix can combine channels and apply gains. Channel mapping alone does not sum stereo into mono. SDK H4; [Apple technical note TN2091](https://developer.apple.com/library/archive/technotes/tn2091/_index.html) is useful background for AUHAL, but is archived documentation, not macOS 26 compatibility testing.

These APIs process/render audio available to this app. They do not independently obtain another process’s audio. For the initial aggregate-based experiment, a HAL `AudioDeviceIOProc` can avoid introducing a separate audio engine and playback clock.

### AVFAudio / AVAudioEngine

`AVAudioEngine`, `AVAudioSourceNode`, `AVAudioMixerNode`, and `AVAudioConverter` are useful for feeding captured PCM into an audio graph, mixing, and converting formats. `AVAudioStereoMixing.pan` supports stereo positioning. An explicit two-channel matrix is easier to verify for strict isolation than relying on unspecified behavior for panning an already-stereo source. [Apple: AVAudioEngine](https://developer.apple.com/documentation/avfaudio/avaudioengine); SDK H5.

An `AVAudioNode.installTap` observes **that node’s output**. It is not a Core Audio process tap and cannot attach directly to Spotify or FaceTime. An engine’s normal microphone input also does not represent all system playback. A process tap or another capture backend must first provide that audio. SDK H5.

### ScreenCaptureKit

ScreenCaptureKit provides application filtering through `SCContentFilter`/`SCRunningApplication`, audio delivery through `SCStreamOutputType.audio`, and configuration through `capturesAudio`, `sampleRate`, `channelCount`, and `excludesCurrentProcessAudio`. Audio capture is available from macOS 13.0; microphone capture is a separate option from 15.0. SDK H6; [Apple: capturesAudio](https://developer.apple.com/documentation/screencapturekit/scstreamconfiguration/capturesaudio).

Apple explicitly describes audio filtering as **application-level**, even when video is filtered to a single window. Selecting a YouTube window therefore does not guarantee YouTube-only audio. Separate filtered streams are the architectural alternative for separate sources; one stream containing several apps yields mixed audio. [Apple WWDC22: Take ScreenCaptureKit to the next level](https://developer.apple.com/videos/play/wwdc2022/10155/).

ScreenCaptureKit is a reasonable capture comparison/fallback, but the inspected interface has no equivalent of CATap’s source-muting behavior. Capturing and replaying alone would leave original playback audible. It therefore does not simplify this router’s central problem. Audio-only consumption also does not imply that authorization is unnecessary.

### Virtual audio devices and drivers

The proposed aggregate is a software audio device managed by Core Audio; that is distinct from shipping a custom HAL driver. Apple documents a driver route separately in [Creating an Audio Server Driver Plug-in](https://developer.apple.com/documentation/coreaudio/creating-an-audio-server-driver-plug-in).

A virtual loopback device such as BlackHole could be evaluated later if applications explicitly need to select a virtual output or consume the router as a microphone. Merely placing several applications onto one shared loopback mix does not preserve their separate identities. A driver also does not establish that protected or otherwise inaccessible sources become capturable. Driver-based designs add installation, distribution, and device-lifecycle work and are not the recommended MVP.

## 3. What is technically possible

1. **Discover audio clients and output activity:** enumerate HAL processes, resolve identities, observe lifecycle changes, and meter authorized captured sources. Documented API capability; friendly app grouping requires validation.
2. **Capture one or more eligible process groups:** maintain one tap for each independently routed source. Multiple taps are represented in the documented aggregate tap list. SDK H1–H2.
3. **Suppress the selected sources’ original hardware output:** use tap muting to prevent the normal stereo mix from bypassing the router. This is essential for actual per-ear separation.
4. **Construct the stereo output ourselves:** with stereo sources A and B, a conservative matrix is:

   `left = gainA × 0.5 × (A.left + A.right)`

   `right = gainB × 0.5 × (B.left + B.right)`

   A mono source is used directly. This is a proposed DSP rule, not Apple sample code. Averaging avoids doubling coherent full-scale stereo samples, but antiphase material can cancel. Multichannel sources require a defined layout-aware downmix or an explicit unsupported status.
5. **Play that result on one two-channel output:** the two streams share the AirPods device and its playback timing. Correct ear mapping must be confirmed with left-only/right-only tests.

The last two points follow from ordinary PCM mixing and output-device/channel APIs. They are conditional on capture succeeding and the output remaining stereo. Stereo content assigned to a single ear necessarily loses its original stereo image.

## 4. What is not possible, or not established

- **No general public “set another app’s output to left ear” setter was found in the inspected APIs.** The recommended implementation captures, suppresses, processes, and replays. HAL’s system default output is system-wide; an app’s own output-unit selection controls its own playback.
- **Cannot recover two independent apps after they have been mixed into one stereo capture** using ordinary channel routing. Separate at capture time.
- **Cannot guarantee one browser tab is one selectable audio source.** YouTube is a website, and browser processes/helpers may aggregate audio from multiple tabs. A dedicated browser used only for YouTube is a practical initial test setup, not a tab-capture guarantee.
- **Cannot treat left and right AirPods as two independent Core Audio devices** under the supplied two-channel-device configuration. They are output channels of one device.
- **Cannot preserve left/right isolation through a mono output path or downstream mono summing.** Two channel labels alone do not establish acoustic separation.
- **Cannot promise arbitrary protected-content capture, FaceTime support, or capture from every system service.** The reviewed official material supplies no macOS 26 compatibility matrix for these cases. Neither a blanket “FaceTime is blocked” nor “FaceTime definitely works” is justified by the evidence.
- **Cannot promise zero latency or avoid capture consent.** A functioning capture API is not permission to bypass authorization or content restrictions.
- **Cannot infer individual FaceTime participants, outgoing microphone audio, or application-internal audio objects** from a mixed process output. The initial feature concerns the audio the application renders for listening.

## 5. Recommended MVP architecture

**Recommendation: a small, native, two-source process-tap router targeting macOS 26.0+, with a feasibility prototype before the selection UI.** Prefer the existing C HAL APIs for the initial data path; use Swift/Core Audio wrappers and AppKit metadata for control/discovery. The layout below is proposed, not yet validated on AirPods.

```text
Audio process discovery and lifecycle tracking
       |                               |
Selected app group A            Selected app group B
       |                               |
Private stereo tap A            Private stereo tap B
       |                               |
       +------ private aggregate ------+
              tap input streams
              AirPods physical output / timing source
                        |
              HAL audio I/O callback
              inspect/convert input formats
              downmix A and B separately
              A -> left, B -> right
                        |
              AirPods stereo output
```

### Proposed data path

1. Enumerate audio process objects and the selected output device. Store stable bundle/device identities for preferences and current object IDs for runtime use. Reject an output that cannot provide the required stereo path.
2. Create two private inclusion taps, one per source group. Never include the router’s own output process. Use stereo taps initially so downmixing and metering remain explicit; start capture-only diagnostics unmuted before testing rerouting with `.mutedWhenTapped`.
3. Create one private aggregate containing both tap UIDs and the physical AirPods device. Use AirPods as the main timing device and enable appropriate subtap drift compensation. Do not make the private aggregate the system default output.
4. Inspect aggregate streams and buffer layouts; identify each tap’s channels and the physical output channels. Do not assume that `AudioBufferList` buffer index equals source index or that buffers are interleaved.
5. In the HAL I/O callback, render the explicit matrix and clear unused output channels. If format conversion is required, use a prepared converter/bounded buffering plan; do not reinterpret samples at a different rate. The initial test targets 48 kHz stereo because that is the reported device state, not because it is permanent.
6. Keep one output clock. Verify how the aggregate aligns/converts the actual tap formats; do not assume drift compensation solves every discontinuity or latency mismatch. If this topology proves unreliable, evaluate separate tap-only capture aggregates feeding bounded ring buffers and one AUHAL output, accepting the additional synchronization work.

### Control and failure behavior

- Keep UI state, discovery, device reconfiguration, and permission handling away from the audio callback. Preallocate buffers; avoid blocking, file I/O, UI calls, actor hops, and unbounded allocation on the real-time path.
- Prepare and validate output before enabling source suppression. On stop or output failure, stop tap reading and tear down resources so original playback can resume. Test this behavior rather than assuming crash recovery is instantaneous.
- Rebuild safely after device disconnect, rate/channel changes, process restart, sleep/wake, or audio service restart. Brief silence is preferable to replaying an incorrect channel map.
- Prevent duplicate/overlapping source assignments initially. Leave unselected applications on their normal playback path; they may still be heard in both ears. The MVP does not promise exclusive ownership of all system sound.
- After validation, add Left/Right source selectors, output selection, independent gain/meters, a Start/Stop action, and clear permission/device status. No recording to disk is needed.

This architecture minimizes separate clocks and removes a driver dependency. Its suitability is an engineering inference based on SDK H1–H4, not evidence of a completed implementation.

## 6. Required permissions

| Capability | Requirement / scope |
| --- | --- |
| Core Audio process-tap capture | Include `NSAudioCaptureUsageDescription`; obtain system audio recording consent. Apple says the first recording start on a tap-containing aggregate triggers the prompt. It is required even if audio is only rerouted in memory. [Apple sample](https://developer.apple.com/documentation/coreaudio/capturing-system-audio-with-core-audio-taps), [usage-description key](https://developer.apple.com/documentation/bundleresources/information-property-list/nsaudiocaptureusagedescription). |
| Hardened Runtime audio input | Apple documents `com.apple.security.device.audio-input` for accessing audio input through Core Audio. Enable/validate this in the signed prototype’s Hardened Runtime configuration. An entitlement does not replace user consent. [Apple: Audio Input entitlement](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.security.device.audio-input). |
| App Sandbox | Treat as a separate validation gate. Apple’s sandbox documentation describes Audio Input/microphone capability, but the reviewed sources do not provide a definitive macOS 26 process-tap entitlement recipe. Test private aggregate capture in the existing sandboxed target and verify the generated entitlements. Do not invent a `com.apple.security.system-audio-capture` entitlement from third-party examples. [Apple: configuring App Sandbox](https://developer.apple.com/documentation/xcode/configuring-the-macos-app-sandbox). |
| Microphone capture by this app | Requires `NSMicrophoneUsageDescription`, microphone authorization, and applicable sandbox/runtime capabilities. Not part of the playback-only MVP. FaceTime’s microphone use does not itself require this router to capture a microphone. |
| ScreenCaptureKit alternative | Programmatic screen-content capture uses screen-recording authorization. `SCContentSharingPicker` can instead authorize the user-selected content for that sharing session without a separate broad screen permission. Do not assume the picker is a persistent permission for arbitrary app capture. [Apple: macOS capture sample](https://developer.apple.com/documentation/screencapturekit/capturing-screen-content-in-macos), [WWDC23 privacy](https://developer.apple.com/videos/play/wwdc2023/10053/). |
| Ordinary output to connected AirPods | No direct Bluetooth API access is proposed. No Bluetooth scanning/pairing entitlement is introduced solely for Core Audio playback. |
| Accessibility, Automation, camera, administrator access | Not part of the proposed design; there is no UI scripting, camera capture, or driver installation. |

Use a signed app bundle with stable identity for permission tests. Exercise denial, revocation, and recovery. The documented tap startup prompt is the baseline; no private TCC database access or undocumented permission API is proposed. The capture-only path does not need screen pixels.

If sandbox behavior blocks the proof of concept, compare a separately configured local nonsandboxed, signed diagnostic build; document the result before choosing distribution. That is a proposed diagnostic step, not a claim that sandboxing is impossible or that Mac App Store acceptance is guaranteed. No signing, sandbox, or privacy settings were changed during this research.

## 7. Risks and limitations

| Risk | Evidence / uncertainty | MVP response |
| --- | --- | --- |
| FaceTime capture | No definitive app-specific guarantee found in the reviewed Apple docs. Actual call audio may need different process attribution than the visible app. | Make incoming-call playback capture a separate early gate. Identify the actual audio process; do not silently expand to a global tap. |
| FaceTime echo and conversational latency | Rerouting adds delay and may interact with the call app’s processing. Not tested. | Test with built-in/external microphone, measure delay, and verify the remote party does not hear new echo. Do not route microphone audio in the MVP. |
| Protected/DRM content | The cited APIs do not promise all protected content is accessible; no verified per-service macOS 26 matrix was found. | Test unprotected audio first. Mark protected playback unsupported/unverified until tested; do not diagnose every silent buffer as DRM. No circumvention design. |
| Spotify and browser behavior | Native/service/helper process relationships and content eligibility are not established here. | Maintain a per-app/version compatibility table. Start browser tests with one playing tab and test additional tabs explicitly. |
| Bluetooth microphone use | Apple documents reduced quality/volume when Bluetooth switches from listening to simultaneous microphone/listening mode. Exact channel count/rate depends on the actual device/mode. | Prefer MacBook/external mic for the first call test. Re-query formats during calls; suspend split-ear routing if stereo separation disappears. [Apple Bluetooth guidance](https://support.apple.com/en-us/102217). |
| “48 kHz, 2 channels” is only a snapshot | Device routing, microphone activation, and reconnection can change the operating state. | Listen for changes; rebuild converters/channel maps. Do not claim that all AirPods always become mono, or always preserve stereo, during calls. |
| Spatial processing, mono accessibility settings, balance, one-ear use | Downstream processing can undermine the intended listening result; exact behavior is untested. | Establish a baseline with mono audio off, neutral balance, both earbuds worn, and spatial processing disabled for the test. Verify acoustically, not just with buffer inspection. |
| Added latency / video lip sync | Capture, conversion, buffering, and Bluetooth playback all contribute; no measured budget exists yet. | Measure incremental latency relative to normal playback. No low-latency promise before measurements. |
| Source muting and output failure | Tap mute semantics are documented; successful rerendering is the app’s responsibility. | Detect failure, stop reading, and release taps. Test stop, crash, permission loss, and disconnect recovery. |
| Feedback / double playback | Recapturing the router or failing to suppress original playback breaks the design. | Narrow inclusion lists; exclude own process; verify each original path is suppressed during routing. |
| Real-time stability and clock drift | Separate clocks, rate changes, buffer underruns, and control-thread work can cause glitches. | Prefer one aggregate/output clock, use bounded buffers, and measure underruns/overruns during long sessions. |
| Restart and identity changes | Process object IDs are runtime identities; browser helpers and system services can change. | Observe lifecycle changes and validate macOS 26 restore-by-bundle-ID behavior. |
| System apps and sounds | Process selection does not provide semantic categories such as “all notifications” or “only FaceTime participant X.” | Keep scope to tested process groups; label uncertain attribution rather than claiming universal support. |
| Sandbox and distribution | Existing project is sandboxed; end-to-end entitlement behavior was not exercised. | Resolve this in the capture spike before investing in the UI or committing to an App Store distribution plan. |

## 8. Proposed next development steps

These are future tasks. No application implementation was performed as part of this research.

1. **Align the target and establish a test matrix.** Decide whether 26.0 remains the minimum; the current project is set to 26.2. Record AirPods model/firmware and actual audio formats. Test on 26.0 if it is a supported release; the current machine cannot establish that baseline by itself.
2. **Build a minimal signed discovery/capture spike.** Enumerate audio clients and active-output flags, resolve process identities, and capture one known unprotected source. Confirm real nonzero PCM and permission grant/deny/revoke behavior. Compare sandbox configurations only if necessary.
3. **Validate original-output suppression and recovery.** Compare unmuted capture with `.mutedWhenTapped`. Confirm no duplicated audio and restoration after stop, forced termination, and output failure.
4. **Prove two independent captures.** Use two distinguishable known signals from different apps. Verify each tap contains only its intended source; pause/restart each independently. A mixed global capture does not pass this test.
5. **Prove stereo routing on a stable output, then AirPods.** Begin with wired headphones if available to isolate Bluetooth variables. Verify A appears only in the left output samples and B only in the right, then confirm the actual ear mapping. Measure leakage, levels, clipping, and incremental latency; record measurements rather than inventing acceptance results.
6. **Test the named applications.** Test ordinary YouTube playback in each supported browser, additional tabs, Spotify, and FaceTime remote audio. Record OS/app versions, source attribution, captured format, capture result, mute result, and restart behavior. Treat protected playback separately from ordinary content.
7. **Run the FaceTime/Bluetooth gate.** Compare built-in/external microphone with AirPods microphone active. Log rate/channel changes, assess stereo separation, and check conversation delay/echo. If FaceTime cannot be captured or stereo disappears, the headline example is not supported in that configuration; report that explicitly.
8. **Exercise lifecycle and stability.** Test a prolonged two-source session, source changes, sleep/wake, AirPods disconnect/reconnect, output changes, permission revocation, and audio service restart. Track underruns and successful restoration of ordinary playback.
9. **Only after the gates pass, build the Left/Right UI.** If a capture backend fails, evaluate ScreenCaptureKit against that specific failure and account for its lack of source muting. Consider a driver only when a concrete requirement cannot be met by the native tap design.

### Local Apple SDK references

The following installed Apple files were read directly. They are primary evidence for symbol availability and API semantics; they are not project files or runtime test results.

- **H1 — HAL discovery, taps, aggregate composition and clocks:** [AudioHardware.h](/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX26.2.sdk/System/Library/Frameworks/CoreAudio.framework/Headers/AudioHardware.h).
- **H2 — Tap selectors, muting, macOS 26 additions, creation availability:** [CATapDescription.h](/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX26.2.sdk/System/Library/Frameworks/CoreAudio.framework/Headers/CATapDescription.h) and [AudioHardwareTapping.h](/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX26.2.sdk/System/Library/Frameworks/CoreAudio.framework/Headers/AudioHardwareTapping.h).
- **H3 — Swift HAL wrapper availability and read-only process properties:** [CoreAudio Swift interface](/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX26.2.sdk/usr/lib/swift/CoreAudio.swiftmodule/arm64e-apple-macos.swiftinterface).
- **H4 — Output device selection, channel maps, and matrix mixing:** [AudioUnitProperties.h](/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX26.2.sdk/System/Library/Frameworks/AudioToolbox.framework/Headers/AudioUnitProperties.h).
- **H5 — Engine-node taps and stereo pan:** [AVAudioNode.h](/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX26.2.sdk/System/Library/Frameworks/AVFAudio.framework/Headers/AVAudioNode.h) and [AVAudioMixing.h](/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX26.2.sdk/System/Library/Frameworks/AVFAudio.framework/Headers/AVAudioMixing.h).
- **H6 — ScreenCaptureKit stream/filter/audio configuration:** [SCStream.h](/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX26.2.sdk/System/Library/Frameworks/ScreenCaptureKit.framework/Headers/SCStream.h).

Web citations throughout point to Apple documentation, Apple developer presentations, or Apple Support. Developer-forum reports were not used as proof of Apple guarantees or as an app compatibility certification.
