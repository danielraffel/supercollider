# SuperCollider iOS Port — Comprehensive Plan

> **Status**: Phase 0 — Planning & Validation Spike
> **Last Updated**: 2026-03-14
> **Fork**: github.com/danielraffel/supercollider
> **Goal**: A production-quality, App Store-ready iOS port of SuperCollider's scsynth audio engine, with a path toward full sclang support.

---

## Table of Contents

1. [Vision](#1-vision)
2. [Architecture Overview](#2-architecture-overview)
3. [Existing iOS Code Audit](#3-existing-ios-code-audit)
4. [Phase 0: Validation Spike](#4-phase-0-validation-spike)
5. [Phase 1: CMake iOS Build Lane](#5-phase-1-cmake-ios-build-lane)
6. [Phase 2: Static Plugin Registration](#6-phase-2-static-plugin-registration)
7. [Phase 3: Modern iOS Audio Backend](#7-phase-3-modern-ios-audio-backend)
8. [Phase 4: Public C API & XCFramework](#8-phase-4-public-c-api--xcframework)
9. [Phase 5: Test App & Validation](#9-phase-5-test-app--validation)
10. [Phase 6: sclang Feasibility](#10-phase-6-sclang-feasibility)
11. [Phase 7: Full iOS App](#11-phase-7-full-ios-app)
12. [File-by-File Impact Matrix](#12-file-by-file-impact-matrix)
13. [Dependency Analysis](#13-dependency-analysis)
14. [Test Strategy](#14-test-strategy)
15. [Risk Register](#15-risk-register)
16. [Status Log](#16-status-log)

---

## 1. Vision

SuperCollider is one of the most powerful and respected audio synthesis platforms in existence, with nearly 30 years of history. Despite ports to macOS, Linux, Windows, and recently WebAssembly, there is no maintained iOS build.

This port aims to be:

- **Production-quality** — not a hack, not a proof-of-concept
- **App Store compliant** — no dynamic code loading, proper audio session handling
- **Community-respectable** — something the SC community would be proud of
- **Incrementally deliverable** — scsynth first, then sclang, then full IDE
- **Well-tested** — comprehensive test suite at every layer, validated on real devices via Sosumi/Xcode

### Prior Art

| Project | Status | What It Proved |
|---------|--------|----------------|
| **Axel Balley's original iOS port (2009-2011)** | Bitrotted, code still in repo | scsynth can run on iOS with RemoteIO |
| **[iSuperColliderKit](https://github.com/wdkk/iSuperColliderKit)** | Archived Jan 2026 | libscsynth can be packaged as iOS static library |
| **[SuperSonic (WASM)](https://github.com/samaaron/supersonic)** | Active, 2025 | scsynth compiles for non-desktop targets with modern tooling |
| **[scsynth-wasm-builds](https://github.com/rd--/scsynth-wasm-builds)** | Active | Independent builds of scsynth for alternative platforms |
| **[PR #6569](https://github.com/supercollider/supercollider/pull/6569)** | In review | Official WASM compile target being added upstream |

---

## 2. Architecture Overview

### Current SC Architecture (Desktop)

```
┌──────────┐     OSC      ┌──────────┐     JACK      ┌──────────┐
│  sclang  │ ──────────── │ scsynth  │ ──────────── │  Audio   │
│ (lang)   │              │ (server) │               │  HW/DAC  │
│          │              │          │               └──────────┘
│ Lua-like │   ┌──────────┤          │
│ runtime  │   │  UGens   │  mixer   │
│ + IDE    │   │ (.scx    │  graph   │
│          │   │  plugins)│          │
└──────────┘   └──────────┘──────────┘
```

### Target iOS Architecture

```
┌─────────────────────────────────────────────┐
│              iOS App (Swift/ObjC)            │
│                                             │
│  ┌─────────────┐    ┌────────────────────┐  │
│  │   UI Layer   │    │  SC Control Layer  │  │
│  │  (SwiftUI/   │    │  (OSC commands,    │  │
│  │   UIKit)     │    │   SynthDef mgmt)   │  │
│  └──────┬──────┘    └────────┬───────────┘  │
│         │                     │              │
│         │    C API            │ In-process   │
│         │    ┌────────────────▼───────────┐  │
│         │    │       libscsynth           │  │
│         │    │  ┌──────────────────────┐  │  │
│         │    │  │   Static UGens       │  │  │
│         │    │  │   (linked at build)  │  │  │
│         │    │  └──────────────────────┘  │  │
│         │    │  ┌──────────────────────┐  │  │
│         │    │  │  SC_iCoreAudioDriver │  │  │
│         │    │  │  (RemoteIO + AVAudio │  │  │
│         │    │  │   Session)           │  │  │
│         │    │  └──────────────────────┘  │  │
│         │    └────────────────────────────┘  │
│         │              │                     │
│         ▼              ▼                     │
│    ┌──────────────────────────┐              │
│    │     Core Audio / DAC     │              │
│    └──────────────────────────┘              │
└─────────────────────────────────────────────┘
```

### Phase 2+ Architecture (with sclang)

```
┌─────────────────────────────────────────────┐
│              iOS App                         │
│                                             │
│  ┌──────────┐  ┌──────────┐  ┌───────────┐ │
│  │    UI    │  │  sclang  │  │ libscsynth│ │
│  │  (edit,  │  │ (in-proc │  │ (in-proc  │ │
│  │  browse) │  │  interp) │  │  server)  │ │
│  └────┬─────┘  └────┬─────┘  └─────┬─────┘ │
│       │              │               │       │
│       └──────────────┴───────────────┘       │
│              All in-process                  │
└─────────────────────────────────────────────┘
```

---

## 3. Existing iOS Code Audit

### Files with `SC_IPHONE` conditionals

| File | Purpose | Status |
|------|---------|--------|
| `server/scsynth/SC_CoreAudio.h` | Audio API constant `SC_AUDIO_API_COREAUDIOIPHONE`, `SC_iCoreAudioDriver` type | **Reusable structure, needs modernization** |
| `server/scsynth/SC_CoreAudio.cpp` | iPhone timing branch + `SC_iCoreAudioDriver` RemoteIO implementation | **Needs rewrite for modern AVAudioSession** |
| `server/scsynth/iPhone/iSCSynthController.h/mm` | UIKit app shell for scsynth | **Reference only, will rewrite** |
| `server/scsynth/iPhone/iscsynthAppDelegate.h/m` | App delegate | **Reference only** |
| `server/scsynth/iPhone/iscsynthmain.m` | iOS main entry point | **Reference only** |
| `server/plugins/iPhoneUGens.mm` | iPhone-specific UGen code | **Review for relevance** |
| `common/SC_Filesystem_iphone.cpp` | iPhone filesystem backend | **Review, may need for sandbox paths** |
| `common/SC_VFP11.h` | ARM VFP asm optimizations | **Must guard for arm64, remove legacy VFP** |
| `lang/LangPrimSource/OSCData.cpp` | In-process server boot with `SC_IPHONE` shared memory path | **Useful reference for in-proc boot** |
| `lang/LangPrimSource/PyrUnixPrim.cpp` | Unix command stubs for iPhone | **Stale, needs fresh approach** |
| `lang/LangPrimSource/PyrFilePrim.cpp` | Pipe primitives with `SC_IPHONE` early returns | **Reference for sclang phase** |
| `lang/LangPrimSource/SC_CoreMIDI.cpp` | Apple MIDI with iPhone compile branch | **Reusable with updates** |
| `SCClassLibrary/Platform/iphone/iPhonePlatform.sc` | iPhone platform class | **Update for modern iOS** |
| `SCClassLibrary/Platform/iphone/extMain.sc` | iPhone Main extensions | **Update** |
| `SCClassLibrary/Platform/iphone/SystemOverwrites/extFile.sc` | File class overrides | **Review** |

### Key CMake Variables

| Variable | Purpose | iOS Setting |
|----------|---------|-------------|
| `AUDIOAPI` | Audio backend selection | `coreaudioiphone` (new value) |
| `LIBSCSYNTH` | Build as shared/static library | `ON` (static for iOS) |
| `SCLANG_SERVER` | Link server into sclang | `OFF` for Phase 1 |
| `SC_QT` | Qt GUI support | `OFF` |
| `SC_IDE` | IDE target | `OFF` |
| `SUPERNOVA` | Alternative server | `OFF` |
| `NO_LIBSNDFILE` | Skip libsndfile | Evaluate |

---

## 4. Phase 0: Validation Spike

**Duration**: 1-2 days
**Goal**: Confirm assumptions, identify unknown blockers

### Tasks

- [ ] Attempt CMake configure with `-DCMAKE_SYSTEM_NAME=iOS -DCMAKE_OSX_ARCHITECTURES=arm64`
- [ ] Identify all compile errors without any code changes
- [ ] Catalog every `SC_IPHONE` usage and its current state
- [ ] Confirm `LIBSCSYNTH` target builds in isolation on macOS
- [ ] Inventory which UGen plugins have iOS-incompatible dependencies
- [ ] Verify Lua/libsndfile/boost headers compile for iOS
- [ ] Check submodule state (`git submodule update --init --recursive`)
- [ ] Run desktop scsynth test suite to establish baseline

### Validation Tests

```bash
# Test 1: Can CMake configure for iOS at all?
cmake -B build-ios -G Xcode \
  -DCMAKE_SYSTEM_NAME=iOS \
  -DCMAKE_OSX_ARCHITECTURES=arm64 \
  -DCMAKE_OSX_DEPLOYMENT_TARGET=16.0 \
  -DLIBSCSYNTH=ON \
  -DSC_QT=OFF \
  -DSC_IDE=OFF \
  -DSUPERNOVA=OFF \
  -DNO_AVAHI=ON \
  -DCMAKE_INSTALL_PREFIX=build-ios/install \
  2>&1 | tee ai/phase0-configure.log

# Test 2: What breaks in compilation?
cmake --build build-ios --target libscsynth 2>&1 | tee ai/phase0-build.log

# Test 3: Desktop baseline
cmake -B build-desktop && cmake --build build-desktop --target libscsynth
# Run any existing server tests
```

### Exit Criteria
- Complete list of compile errors categorized by: trivial fix, needs reimplementation, hard blocker
- Decision on whether to proceed or pivot

---

## 5. Phase 1: CMake iOS Build Lane

**Duration**: 3-5 days
**Goal**: `libscsynth` compiles for iOS arm64 (no audio yet, no plugins yet)

### Changes to `CMakeLists.txt` (top-level)

Add new option:
```cmake
option(SC_IOS "Build for iOS" OFF)

if(SC_IOS)
  # Force server-only configuration
  set(LIBSCSYNTH ON CACHE BOOL "" FORCE)
  set(SC_QT OFF CACHE BOOL "" FORCE)
  set(SC_IDE OFF CACHE BOOL "" FORCE)
  set(SUPERNOVA OFF CACHE BOOL "" FORCE)
  set(NO_AVAHI ON CACHE BOOL "" FORCE)
  set(SC_STATIC_PLUGINS ON CACHE BOOL "" FORCE)

  # Don't build sclang in Phase 1
  set(SC_BUILD_SCLANG OFF CACHE BOOL "" FORCE)

  # iOS deployment target
  if(NOT CMAKE_OSX_DEPLOYMENT_TARGET)
    set(CMAKE_OSX_DEPLOYMENT_TARGET "16.0")
  endif()

  # Audio API
  set(AUDIOAPI "coreaudioiphone" CACHE STRING "" FORCE)

  message(STATUS "SuperCollider iOS build: server-only, static plugins")
endif()
```

### Changes to `server/scsynth/CMakeLists.txt`

- Gate `scsynth` executable target behind `NOT SC_IOS`
- Add iOS-specific framework links: `AudioToolbox`, `AVFoundation`, `CoreAudio`, `CoreMIDI`, `Foundation`
- Remove macOS-only framework links when `SC_IOS`: `AppKit`
- Add new iOS source files to `libscsynth` target
- Set `POSITION_INDEPENDENT_CODE ON` for static lib

### Changes to `lang/CMakeLists.txt`

- Add guard: `if(SC_IOS AND NOT SC_BUILD_SCLANG) return() endif()`

### Changes to `external_libraries/CMakeLists.txt`

- Disable PortAudio, JACK when `SC_IOS`
- Ensure boost headers, tlsf compile for iOS

### Tests

```bash
# Test: iOS CMake configure succeeds
cmake -B build-ios -G Xcode \
  -DCMAKE_SYSTEM_NAME=iOS \
  -DSC_IOS=ON \
  -DCMAKE_OSX_ARCHITECTURES=arm64
# Expected: Configure completes without error

# Test: libscsynth compiles (may have link errors, that's Phase 2)
cmake --build build-ios --target libscsynth -- -sdk iphoneos
# Expected: Compiles, links may fail on missing plugin symbols

# Test: Desktop build still works (regression)
cmake -B build-desktop && cmake --build build-desktop --target libscsynth
# Expected: No regressions
```

---

## 6. Phase 2: Static Plugin Registration

**Duration**: 3-6 days
**Goal**: UGen plugins are statically linked into libscsynth, no dlopen

### Problem

`SC_Lib_Cintf.cpp` uses `dlopen`/`dlsym` to load `.scx` plugin bundles at runtime. This violates iOS App Store policy and doesn't work in static library builds.

### Solution

1. **New CMake variable**: `SC_STATIC_PLUGINS` (forced ON when `SC_IOS`)
2. **Plugin profile system**: `SC_PLUGIN_PROFILE` = `core` | `full`
   - `core`: Essential UGens only (~50 core synthesis/filter/math UGens)
   - `full`: All plugins that compile for iOS
3. **Generated registry**: CMake generates `SC_StaticPluginRegistry.cpp` from the plugin profile
4. **Boot-time registration**: `SC_Lib_Cintf.cpp` calls registry function instead of scanning directories

### File Changes

**`server/plugins/CMakeLists.txt`**:
- When `SC_STATIC_PLUGINS`: build each plugin as OBJECT library, not MODULE
- Generate `SC_StaticPluginRegistry.cpp` with forward declarations and registration calls
- Link all plugin objects into libscsynth

**`server/scsynth/SC_Lib_Cintf.cpp`**:
- Add `#if SC_STATIC_PLUGINS` branch in initialization
- Call `SC_RegisterStaticPlugins(InterfaceTable*)` instead of directory scan
- Preserve dynamic path for desktop builds

**New: `server/scsynth/SC_StaticPluginRegistry.cpp.in`** (CMake template):
```cpp
// AUTO-GENERATED — do not edit
#include "SC_PlugIn.h"

// Forward declarations
@PLUGIN_EXTERN_DECLARATIONS@

void SC_RegisterStaticPlugins(InterfaceTable* inTable) {
    @PLUGIN_REGISTRATION_CALLS@
}
```

### Plugin Inventory (Core Profile)

Essential UGens to include:
- **Oscillators**: SinOsc, Saw, Pulse, LFSaw, LFPulse, LFNoise0/1/2, WhiteNoise, PinkNoise, BrownNoise
- **Filters**: LPF, HPF, BPF, BRF, RLPF, RHPF, Resonz, MoogFF, SVF
- **Envelopes**: EnvGen, Linen, Line, XLine
- **Math/Logic**: BinaryOpUGen, UnaryOpUGen, MulAdd
- **Delays**: DelayN/L/C, CombN/L/C, AllpassN/L/C
- **Reverbs**: FreeVerb, GVerb
- **Dynamics**: Compander, Limiter, Normalizer
- **Triggers**: Trig, Trig1, TDuty, Demand, Dseq, Drand
- **Buffers**: PlayBuf, RecordBuf, BufRd, BufWr, LocalBuf
- **Panning**: Pan2, Balance2, LinPan2, Splay
- **I/O**: In, Out, LocalIn, LocalOut, InFeedback
- **Control**: Control, TrigControl, LagControl, NamedControl
- **FFT**: FFT, IFFT, PV_MagSmear, PV_BrickWall, etc.

### Tests

```bash
# Test: Static plugin registry generates correctly
cmake -B build-ios -DSC_IOS=ON
cat build-ios/server/scsynth/SC_StaticPluginRegistry.cpp
# Expected: Contains extern declarations and registration calls for core plugins

# Test: libscsynth links with static plugins
cmake --build build-ios --target libscsynth
# Expected: Successful link, no undefined symbols

# Test: Plugin count matches profile
# In test app: boot server, send /status, verify UGen count > 0

# Test: Desktop dynamic loading still works (regression)
cmake -B build-desktop && cmake --build build-desktop
# Run existing plugin load tests
```

---

## 7. Phase 3: Modern iOS Audio Backend

**Duration**: 5-8 days
**Goal**: Audio renders correctly on iOS devices with proper session management

### Current State

`SC_iCoreAudioDriver` exists but uses deprecated AudioSession API patterns and old AUGraph-era code. Needs modernization for:
- AVAudioSession (category, activation, interruption handling)
- RemoteIO AudioUnit (modern setup for arm64)
- Route change handling
- Background audio support

### New Files

**`server/scsynth/SC_iOSAudioSession.h`**:
```cpp
// C++ interface to AVAudioSession management
class SCiOSAudioSessionManager {
public:
    struct Config {
        double preferredSampleRate = 48000.0;
        int preferredBufferSize = 256;
        bool enableInput = true;
        bool mixWithOthers = false;
    };

    struct RuntimeConfig {
        double actualSampleRate;
        int actualBufferSize;
        int inputChannels;
        int outputChannels;
    };

    enum class State {
        Inactive, Active, Interrupted
    };

    using InterruptionCallback = std::function<void(bool began)>;
    using RouteChangeCallback = std::function<void(RuntimeConfig newConfig)>;

    bool configure(const Config& config);
    bool activate();
    void deactivate();
    State getState() const;
    RuntimeConfig getRuntimeConfig() const;

    void setInterruptionCallback(InterruptionCallback cb);
    void setRouteChangeCallback(RouteChangeCallback cb);
};
```

**`server/scsynth/SC_iOSAudioSession.mm`**:
- ObjC++ implementation wrapping AVAudioSession
- Notification observers for interruptions and route changes
- Thread-safe state management

### Modified Files

**`server/scsynth/SC_CoreAudio.h`**:
- Update `SC_iCoreAudioDriver` class for modern API
- Add state machine: `Stopped → Starting → Running → Interrupted → Stopped`
- Add audio session manager ownership

**`server/scsynth/SC_CoreAudio.cpp`**:
- Rewrite `SC_iCoreAudioDriver` implementation:
  - Use `AudioComponentInstanceNew` (not deprecated `AUGraphNewNode`)
  - kAudioUnitSubType_RemoteIO for input/output
  - Proper render callback with `AudioUnitRender` for input
  - Handle sample rate from session manager, not hardcoded
  - Interruption → stop audio unit, resume on end
  - Route change → check if SR/buffer changed, restart if needed

**`common/SC_VFP11.h`**:
- Guard all VFP asm with `#if !defined(__aarch64__)`
- arm64 uses NEON intrinsics via compiler, no manual asm needed

### Audio Flow

```
AVAudioSession.configure(playAndRecord, 48kHz, 256 frames)
         │
         ▼
AudioComponentInstanceNew(kAudioUnitSubType_RemoteIO)
         │
         ├── Input scope: enable mic/interface input
         ├── Output scope: enable speaker/headphone output
         ├── Set stream format: Float32, non-interleaved, 48kHz
         └── Set render callback: SC_iCoreAudioDriver::RenderCallback
                   │
                   ▼
            World_Run(numFrames)
            ├── Process synth graph
            ├── Write output buffers
            └── Read input buffers (if needed)
```

### Tests

```bash
# Test: Audio session activates on device (Sosumi or real device)
# Boot server, verify AVAudioSession.isActive == true

# Test: Sine wave renders
# Send /d_recv with SinOsc SynthDef, /s_new, verify audio output

# Test: Interruption recovery
# Simulate phone call interruption, verify audio resumes

# Test: Route change handling
# Plug/unplug headphones, verify audio continues

# Test: Background audio
# Background the app, verify audio continues rendering

# Test: Sample rate negotiation
# Request 48kHz, verify actual rate matches or gracefully adapts

# Test: Buffer size negotiation
# Request 256 frames, verify actual size and latency

# Test: Input works
# Send SoundIn UGen SynthDef, verify mic input passes through

# Test: No audio glitches under load
# Run complex synth graph, monitor for dropouts over 60 seconds
```

---

## 8. Phase 4: Public C API & XCFramework

**Duration**: 2-4 days
**Goal**: Clean, stable API for host apps; packaged as XCFramework

### New Files

**`server/scsynth/SC_iOSLibSynth.h`** (public C API):
```c
#ifndef SC_IOS_LIB_SYNTH_H
#define SC_IOS_LIB_SYNTH_H

#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

// Opaque server handle
typedef struct SCiOSServer* SCiOSServerRef;

// Configuration
typedef struct {
    double sampleRate;          // Preferred sample rate (48000.0)
    int blockSize;              // Audio block size (64)
    int numInputChannels;       // 0 to disable input
    int numOutputChannels;      // 2 for stereo
    int maxNodes;               // Max synth nodes (1024)
    int maxGraphDefs;           // Max SynthDef slots (1024)
    int realtimeMemorySize;     // RT memory in KB (8192)
    int numWireBufs;            // Wire buffers (64)
    int numAudioBusChannels;    // Audio buses (1024)
    int numControlBusChannels;  // Control buses (16384)
    int numSampleBuffers;       // Sample buffers (1024)
    bool verbose;               // Log to console
    const char* pluginSearchPath; // NULL for static-only
    const char* synthDefSearchPath; // Path to .scsyndef files
} SCiOSServerConfig;

// Callbacks
typedef void (*SCiOSEventCallback)(void* context, const char* event, const void* data, int dataSize);

// Lifecycle
SCiOSServerConfig SCiOSServerConfigDefault(void);
SCiOSServerRef SCiOSServerCreate(const SCiOSServerConfig* config, char* errorBuf, int errorBufSize);
bool SCiOSServerStart(SCiOSServerRef server);
void SCiOSServerStop(SCiOSServerRef server);
void SCiOSServerDestroy(SCiOSServerRef server);

// OSC communication (in-process, no network)
bool SCiOSServerSendOSC(SCiOSServerRef server, const uint8_t* packet, int packetSize);
void SCiOSServerSetOSCCallback(SCiOSServerRef server, SCiOSEventCallback callback, void* context);

// Status
bool SCiOSServerIsRunning(SCiOSServerRef server);
double SCiOSServerActualSampleRate(SCiOSServerRef server);
int SCiOSServerActualBlockSize(SCiOSServerRef server);
int SCiOSServerNumUGens(SCiOSServerRef server);
int SCiOSServerNumSynths(SCiOSServerRef server);
float SCiOSServerAvgCPU(SCiOSServerRef server);
float SCiOSServerPeakCPU(SCiOSServerRef server);

// Audio session events
void SCiOSServerSetInterruptionCallback(SCiOSServerRef server, SCiOSEventCallback callback, void* context);

// Utility
const char* SCiOSServerVersion(void);

#ifdef __cplusplus
}
#endif

#endif // SC_IOS_LIB_SYNTH_H
```

**`server/scsynth/SC_iOSLibSynth.cpp`**:
- Implementation wrapping `World_New`, `World_OpenUDP` (optional), `World_SendPacket`, `World_Cleanup`
- Thread safety for lifecycle operations
- Error handling with descriptive messages

### XCFramework Packaging

**New: `platform/iOS/build_xcframework.sh`**:
```bash
#!/bin/bash
set -euo pipefail

# Build for device
cmake -B build-ios-device -G Xcode \
  -DCMAKE_SYSTEM_NAME=iOS \
  -DSC_IOS=ON \
  -DCMAKE_OSX_ARCHITECTURES=arm64 \
  -DCMAKE_OSX_DEPLOYMENT_TARGET=16.0

cmake --build build-ios-device --config Release --target libscsynth -- -sdk iphoneos

# Build for simulator
cmake -B build-ios-sim -G Xcode \
  -DCMAKE_SYSTEM_NAME=iOS \
  -DSC_IOS=ON \
  -DCMAKE_OSX_ARCHITECTURES="arm64;x86_64" \
  -DCMAKE_OSX_DEPLOYMENT_TARGET=16.0

cmake --build build-ios-sim --config Release --target libscsynth -- -sdk iphonesimulator

# Create XCFramework
xcodebuild -create-xcframework \
  -library build-ios-device/server/scsynth/Release-iphoneos/libscsynth.a \
  -headers server/scsynth/SC_iOSLibSynth.h \
  -library build-ios-sim/server/scsynth/Release-iphonesimulator/libscsynth.a \
  -headers server/scsynth/SC_iOSLibSynth.h \
  -output build-xcframework/SuperCollider.xcframework
```

### Tests

```bash
# Test: XCFramework builds for both device and simulator
./platform/iOS/build_xcframework.sh
# Expected: SuperCollider.xcframework exists with both slices

# Test: Framework links in fresh Xcode project
# Create minimal iOS app, add xcframework, call SCiOSServerVersion()

# Test: C API lifecycle
# Create → Start → send /status OSC → verify response → Stop → Destroy
# Expected: No crashes, no leaks

# Test: Memory management
# Create/destroy server 100 times, verify no leaks with Instruments

# Test: Thread safety
# Start server, send OSC from multiple threads simultaneously
# Expected: No crashes, no data races (TSan clean)
```

---

## 9. Phase 5: Test App & Validation

**Duration**: 3-5 days
**Goal**: Working iOS app that validates the entire stack on real devices

### Test App Features

A minimal but functional iOS app (Swift + SwiftUI) that:

1. **Boots scsynth** via the C API
2. **Loads SynthDefs** from bundled `.scsyndef` files
3. **Plays sounds** via on-screen controls:
   - Sine wave with frequency slider
   - PolySynth with keyboard
   - Sample playback from buffer
   - Mic input processing (echo/reverb)
4. **Displays server status**: CPU, UGen count, synth count, sample rate
5. **Handles lifecycle**: background audio, interruptions, route changes
6. **Runs on real device** via Xcode or Sosumi

### SynthDef Asset Pipeline

Pre-compile SynthDefs on desktop:
```bash
# compile_synthdefs.scd — run with desktop sclang
SynthDef(\sine, { |out=0, freq=440, amp=0.3|
    Out.ar(out, SinOsc.ar(freq, 0, amp) ! 2);
}).writeDefFile("synthdefs/");

SynthDef(\ping, { |out=0, freq=440, amp=0.5, gate=1|
    var env = EnvGen.kr(Env.perc(0.01, 0.3), gate, doneAction: 2);
    Out.ar(out, SinOsc.ar(freq, 0, amp * env) ! 2);
}).writeDefFile("synthdefs/");

// ... more SynthDefs for test coverage
```

### Comprehensive Test Suite

#### Unit Tests (XCTest)

```swift
class SCiOSServerTests: XCTestCase {

    func testServerCreation() {
        var config = SCiOSServerConfigDefault()
        var error = [CChar](repeating: 0, count: 256)
        let server = SCiOSServerCreate(&config, &error, 256)
        XCTAssertNotNil(server)
        SCiOSServerDestroy(server)
    }

    func testServerStartStop() {
        // Create, start, verify running, stop, verify stopped
    }

    func testSendOSC() {
        // Boot server, send /d_recv, /s_new, verify synth created
    }

    func testSineWaveOutput() {
        // Boot server, play sine, verify non-zero audio output
    }

    func testMultipleSynths() {
        // Create 64 simultaneous synths, verify CPU < 100%
    }

    func testBufferLoading() {
        // Load audio file into buffer, play with PlayBuf
    }

    func testInputRouting() {
        // Enable input, route through effects, verify output
    }

    func testInterruptionRecovery() {
        // Simulate interruption, verify audio resumes
    }

    func testBackgroundAudio() {
        // Enter background, verify audio continues
    }

    func testMemoryPressure() {
        // Simulate memory warning, verify graceful behavior
    }

    func testCPUMonitoring() {
        // Verify avgCPU and peakCPU return sensible values
    }

    func testRepeatedCreateDestroy() {
        // 100x create/destroy cycle, verify no leaks
    }
}
```

#### Integration Tests

- Play complex SynthDef (FM synthesis with 8 operators)
- Run for 10 minutes continuous, check for dropouts
- Rapid synth creation/destruction (stress test node allocation)
- Large buffer allocation (load 5-minute stereo file)
- MIDI input triggers synths (if MIDI available)

#### Device Matrix

| Device | iOS Version | Test Priority |
|--------|-------------|---------------|
| iPhone 15/16 | iOS 18 | Primary |
| iPad Pro M-series | iPadOS 18 | Primary |
| iPhone SE 3 | iOS 16 | Minimum spec |
| iPad mini 6 | iPadOS 16 | Small screen |
| Simulator arm64 | Latest | CI |

---

## 10. Phase 6: sclang Feasibility

**Duration**: 2-3 weeks (investigation + prototype)
**Goal**: Determine if sclang can run on iOS and what subset is viable

### Challenges

| Issue | Severity | Mitigation |
|-------|----------|------------|
| Qt dependency | Medium | Already optional via `SC_QT=OFF` |
| `fork`/`exec`/`popen` (PyrUnixPrim) | High | Stub or reimplement with iOS-safe alternatives |
| `system()` calls | High | Stub |
| Carbon/IOKit framework links | Medium | Replace with iOS equivalents |
| Class library filesystem assumptions | Medium | Adapt paths for iOS sandbox |
| Process model (sclang as separate process) | High | Must run in-process on iOS |
| Dynamic class library compilation | Medium | Pre-compile or compile on first launch |
| Pipe primitive (File.sc, String.sc) | Medium | Stub — not meaningful on iOS |

### Approach

1. Build sclang with maximum features disabled
2. Stub all process-spawning primitives (return error, don't crash)
3. Use in-process server boot (`World_New`) instead of `unixCmd`
4. Adapt filesystem paths for iOS sandbox
5. Run class library compilation — this is the key test
6. If class library compiles: execute simple SC code, verify synth control
7. Profile memory and startup time

### Exit Criteria
- sclang boots and compiles class library on iOS: **proceed to Phase 7**
- sclang cannot compile class library: **stay with scsynth-only + precompiled SynthDefs**

---

## 11. Phase 7: Full iOS App

**Duration**: 4-8 weeks
**Goal**: A polished, App Store-quality SuperCollider app for iOS

### Features (prioritized)

#### Must Have (v1.0)
- scsynth audio engine with all core UGens
- Pre-compiled SynthDef library (50+ common SynthDefs)
- OSC control interface (receive from other apps/desktop)
- Audio input processing
- MIDI input/output (Bluetooth + USB)
- Background audio
- Interruption handling
- Audio session management (play and record category)

#### Should Have (v1.0)
- sclang interpreter (if Phase 6 succeeds)
- Code editor with SC syntax highlighting
- SynthDef compilation on-device
- File browser for scripts and SynthDefs
- Server status dashboard (CPU, nodes, UGens)
- Ableton Link support

#### Nice to Have (v1.x)
- AUv3 plugin mode (host scsynth in other apps)
- Inter-app audio (Audiobus SDK)
- Help browser with SC documentation
- Example scripts and tutorials
- iCloud sync for scripts
- MIDI Learn for control mapping

### UI Design Principles
- Clean, professional, respects the SC community aesthetic
- Not skeuomorphic — modern iOS design language
- Dark mode as primary (matches SC IDE aesthetic)
- Keyboard-friendly for iPad with external keyboard
- Accessibility: VoiceOver support for key controls

---

## 12. File-by-File Impact Matrix

| File | Phase | Change Type | Risk | Description |
|------|-------|-------------|------|-------------|
| `CMakeLists.txt` (top) | 1 | Modify | Medium | Add `SC_IOS` option, force server-only config |
| `lang/CMakeLists.txt` | 1 | Modify | Low | Guard against building sclang in iOS mode |
| `server/scsynth/CMakeLists.txt` | 1 | Modify | Medium | iOS sources, frameworks, lib-only target |
| `server/plugins/CMakeLists.txt` | 2 | Modify | High | Static plugin build, registry generation |
| `external_libraries/CMakeLists.txt` | 1 | Modify | Low | Disable desktop-only deps |
| `server/scsynth/SC_Lib_Cintf.cpp` | 2 | Modify | High | Static plugin init branch |
| `server/scsynth/SC_CoreAudio.h` | 3 | Modify | Medium | Update driver class interface |
| `server/scsynth/SC_CoreAudio.cpp` | 3 | Modify | High | Rewrite iPhone audio driver |
| `common/SC_VFP11.h` | 1 | Modify | Low | arm64 guards |
| `server/scsynth/SC_iOSAudioSession.h` | 3 | **New** | Medium | Audio session C++ interface |
| `server/scsynth/SC_iOSAudioSession.mm` | 3 | **New** | High | AVAudioSession implementation |
| `server/scsynth/SC_iOSLibSynth.h` | 4 | **New** | Low | Public C API |
| `server/scsynth/SC_iOSLibSynth.cpp` | 4 | **New** | Medium | API implementation |
| `server/scsynth/SC_StaticPluginRegistry.cpp.in` | 2 | **New** | Medium | CMake template for plugin registry |
| `platform/iOS/build_xcframework.sh` | 4 | **New** | Low | Build/package script |
| `platform/iOS/TestApp/` | 5 | **New** | Medium | Swift test application |
| `.github/workflows/build_ios.yml` | 4 | **New** | Low | CI pipeline |

---

## 13. Dependency Analysis

### Required (must compile for iOS)

| Dependency | Source | iOS Status | Action |
|------------|--------|------------|--------|
| **Boost (headers)** | Bundled | Headers-only, works | None |
| **tlsf** | Bundled | Pure C, works | None |
| **oscpack** | Bundled | Pure C++, works | None |
| **yaml-cpp** | Bundled | C++, should work | Verify |
| **libsndfile** | System/bundled | Has iOS builds | Build or vcpkg |

### Optional (can disable)

| Dependency | Purpose | iOS Action |
|------------|---------|------------|
| **PortAudio** | Audio backend | Disable (using CoreAudio) |
| **JACK** | Audio backend | Disable |
| **Qt** | GUI | Disable |
| **readline** | CLI | Disable |
| **avahi/dns_sd** | mDNS | Disable (use Bonjour directly if needed) |
| **libfftw3** | FFT | Evaluate; iOS has vDSP |
| **X11** | UI UGens | Disable |

### Problematic

| Dependency | Issue | Resolution |
|------------|-------|------------|
| **dlopen** (plugin loading) | App Store policy | Static plugins (Phase 2) |
| **fork/exec/popen** (sclang) | iOS sandbox | Stub (Phase 6) |
| **ALSA** | Linux-only | Not compiled on Apple |
| **Carbon/IOKit** (sclang) | macOS-only | iOS equivalents (Phase 6) |

---

## 14. Test Strategy

### Testing Philosophy

Every phase must have automated tests that run in CI and on real devices. We use:
- **XCTest** for unit and integration tests
- **Sosumi** (macOS iOS simulator automation) for headless CI testing
- **Real device testing** via Xcode for audio validation
- **Instruments** for memory/performance profiling

### Test Pyramid

```
         ┌──────────┐
         │  Device   │  Real device audio tests
         │  Tests    │  (manual + Xcode test plans)
         ├──────────┤
         │ Integr.  │  Full server boot, SynthDef load,
         │ Tests    │  audio render, lifecycle (Sosumi)
         ├──────────┤
         │   Unit   │  C API, plugin registry, session
         │  Tests   │  manager, OSC parsing (XCTest)
         ├──────────┤
         │  Build   │  CMake configure + compile for
         │  Tests   │  device + sim (CI, every commit)
    ─────┴──────────┴─────
```

### CI Pipeline (`.github/workflows/build_ios.yml`)

```yaml
name: iOS Build & Test
on: [push, pull_request]
jobs:
  build-ios:
    runs-on: macos-14
    steps:
      - uses: actions/checkout@v4
        with:
          submodules: recursive

      - name: Configure iOS build
        run: |
          cmake -B build-ios -G Xcode \
            -DCMAKE_SYSTEM_NAME=iOS \
            -DSC_IOS=ON \
            -DCMAKE_OSX_ARCHITECTURES=arm64

      - name: Build libscsynth (device)
        run: cmake --build build-ios --config Release --target libscsynth -- -sdk iphoneos

      - name: Build libscsynth (simulator)
        run: |
          cmake -B build-ios-sim -G Xcode \
            -DCMAKE_SYSTEM_NAME=iOS \
            -DSC_IOS=ON \
            -DCMAKE_OSX_ARCHITECTURES=arm64
          cmake --build build-ios-sim --config Release --target libscsynth -- -sdk iphonesimulator

      - name: Run simulator tests
        run: |
          xcodebuild test \
            -project platform/iOS/TestApp/SCiOSTest.xcodeproj \
            -scheme SCiOSTests \
            -destination 'platform=iOS Simulator,name=iPhone 16'

      - name: Build XCFramework
        run: ./platform/iOS/build_xcframework.sh

      - name: Upload artifacts
        uses: actions/upload-artifact@v4
        with:
          name: SuperCollider-iOS-xcframework
          path: build-xcframework/SuperCollider.xcframework

  build-desktop-regression:
    runs-on: macos-14
    steps:
      - uses: actions/checkout@v4
        with:
          submodules: recursive
      - name: Build desktop (regression test)
        run: |
          cmake -B build-desktop
          cmake --build build-desktop --target libscsynth
```

### Sosumi Integration

For automated device-like testing in CI:
```bash
# Boot iOS simulator via Sosumi
sosumi boot --device "iPhone 16" --ios 18.0

# Install test app
sosumi install build/TestApp.app

# Run test suite
sosumi test --scheme SCiOSTests --output test-results.xml

# Capture audio output for analysis
sosumi audio-capture --duration 5 --output test-audio.wav

# Verify audio is non-silent
python3 scripts/verify_audio.py test-audio.wav --min-rms 0.001
```

---

## 15. Risk Register

| # | Risk | Likelihood | Impact | Mitigation | Phase |
|---|------|-----------|--------|------------|-------|
| 1 | Static plugin symbol drift between builds | Medium | High | Generate registry from CMake source-of-truth; build fails on missing symbols | 2 |
| 2 | Audio route/interruption edge cases cause crashes | Medium | High | Explicit driver state machine + comprehensive device testing | 3 |
| 3 | Binary size too large with all static plugins | Low | Medium | Plugin profiles; strip unused symbols; bitcode | 2,4 |
| 4 | AVAudioSession conflicts with host app | Medium | Medium | Document single-owner policy; provide session config API | 3,4 |
| 5 | UGen plugins use macOS-only APIs | Low | Medium | Inventory in Phase 0; exclude problematic plugins | 0,2 |
| 6 | libsndfile iOS build issues | Low | Medium | Use ExtAudioFile wrapper as fallback | 1 |
| 7 | Memory pressure from large synth graphs | Medium | Medium | Document limits; test with complex patches; provide monitoring API | 5 |
| 8 | sclang class library compilation fails on iOS | High | Low (Phase 1 doesn't need it) | Phase 6 is explicitly investigatory | 6 |
| 9 | App Store rejection for code execution | Low | High | No JIT, no dlopen, no eval — scsynth is data-driven (SynthDefs are bytecode) | All |
| 10 | Upstream SC changes break iOS build | Medium | Medium | CI regression tests; rebase strategy documented | All |

---

## 16. Status Log

### 2026-03-14 — Project Initialized

- [x] Forked supercollider to github.com/danielraffel/supercollider
- [x] Created `ai/` directory with `.gitignore`
- [x] Completed comprehensive architecture analysis via RepoPrompt
- [x] Documented full iOS port plan
- [ ] Phase 0: Validation spike — **NEXT**

### Next Steps
1. Initialize git submodules
2. Run Phase 0 validation spike (CMake configure attempt)
3. Catalog compile errors
4. Begin Phase 1 CMake changes

---

## Appendix A: Useful Commands

```bash
# Initialize submodules (required first!)
cd /Users/danielraffel/Code/supercollider
git submodule update --init --recursive

# Quick iOS configure test
cmake -B build-ios -G Xcode \
  -DCMAKE_SYSTEM_NAME=iOS \
  -DCMAKE_OSX_ARCHITECTURES=arm64 \
  -DCMAKE_OSX_DEPLOYMENT_TARGET=16.0 \
  -DLIBSCSYNTH=ON \
  -DSC_QT=OFF \
  -DSC_IDE=OFF \
  -DSUPERNOVA=OFF \
  -DNO_AVAHI=ON

# Build for device
cmake --build build-ios --config Release -- -sdk iphoneos

# Build for simulator
cmake --build build-ios --config Release -- -sdk iphonesimulator

# Desktop regression test
cmake -B build-desktop && cmake --build build-desktop
```

## Appendix B: Key Source File Locations

```
server/scsynth/
├── CMakeLists.txt          # Server build config
├── SC_CoreAudio.h/cpp      # Audio drivers (including iPhone)
├── SC_Lib_Cintf.cpp        # Plugin loading (dlopen → static)
├── scsynth_main.cpp        # Standalone entry (not used on iOS)
├── SC_AU.h/cpp             # AudioUnit host driver
└── iPhone/                 # Legacy iOS app shell (reference)

server/plugins/
├── CMakeLists.txt          # Plugin build config
├── iPhoneUGens.mm          # iPhone-specific UGens
└── *.cpp                   # Individual UGen source files

common/
├── SC_Filesystem_iphone.cpp # iOS filesystem backend
├── SC_VFP11.h              # ARM asm (needs arm64 guard)
└── sc_popen.cpp            # Process spawning (stub on iOS)

lang/                       # sclang (Phase 6+)
├── CMakeLists.txt
├── LangPrimSource/
│   ├── OSCData.cpp         # In-process server boot
│   ├── PyrUnixPrim.cpp     # Unix commands (stub on iOS)
│   └── SC_CoreMIDI.cpp     # Apple MIDI
└── LangSource/
    ├── PyrInterpreter3.cpp # Bytecode VM
    └── PyrLexer.cpp        # Class library compiler

SCClassLibrary/Platform/iphone/  # sclang class library (Phase 6+)
```
