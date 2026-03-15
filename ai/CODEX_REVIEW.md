# Review of `ai/IOS_PORT_PLAN.md` Against the Actual SuperCollider Tree

## Verdict

The plan is directionally sound on the big picture: server-first, static plugins, modern iOS audio, then an embeddable C API. The problem is that it overestimates how much of the existing iPhone code and current CMake can be reused as-is. The current iOS-related code is mostly dormant, partially stale, and in a few places more archival than reusable.

If the goal is a production-quality iOS port the SuperCollider community would respect, the port should treat the old iPhone code as reference material, not as an implementation base.

## 1. CMake Variables: What Exists vs. What Does Not

- `LIBSCSYNTH` exists at `CMakeLists.txt:98`, but the plan gets its semantics wrong. In `server/scsynth/CMakeLists.txt:149-153`, `LIBSCSYNTH=ON` builds `libscsynth` as `SHARED`, not static.
- `AUDIOAPI` exists at `CMakeLists.txt:86`.
- `SC_QT` exists at `CMakeLists.txt:102`.
- `SC_IDE` exists at `CMakeLists.txt:103`.
- `SUPERNOVA` exists at `CMakeLists.txt:117`.
- `NO_LIBSNDFILE` exists at `CMakeLists.txt:123`.
- `NO_AVAHI` exists at `CMakeLists.txt:125-128`.
- `SCLANG_SERVER` exists at `CMakeLists.txt:130`.

- `SC_IOS` does not exist anywhere in current CMake.
- `SC_STATIC_PLUGINS` does not exist anywhere in current CMake.
- `SC_PLUGIN_PROFILE` does not exist anywhere in current CMake.
- `SC_BUILD_SCLANG` does not exist anywhere in current CMake.

Important mismatches:

- `AUDIOAPI` currently only accepts `default|coreaudio|jack|portaudio|bela` in both `server/scsynth/CMakeLists.txt:25-37` and `lang/CMakeLists.txt:105-117`. The plan's proposed `coreaudioiphone` value is not currently accepted.
- `SCLANG_SERVER=OFF` only stops linking `libscsynth` into `libsclang` at `lang/CMakeLists.txt:246-250`. It does not skip building `lang/`.
- Top-level CMake still unconditionally enters `lang/` at `CMakeLists.txt:453-456`, so an iOS server-only lane needs a real gate there, not just `SCLANG_SERVER=OFF`.

Additional relevant options the plan should mention for an initial iOS lane:

- `NO_X11` at `CMakeLists.txt:112`
- `SC_HIDAPI` at `CMakeLists.txt:160`
- `SC_ABLETON_LINK` at `CMakeLists.txt:162`
- `ENABLE_TESTSUITE` at `CMakeLists.txt:114`

## 2. File Paths: Mostly Correct, but Some Are Archival or Missing from the Plan

The following paths in the plan are real:

- `server/scsynth/SC_CoreAudio.h`
- `server/scsynth/SC_CoreAudio.cpp`
- `server/scsynth/SC_Lib_Cintf.cpp`
- `server/scsynth/iPhone/`
- `common/SC_Filesystem_iphone.cpp`
- `server/plugins/iPhoneUGens.mm`
- `SCClassLibrary/Platform/iphone/iPhonePlatform.sc`
- `SCClassLibrary/Platform/iphone/extMain.sc`
- `SCClassLibrary/Platform/iphone/SystemOverwrites/extFile.sc`

However:

- `server/scsynth/iPhone/` is not referenced by current CMake at all.
- `server/plugins/iPhoneUGens.mm` exists, but is not built by current `server/plugins/CMakeLists.txt`.
- The plan missed `SCClassLibrary/Common/Audio/iphone/iPhoneUGens.sc`, which is the language-side wrapper for the accelerometer UGens.

Additional files the plan should explicitly account for:

- `server/CMakeLists.txt:12-17`
- `common/SC_Apple.mm:23`
- `common/SC_AppleEventLoop.mm:23`
- `server/plugins/UIUGens.mm:25`
- `server/plugins/IOUGens.cpp:24-26`
- `include/plugin_interface/SC_InterfaceTable.h:230-248`
- `include/common/clz.h:79-83`
- `cmake_modules/MacAppFolder.cmake:1-22`

## 3. `SC_IPHONE` Conditionals: They Exist, but the Plan's Table Is Not Precise

Actual source files containing `SC_IPHONE` today:

- `common/SC_Filesystem_iphone.cpp`
- `common/SC_Filesystem_macos.cpp`
- `include/common/clz.h`
- `lang/LangPrimSource/OSCData.cpp`
- `lang/LangPrimSource/PyrFilePrim.cpp`
- `lang/LangPrimSource/PyrUnixPrim.cpp`
- `lang/LangPrimSource/SC_CoreMIDI.cpp`
- `server/plugins/FFT_UGens.cpp`
- `server/plugins/IOUGens.cpp`
- `server/plugins/iPhoneUGens.mm`
- `server/scsynth/Rendezvous.cpp`
- `server/scsynth/SC_CoreAudio.cpp`
- `server/scsynth/SC_CoreAudio.h`
- `server/scsynth/SC_Lib_Cintf.cpp`

Important corrections:

- The plan's "Files with `SC_IPHONE` conditionals" table includes files that do not actually test `SC_IPHONE`, such as the `server/scsynth/iPhone/*` app shell files and the `.sc` class library files under `SCClassLibrary/Platform/iphone/`.
- `SC_IPHONE` is not defined anywhere in current CMake. I found zero CMake references. That means the legacy iPhone code path is dormant under the current build system.

Practical consequence:

- The port is not "turn on an existing iPhone lane". It is "reconnect a dormant legacy lane, or replace it cleanly".

## 4. `SC_iCoreAudioDriver`: It Exists, but It Is Not Close to Production

The class exists at:

- `server/scsynth/SC_CoreAudio.h:286-317`
- `server/scsynth/SC_CoreAudio.cpp:1919-2437`

Assessment of the current implementation:

- It uses deprecated `AudioSession*` APIs at `server/scsynth/SC_CoreAudio.cpp:2233-2259`.
- The interruption callback is empty at `server/scsynth/SC_CoreAudio.cpp:2233`.
- It hard-codes `44100` Hz at `server/scsynth/SC_CoreAudio.cpp:2249-2263`, `2344`, and `2356`.
- It uses `AUGraph` plus a separate `AudioComponentInstanceNew` RemoteIO instance in the same setup path at `server/scsynth/SC_CoreAudio.cpp:2264-2285`, which is a legacy and awkward design.
- It does not use `AVAudioSession`.
- It has no route change handling, no modern interruption recovery, and no background-audio policy.
- The destructor is empty at `server/scsynth/SC_CoreAudio.cpp:1922`, so buffers, graph objects, and units are not cleaned up there.
- It allocates fixed-size scratch buffers at `server/scsynth/SC_CoreAudio.cpp:2304-2315` instead of sizing from the real negotiated I/O format.
- It still uses old integer conversion tricks in the render path at `server/scsynth/SC_CoreAudio.cpp:1988-2005`.

This is useful as archeology, not as a modern implementation base. The plan is right to rewrite it, but the current document understates how complete that rewrite needs to be.

## 5. Static Plugin Branch in `SC_Lib_Cintf.cpp`: Yes, It Exists, but It Is Stale

There is already a static plugin path:

- `server/scsynth/SC_Lib_Cintf.cpp:103-128`
- `server/scsynth/SC_Lib_Cintf.cpp:167-192`
- `include/plugin_interface/SC_InterfaceTable.h:230-248`

This means the plan is not starting from zero. But that branch is stale in multiple ways:

- Current CMake never defines `STATIC_PLUGINS`.
- The hard-coded static load list omits current plugin modules:
  - `Chaos`
  - `DemoUGens`
  - `LinkUGen`
  - `ML_UGens`
  - `PV_ThirdParty`
  - `UIUGens`
  - `UnpackFFTUGens`
  - `BELA`
- It references `iPhone_Load` at `server/scsynth/SC_Lib_Cintf.cpp:124` and `187-189`, but `server/plugins/iPhoneUGens.mm` is not built by current CMake.
- `deinitialize_library()` hard-codes `DiskIO_Unload()` and `UIUGens_Unload()` at `server/scsynth/SC_Lib_Cintf.cpp:131-134`, which is brittle for any generated-profile system.

Conclusion:

- The generated-registry idea is good.
- The plan should explicitly say it is replacing a stale `STATIC_PLUGINS` mechanism, not introducing the concept for the first time.

## 6. Current Plugin Build System: Module-Based `.scx`, Not UGen-by-UGen

Current plugin build behavior in `server/plugins/CMakeLists.txt`:

- It builds one `MODULE` target per plugin translation unit at `server/plugins/CMakeLists.txt:58-63`.
- It forces module suffix `.scx` at `server/plugins/CMakeLists.txt:55-56`.
- FFT-related plugins are separate module targets at `103-135`.
- `DiskIO_UGens` is optional on libsndfile at `150-174`.
- `Link_UGen` is optional on `SC_ABLETON_LINK` at `137-148`.
- `UIUGens` is built on Apple with AppKit at `90-101` and linked with AppKit at `298-301`.
- Supernova duplicates its own module builds at `183-246`.

Important implications for the plan:

- A static iOS registry should operate at the plugin-module level, not at the individual UGen name level shown in the plan's "Core Profile" list.
- A credible iOS profile needs explicit exclusions for at least:
  - `UIUGens`
  - `iPhoneUGens` unless rewritten
  - `BelaUGens`
  - probably `Link_UGen` in the initial lane
  - `DiskIO_UGens` if `libsndfile` is not solved yet

Also note:

- `NO_X11=OFF` still builds `UIUGens` on Apple through AppKit. For iOS, that must be turned off or split explicitly.

## 7. Submodule Status: The Checkout Is Not Ready to Configure

Current `git submodule status --recursive` shows these uninitialized:

- `editors/sc-el`
- `editors/scvim`
- `external_libraries/hidapi`
- `external_libraries/link`
- `external_libraries/nova-simd`
- `external_libraries/nova-tt`
- `external_libraries/portaudio/portaudio_submodule`
- `external_libraries/portmidi/portmidi_submodule`
- `external_libraries/yaml-cpp`

This matters immediately:

- Configure already fails on missing submodules at `external_libraries/CMakeLists.txt:1-7`.
- The fatal check is for `nova-simd`, so at minimum that must exist even before deeper work starts.

What likely matters for a server-only iOS lane:

- Required or effectively required:
  - `external_libraries/nova-simd`
  - `external_libraries/nova-tt`
- Probably avoidable if you trim the initial lane correctly:
  - `external_libraries/hidapi`
  - `external_libraries/link`
  - `external_libraries/yaml-cpp`
  - `external_libraries/portaudio/portaudio_submodule`
  - `external_libraries/portmidi/portmidi_submodule`

One more correction:

- The tree does not build a bundled libsndfile. It uses `find_package(Sndfile)` in `server/scsynth/CMakeLists.txt:183-199` and `server/plugins/CMakeLists.txt:1-5`. The plan's "system/bundled" wording is too loose.

## 8. Gaps and Inaccuracies in the Plan

### Major factual inaccuracies

- `LIBSCSYNTH=ON` is not "static for iOS". It is shared today.
- `AUDIOAPI=coreaudioiphone` does not exist in current CMake validation.
- `SC_BUILD_SCLANG` does not exist.
- `SCLANG_SERVER=OFF` does not skip the language build.
- "Verify Lua..." is inaccurate. There is no Lua dependency in this tree.

### Major build-graph gaps

- Top-level Apple handling is macOS-biased:
  - `cmake_modules/MacAppFolder.cmake:1-22` assumes `.app/Contents/...`.
  - `server/scsynth/CMakeLists.txt:104-113` includes `common/SC_Apple.mm`, which imports Cocoa.
  - `server/scsynth/CMakeLists.txt:253-255` links `AppKit` on all Apple builds.
  - `server/plugins/CMakeLists.txt:298-301` links `AppKit` for `UIUGens` on all Apple builds.
  - `common/SC_AppleEventLoop.mm:23` is Cocoa-only.

- `server/scsynth/iPhone/` is more stale than the plan suggests:
  - `server/scsynth/iPhone/iSCSynthController.mm:91` still calls `World_OpenUDP(world, 57110)`, but the current API is `World_OpenUDP(World*, const char*, int)` at `include/server/SC_WorldOptions.h:111`.
  - It uses deprecated `AudioSessionSetProperty` at `server/scsynth/iPhone/iSCSynthController.mm:42-43` and `140-147`.
  - It still uses manual retain/release patterns and `NSAutoreleasePool`.

- `server/plugins/iPhoneUGens.mm` is also much staler than "review for relevance" suggests:
  - It uses deprecated `UIAccelerometer` at `server/plugins/iPhoneUGens.mm:37`, `172`, and `202`.
  - It is excluded on simulator builds at `server/plugins/iPhoneUGens.mm:23`.
  - It is not built by current CMake.

### Architectural gaps the plan should address explicitly

- If the new option is `SC_IOS`, the plan needs a clean bridge strategy for all existing `SC_IPHONE` code. Right now the document mixes a new build flag with an old source flag but does not explain how they connect.
- `common/SC_Filesystem_iphone.cpp:102-113` and `113` map user/resource paths into the sandboxed Documents area, not the app bundle. That directly affects how bundled SynthDefs and resources are found.
- `server/scsynth/SC_World.cpp:316-321` uses a process-global `gLibInitted` flag, but `World_Cleanup(..., unload_plugins=true)` can call `deinitialize_library()` at `925-946` without resetting that flag. The plan's "create/destroy 100 times" API test is not aligned with the current lifecycle design.
- The current static plugin machinery assumes process-global plugin init, not per-server registration. A public SDK API needs explicit lifecycle semantics.

## 9. Additional Files and Considerations the Plan Missed

Files:

- `server/CMakeLists.txt`
- `common/SC_Apple.mm`
- `common/SC_AppleEventLoop.mm`
- `server/plugins/UIUGens.mm`
- `server/plugins/IOUGens.cpp`
- `include/plugin_interface/SC_InterfaceTable.h`
- `include/common/clz.h`
- `SCClassLibrary/Common/Audio/iphone/iPhoneUGens.sc`
- `cmake_modules/MacAppFolder.cmake`

Build/config considerations:

- Force `NO_X11=ON` for early iOS work unless UIUGens is split out cleanly.
- Consider `SC_ABLETON_LINK=OFF` for Phase 1 unless Link is explicitly in-scope.
- Consider `SC_HIDAPI=OFF` for Phase 1 if `lang/` is skipped.
- The initial plan should distinguish "server-only iOS static library" from "full Apple build" much earlier in CMake.

Product/platform considerations:

- `NSMicrophoneUsageDescription`
- `UIBackgroundModes` for audio
- Local network / Bonjour permission story if UDP/TCP OSC remains part of the public app behavior
- A clear statement that arbitrary third-party `.scx` loading is not part of iOS, because App Store policy makes desktop-style extension loading non-credible

Class library considerations for later sclang work:

- `SCClassLibrary/Platform/iphone/iPhonePlatform.sc:21` calls `Server.internal.makeWindow`
- `SCClassLibrary/Platform/iphone/iPhonePlatform.sc:36` uses `systemCmd`
- `SCClassLibrary/Platform/iphone/SystemOverwrites/extFile.sc` is a workaround for sandbox/path behavior, not a full modern file model

## Production Assessment

What feels production-grade in the current plan:

- Server-first sequencing
- Static plugin requirement
- AVAudioSession-based rewrite instead of trying to preserve old AudioSession code
- Public C API as a stable wrapper over libscsynth internals

What still feels hacky or incomplete:

- Treating the old iPhone code as more reusable than it is
- Treating static plugins as a new concept instead of acknowledging the stale legacy implementation already in-tree
- Missing the `LIBSCSYNTH` shared-vs-static mismatch
- Missing the fact that `lang/` is still unconditionally entered
- Not accounting for Apple-wide macOS assumptions currently triggered by `APPLE`
- Not addressing the current resource-path model on iPhone
- Not addressing process-global plugin/library initialization when proposing an embeddable, repeatedly creatable server API

## Recommended Adjustment

For an upstream-quality iOS effort, Phase 1 should be reframed as:

1. Add an explicit iOS build mode that cleanly separates iOS from generic `APPLE`.
2. Skip `lang/` entirely in the first lane.
3. Disable or exclude macOS-only Apple sources and UIUGens.
4. Replace the stale `STATIC_PLUGINS` path with a generated module-level registry.
5. Rewrite the audio backend around `AVAudioSession` and modern RemoteIO.
6. Define a resource/sandbox model for SynthDefs and bundled assets before the public API is frozen.

That path is much more likely to produce something the SuperCollider community would consider serious.
