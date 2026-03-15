# SuperCollider iOS Port — Work Items

> **Status**: Phase 2 — Static Plugin Registration (complete)
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
- [~] Add `SC_STATIC_PLUGINS` option (BOOL, forced ON when SC_IOS) — deferred to Phase 2
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
- [~] Address `gLibInitted` process-global flag lifecycle issue in `SC_World.cpp` — deferred to Phase 4 (API)
- [x] Preserve dynamic loading path for desktop builds (no regression)

### 2.3 Registry Template
- [x] Create `server/scsynth/SC_StaticPluginRegistry.cpp.in` (CMake configure_file template)
- [x] Template generates extern declarations + registration calls per plugin module
- [x] No changes needed to `SC_InterfaceTable.h` — existing `STATIC_PLUGINS` macros work

### 2.4 Validation
- [x] Verify: `libscsynth.a` links with static plugins (25 plugins, no undefined symbols)
- [~] Verify: server boots and logs correct plugin/UGen count — needs test app (Phase 5)
- [x] Verify: desktop dynamic plugin loading still works (10/10 tests pass)
- [x] Verify: plugin count matches expected core profile (25 plugins)

---

## Phase 3: Modern iOS Audio Backend
> Goal: Audio renders correctly on iOS with proper session management

### 3.1 AVAudioSession Manager (new files)
- [ ] Create `server/scsynth/SC_iOSAudioSession.h` — C++ interface
- [ ] Create `server/scsynth/SC_iOSAudioSession.mm` — ObjC++ implementation
- [ ] Configure AVAudioSession with playAndRecord category
- [ ] Handle preferred sample rate negotiation (48kHz default)
- [ ] Handle preferred buffer size negotiation (256 frames default)
- [ ] Implement interruption notification handling (begin/end)
- [ ] Implement route change notification handling
- [ ] Thread-safe state management (Inactive/Active/Interrupted)
- [ ] Support background audio mode

### 3.2 Rewrite SC_iCoreAudioDriver
- [ ] Modernize `SC_CoreAudio.h` — update class interface for modern iOS
- [ ] Rewrite `SC_CoreAudio.cpp` iPhone path:
  - [ ] Use `AudioComponentInstanceNew` (not deprecated AUGraph)
  - [ ] kAudioUnitSubType_RemoteIO for input/output
  - [ ] Float32 non-interleaved stream format
  - [ ] Proper render callback with `AudioUnitRender` for input
  - [ ] Get actual sample rate from session manager (not hardcoded 44100)
  - [ ] Handle interruption → stop audio unit, resume on end
  - [ ] Handle route change → restart if SR/buffer changed
  - [ ] Proper cleanup in destructor (free buffers, dispose unit)
  - [ ] Driver state machine: Stopped → Starting → Running → Interrupted → Stopped
- [ ] Remove old integer conversion tricks in render path
- [ ] Remove old AudioSession* API calls

### 3.3 Audio Tests
- [ ] Test: AVAudioSession activates successfully
- [ ] Test: sine wave renders (non-silent output)
- [ ] Test: sample rate matches requested or gracefully adapts
- [ ] Test: buffer size matches requested or gracefully adapts
- [ ] Test: audio input works (SoundIn UGen)
- [ ] Test: interruption recovery (simulate, verify resume)
- [ ] Test: route change handling (headphone plug/unplug)
- [ ] Test: background audio continues when app backgrounded
- [ ] Test: no audio glitches under sustained 60-second load
- [ ] Test: complex synth graph CPU stays reasonable

### 3.4 Regression
- [ ] Desktop macOS CoreAudio driver unaffected
- [ ] Desktop build + test suite still passes

---

## Phase 4: Public C API & XCFramework
> Goal: Clean, stable API for host apps; packaged as XCFramework

### 4.1 Filesystem / Sandbox Model
- [ ] Define resource path strategy: bundled SynthDefs in app bundle vs Documents
- [ ] Review/update `SC_Filesystem_iphone.cpp` for modern sandbox paths
- [ ] Document path conventions in API header comments

### 4.2 Public C API
- [ ] Create `server/scsynth/SC_iOSLibSynth.h` — public C header
  - [ ] Server config struct with sensible defaults
  - [ ] Create / Start / Stop / Destroy lifecycle
  - [ ] In-process OSC send (no UDP required)
  - [ ] OSC receive callback
  - [ ] Status queries (running, sample rate, CPU, synth count, UGen count)
  - [ ] Interruption event callback
  - [ ] Version string
- [ ] Create `server/scsynth/SC_iOSLibSynth.cpp` — implementation
  - [ ] Wrap `World_New` / `World_SendPacket` / `World_Cleanup`
  - [ ] Thread safety for lifecycle operations
  - [ ] Handle process-global plugin init lifecycle correctly
  - [ ] Descriptive error messages in error buffer
- [ ] Install public headers with libscsynth target

### 4.3 XCFramework Packaging
- [ ] Create `platform/iOS/build_xcframework.sh`
  - [ ] Build device static lib (iphoneos arm64)
  - [ ] Build simulator static lib (iphonesimulator arm64 + x86_64)
  - [ ] `xcodebuild -create-xcframework` combining both
  - [ ] Stage public headers
- [ ] Verify: XCFramework builds successfully
- [ ] Verify: XCFramework links in fresh Xcode project

### 4.4 API Tests
- [ ] Test: create/destroy lifecycle (no crash, no leak)
- [ ] Test: start/stop cycle
- [ ] Test: send /status OSC, receive response via callback
- [ ] Test: send /d_recv + /s_new, verify synth created
- [ ] Test: repeated create/destroy (100x, check for leaks)
- [ ] Test: thread safety — send OSC from multiple threads
- [ ] Test: error handling — invalid config, double start, etc.

---

## Phase 5: Test App & Validation
> Goal: Working iOS app validates entire stack on real devices

### 5.1 SynthDef Asset Pipeline
- [ ] Create `platform/iOS/synthdefs/compile_synthdefs.scd` (desktop sclang script)
- [ ] Compile core SynthDefs: sine, ping, fm, noise, filter, playbuf, soundin
- [ ] Bundle `.scsyndef` files as app resources

### 5.2 iOS Test App (Swift + SwiftUI)
- [ ] Create `platform/iOS/TestApp/` Xcode project
- [ ] Link SuperCollider.xcframework
- [ ] Boot scsynth via C API on app launch
- [ ] Display server status dashboard (CPU, UGens, synths, sample rate)
- [ ] Sine wave with frequency slider
- [ ] Polyphonic keyboard (trigger ping SynthDef)
- [ ] Sample playback from buffer (load + PlayBuf)
- [ ] Mic input processing (SoundIn → reverb → out)
- [ ] Handle app lifecycle (background, foreground, interruption)
- [ ] Add `NSMicrophoneUsageDescription` to Info.plist
- [ ] Add `UIBackgroundModes: audio` to Info.plist

### 5.3 Comprehensive Device Tests (XCTest)
- [ ] Test: server boots on real device
- [ ] Test: sine wave produces non-silent output
- [ ] Test: 64 simultaneous synths, CPU < 100%
- [ ] Test: buffer load from file, playback works
- [ ] Test: audio input routing through effects
- [ ] Test: interruption recovery on device
- [ ] Test: background audio on device
- [ ] Test: memory pressure handling
- [ ] Test: 10-minute sustained playback (no dropouts)
- [ ] Test: rapid synth create/destroy stress test
- [ ] Test: FM synthesis with 8 operators
- [ ] Test: large buffer allocation (5-minute stereo file)

### 5.4 Device Matrix
- [ ] Test on iPhone simulator (arm64)
- [ ] Test on iPad simulator (arm64)
- [ ] Test on real iPhone (if available)
- [ ] Test on real iPad (if available)

---

## Phase 6: sclang Feasibility Investigation
> Goal: Determine if sclang can run on iOS, what subset is viable

### 6.1 Build Investigation
- [ ] Attempt to build sclang for iOS with maximum features disabled
- [ ] Catalog all compile errors from lang/ when targeting iOS
- [ ] Identify all `fork`/`exec`/`popen`/`system()` calls that need stubbing
- [ ] Identify all macOS framework dependencies (Carbon, IOKit, etc.)
- [ ] Identify all Qt-dependent code paths
- [ ] Document: what can be stubbed vs what needs reimplementation

### 6.2 Minimal sclang Prototype (if build succeeds)
- [ ] Stub all process-spawning primitives (return error gracefully)
- [ ] Use in-process server boot (`World_New`) instead of `unixCmd`
- [ ] Adapt filesystem paths for iOS sandbox
- [ ] Attempt class library compilation
- [ ] If class library compiles: execute simple SC code, verify synth control
- [ ] Profile memory usage and startup time

### 6.3 Decision Gate
- [ ] Document findings: what works, what doesn't, estimated effort for full sclang
- [ ] Decision: proceed with sclang integration or stay scsynth-only + precompiled SynthDefs
- [ ] If proceeding: create Phase 6b work items for full sclang integration

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

- [ ] Create `.github/workflows/build_ios.yml`
  - [ ] iOS CMake configure
  - [ ] Build libscsynth for device (arm64)
  - [ ] Build libscsynth for simulator (arm64)
  - [ ] Run simulator unit tests
  - [ ] Build XCFramework
  - [ ] Upload artifacts
- [ ] Create desktop regression job in same workflow
  - [ ] Build desktop libscsynth
  - [ ] Run desktop test suite
- [ ] Verify CI passes on first commit
