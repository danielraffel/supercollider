# Actions from Codex Review

> Generated 2026-03-14 from CODEX_REVIEW.md findings

## Critical Corrections to Plan

### 1. `LIBSCSYNTH=ON` builds SHARED, not STATIC
- **Fix**: Must add `BUILD_SHARED_LIBS=OFF` or change libscsynth target type when `SC_IOS=ON`
- **Where**: `server/scsynth/CMakeLists.txt:149-153`

### 2. `AUDIOAPI=coreaudioiphone` doesn't exist yet
- **Fix**: Must add `coreaudioiphone` to the accepted values in both `server/scsynth/CMakeLists.txt:25-37` and `lang/CMakeLists.txt:105-117`
- **Or**: Use a separate `SC_IOS` flag to select the iPhone CoreAudio driver path

### 3. `lang/` is unconditionally entered at `CMakeLists.txt:453-456`
- **Fix**: Must add explicit guard: `if(NOT SC_IOS)` around lang subdirectory entry
- **Not enough**: `SCLANG_SERVER=OFF` only affects linking, doesn't skip lang build

### 4. macOS-only code triggered by `APPLE` flag
Must handle these files that assume macOS when `APPLE` is true:
- `common/SC_Apple.mm` — imports Cocoa
- `common/SC_AppleEventLoop.mm` — Cocoa-only
- `server/scsynth/CMakeLists.txt:253-255` — links AppKit unconditionally on Apple
- `server/plugins/CMakeLists.txt:298-301` — links AppKit for UIUGens on Apple
- `cmake_modules/MacAppFolder.cmake` — assumes .app/Contents/...
- **Fix**: Use `CMAKE_SYSTEM_NAME STREQUAL "iOS"` to distinguish from macOS throughout

### 5. No Lua in the SC tree
- **Fix**: Remove "Verify Lua..." from Phase 0 tasks. Lua is a norns dependency, not SC.

### 6. Static plugin mechanism is stale, not new
- **Fix**: Acknowledge existing `STATIC_PLUGINS` branch in `SC_Lib_Cintf.cpp:103-128` and `SC_InterfaceTable.h:230-248`
- Registry should operate at **plugin-module level**, not individual UGen level
- Must update stale load list (missing: Chaos, DemoUGens, LinkUGen, ML_UGens, PV_ThirdParty, UIUGens, UnpackFFTUGens, BELA)
- Must fix `deinitialize_library()` hardcoded unload calls

### 7. Process-global plugin init vs embeddable API
- `SC_World.cpp:316-321` uses `gLibInitted` flag
- `World_Cleanup()` can call `deinitialize_library()` without resetting the flag
- **Fix**: Must address lifecycle semantics before publishing "create/destroy 100 times" API

### 8. iPhone filesystem paths map to Documents, not app bundle
- `SC_Filesystem_iphone.cpp:102-113` maps to sandboxed Documents area
- **Fix**: Define clear resource/sandbox model BEFORE freezing the public C API

## Additional Files to Track

| File | Relevance |
|------|-----------|
| `server/CMakeLists.txt` | Parent CMake for server subdirectories |
| `common/SC_Apple.mm` | macOS Cocoa code, must exclude on iOS |
| `common/SC_AppleEventLoop.mm` | Cocoa-only, must exclude on iOS |
| `server/plugins/UIUGens.mm` | Uses AppKit, must exclude on iOS |
| `server/plugins/IOUGens.cpp` | Has SC_IPHONE conditionals |
| `include/plugin_interface/SC_InterfaceTable.h` | Static plugin declarations |
| `include/common/clz.h` | Has SC_IPHONE conditional |
| `SCClassLibrary/Common/Audio/iphone/iPhoneUGens.sc` | sclang wrapper for accel UGens |
| `cmake_modules/MacAppFolder.cmake` | macOS .app bundle assumptions |

## Additional CMake Options for Phase 1

Force these in the iOS lane:
- `NO_X11=ON`
- `SC_ABLETON_LINK=OFF` (defer to later phase)
- `SC_HIDAPI=OFF`
- `ENABLE_TESTSUITE=OFF` initially, then `ON`

## iOS App Configuration Requirements

- `NSMicrophoneUsageDescription` in Info.plist
- `UIBackgroundModes: audio` in Info.plist
- Local network permission if UDP/TCP OSC is exposed
- Clear documentation: no third-party `.scx` loading on iOS

## Plugin Exclusions for iOS Core Profile

Must exclude:
- `UIUGens` (AppKit dependency)
- `iPhoneUGens` (deprecated UIAccelerometer, not in current CMake)
- `BelaUGens` (hardware-specific)
- `Link_UGen` (defer to later phase)
- `DiskIO_UGens` (if libsndfile not yet available)

## Revised Phase 1 Focus (per Codex recommendation)

1. Add explicit iOS build mode that cleanly separates iOS from generic `APPLE`
2. Skip `lang/` entirely
3. Disable/exclude macOS-only Apple sources and UIUGens
4. Replace stale `STATIC_PLUGINS` with generated module-level registry
5. Rewrite audio backend around `AVAudioSession` + modern RemoteIO
6. Define resource/sandbox model before public API freeze

## Status
- [ ] Update IOS_PORT_PLAN.md with all corrections
- [ ] Begin Phase 0 validation spike with corrected assumptions
