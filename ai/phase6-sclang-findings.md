# Phase 6: sclang iOS Feasibility — Findings

## Verdict: sclang CAN build for iOS

libsclang builds successfully for iOS arm64 with minimal modifications. The existing SC_IPHONE guards in the codebase already handle most iOS-incompatible code paths.

## Changes Required (all completed)

### CMake Changes (lang/CMakeLists.txt)
1. **Framework links**: Guard Carbon/IOKit/CoreServices (macOS-only) behind `if(NOT SC_IOS)`. Link CoreMIDI, CoreFoundation, Foundation, AudioToolbox for iOS instead.
2. **SC_Apple.mm**: Exclude on iOS (imports Cocoa).
3. **sclang executable**: Skip building on iOS (only build libsclang static library).
4. **SC_IOS define**: Add `target_compile_definitions(libsclang PUBLIC SC_IOS=1)` for iOS builds.

### Source Changes
1. **SC_AudioDevicePrim.cpp**: Guard `CoreAudio/AudioHardware.h` and device listing functions with `!defined(SC_IOS)` — desktop-only audio device enumeration API.
2. **PyrSched.cpp**: Use `mach/mach_time.h` on iOS instead of `CoreAudio/HostTime.h`.
3. **PyrUnixPrim.cpp**: Guard `system()` call with `SC_IOS` (returns -1 on iOS). Fix popen guards to use `callerSlot` instead of `a`.
4. **SC_CoreMIDI.cpp**: Update SC_IPHONE guards to also accept SC_IOS (`SC_IPHONE || SC_IOS`).
5. **PyrFilePrim.cpp**: Update SC_IPHONE guards for popen and CoreServices to also accept SC_IOS.
6. **OSCData.cpp**: Update SC_IPHONE guards for shared memory ID and prConnectSharedMem to also accept SC_IOS.

### Top-level CMakeLists.txt
- Added `SC_IOS_SCLANG` option to allow building lang/ alongside SC_IOS server build.

## Error Catalog (before fixes)
Only 3 compile errors were encountered:
1. `CoreAudio/AudioHardware.h` not found — macOS desktop audio API
2. `CoreAudio/HostTime.h` not found — macOS time conversion
3. `system()` unavailable on iOS — process spawning banned

## Process Spawning (fork/exec/popen/system)
All process-spawning primitives are now guarded for iOS:
- `system()` — returns -1 on iOS (SC_IOS guard)
- `sc_popen_shell()` — returns 0 on iOS (SC_IPHONE/SC_IOS guard in PyrUnixPrim.cpp)
- `sc_popen_argv()` — returns 0 on iOS (SC_IPHONE/SC_IOS guard in PyrUnixPrim.cpp/PyrFilePrim.cpp)
- `fork()/execvp()` — in sc_popen.cpp, guarded by the callers above

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

## Next Steps for Full sclang Integration
1. Attempt class library compilation (SCClassLibrary)
2. Test interpreter startup and simple SC code execution
3. Profile memory usage and startup time
4. Integrate with in-process scsynth via World_New
5. Adapt filesystem paths for iOS sandbox
