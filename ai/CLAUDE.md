# SuperCollider iOS Port — Coding Standards & Rules

## Project Identity

This is a production-quality iOS port of SuperCollider's scsynth audio engine. The goal is an App Store-ready, community-respectable port — not a hack, not a proof-of-concept.

**Fork**: github.com/danielraffel/supercollider
**Working directory**: /Users/danielraffel/Code/supercollider
**Plans & status**: ai/ directory

## Mandatory Rules

### Architecture
- **iOS ≠ macOS**: Use `CMAKE_SYSTEM_NAME STREQUAL "iOS"` to distinguish from macOS. Never assume `APPLE` means macOS.
- **Server-first**: Build scsynth/libscsynth before sclang. Don't mix concerns.
- **Static only**: No `dlopen`, no `.scx` dynamic loading on iOS. All plugins statically linked.
- **In-process**: scsynth runs in-process via `World_New`, not as a separate executable.
- **Single audio owner**: Only one component owns AVAudioSession. Document which one.

### CMake
- All iOS changes gated behind `SC_IOS` option (new, does not exist upstream)
- `LIBSCSYNTH=ON` builds SHARED by default — must force STATIC for iOS
- `lang/` is unconditionally entered in top-level CMake — must add explicit `if(NOT SC_IOS)` guard
- Force: `SC_QT=OFF`, `SC_IDE=OFF`, `SUPERNOVA=OFF`, `NO_AVAHI=ON`, `NO_X11=ON`, `SC_HIDAPI=OFF`, `SC_ABLETON_LINK=OFF` (Phase 1)
- Desktop builds must never regress — always test both iOS and desktop configs

### Code Quality
- No deprecated APIs (AudioSession*, UIAccelerometer, AUGraph for new code)
- Modern Objective-C++ (ARC, no manual retain/release, no NSAutoreleasePool)
- arm64 only — no VFP asm, no 32-bit code paths
- All new code must have tests
- Follow existing SC coding style (see `CODE_OF_CONDUCT.md` and existing patterns)

### Testing
- Use RepoPrompt to validate changes against the real codebase at every step
- Use XcodeBuildMCP for building and testing iOS targets
- Run desktop regression tests after every iOS change
- Test on both device (arm64) and simulator
- Memory: no leaks (validate with Instruments or ASan)
- Threading: no races (validate with TSan)
- Audio: no glitches under sustained load

### Git
- Commit at end of every meaningful iteration
- Small, focused commits aligned to work items
- Imperative commit messages: "Add SC_IOS CMake option" not "Added SC_IOS"
- Never force push to main
- Never commit build artifacts, .DS_Store, or IDE project files

### Documentation
- Update `ai/work-items.md` status after completing each item
- Update `ai/IOS_PORT_PLAN.md` Status Log section with progress
- Document any blockers, discoveries, or architecture decisions in `ai/`

## Key Files Reference

### Must modify for iOS port
| File | Why |
|------|-----|
| `CMakeLists.txt` | Add `SC_IOS` option, gate `lang/` |
| `server/scsynth/CMakeLists.txt` | iOS sources, static lib, framework links |
| `server/plugins/CMakeLists.txt` | Static plugin build, exclude macOS-only |
| `external_libraries/CMakeLists.txt` | Disable desktop-only deps |
| `server/scsynth/SC_CoreAudio.h/cpp` | Rewrite iPhone audio driver |
| `server/scsynth/SC_Lib_Cintf.cpp` | Replace stale STATIC_PLUGINS with generated registry |
| `common/SC_VFP11.h` | Guard legacy VFP asm for arm64 |

### Must exclude on iOS (macOS-only)
| File | Why |
|------|-----|
| `common/SC_Apple.mm` | Imports Cocoa |
| `common/SC_AppleEventLoop.mm` | Cocoa-only event loop |
| `server/plugins/UIUGens.mm` | Links AppKit |
| `cmake_modules/MacAppFolder.cmake` | .app/Contents/ assumptions |

### New files to create
| File | Purpose |
|------|---------|
| `server/scsynth/SC_iOSAudioSession.h/mm` | AVAudioSession wrapper |
| `server/scsynth/SC_iOSLibSynth.h/cpp` | Public C API |
| `server/scsynth/SC_StaticPluginRegistry.cpp.in` | CMake-generated plugin registry |
| `platform/iOS/build_xcframework.sh` | Build + package script |
| `platform/iOS/TestApp/` | Swift validation app |
| `.github/workflows/build_ios.yml` | CI pipeline |

## Critical Corrections (from Codex Review)

1. `LIBSCSYNTH=ON` builds SHARED not STATIC — force STATIC for iOS
2. `lang/` unconditionally entered — needs explicit guard
3. `APPLE` flag triggers macOS code — must separate iOS vs macOS
4. Old iPhone code is REFERENCE ONLY — do not reuse as implementation base
5. Static plugin mechanism exists but is STALE — replace with generated module-level registry
6. Plugin init is PROCESS-GLOBAL — must handle lifecycle for embeddable API
7. iPhone filesystem maps to Documents, not app bundle — define sandbox model early
8. No Lua in SC tree — that's a norns dependency

## Validation Checklist (run after every phase)

- [ ] `cmake -B build-ios -DSC_IOS=ON` configures without error
- [ ] `cmake --build build-ios --target libscsynth` compiles for iOS arm64
- [ ] `cmake -B build-desktop && cmake --build build-desktop` still works (regression)
- [ ] No macOS-only frameworks linked when building for iOS
- [ ] No dlopen/dlsym calls in iOS code paths
- [ ] Tests pass on simulator
- [ ] Memory clean (no leaks)
- [ ] Thread clean (no races)
