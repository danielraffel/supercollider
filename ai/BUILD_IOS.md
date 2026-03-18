# Building SuperCollider for iOS

## Prerequisites

- **macOS** with Xcode 15.2+ and command line tools (`xcode-select --install`)
- **CMake 3.12+** (`brew install cmake`)
- **Git** with submodule support

## Branches

| Branch | Purpose |
|--------|---------|
| `develop` | Main development branch |
| `feature/ux-redesign` | Latest iOS app UI (recommended for testing) |

## Step 1: Clone and checkout

```bash
git clone --recursive https://github.com/danielraffel/supercollider.git
cd supercollider
git checkout feature/ux-redesign
git submodule update --init --recursive
```

If you already cloned without `--recursive`:
```bash
git submodule update --init --recursive
```

## Step 2: Build the XCFramework

This builds libscsynth (audio engine) and libsclang (language interpreter) as static libraries for both device (arm64) and simulator (arm64). **This must complete before opening the Xcode project.**

```bash
cd platform/iOS
./build_xcframework.sh --with-sclang
```

Takes ~10-15 minutes on first run. Output goes to:
```
build-xcframework/output/SuperCollider.xcframework
```

To build without the language interpreter (audio engine only):
```bash
./build_xcframework.sh
```

## Step 3: Open and run the iOS app

```bash
cd platform/iOS/TestApp
open SCiOSTest.xcodeproj
```

In Xcode:
1. Select the **SCiOSTest** scheme
2. Pick a simulator (e.g. iPhone 16 Pro) or connect a physical device
3. Update **Signing & Capabilities** to your own Apple Developer team
4. Build and run (`Cmd+R`)

### Command-line build (simulator)

```bash
xcodebuild -project platform/iOS/TestApp/SCiOSTest.xcodeproj \
    -scheme SCiOSTest \
    -destination "platform=iOS Simulator,name=iPhone 16 Pro" \
    build
```

### Command-line build (device)

```bash
xcodebuild -project platform/iOS/TestApp/SCiOSTest.xcodeproj \
    -scheme SCiOSTest \
    -destination "generic/platform=iOS" \
    build
```

You'll need to configure code signing for device builds.

## Troubleshooting

| Problem | Fix |
|---------|-----|
| "XCFramework not found" or linker errors | Re-run step 2: `./build_xcframework.sh --with-sclang` |
| Signing errors | Change the development team in Xcode → SCiOSTest target → Signing & Capabilities |
| "Header not found" | Ensure submodules are initialized: `git submodule update --init --recursive` |
| "SynthDef not found" at runtime | The app auto-loads SynthDefs before first evaluate. If a file uses custom SynthDefs in separate blocks, long-press to select and evaluate the SynthDef block first. |
| CMake errors | Ensure CMake is installed (`brew install cmake`) and is v3.12+ (`cmake --version`) |
| Build takes forever | First build fetches and compiles libsndfile, Boost, etc. Subsequent builds use the CMake cache and are faster. |

## Architecture Overview

```
SwiftUI App (platform/iOS/TestApp/)
    │
    ├── SC_iOSLibSynth.h  ← C API for scsynth (audio engine)
    ├── SC_iOSSclang.h     ← C API for sclang (language interpreter)
    │
    └── SuperCollider.xcframework
        ├── libscsynth.a   (static, arm64 device + simulator)
        ├── libsclang.a    (static, arm64 device + simulator)
        └── Headers/
```

- **scsynth** runs in-process via `World_New` (not a separate daemon)
- All UGen plugins are statically linked (no dlopen on iOS)
- AVAudioSession is configured for 48kHz, 240-sample buffer
- SCClassLibrary is bundled as an app resource
