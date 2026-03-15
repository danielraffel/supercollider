# Phase 0 Validation Spike — Findings

> **Date**: 2026-03-14
> **Status**: Complete — proceed to Phase 1

## Submodules

All submodules initialized successfully:
- `nova-simd` ✓ (required)
- `nova-tt` ✓ (required)
- `yaml-cpp` ✓ (required)
- `portaudio` ✓ (not needed for iOS, but present)
- `portmidi` ✓ (not needed for iOS)
- `hidapi` ✓ (disabled for iOS)
- `link` ✓ (disabled for iOS Phase 1)

## CMake Configure

CMake configures for iOS **without errors** when using:
```
cmake -B build-ios -DCMAKE_SYSTEM_NAME=iOS -DCMAKE_OSX_ARCHITECTURES=arm64 \
  -DLIBSCSYNTH=ON -DSC_QT=OFF -DSC_IDE=OFF -DSUPERNOVA=OFF -DNO_AVAHI=ON \
  -DNO_X11=ON -DSC_HIDAPI=OFF -DSC_ABLETON_LINK=OFF
```

Key observations:
- Audio API defaults to `coreaudio` (not `coreaudioiphone` — that value doesn't exist yet)
- `lang/` is still entered (no guard exists)
- Bundled libsndfile is used (system libsndfile not found for iOS)
- vDSP used for FFT (correct for Apple platforms)

## Compile Errors

### Fatal: `CoreAudio/AudioHardware.h` not found (trivial fix)

`SC_CoreAudio.h:54` includes macOS-only `CoreAudio/AudioHardware.h` when `SC_AUDIO_API == SC_AUDIO_API_COREAUDIO`. Since `SC_IPHONE` is never defined by CMake, the code falls through to the macOS path. Fix: define `SC_AUDIO_API_COREAUDIOIPHONE` when building for iOS.

### Secondary: `SC_Apple.mm` imports Cocoa (trivial fix)

`common/SC_Apple.mm` is included in the libscsynth sources on all `APPLE` platforms. It imports Cocoa, which doesn't exist on iOS. Fix: exclude from iOS builds.

### Categorized error list:

| Error | Category | Fix |
|-------|----------|-----|
| `CoreAudio/AudioHardware.h` not found | Trivial | Gate with iOS check in SC_CoreAudio.h |
| `SC_Apple.mm` imports Cocoa | Trivial | Exclude from iOS sources |
| `SC_AppleEventLoop.mm` uses Cocoa | Trivial | Already only in scsynth executable, not libscsynth |
| AppKit framework linked on all Apple | Trivial | Gate with `NOT iOS` |
| `dlopen`/`dlsym` in `SC_Lib_Cintf.cpp` | Needs reimplementation | Static plugin registry (Phase 2) |
| UIUGens uses AppKit | Already handled | `NO_X11=ON` excludes it |

## LIBSCSYNTH Target

- `LIBSCSYNTH=ON` builds **SHARED** library (not STATIC as plan assumed)
- `LIBSCSYNTH=OFF` builds **STATIC** library
- For iOS: must force STATIC (`LIBSCSYNTH=OFF` or override library type)

## AUDIOAPI

Accepted values: `default|coreaudio|jack|portaudio|bela`
- `coreaudioiphone` is NOT accepted — will need to add it or use `SC_IOS` flag

## SC_IPHONE Usages (codebase grep)

Source files with `SC_IPHONE` conditionals:
1. `server/scsynth/SC_CoreAudio.h` — audio API selection
2. `server/scsynth/SC_CoreAudio.cpp` — iPhone audio driver, timing
3. `server/scsynth/SC_Lib_Cintf.cpp` — static plugin loading
4. `server/scsynth/Rendezvous.cpp` — Bonjour exclusion
5. `server/plugins/IOUGens.cpp` — I/O configuration
6. `server/plugins/iPhoneUGens.mm` — accelerometer UGens (deprecated)
7. `server/plugins/FFT_UGens.cpp` — FFT library selection
8. `common/SC_Filesystem_iphone.cpp` — iOS sandbox paths
9. `common/SC_Filesystem_macos.cpp` — macOS exclusion guard
10. `include/common/clz.h` — arm32 fallback CLZ
11. `lang/LangPrimSource/OSCData.cpp` — in-process server boot
12. `lang/LangPrimSource/PyrFilePrim.cpp` — pipe stubs
13. `lang/LangPrimSource/PyrUnixPrim.cpp` — unix cmd stubs
14. `lang/LangPrimSource/SC_CoreMIDI.cpp` — MIDI conditionals

**Critical**: `SC_IPHONE` is never defined by current CMake. All legacy iPhone code is dormant.

## STATIC_PLUGINS Branch

Exists at `SC_Lib_Cintf.cpp:103-128` and `167-192`. State:
- Stale — missing: Chaos, DemoUGens, LinkUGen, ML_UGens, PV_ThirdParty, UIUGens, UnpackFFTUGens
- References `iPhone_Load` which isn't built
- `deinitialize_library()` hardcodes `DiskIO_Unload()` and `UIUGens_Unload()`
- `SC_InterfaceTable.h:230-248` has `STATIC_PLUGINS` macro definitions

## SC_iCoreAudioDriver

Exists at `SC_CoreAudio.h:286-317` and `SC_CoreAudio.cpp:1919-2437`.
- Uses deprecated `AudioSession*` APIs
- Hardcodes 44100 Hz
- Empty destructor (resource leak)
- No AVAudioSession usage
- No route change or interruption handling
- Uses legacy integer conversion in render path
- **Verdict**: Reference only. Full rewrite needed.

## SC_VFP11.h

All VFP assembly (`fmrx`, `fldmias`, etc.) is ARM32 VFP instructions.
- Already guarded with `#if !TARGET_IPHONE_SIMULATOR` but NOT guarded for arm64
- Will fail to compile on arm64 iOS device builds
- Fix: guard with `#if !defined(__aarch64__)`

## clz.h

`SC_IPHONE` branch at line 79 provides `__builtin_clz` — but `__GNUC__` branch at line 39 already provides the same thing. On arm64 iOS with clang (which defines `__GNUC__`), the `__GNUC__` branch is hit first, so this works without changes.

## Plugin Incompatibilities

| Plugin | Issue | Action |
|--------|-------|--------|
| UIUGens | AppKit dependency | Exclude (`NO_X11=ON`) |
| iPhoneUGens | Deprecated UIAccelerometer, not in CMake | Do not include |
| BelaUGens | Hardware-specific | Not built without Bela |
| Link_UGen | Ableton Link dependency | Exclude Phase 1 (`SC_ABLETON_LINK=OFF`) |
| DiskIO_UGens | libsndfile dependency | Include if bundled sndfile works |

## Desktop Baseline

- Desktop macOS libscsynth builds successfully as static library
- Configure + build with `SC_QT=OFF SC_IDE=OFF` works cleanly

## lang/ Unconditionally Entered

`CMakeLists.txt:454` — `add_subdirectory(lang)` with no guard.
- Must add `if(NOT SC_IOS)` guard

## Decision

**Proceed to Phase 1.** All blockers are well-understood and fixable:
1. Add `SC_IOS` CMake option with proper gating
2. Fix `SC_CoreAudio.h` includes for iOS
3. Exclude macOS-only sources on iOS
4. Guard VFP assembly for arm64
5. Skip `lang/` on iOS
