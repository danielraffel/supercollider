# SuperCollider iOS Port — Status & Feature Comparison

> Last Updated: 2026-03-16
> Branch: develop
> Deployment Target: iOS 16.0+

---

## Summary

Both **scsynth** (audio server) and **sclang** (language interpreter) are fully ported to iOS arm64. The core synthesis engine is complete. Missing features are either iOS platform restrictions or deferred for post-launch.

---

## What's Ported

### scsynth (Audio Server) — ✅ Complete

| Feature | Status | Details |
|---------|--------|---------|
| Audio driver | ✅ | CoreAudio iPhone (AVAudioSession + RemoteIO) |
| Audio output | ✅ | 2 channels stereo, 48kHz |
| Audio input | ✅ | 1 channel mic (requires permission) |
| FFT | ✅ | Apple Accelerate (vDSP) — same as macOS |
| SIMD | ✅ | nova-simd optimizations |
| Static plugins | ✅ | 26 plugin modules linked into libscsynth |
| Default Group 1 | ✅ | Created in World_New at C++ level |
| Output bus zeroing | ✅ | Silence when no synths running |
| Interruption handling | ✅ | AVAudioSession interruption/route change |
| Background audio | ✅ | UIBackgroundModes: audio |

### UGen Plugin Modules (26 total)

| Module | UGens | Status |
|--------|-------|--------|
| BinaryOp | +, -, *, /, etc. | ✅ |
| Chaos | Logistic, Henon, etc. | ✅ |
| Delay | DelayL, DelayC, CombL, AllpassL, etc. | ✅ |
| Demand | Dseq, Drand, Dwhite, etc. | ✅ |
| DemoUGens | — | ✅ |
| DiskIO | DiskIn, DiskOut, VDiskIn | ✅ (requires libsndfile) |
| DynNoise | LFDNoise0/1/3, LFDClipNoise | ✅ |
| FFT_UGens | FFT, IFFT, PV_* | ✅ |
| Filter | LPF, HPF, BPF, RLPF, MoogFF, etc. | ✅ |
| Gendyn | Gendy1, Gendy2, Gendy3 | ✅ |
| Grain | GrainSin, GrainBuf, GrainFM, GrainIn | ✅ |
| IO | In, Out, LocalIn, LocalOut, SoundIn | ✅ |
| LF | LFSaw, LFPulse, LFNoise0/1/2, etc. | ✅ |
| ML_UGens | BeatTrack, MFCC, Onsets, Loudness, KeyTrack | ✅ |
| MulAdd | MulAdd | ✅ |
| Noise | WhiteNoise, PinkNoise, BrownNoise, Dust, Crackle | ✅ |
| Osc | SinOsc, Saw, Pulse, Blip, etc. | ✅ |
| Pan | Pan2, Balance2, Splay, etc. | ✅ |
| PhysicalModeling | Pluck, Ball, Spring, TBall | ✅ |
| PV_ThirdParty | PV_MagFreeze, PV_BrickWall, etc. | ✅ |
| Reverb | FreeVerb, GVerb | ✅ |
| Test | — | ✅ |
| Trigger | Trig, TrigControl, SendTrig, etc. | ✅ |
| UnaryOp | abs, neg, sqrt, etc. | ✅ |
| UnpackFFT | Unpack1FFT, UnpackFFT | ✅ |

### Excluded UGen Modules

| Module | Reason |
|--------|--------|
| UIUGens (MouseX/Y/Button/KeyState) | Linker symbol ordering issue with XCFramework. Code exists in UIUGens_iOS.cpp but not linked. |
| iPhoneUGens (deprecated accelerometer) | Legacy code, uses deprecated UIAccelerometer API |
| BelaUGens | Bela platform only |
| Link_UGen | Ableton Link disabled (SC_ABLETON_LINK=OFF) |

---

### sclang (Language Interpreter) — ✅ Complete

| Feature | Status | Details |
|---------|--------|---------|
| libsclang build | ✅ | Static library for iOS arm64 |
| Class library compilation | ✅ | 334 files, 5629 methods, 2314 classes in ~0.2s |
| Code interpretation | ✅ | `SCiOSSclangInterpret()` C API |
| In-process server | ✅ | `_BootInProcessServer` → `World_New` |
| Server.internal | ✅ | Connected via `SCiOSSclangConnectToServer` |
| Filesystem (sandbox) | ✅ | Documents/, Extensions/, tmp/ |
| startup.scd | ✅ | Loaded from ~/Documents/startup.scd |
| Class library recompile | ✅ | `SCiOSSclangRecompileLibrary()` |
| User extensions | ✅ | ~/Documents/Extensions/ auto-scanned |

### Primitive/Feature Status

| Feature | macOS | iOS | Notes |
|---------|-------|-----|-------|
| File I/O | ✅ Full | ⚠️ Sandbox | App Documents/Library/tmp only |
| system() | ✅ | ❌ Returns -1 | iOS sandbox restriction |
| popen/fork/exec | ✅ | ❌ Returns 0 | iOS sandbox restriction |
| Audio device listing | ✅ | ❌ Disabled | No AudioHardware.h on iOS |
| CoreMIDI | ✅ | ✅ | Full support |
| OSC (UDP) | ✅ Network | ✅ In-process | Network OSC possible via host app |
| SoundFile | ✅ | ✅ | libsndfile cross-compiled |

---

### SCClassLibrary — ✅ Bundled

| Item | Status | Details |
|------|--------|---------|
| Core classes | ✅ | Bundled in app bundle as folder resource |
| Platform override | ✅ | `IPhonePlatform.sc` with iOS defaults |
| Extensions dir | ✅ | ~/Documents/Extensions/ |
| Pattern system | ✅ | Pbind, Pseq, Prand, Pdef, etc. |
| JITLib | ✅ | Ndef, NodeProxy, ProxySpace |
| MIDI classes | ✅ | MIDIClient, MIDIIn, MIDIOut, MIDIFunc |
| OSC classes | ✅ | NetAddr, OSCFunc, OSCdef |
| Buffer classes | ✅ | Buffer.alloc, .read, .write |
| Recorder | ✅ | Via Buffer.write + libsndfile |

---

### External Libraries

| Library | macOS | iOS | Notes |
|---------|-------|-----|-------|
| libsndfile | System/bundled | ✅ Cross-compiled | FetchContent 1.2.2 |
| Boost | Bundled | ✅ | thread, program_options, regex |
| yaml-cpp | Bundled | ✅ | Config parsing |
| tlsf | ✅ | ✅ | Memory allocator |
| nova-simd | ✅ | ✅ | SIMD headers |
| PortAudio | ✅ | ❌ | Not used (CoreAudio only) |
| JACK | ✅ | ❌ | Not available on iOS |
| Qt | ✅ | ❌ | Replaced by native SwiftUI |
| Readline | ✅ | ❌ | Not needed (editor replaces REPL) |

---

## Missing Features vs macOS

### Platform Restrictions (Cannot Fix)

| Feature | Reason |
|---------|--------|
| fork/exec/system/popen | iOS sandbox prohibits process spawning |
| dlopen (dynamic plugins) | iOS requires static linking |
| Full filesystem access | App sandbox — Documents/Library/tmp only |
| Background unlimited CPU | iOS throttles background audio apps |

### Deferred for Post-Launch

| Feature | Effort | Priority |
|---------|--------|----------|
| UIUGens (MouseX/Y via pointer) | Medium — linker fix needed | High |
| Accelerometer UGens (AccelX/Y/Z) | Medium — CoreMotion permission | High |
| Ableton Link | Medium — re-enable SC_ABLETON_LINK | Medium |
| HID support | Low — enable SC_HIDAPI | Low |
| Network OSC (WiFi control) | Low — add UDP in host app | Medium |
| AUv3 plugin mode | High — new app extension | Medium |
| Audiobus | Medium — SDK integration | Low |
| Multi-channel I/O (>2ch) | Low — ServerOptions change | Low |

### Intentionally Excluded

| Feature | Reason |
|---------|--------|
| Qt GUI / SC IDE | Replaced by native SwiftUI app |
| Bonjour/Avahi | Not useful for in-process server |
| SerialPort | No serial on iOS |
| X11 | Not applicable |
| Supernova | Single-threaded server sufficient for mobile |

---

## iOS App Features

### Implemented

| Feature | Status |
|---------|--------|
| Code editor with syntax highlighting | ✅ |
| Post window (sclang output) | ✅ |
| Server control panel (CPU, synths, UGens) | ✅ |
| File browser (Scripts, Examples) | ✅ |
| Long-press block selection (bracket-matched) | ✅ |
| Two-finger tap to evaluate | ✅ |
| Three-finger tap to stop all | ✅ |
| Play/Stop buttons | ✅ |
| CmdPeriod (stop all patterns + synths) | ✅ |
| Auto-evaluate SynthDefs on file open | ✅ |
| Keyboard inset adjustment | ✅ |
| Autosave with version gating | ✅ |
| Multi-block file protection | ✅ |
| Dark mode | ✅ |
| App icon | ✅ |
| iPad sidebar layout | ✅ |
| iPhone tab layout | ✅ |
| Bundled tutorials | ✅ |

### Planned (UX Spec in ai/ux-editor-spec.md)

| Feature | Priority |
|---------|----------|
| Pages-style document browser | High |
| Read/Edit mode toggle | High |
| Templates | Medium |
| Evaluate feedback (green flash) | Medium |
| Post as bottom panel | Medium |
| Settings screen | Low |
| Help browser | Low |

---

## Build Configuration

### CMake iOS Mode

```
-DSC_IOS=ON
-DCMAKE_SYSTEM_NAME=iOS
-DCMAKE_OSX_ARCHITECTURES=arm64
-DCMAKE_OSX_DEPLOYMENT_TARGET=16.0
```

### Forced Settings

```
LIBSCSYNTH=OFF          → Static library
SC_QT=OFF               → No Qt
SC_IDE=OFF              → No IDE
SUPERNOVA=OFF           → Single-threaded
NO_AVAHI=ON             → No Bonjour
NO_X11=ON               → No X11
SC_HIDAPI=OFF           → No HID
SC_ABLETON_LINK=OFF     → No Link
SC_STATIC_PLUGINS=ON    → Plugins in binary
SC_IPHONE=1             → Legacy macro bridge
```

### Optional sclang

```
-DSC_IOS_SCLANG=ON      → Build libsclang
-DSCLANG_SERVER=ON       → Link libscsynth into libsclang
```

---

## Architecture

```
┌─────────────────────────────────────┐
│         SwiftUI App Shell           │
│  (Editor, Post, Server, Files)      │
├─────────────┬───────────────────────┤
│  AppState   │    CodeTextView       │
│  (Swift)    │    (UITextView)       │
├─────────────┴───────────────────────┤
│         C API Bridge                │
│  SC_iOSLibSynth.h  SC_iOSSclang.h  │
├─────────────┬───────────────────────┤
│  libscsynth │    libsclang          │
│  (C++)      │    (C++)              │
├─────────────┴───────────────────────┤
│    26 UGen Plugins (static)         │
├─────────────────────────────────────┤
│  libsndfile │ boost │ yaml-cpp │tlsf│
├─────────────────────────────────────┤
│    AVAudioSession + RemoteIO        │
│    CoreMIDI                         │
│    Accelerate (vDSP FFT)            │
└─────────────────────────────────────┘
```

---

## Key Files

| File | Purpose |
|------|---------|
| `server/scsynth/SC_iOSLibSynth.h/cpp` | C API for scsynth |
| `server/scsynth/SC_iOSAudioSession.h/mm` | AVAudioSession manager |
| `server/scsynth/SC_CoreAudio.cpp` (iOS section) | RemoteIO audio driver |
| `server/scsynth/SC_World.cpp` | Default Group 1 creation |
| `lang/SC_iOSSclang.h/cpp` | C API for sclang |
| `common/SC_Filesystem_iphone.cpp` | iOS sandbox paths |
| `SCClassLibrary/Platform/iphone/` | Platform class + overrides |
| `platform/iOS/build_xcframework.sh` | XCFramework build script |
| `platform/iOS/TestApp/` | SwiftUI app |
| `cmake_modules/FindSndfileIOS.cmake` | libsndfile cross-compile |
| `server/plugins/UIUGens_iOS.cpp` | MouseX/Y stubs (not linked yet) |
