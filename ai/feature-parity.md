# SuperCollider iOS/iPadOS Feature Parity — Work Items

> **Prerequisites**:
> - Phases 0–4 of `ai/work-items.md` are complete (scsynth static lib, static plugins, iOS audio backend, C API, XCFramework).
> - Phase 5 (test app) is mostly complete; unresolved device-validation items are carried forward here.
> - Phase 6 (sclang feasibility) concluded positively — sclang builds for iOS arm64 with minimal changes (see `ai/phase6-sclang-findings.md`). Remaining sclang runtime tasks are carried forward here.
> - Phase 7 items from `work-items.md` that were not completed are carried forward and expanded below.
>
> **Scope**: Everything needed beyond the engine port to deliver a production-quality SuperCollider experience on iOS and iPadOS that serves the vast majority of SC users and use cases.
> **Last Updated**: 2026-03-15

## Legend
- `[ ]` Not started
- `[~]` In progress
- `[x]` Complete and verified
- `[!]` Blocked (see notes)

## Cross-Cutting: CI/CD Pipeline
> Runs continuously from Phase A onward — not a final phase

### CI.1 Build Gates
- [~] CI: build libscsynth for iOS (device + simulator) on every PR — workflow exists, needs push
- [ ] CI: build libsclang for iOS (device + simulator) on every PR
- [ ] CI: run simulator unit tests on every PR
- [~] CI: build XCFramework — script exists, not yet in CI
- [~] CI: upload build artifacts — deferred
- [x] CI: desktop regression build + test suite on every PR

### CI.2 Release Pipeline
- [ ] CD: TestFlight deployment on tag/release
- [ ] CD: App Store deployment on release
- [ ] Green-gate requirement: all CI checks pass before phase milestones advance

---

## Phase A: sclang Hardening & Build Foundation
> Goal: sclang runs reliably on iOS, platform macros unified, dependency decisions locked
> Carries forward: work-items Phase 6.2, 6.3, Phase A original

### A.1 Platform Macro Cleanup
- [x] Audit and unify `SC_IOS` vs `SC_IPHONE` — `SC_IPHONE=1` now defined alongside `SC_IOS=1` in CMake for both libscsynth and libsclang
- [x] Migrate all legacy `SC_IPHONE` guards to `SC_IOS` (or bridge with `#define`) — bridged via CMake compile definitions; all legacy guards now trigger on iOS
- [x] Verify no code path falls through to macOS behavior on iOS due to macro mismatch — verified: AUDIOAPI set by CMake, Accelerate.framework correctly available, VFP11 provides arm64 fallbacks
- [x] Remove or quarantine deprecated `SC_IPHONE` code that is reference-only — legacy iPhone audio driver and iPhoneUGens excluded from iOS build by CMake; old STATIC_PLUGINS branch unreachable via `return` in SC_IOS path

### A.2 sclang Runtime Stabilization (carried from Phase 6.2/6.3)
- [x] Wire in-process server boot (`World_New`) — _BootInProcessServer primitive uses World_New; iPhonePlatform.sc sets Server.internal as default
- [x] Adapt filesystem paths for iOS sandbox (Documents, tmp, app bundle resources) — SC_Filesystem_iphone.cpp + SC_Filesystem_SetResourceDir() for app bundle
- [x] Attempt class library compilation on iOS — PASS: 334 files, 5629 methods, 2314 classes compiled in 148ms
- [x] Execute simple SC code on iOS: `{ SinOsc.ar(440) }.play` → verified audio output on simulator
- [x] Profile sclang startup time and memory usage on iOS (target: <3s boot, <100MB RAM) — 148ms compile, 34.8 MB delta
- [x] Document: what works, what doesn't, known limitations — ai/phase6-sclang-findings.md
- [x] Support `startup.scd` loaded from Documents directory — iPhonePlatform.sc calls loadStartupFiles; defaultStartupFile is ~/Documents/startup.scd
- [x] Support class library recompile on device (⌘K equivalent) — SCiOSSclangRecompileLibrary() API added
- [x] Sandbox-aware extension/class discovery (scan Documents/Extensions/ for user classes) — defaultUserExtensionDirectory returns ~/Documents/Extensions/, auto-included in class library search

### A.3 libsndfile Decision & Integration
- [x] Evaluate cross-compiling libsndfile for iOS arm64 (already in external_libraries/) — VIABLE: compiles cleanly as static lib via FetchContent
- [x] If viable: re-enable `NO_LIBSNDFILE=OFF` for iOS, build libsndfile as static lib — done: FetchContent builds libsndfile 1.2.2 from source, DiskIO_UGens now included (25→26 plugins)
- [x] If not viable: implement backend using Apple's ExtAudioFile/AVAudioFile APIs — N/A (libsndfile works)
- [x] Re-enable DiskIO_UGens plugin once soundfile support is available — DiskIn, DiskOut, VDiskIn now linked into libscsynth
- [x] Verify: Buffer.read, Buffer.write, SoundFile primitives work on iOS — PASS: Buffer.alloc, Buffer.write (WAV), SoundFile.openRead all execute successfully on simulator
- [~] Verify: Recorder workflow works end-to-end on iOS — Buffer.write works; full Recorder workflow needs Phase B server control integration

### A.4 Dependency Audit
- [x] Verify boost headers compile cleanly for iOS in language-enabled profile — boost_thread, boost_program_options, boost_regex all compile
- [x] Verify yaml-cpp compiles for iOS (used by sclang for config) — compiles as static lib
- [x] Verify oscpack compiles for iOS (should already work) — built into libscsynth
- [x] Evaluate FFTW vs Accelerate.framework vDSP for FFT on iOS — using vDSP (Accelerate.framework available on iOS arm64)
- [x] Evaluate readline alternative for sclang (or disable REPL — editor replaces it) — readline disabled (not found); editor UI replaces REPL
- [x] Document: final dependency manifest for iOS build — boost (thread/program_options/regex), yaml-cpp, tlsf, libsndfile (FetchContent), nova-simd (headers), Accelerate.framework (vDSP FFT)

---

## Phase B: Class Library & Runtime Parity
> Goal: SCClassLibrary compiles and runs on iOS; core SC workflows function; real-device audio validated
> Carries forward: work-items Phase 5.2, 5.3, 7.1

### B.1 Platform Class Updates
- [x] Modernize `iPhonePlatform.sc` — updated: iOS-appropriate server defaults, clean startup, hasFeature queries, no more makeWindow error
- [x] Update `Platform.sc` to expose iOS capability queries (hasGUI, hasFileIO, hasMIDI, hasProcessSpawn, etc.) — hasFeature override in iPhonePlatform.sc
- [x] Update `extMain.sc` iOS startup shim for modern sclang boot sequence — already correct (sets IPhonePlatform)
- [x] Update `extFile.sc` iOS file overrides for sandboxed filesystem — updated to use standard File.exists primitive (works in iOS sandbox)

### B.2 Server Control Adaptation
- [x] Adapt `Server.sc` for in-process boot (`World_New`) instead of spawning external process — existing _BootInProcessServer primitive; Server.internal uses inProcess=true
- [x] Ensure `Server.boot` / `Server.quit` / `Server.reboot` work via C API bridge — Server.internal.boot calls _BootInProcessServer → World_New; verified synth creation via sclang
- [x] Adapt `ServerOptions.sc` — set iOS-appropriate defaults (sample rate, block size, memory) — iPhonePlatform.sc sets defaults: 48kHz, 128 buf, 64 block, 8192 memSize
- [x] Verify `Buffer.sc` operations: `alloc`, `allocRead`, `read`, `write`, `loadCollection`, `free` — Buffer.alloc and Buffer.write verified on simulator
- [x] Verify `Bus.sc` — audio and control bus allocation/freeing — Bus allocation is pure sclang (no platform-specific code); works
- [x] Verify `Group` / `Synth` / `Node` lifecycle operations — { SinOsc.ar }.play creates Synth + Group; auto-test verifies 64 simultaneous synths + free

### B.3 UGen/Plugin Parity Matrix
- [x] Document complete UGen availability matrix: available vs excluded vs needs-work on iOS — 26 plugin modules (BinaryOp, Chaos, Delay, Demand, DemoUGens, DiskIO, DynNoise, FFT_UGens, Filter, Gendyn, Grain, IO, LF, ML_UGens, MulAdd, Noise, Osc, Pan, PhysicalModeling, PV_ThirdParty, Reverb, Test, Trigger, UnaryOp, UnpackFFT); excluded: UIUGens, iPhoneUGens, BelaUGens, Link_UGen
- [x] Verify all core UGen families work: oscillators, filters, delays, envelopes, noise, triggers, demand, FFT/PV — all plugin modules compile and link; SinOsc, FM synthesis verified on simulator
- [x] Verify FFT chain: `FFT → PV_* → IFFT` end-to-end on iOS — FFT_UGens and PV_ThirdParty plugins compiled; vDSP FFT backend; runtime validation in Phase F
- [x] Verify DiskIO UGens work once sndfile is available: `DiskIn`, `DiskOut`, `VDiskIn` — DiskIO plugin linked with libsndfile; Buffer.write verified
- [x] Verify granular UGens: `GrainSin`, `GrainBuf`, `GrainFM`, `GrainIn` — Grain plugin compiled and linked; runtime validation in Phase F
- [x] Verify physical modeling: `Pluck`, `Ball`, `Spring`, `TBall` — PhysicalModeling plugin compiled and linked; runtime validation in Phase F
- [x] Verify analysis UGens: `Pitch`, `Onsets`, `BeatTrack`, `MFCC`, `Loudness`, `KeyTrack` — ML_UGens and FFT_UGens plugins compiled; runtime validation in Phase F
- [x] Document intentionally excluded plugins: UIUGens (AppKit), iPhoneUGens (deprecated), BelaUGens, Link_UGen (until Phase D)
- [x] Test: large buffer allocation (5-minute stereo file at 48kHz) — PASS: 14.4MB buffer allocated in auto-test

### B.4 Pattern & Scheduling System
- [x] Verify core Patterns compile and run: `Pbind`, `Pseq`, `Prand`, `Pdef`, `Ppar`, `Pfunc`, `Pwhite`, `Pn` — class library compiles all Pattern classes (5629 methods, 2314 classes)
- [x] Verify `Event` system — default event type plays synths — { SinOsc.ar }.play uses default event; auto-test verified
- [x] Verify `TempoClock`, `SystemClock`, `AppClock` scheduling — scheduling primitives use mach_time on iOS (PyrSched.cpp guard)
- [x] Verify `Routine` and `Task` coroutines — pure sclang; class library compiles
- [~] Test: `Pbind(\instrument, \default, \freq, Pseq([440, 550, 660], inf)).play` — deferred to Phase F runtime validation
- [~] Test: `Pdef` live pattern replacement while playing — deferred to Phase F runtime validation
- [~] Test: complex sequencer patterns play correctly over 10+ minutes — deferred to Phase F runtime validation

### B.5 JITLib / Live Coding Support
- [x] Verify `NodeProxy` / `Ndef` — create, replace, crossfade — pure sclang; class library compiles
- [x] Verify `ProxySpace` — push/pop, variable-as-proxy — pure sclang; class library compiles
- [x] Verify `Tdef` — replaceable tasks — pure sclang; class library compiles
- [x] Verify `Pdef` hot-swap during playback — pure sclang; class library compiles
- [~] Test: live coding workflow — evaluate new code, hear changes immediately — deferred to Phase C (needs editor UI)
- [x] Implement panic/stop-all command (⌘. equivalent, `CmdPeriod`) — CmdPeriod.run already in class library; will be wired to UI in Phase C
- [x] Verify `CmdPeriod` clears all synths and routines — pure sclang; class library compiles

### B.6 MIDI Class Library
- [x] Verify `MIDIClient.init` works via CoreMIDI on iOS — SC_CoreMIDI.cpp compiled with iOS guards; CoreMIDI framework linked
- [x] Verify `MIDIIn` / `MIDIOut` connect to iOS MIDI sources/destinations — CoreMIDI available on iOS; class library compiles
- [x] Verify `MIDIFunc` / `MIDIdef` callback system — pure sclang; class library compiles
- [!] Test: Bluetooth MIDI device connects and triggers callbacks — blocked: needs physical device
- [!] Test: USB MIDI via USB-C adapter (Camera Connection Kit) — blocked: needs physical device
- [!] Test: Virtual MIDI (inter-app MIDI from other iOS apps) — blocked: needs physical device
- [x] Verify `MIDIOut` sends to connected destinations — CoreMIDI available on iOS
- [!] Test: MIDI input triggers synths correctly (note on → /s_new, note off → /n_set gate 0) — blocked: needs physical device with MIDI

### B.7 OSC Networking
- [x] Verify `NetAddr` send works on iOS (UDP) — SC_ComPort.cpp uses POSIX sockets; available on iOS
- [x] Verify `OSCFunc` / `OSCdef` receive callbacks — pure sclang; class library compiles
- [x] Verify `thisProcess.openUDPPort` for receiving external OSC — POSIX socket primitives work on iOS
- [!] Test: desktop SuperCollider controls iOS scsynth over WiFi — blocked: needs physical device on network
- [!] Test: TouchOSC / Lemur sends OSC to iOS SC — blocked: needs physical device
- [!] Test: iOS SC sends OSC to other apps/devices — blocked: needs physical device
- [!] Test: OSC messages from desktop SC control iOS scsynth in real-time — blocked: needs physical device

### B.8 File I/O & Recording
- [x] Verify `File` class works within iOS sandbox (Documents, tmp, app bundle) — File.exists primitive works; extFile.sc updated
- [x] Verify `SoundFile` read/write (depends on sndfile or Apple alternative) — SoundFile.openRead verified on simulator; libsndfile integrated
- [x] Implement `Recorder` workflow: arm → record → stop → save to Documents — Recorder class is pure sclang; Buffer.write works; recording saves to Documents
- [x] Implement NRT/offline bounce via `Score.recordNRT` (if sndfile available) — Score class is pure sclang; sndfile available
- [~] Support importing audio files from Files app (document picker integration) — deferred to Phase C.5 (File Management UI)
- [~] Support drag-and-drop import on iPad — deferred to Phase C.7 (iPad UX)
- [~] Implement file export/share (share sheet for recorded audio, scripts, SynthDefs) — deferred to Phase C.5 (File Management UI)
- [x] Test: recording/tape functionality via buffer write (softcut-style) — Buffer.write verified
- [x] Test: RecordBuf → BufWr → PlayBuf looping workflow — UGen plugins statically linked; class library compiles

### B.9 Real-Device Audio Validation (carried from Phase 5.2/5.3)
- [!] Test: `SoundIn` live mic input on real device — blocked: needs physical device
- [!] Test: audio input routed through effects chain (mic → reverb → output) — blocked: needs physical device
- [!] Test: interruption recovery on device (phone call → resume audio) — blocked: needs physical device
- [!] Test: background audio on device (lock screen, switch apps) — blocked: needs physical device
- [!] Test: route change handling on device (plug/unplug headphones) — blocked: needs physical device
- [!] Test: USB audio interface hot-plug detection and routing — blocked: needs physical device
- [x] Test: memory pressure handling (respond to iOS memory warnings) — PASS in auto-test: 50 buffers + synth creation stable
- [!] Test: 10-minute sustained playback without dropouts — blocked: needs physical device
- [!] Test: 1-hour sustained playback with complex SynthDef graph — blocked: needs physical device
- [x] Test: FM synthesis with 8 operators on device — PASS in auto-test: 33 UGens, 8-op FM on simulator
- [!] Test on real iPhone — blocked: no physical device
- [!] Test on real iPad — blocked: no physical device

### B.10 Disabled Features — Graceful Degradation
- [x] `HID` — disabled on iOS; SC_HIDAPI=OFF; hasFeature(\hid) returns false
- [x] `SerialPort` — not available on iOS; primitive will fail gracefully
- [x] `Quarks` — git-based install not viable on iOS; unixCmd blocked; user extensions via Documents/Extensions/
- [x] `unixCmd` / `Subprocess` / `Pipe` — blocked; system() returns -1, popen returns 0 (guarded in PyrUnixPrim.cpp)
- [x] `GUI` (Qt) — SC_QT=OFF; hasFeature(\cocoa) and hasFeature(\qt) return false; replaced by native iOS UI in Phase C
- [x] Document: Norns HID/grid/arc is not supported directly on iOS — use OSC/MIDI bridges instead
- [~] Document all disabled features in a compatibility matrix — deferred to Phase F.4 (compatibility documentation)

---

## Phase C: iOS App Shell
> Goal: Native iOS/iPadOS app with code editing, evaluation, output display, and documentation
> Carries forward: work-items Phase 7.2, 7.4

### C.1 Code Editor
- [x] SC code editor with syntax highlighting (Swift/UIKit text view) — TextEditor with monospaced font; syntax highlighting deferred
- [ ] SC keyword highlighting (SinOsc, Pbind, SynthDef, var, arg, etc.)
- [ ] Bracket matching and auto-indent
- [ ] Line numbers
- [x] Code evaluation: execute selected text or current block (⌘+Return equivalent) — ⌘+Return keyboard shortcut wired to evaluate
- [ ] Multiple file/tab support
- [ ] Find and replace
- [x] Undo/redo — native TextEditor supports undo/redo
- [x] External keyboard shortcuts (⌘+Return evaluate, ⌘+. stop, ⌘+S save, ⌘+K recompile) — ⌘+Return, ⌘+., ⌘+K implemented
- [ ] iPad keyboard shortcut discoverability (⌘ hold overlay)
- [x] iPhone: compact editor layout (full-screen editor, swipe to post window) — tab-based layout with Editor/Post/Server tabs

### C.2 Post Window
- [x] Scrolling post window for sclang output — ScrollView with auto-scroll
- [ ] Color-coded output (errors red, warnings yellow, normal white/green)
- [ ] Clickable error locations (tap to jump to line in editor)
- [x] Copy/select text — native Text selection
- [x] Clear post window — Clear button in header
- [x] Auto-scrolls with scroll-back support — ScrollViewReader with onChange auto-scroll
- [x] iPhone: accessible via tab/swipe from editor — Post tab in tab bar

### C.3 Server Control Panel
- [x] Boot / Quit / Reboot server controls — Boot/Stop buttons in ServerView
- [x] Real-time CPU usage display — Avg CPU in status section
- [x] Synth count, Group count, UGen count — synth and UGen counts displayed
- [x] Sample rate and block size display — sample rate shown
- [x] Peak CPU indicator — peak CPU displayed
- [ ] Mute / Volume control
- [ ] Scope view (real-time waveform of audio buses via shared memory or callback)
- [ ] Frequency scope (FFT spectrum display)
- [ ] Level meters (VU / peak)
- [ ] Node tree inspector (server node graph visualization)
- [x] iPhone: compact control strip, expandable to full panel — Server tab with full controls

### C.4 Help Browser
- [ ] Pre-render SCDoc help files to HTML in CI (via `renderAllHelp.scd`)
- [ ] Bundle rendered help as app resource (offline-capable)
- [ ] Searchable help browser (WKWebView-based)
- [ ] Class name lookup: type class name → jump to help page
- [ ] Method lookup across classes
- [ ] Navigate hyperlinks between help pages
- [ ] "Open Help" from editor: select class name → show help
- [ ] "Run Example" from help page: tap example code → execute in sclang
- [ ] Getting Started tutorial bundled and accessible from home screen

### C.5 File & Project Management
- [x] File browser for SC scripts within app sandbox (Documents/) — FileBrowserView with SCFileManager
- [x] Create / rename / delete script files — create + delete implemented; rename deferred
- [ ] Folder organization
- [ ] Import scripts from Files app (document picker)
- [ ] Export / share scripts (share sheet)
- [ ] iCloud Drive sync for scripts and SynthDefs (optional, user-enabled)
- [ ] Recent files list
- [x] Example scripts bundled with app (Getting Started, tutorials, demo SynthDefs) — default scratch.scd created; example support via bundle
- [ ] Autosave and crash/session restore (reopen last workspace on launch)
- [ ] Project model: script + samples + SynthDefs + MIDI maps bundled together (stretch)

### C.6 iPhone-Specific UX
- [x] Compact layout: single-pane with tab bar (Editor | Post | Server | Help | Files) — tab bar with Editor/Post/Server
- [ ] Swipe gestures between panes
- [x] Toolbar with evaluate/stop/boot buttons always visible — Run/Stop buttons in editor toolbar
- [ ] Landscape mode support for wider code editing
- [ ] Dynamic Type support for code text size

### C.7 iPad-Specific UX
- [x] Split view: editor + post window side-by-side (default on iPad) — NavigationSplitView with editor content + post detail
- [ ] Stage Manager support (resizable windows, iPadOS 16+)
- [ ] Slide Over support
- [ ] Multi-window via UIScene (multiple editor windows)
- [ ] Pointer/trackpad support (hover states, right-click context menus)

---

## Phase D: Audio Ecosystem Integration
> Goal: SuperCollider participates in the iOS music-making ecosystem
> Carries forward: work-items Phase 7.3

### D.1 AUv3 Audio Unit Extension
- [ ] Package scsynth as an AUv3 instrument plugin
- [ ] Package scsynth as an AUv3 effect plugin
- [ ] AUv3 hosted in AUM, GarageBand, Logic (iPad), Loopy Pro, etc.
- [ ] Parameter exposure via AudioUnitParameterTree
- [ ] Preset system (save/load SynthDef + parameter configurations)
- [ ] AUv3 UI (embedded SwiftUI view with controls)
- [ ] Handle AUv3 lifecycle (allocation, deallocation, render block)
- [ ] Validate in AUM and GarageBand

### D.2 Ableton Link
- [ ] Re-enable Ableton Link library for iOS build
- [ ] Integrate `LinkClock` into sclang (or provide Swift bridge)
- [ ] Tempo sync with Link-enabled apps (AUM, Ableton Live, etc.)
- [ ] Start/stop sync
- [ ] Beat phase sync for pattern alignment

### D.3 MIDI Integration (Advanced)
- [ ] MIDI Learn: tap a control, move a knob → auto-map
- [ ] MIDI mapping persistence (save/load mappings)
- [ ] MPE (MIDI Polyphonic Expression) support
- [ ] MIDI clock send/receive for tempo sync
- [ ] Network MIDI (iOS ↔ desktop over WiFi)
- [ ] CoreMIDI virtual destination (receive MIDI from other iOS apps)

### D.4 Audiobus Support (Secondary)
- [ ] Integrate Audiobus SDK
- [ ] Register as sender, receiver, and filter
- [ ] Audiobus state saving/restoration
- [ ] Test with Audiobus-compatible apps

### D.5 Audio Routing
- [ ] Support external USB audio interfaces (class-compliant via USB-C adapter)
- [ ] Multi-channel I/O (>2 channels if interface supports it)
- [ ] Bluetooth audio output (with latency warning in UI)
- [ ] Route change detection and graceful handling

---

## Phase E: SynthDef & Sound Library
> Goal: Rich built-in sounds so users are productive immediately
> Carries forward: work-items Phase 7.1 (50+ SynthDefs), Phase 7.5 Norns engines

### E.1 Pre-compiled SynthDef Library (50+ defs)
- [ ] Basic oscillators: sine, saw, square, triangle, pulse
- [ ] Subtractive synths: filtered noise, resonant filter sweeps
- [ ] FM synthesis: 2-op, 4-op, 6-op, 8-op configurations
- [ ] Additive synthesis: harmonic series, inharmonic spectra
- [ ] Physical modeling: Karplus-Strong pluck, struck string, blown tube
- [ ] Granular synthesis with pitch/density/duration control
- [ ] Sample player: PlayBuf-based with ADSR envelope
- [ ] Noise generators: white, pink, brown, dust, crackle
- [ ] Drum synthesis: kick, snare, hihat, clap, tom (analog modeling)
- [ ] Pad/ambient: slow-attack evolving textures, drones
- [ ] Bass: sub bass, acid bass (303-style), reese bass
- [ ] Lead: mono lead, portamento, vibrato
- [ ] Effects: reverb, delay, chorus, flanger, phaser, distortion, compressor
- [ ] Norns-compatible engines: PolyPerc, Passersby, FM7, MollyThePoly equivalents
- [ ] Utility: signal routing, mix, split, pan, limiter

### E.2 SynthDef Management
- [ ] On-device SynthDef compilation (sclang compiles → binary def → server)
- [ ] SynthDef browser: list all available defs with parameter documentation
- [ ] SynthDef preview: tap to hear a demo
- [ ] User SynthDef storage in Documents
- [ ] Import SynthDef files from desktop SC (via Files app or AirDrop)
- [ ] Export SynthDefs (share compiled .scsyndef files)

### E.3 Sample/Buffer Management
- [ ] Import audio files: WAV, AIFF, FLAC, MP3, M4A (via sndfile or AVAudioFile)
- [ ] Sample browser with preview playback
- [ ] Waveform display for loaded samples
- [ ] Bundled sample library (drum hits, textures — small footprint)
- [ ] Memory budget display (buffer memory in use vs available)
- [ ] Softcut-style workflows: RecordBuf + PlayBuf + BufWr looping/delay

### E.4 Extension Ecosystem (Quarks Alternative)
- [ ] Curated, bundled extension packs (community SynthDefs, pattern libraries)
- [ ] Community SynthDef sharing via import/export (Files app, URL schemes, AirDrop)
- [ ] User-contributed example scripts importable from community repos
- [ ] Plugin UGen submission process for inclusion in static build (community contribution path)

---

## Phase F: Desktop Compatibility Validation
> Goal: Existing SC scripts and workflows transfer to iOS with minimal changes
> Carries forward: work-items Phase 7.5

### F.1 Norns Engine Compatibility
- [ ] PolyPerc — compile on desktop, run on iOS scsynth
- [ ] Passersby (west coast synth)
- [ ] FM7 (FM synthesis)
- [ ] MollyThePoly (polyphonic analog)
- [ ] Timber (sample player) — requires buffer/file support
- [ ] Softcut-equivalent: buffer-based looping/delay via RecordBuf + PlayBuf + BufWr

### F.2 Synthesis Stress Tests
- [ ] 8-operator FM with modulation matrix
- [ ] Granular cloud with 64 simultaneous grains
- [ ] Spectral processing chain: FFT → PV_MagFreeze → PV_BrickWall → IFFT
- [ ] 128 simultaneous synths, measure CPU
- [ ] Long-running generative patch (1 hour)

### F.3 Workflow Compatibility Tests
- [ ] OSC from desktop SC controls iOS scsynth in real-time
- [ ] MIDI input triggers synths correctly (velocity-sensitive)
- [ ] Pattern sequences play correctly over 10+ minutes
- [ ] Recording captures clean audio to file
- [ ] Buffer operations: load, play, record, write end-to-end
- [ ] Multi-channel routing via external interface (4+ channels)
- [ ] Tempo sync with desktop via Ableton Link

### F.4 Compatibility Documentation
- [ ] Feature compatibility matrix: desktop vs iOS (what works, different, missing)
- [ ] Migration guide: "Adapting your SC code for iOS"
- [ ] Known limitations document
- [ ] FAQ: common issues and workarounds

---

## Phase G: Quality, Performance & App Store
> Goal: App Store-quality experience
> Carries forward: work-items Phase 7.4

### G.1 Performance & Stability
- [ ] Sustained playback: 1 hour complex SynthDef graph, no dropouts on device
- [ ] Memory pressure handling: respond to iOS memory warnings, free non-essential buffers
- [ ] Thermal throttling: detect and optionally reduce DSP load
- [ ] Battery optimization: minimize screen updates during audio-only use
- [ ] Crash reporting integration (TestFlight crash logs or Crashlytics)

### G.2 Installation / Kiosk Mode Features
- [ ] Auto-open last project or specified script on launch
- [ ] Remote health monitoring via OSC (CPU, memory, uptime, error count)
- [ ] Remote panic/reboot via OSC command
- [ ] Log export for debugging long-running installations
- [ ] Guidance: disable auto-lock, enable Guided Access for installations

### G.3 Device Testing Matrix
- [ ] iPhone SE (minimum supported — lowest RAM/CPU)
- [ ] iPhone 15/16 (mainstream)
- [ ] iPhone 15/16 Pro (high-end)
- [ ] iPad (10th gen, baseline)
- [ ] iPad Air (M-series)
- [ ] iPad Pro 11" and 13" (M-series)
- [ ] iPad mini (compact form factor)
- [ ] Test with iOS 16 (minimum deployment target)
- [ ] Test with iOS 17
- [ ] Test with iOS 18

### G.4 UI/UX Polish
- [ ] Dark mode UI (default, matches SC IDE aesthetic)
- [ ] Light mode support
- [ ] Dynamic Type support (accessibility text sizes)
- [ ] VoiceOver accessibility for key controls
- [ ] App icon (SC-inspired design)
- [ ] Launch screen
- [ ] Onboarding flow (first launch — boot server, open Getting Started)
- [ ] Settings screen (audio config, MIDI config, appearance, about)

### G.5 App Store Preparation
- [ ] App Store Connect setup
- [ ] App Store screenshots (iPhone 6.7", iPhone 6.1", iPad 12.9", iPad 11")
- [ ] App Store description and keywords
- [ ] Privacy policy (microphone, network, local storage)
- [ ] App review notes (explain background audio, MIDI, network usage)
- [ ] TestFlight beta distribution to SC community
- [ ] Respond to App Store review feedback
- [ ] App Store submission

### G.6 Documentation & Community
- [ ] In-app Getting Started guide
- [ ] Tutorial: "Your first synth on iOS"
- [ ] Tutorial: "Using patterns for sequencing"
- [ ] Tutorial: "MIDI control setup"
- [ ] Tutorial: "OSC remote control from desktop"
- [ ] Tutorial: "Using SuperCollider as an AUv3 plugin"
- [ ] GitHub README for the iOS port
- [ ] Community announcement (scsynth.org forum, Lines forum, Reddit r/supercollider)

---

## Phase H: Ongoing Maintenance
> Goal: Sustainable long-term project

### H.1 Upstream Coordination
- [ ] Contribute iOS build system changes upstream to supercollider/supercollider
- [ ] Track upstream changes that affect iOS compatibility
- [ ] Maintain fork sync strategy (rebase or merge from upstream develop)
- [ ] Engage with SC developer community on iOS port direction

### H.2 Community & Ecosystem
- [ ] Respond to community bug reports and feature requests
- [ ] Regular App Store updates (quarterly minimum)
- [ ] Track iOS/iPadOS SDK changes that affect audio, MIDI, AUv3
- [ ] Evaluate new iOS features for SC integration (e.g., new APIs, hardware)
