#!/bin/bash
# Build SuperCollider.xcframework for iOS
# Produces a universal static library for device (arm64) and simulator (arm64)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
BUILD_DIR="$ROOT_DIR/build-xcframework"
OUTPUT_DIR="$BUILD_DIR/output"

echo "=== Building SuperCollider.xcframework ==="
echo "Root: $ROOT_DIR"

# Clean
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# Build for device (iphoneos arm64)
echo ""
echo "=== Building for device (iphoneos arm64) ==="
cmake -B "$BUILD_DIR/device" -G Xcode \
    -DCMAKE_SYSTEM_NAME=iOS \
    -DSC_IOS=ON \
    -DCMAKE_OSX_ARCHITECTURES=arm64 \
    -DCMAKE_OSX_DEPLOYMENT_TARGET=16.0

cmake --build "$BUILD_DIR/device" --config Release --target libscsynth -- \
    -sdk iphoneos \
    CODE_SIGNING_ALLOWED=NO

# Build for simulator (iphonesimulator arm64)
echo ""
echo "=== Building for simulator (iphonesimulator arm64) ==="
cmake -B "$BUILD_DIR/sim" -G Xcode \
    -DCMAKE_SYSTEM_NAME=iOS \
    -DSC_IOS=ON \
    -DCMAKE_OSX_ARCHITECTURES=arm64 \
    -DCMAKE_OSX_DEPLOYMENT_TARGET=16.0

cmake --build "$BUILD_DIR/sim" --config Release --target libscsynth -- \
    -sdk iphonesimulator \
    CODE_SIGNING_ALLOWED=NO

# Find built libraries
DEVICE_LIB=$(find "$BUILD_DIR/device" -name "libscsynth.a" -path "*/Release-iphoneos/*" | head -1)
SIM_LIB=$(find "$BUILD_DIR/sim" -name "libscsynth.a" -path "*/Release-iphonesimulator/*" | head -1)

if [ -z "$DEVICE_LIB" ]; then
    echo "ERROR: Device library not found"
    exit 1
fi
if [ -z "$SIM_LIB" ]; then
    echo "ERROR: Simulator library not found"
    exit 1
fi

echo ""
echo "Device lib: $DEVICE_LIB"
echo "Sim lib: $SIM_LIB"

# Stage headers
HEADERS_DIR="$BUILD_DIR/headers"
mkdir -p "$HEADERS_DIR"
cp "$ROOT_DIR/server/scsynth/SC_iOSLibSynth.h" "$HEADERS_DIR/"

# Create XCFramework
echo ""
echo "=== Creating XCFramework ==="
mkdir -p "$OUTPUT_DIR"

xcodebuild -create-xcframework \
    -library "$DEVICE_LIB" \
    -headers "$HEADERS_DIR" \
    -library "$SIM_LIB" \
    -headers "$HEADERS_DIR" \
    -output "$OUTPUT_DIR/SuperCollider.xcframework"

echo ""
echo "=== Done ==="
echo "XCFramework: $OUTPUT_DIR/SuperCollider.xcframework"
ls -la "$OUTPUT_DIR/SuperCollider.xcframework/"
