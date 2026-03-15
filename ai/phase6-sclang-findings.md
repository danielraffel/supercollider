# Phase 6: sclang iOS Feasibility — Findings

## Verdict: sclang WORKS on iOS

libsclang builds and runs successfully on iOS arm64. The class library compiles, the interpreter executes SC code, and synths can be created — all on the iOS simulator.

## Runtime Test Results (iOS Simulator, iPhone 16 Pro, iOS 18.4)

| Test | Result | Details |
|------|--------|---------|
| libsclang build | PASS | Builds as static library for iOS arm64 |
| sclang init | PASS | SC_LanguageClient creates, runtime initializes |
| Class library compile | PASS | 334 files, 5629 methods, 2314 classes |
| Compile time | 148ms | Fast — no performance concern |
| Memory delta | 34.8 MB | From 240.8 to 275.6 MB — acceptable |
| Simple interpret (`1 + 1`) | PASS | Expression evaluates correctly |
| Synth creation (`{ SinOsc.ar }.play`) | PASS | Synth plays audio on simulator |
| Shutdown | PASS | Clean shutdown, no crashes |

## New Files Created

### Public API
- `lang/SC_iOSSclang.h` — C API for sclang on iOS (init, compile, interpret, shutdown)
- `lang/SC_iOSSclang.cpp` — Implementation wrapping SC_LanguageClient

### Filesystem
- `common/SC_Filesystem_iphone.cpp` — Added `SC_Filesystem_SetResourceDir()` so host apps can point sclang to the app bundle for SCClassLibrary

### Build System
- `platform/iOS/build_xcframework.sh` — Updated with `--with-sclang` option to merge libsclang + dependencies into XCFramework

### Test App
- `platform/iOS/TestApp/SCiOSTest/SclangEngine.swift` — Swift wrapper for sclang C API
- SCClassLibrary bundled as app resource via xcodegen `type: folder`

## Changes Required (all completed)

### CMake Changes (lang/CMakeLists.txt)
1. **Framework links**: Guard Carbon/IOKit/CoreServices (macOS-only) behind `if(NOT SC_IOS)`. Link CoreMIDI, CoreFoundation, Foundation, AudioToolbox for iOS instead.
2. **SC_Apple.mm**: Exclude on iOS (imports Cocoa).
3. **sclang executable**: Skip building on iOS (only build libsclang static library).
4. **SC_IOS define**: Add `target_compile_definitions(libsclang PUBLIC SC_IOS=1)` for iOS builds.
5. **SC_iOSSclang.cpp**: Added to iOS build via `target_sources`.

### Source Changes
1. **SC_AudioDevicePrim.cpp**: Guard `CoreAudio/AudioHardware.h` and device listing functions with `!defined(SC_IOS)` — desktop-only audio device enumeration API.
2. **PyrSched.cpp**: Use `mach/mach_time.h` on iOS instead of `CoreAudio/HostTime.h`.
3. **PyrUnixPrim.cpp**: Guard `system()` call with `SC_IOS` (returns -1 on iOS). Fix popen guards to use `callerSlot` instead of `a`.
4. **SC_CoreMIDI.cpp**: Update SC_IPHONE guards to also accept SC_IOS (`SC_IPHONE || SC_IOS`).
5. **PyrFilePrim.cpp**: Update SC_IPHONE guards for popen and CoreServices to also accept SC_IOS.
6. **OSCData.cpp**: Update SC_IPHONE guards for shared memory ID and prConnectSharedMem to also accept SC_IOS.

### Top-level CMakeLists.txt
- Added `SC_IOS_SCLANG` option to allow building lang/ alongside SC_IOS server build.

## In-Process Server Boot

The existing `_BootInProcessServer` primitive in `OSCData.cpp` already calls `World_New()` for in-process scsynth. The `iPhonePlatform.sc` class sets `Server.internal` as the default server, which uses in-process boot. No additional work needed.

## Filesystem Integration

`SC_Filesystem_iphone.cpp` provides iOS-specific path resolution:
- `defaultResourceDirectory()` → `~/Documents/` (default) or custom app bundle path via `SC_Filesystem_SetResourceDir()`
- `defaultUserAppSupportDirectory()` → `~/Documents/`
- Host apps call `SCiOSSclangSetResourceDir()` before init to point to the app bundle

## Process Spawning (fork/exec/popen/system)
All process-spawning primitives are guarded for iOS:
- `system()` — returns -1 on iOS (SC_IOS guard)
- `sc_popen_shell()` — returns 0 on iOS (SC_IPHONE/SC_IOS guard)
- `sc_popen_argv()` — returns 0 on iOS (SC_IPHONE/SC_IOS guard)
- `fork()/execvp()` — guarded by the callers above

## macOS Framework Dependencies
| Framework | Status | iOS Alternative |
|-----------|--------|-----------------|
| Carbon | Excluded on iOS | Not needed |
| CoreAudio (desktop API) | Excluded on iOS | AudioToolbox |
| CoreMIDI | Available on iOS | Same API |
| CoreServices | Excluded on iOS | Not needed |
| IOKit | Excluded on iOS | Not needed |
| CoreFoundation | Available on iOS | Same API |

## Qt Dependencies
Completely optional, already gated behind `SC_QT`/`SC_IDE` flags (both forced OFF for iOS).

## Decision: PROCEED with sclang Integration

sclang works fully on iOS. The class library compiles in 148ms with only 34.8 MB memory overhead. SC code executes correctly and can create synths. This enables on-device SynthDef compilation, live coding, and full SuperCollider scripting on iOS.

### Remaining Work for Full Integration (Phase 7)
1. Add sclang interpreter UI to test app (code editor + post window)
2. Bundle SCClassLibrary + Extensions in production app
3. Handle platform-specific primitives gracefully (file dialogs, GUI, etc.)
4. Test complex SC patterns, Routines, and server control
5. Profile sustained sclang usage and memory
