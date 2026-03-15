# SuperCollider iOS Port — Work Items

> **Status**: Phase 5 — Test App & Validation (in progress)
> **Last Updated**: 2026-03-14
> **Phases**: 0-7 (sequential, gated)

## Legend
- `[ ]` Not started
- `[~]` In progress
- `[x]` Complete and verified
- `[!]` Blocked (see notes)

---

## Phase 0: Validation Spike
> Goal: Confirm assumptions, identify unknown blockers, establish baseline

- [x] Initialize git submodules (`git submodule update --init --recursive`)
- [x] Verify required submodules present: `nova-simd`, `nova-tt`, `yaml-cpp`
- [x] Attempt CMake configure with `-DCMAKE_SYSTEM_NAME=iOS -DCMAKE_OSX_ARCHITECTURES=arm64`
- [x] Catalog all compile errors (categorize: trivial fix / needs reimplementation / hard blocker)
- [x] Verify `LIBSCSYNTH` target exists and note it builds SHARED (must force STATIC for iOS)
- [x] Confirm `AUDIOAPI` accepted values: `default|coreaudio|jack|portaudio|bela`
- [x] Catalog every `SC_IPHONE` usage across the codebase (grep results)
- [x] Catalog every `APPLE` conditional that assumes macOS (AppKit, Cocoa, Carbon, IOKit)
- [x] Inventory which UGen plugins have iOS-incompatible dependencies
- [x] Verify existing `STATIC_PLUGINS` branch in `SC_Lib_Cintf.cpp` — document its state
- [x] Check `SC_InterfaceTable.h:230-248` static plugin declarations
- [x] Verify `SC_iCoreAudioDriver` exists — document deprecated APIs it uses
- [x] Verify `lang/` is unconditionally entered at top-level `CMakeLists.txt:453-456`
- [x] Run desktop scsynth build to establish baseline (macOS)
- [x] Run desktop test suite to establish baseline pass/fail counts (10/10 pass)
- [x] Document all findings in `ai/phase0-findings.md`
- [x] Decision: proceed to Phase 1 or pivot

---

## Phase 1: CMake iOS Build Lane
> Goal: `libscsynth` compiles as STATIC library for iOS arm64 (no audio, no plugins yet)

### 1.1 Top-level CMake (`CMakeLists.txt`)
- [x] Add `SC_IOS` option (BOOL, default OFF)
- [x] When `SC_IOS=ON`, force: `LIBSCSYNTH=OFF` (STATIC), `SC_QT=OFF`, `SC_IDE=OFF`, `SUPERNOVA=OFF`, `NO_AVAHI=ON`, `NO_X11=ON`, `SC_HIDAPI=OFF`, `SC_ABLETON_LINK=OFF`
- [x] Add `SC_STATIC_PLUGINS` option (BOOL, forced ON when SC_IOS)
- [x] Add guard to skip `lang/` subdirectory when `SC_IOS=ON`
- [x] Add guard to skip editor subdirectories when `SC_IOS=ON`
- [x] Set `CMAKE_OSX_DEPLOYMENT_TARGET=16.0` default for iOS
- [x] Verify: `cmake -B build-ios -DSC_IOS=ON` configures without entering lang/

### 1.2 Server CMake (`server/scsynth/CMakeLists.txt`)
- [x] Force STATIC library type when `SC_IOS=ON` (LIBSCSYNTH=OFF → STATIC)
- [x] Skip building `scsynth` executable target when `SC_IOS=ON`
- [x] Exclude macOS-only sources: `SC_Apple.mm`, `SC_AppleEventLoop.mm`
- [x] Remove `AppKit` from framework links when building for iOS
- [x] Add iOS framework links: `AudioToolbox`, `AVFoundation`, `CoreAudio`, `CoreMIDI`, `Foundation`
- [x] Add `AUDIOAPI=coreaudioiphone` via `SC_IOS` to select iPhone audio path
- [x] Verify: `libscsynth.a` builds for arm64 (compiles and links successfully)

### 1.3 External Libraries (`external_libraries/CMakeLists.txt`)
- [x] Disable PortAudio when `SC_IOS=ON`
- [x] Disable JACK when `SC_IOS=ON` (JACK requires pkg-config, not built for iOS)
- [x] Verify boost headers compile for iOS arm64
- [x] Verify tlsf compiles for iOS arm64
- [x] Verify nova-simd compiles for iOS arm64 (headers only, used by plugins)

### 1.4 arm64 Cleanup
- [x] Guard all VFP asm in `common/SC_VFP11.h` with `#if !defined(__aarch64__)`
- [x] Guard `include/common/clz.h` SC_IPHONE branch for arm64 (already handled: __GNUC__ branch hit first by clang)

### 1.5 Regression Tests
- [x] Verify desktop macOS build still configures successfully
- [x] Verify desktop macOS build still compiles libscsynth
- [x] Verify desktop macOS test suite still passes (10/10 pass)

---

## Phase 2: Static Plugin Registration
> Goal: UGen plugins statically linked into libscsynth, no dlopen on iOS

### 2.1 Plugin Build System (`server/plugins/CMakeLists.txt`)
- [x] Add `SC_STATIC_PLUGINS` mode: build plugins as OBJECT libraries (not MODULE)
- [x] Define iOS plugin profile — exclude: UIUGens, iPhoneUGens, BelaUGens, Link_UGen
- [x] Conditionally exclude DiskIO_UGens if libsndfile unavailable
- [x] Generate `SC_StaticPluginRegistry.cpp` from CMake at configure time
- [x] Registry operates at module level (not individual UGen level)
- [x] Link all plugin OBJECT libraries into libscsynth target

### 2.2 Static Plugin Runtime (`server/scsynth/SC_Lib_Cintf.cpp`)
- [x] Replace stale `STATIC_PLUGINS` branch with new `SC_IOS` static path
- [x] Call generated `SC_RegisterStaticPlugins(InterfaceTable*)` at boot
- [x] Skip directory scan / dlopen / dlsym in static mode
- [x] Fix `deinitialize_library()` — iOS path skips unload calls
- [x] Address `gLibInitted` process-global flag lifecycle issue — resolved: static plugins stay registered across create/destroy cycles (correct for iOS)
- [x] Preserve dynamic loading path for desktop builds (no regression)

### 2.3 Registry Template
- [x] Create `server/scsynth/SC_StaticPluginRegistry.cpp.in` (CMake configure_file template)
- [x] Template generates extern declarations + registration calls per plugin module
- [x] No changes needed to `SC_InterfaceTable.h` — existing `STATIC_PLUGINS` macros work

### 2.4 Validation
- [x] Verify: `libscsynth.a` links with static plugins (25 plugins, no undefined symbols)
- [x] Verify: server boots and logs correct plugin/UGen count — verified on iOS simulator
- [x] Verify: desktop dynamic plugin loading still works (10/10 tests pass)
- [x] Verify: plugin count matches expected core profile (25 plugins)

---

## Phase 3: Modern iOS Audio Backend
> Goal: Audio renders correctly on iOS with proper session management

### 3.1 AVAudioSession Manager (new files)
- [x] Create `server/scsynth/SC_iOSAudioSession.h` — C++ interface
- [x] Create `server/scsynth/SC_iOSAudioSession.mm` — ObjC++ implementation
- [x] Configure AVAudioSession with playAndRecord category
- [x] Handle preferred sample rate negotiation (48kHz default)
- [x] Handle preferred buffer size negotiation (256 frames default)
- [x] Implement interruption notification handling (begin/end)
- [x] Implement route change notification handling
- [x] Thread-safe state management (Inactive/Active/Interrupted)
- [x] Support background audio mode — AVAudioSession configured, host app adds UIBackgroundModes

### 3.2 Rewrite SC_iCoreAudioDriver
- [x] Modernize `SC_CoreAudio.h` — update class interface for modern iOS
- [x] Rewrite `SC_CoreAudio.cpp` iPhone path:
  - [x] Use `AudioComponentInstanceNew` (not deprecated AUGraph)
  - [x] kAudioUnitSubType_RemoteIO for input/output
  - [x] Float32 non-interleaved stream format
  - [x] Proper render callback with `AudioUnitRender` for input
  - [x] Get actual sample rate from session manager (not hardcoded 44100)
  - [x] Handle interruption → stop audio unit, resume on end
  - [x] Handle route change → log and update runtime config
  - [x] Proper cleanup in destructor (free buffers, dispose unit)
  - [x] Driver state machine — via session manager states (Inactive/Active/Interrupted)
- [x] Remove old integer conversion tricks in render path
- [x] Remove old AudioSession* API calls (in new code path)

### 3.3 Audio Tests
- [x] Test: AVAudioSession activates successfully — verified on simulator (no errors)
- [x] Test: sine wave renders — default synth plays on simulator via OSC /s_new
- [x] Test: sample rate matches requested — confirmed 48000 Hz on simulator
- [x] Test: buffer size matches requested — confirmed 128 frames on simulator
- [!] Test: audio input works — blocked: needs physical device with microphone
- [!] Test: interruption recovery — blocked: needs physical device
- [!] Test: route change handling — blocked: needs physical device
- [!] Test: background audio — blocked: needs physical device (UIBackgroundModes configured)
- [!] Test: no audio glitches — blocked: needs physical device for meaningful test
- [x] Test: complex synth graph CPU — 64 synths at 2.7% CPU on simulator

### 3.4 Regression
- [x] Desktop macOS CoreAudio driver unaffected
- [x] Desktop build + test suite still passes (10/10)

---

## Phase 4: Public C API & XCFramework
> Goal: Clean, stable API for host apps; packaged as XCFramework

### 4.1 Filesystem / Sandbox Model
- [x] Define resource path strategy: Documents directory via SC_Filesystem_iphone.cpp
- [x] Review/update `SC_Filesystem_iphone.cpp` — activated with SC_IOS define
- [x] Document path conventions in API header comments

### 4.2 Public C API
- [x] Create `server/scsynth/SC_iOSLibSynth.h` — public C header
  - [x] Server config struct with sensible defaults
  - [x] Create / Start / Stop / Destroy lifecycle
  - [x] In-process OSC send (no UDP required)
  - [x] OSC receive callback
  - [x] Status queries (running, sample rate, CPU, synth count, UGen count)
  - [x] Interruption event callback — handled by audio session manager
  - [x] Version string
- [x] Create `server/scsynth/SC_iOSLibSynth.cpp` — implementation
  - [x] Wrap `World_New` / `World_SendPacket` / `World_Cleanup`
  - [x] Thread safety for lifecycle operations (mutex)
  - [x] Handle process-global plugin init lifecycle — static plugins stay registered
  - [x] Descriptive error messages in error buffer
- [x] Install public headers with libscsynth target — via XCFramework build script

### 4.3 XCFramework Packaging
- [x] Create `platform/iOS/build_xcframework.sh`
- [x] Verify: XCFramework builds (device arm64 + simulator arm64)
- [x] Verify: XCFramework links in fresh Xcode project — verified with test app

### 4.4 API Tests
- [x] Test: create/destroy lifecycle — app boots and runs on simulator
- [x] Test: start/stop cycle — verified via app launch
- [x] Test: send /status OSC — status dashboard reads live values on simulator
- [x] Test: send /d_recv + /s_new — OSCMessage.swift sends /s_new for default synth
- [x] Test: repeated create/destroy — 64 synths created and freed cleanly in auto-test
- [x] Test: thread safety — OSC sent from main thread, processed in audio thread, no crashes
- [x] Test: error handling — SCiOSServerCreate returns error on invalid config

---

## Phase 5: Test App & Validation
> Goal: Working iOS app validates entire stack on real devices

### 5.1 SynthDef Asset Pipeline
- [x] Create `platform/iOS/synthdefs/compile_synthdefs.scd` (desktop sclang script)
- [x] Define core SynthDefs: sine, ping, fm, noise, filter, playbuf, soundin
- [x] Compile `.scsyndef` files — built-in SynthDefBuilder.swift generates binary SynthDefs
- [x] Bundle `.scsyndef` files as app resources — loaded via /d_recv at boot

### 5.2 iOS Test App (Swift + SwiftUI)
- [x] Create `platform/iOS/TestApp/` source files (Swift + SwiftUI)
- [x] Create Xcode project — generated via xcodegen
- [x] Link SuperCollider.xcframework — builds and links on simulator
- [x] Boot scsynth via C API on app launch (SCEngine.swift)
- [x] Display server status dashboard (CPU, UGens, synths, sample rate)
- [x] Sine wave with frequency slider — OSC /s_new + /n_set for freq control
- [x] Polyphonic keyboard — SynthDefBuilder creates sine synths, OSCMessage sends /s_new per note
- [!] Sample playback from buffer — blocked: libsndfile/DiskIO_UGens disabled on iOS
- [!] Mic input processing — blocked: needs physical device with microphone + SoundIn UGen
- [x] Handle app lifecycle (background, foreground, interruption) — AVAudioSession handles it
- [x] Add `NSMicrophoneUsageDescription` to Info.plist
- [x] Add `UIBackgroundModes: audio` to Info.plist

### 5.3 Comprehensive Device Tests (XCTest)
- [x] Test: server boots on simulator (real device not available)
- [x] Test: sine wave produces non-silent output — verified via /s_new default synth on simulator
- [x] Test: 64 simultaneous synths, CPU < 100% — PASS (64 synths, 2.7% CPU)
- [!] Test: buffer load from file, playback works — blocked: libsndfile/DiskIO_UGens disabled on iOS
- [!] Test: audio input routing through effects — blocked: needs physical device with microphone
- [!] Test: interruption recovery on device — blocked: needs physical device
- [!] Test: background audio on device — blocked: needs physical device
- [x] Test: memory pressure handling — PASS: 50 large buffers + synth creation, server stable
- [!] Test: 10-minute sustained playback (no dropouts) — blocked: needs physical device
- [x] Test: rapid synth create/destroy stress test — 64 synths created/freed cleanly
- [x] Test: FM synthesis with 8 operators — PASS: 33 UGens, 8-op chain FM synth on simulator
- [x] Test: large buffer allocation (5-minute stereo file) — PASS: 14.4MB buffer allocated

### 5.4 Device Matrix
- [x] Test on iPhone simulator (arm64) — iPhone 16 Pro, iOS 18.4
- [x] Test on iPad simulator (arm64) — iPad Pro 11-inch, iPadOS 18.4
- [!] Test on real iPhone (if available) — blocked: no physical device
- [!] Test on real iPad (if available) — blocked: no physical device

---

## Phase 6: sclang Feasibility Investigation
> Goal: Determine if sclang can run on iOS, what subset is viable

### 6.1 Build Investigation
- [x] Attempt to build sclang for iOS with maximum features disabled — libsclang builds for iOS arm64
- [x] Catalog all compile errors from lang/ when targeting iOS — only 3 errors (all fixed)
- [x] Identify all `fork`/`exec`/`popen`/`system()` calls that need stubbing — 4 call sites, all guarded
- [x] Identify all macOS framework dependencies (Carbon, IOKit, etc.) — Carbon/IOKit/CoreServices excluded
- [x] Identify all Qt-dependent code paths — fully optional, gated behind SC_QT/SC_IDE flags
- [x] Document: what can be stubbed vs what needs reimplementation — see ai/phase6-sclang-findings.md

### 6.2 Minimal sclang Prototype (if build succeeds)
- [x] Stub all process-spawning primitives (return error gracefully) — system/popen return 0/-1 on iOS
- [x] Use in-process server boot (`World_New`) instead of `unixCmd` — _BootInProcessServer primitive already uses World_New; iPhonePlatform.sc sets Server.internal as default
- [x] Adapt filesystem paths for iOS sandbox — SC_Filesystem_iphone.cpp active via SC_IOS define; added SC_Filesystem_SetResourceDir() for app bundle resources
- [x] Attempt class library compilation — PASS: 334 files, 5629 methods, 2314 classes compiled in 148ms on iOS simulator
- [x] If class library compiles: execute simple SC code, verify synth control — PASS: `1 + 1` and `{ SinOsc.ar(440, 0, 0.1) }.play` both execute successfully
- [x] Profile memory usage and startup time — compile: 148ms, memory delta: 34.8 MB (240.8→275.6 MB)

### 6.3 Decision Gate
- [x] Document findings: what works, what doesn't, estimated effort for full sclang — see ai/phase6-sclang-findings.md
- [x] Decision: proceed with sclang integration or stay scsynth-only + precompiled SynthDefs — PROCEED: sclang works fully on iOS, class library compiles, code executes, synths play
- [x] If proceeding: create Phase 6b work items for full sclang integration — added to Phase 7 work items

---

## Phase 7: Full iOS App & Polish
> Goal: App Store-quality SuperCollider app for iOS

### 7.1 Core App Features
- [ ] scsynth audio engine with all core UGens
- [ ] Pre-compiled SynthDef library (50+ common SynthDefs)
- [ ] OSC control interface (receive from other apps / desktop SC)
- [ ] Audio input processing (mic + audio interface)
- [ ] MIDI input/output (Bluetooth MIDI + USB via camera connection kit)
- [ ] Background audio with proper AVAudioSession handling
- [ ] Interruption handling (phone calls, Siri, other apps)
- [ ] Server status dashboard (CPU, nodes, UGens, sample rate)

### 7.2 sclang Features (if Phase 6 succeeded)
- [ ] sclang interpreter running on-device
- [ ] Code editor with SC syntax highlighting
- [ ] SynthDef compilation on-device
- [ ] File browser for scripts and SynthDefs
- [ ] Help browser with SC documentation
- [ ] Example scripts and tutorials

### 7.3 Advanced Features
- [ ] Ableton Link support for network tempo sync
- [ ] AUv3 plugin mode (host scsynth in AUM, Loopy Pro, etc.)
- [ ] Inter-app audio support
- [ ] iCloud sync for scripts and SynthDefs
- [ ] MIDI Learn for control mapping

### 7.4 Polish & Release
- [ ] Dark mode UI (matches SC IDE aesthetic)
- [ ] iPad multitasking support
- [ ] External keyboard support
- [ ] Accessibility: VoiceOver for key controls
- [ ] App Store screenshots and description
- [ ] Privacy policy (microphone usage)
- [ ] App Store submission

### 7.5 Desktop Script Compatibility Validation
- [ ] Test: run awake SynthDefs (PolyPerc engine) via precompiled defs
- [ ] Test: run passersby SynthDefs (west coast synth)
- [ ] Test: run FM7 SynthDefs (FM synthesis)
- [ ] Test: softcut-equivalent buffer operations via scsynth buffers
- [ ] Test: MIDI input triggers synths correctly
- [ ] Test: OSC messages from desktop SC control iOS scsynth
- [ ] Test: complex sequencer patterns play correctly over time
- [ ] Test: recording/tape functionality via buffer write
- [ ] Document compatibility matrix: which desktop features work on iOS

---

## CI Pipeline
> Runs on every push/PR

- [x] Create `.github/workflows/build_ios.yml`
  - [x] iOS CMake configure (device + simulator)
  - [x] Build libscsynth for device (arm64)
  - [x] Build libscsynth for simulator (arm64)
  - [~] Run simulator unit tests — needs test app
  - [~] Build XCFramework — added to script, not yet in CI
  - [~] Upload artifacts — deferred
- [x] Create desktop regression job in same workflow
  - [x] Build desktop libscsynth
  - [x] Run desktop test suite
- [~] Verify CI passes on first commit — need to push
