#!/bin/bash
# Build SuperCollider.xcframework for iOS
# Produces a universal static library for device (arm64) and simulator (arm64)
# Includes both scsynth (audio engine) and sclang (language interpreter)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
BUILD_DIR="$ROOT_DIR/build-xcframework"
OUTPUT_DIR="$BUILD_DIR/output"

# Parse options
BUILD_SCLANG=OFF
for arg in "$@"; do
    case $arg in
        --with-sclang) BUILD_SCLANG=ON ;;
    esac
done

echo "=== Building SuperCollider.xcframework ==="
echo "Root: $ROOT_DIR"
echo "Include sclang: $BUILD_SCLANG"

# Clean
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

CMAKE_COMMON_OPTS="-DCMAKE_SYSTEM_NAME=iOS -DSC_IOS=ON -DCMAKE_OSX_ARCHITECTURES=arm64 -DCMAKE_OSX_DEPLOYMENT_TARGET=16.0 -DNO_LIBSNDFILE=ON"
if [ "$BUILD_SCLANG" = "ON" ]; then
    CMAKE_COMMON_OPTS="$CMAKE_COMMON_OPTS -DSC_IOS_SCLANG=ON -DSCLANG_SERVER=ON"
fi

# Build for device (iphoneos arm64)
echo ""
echo "=== Building for device (iphoneos arm64) ==="
cmake -B "$BUILD_DIR/device" -G Xcode $CMAKE_COMMON_OPTS

TARGETS="libscsynth"
if [ "$BUILD_SCLANG" = "ON" ]; then
    TARGETS="libscsynth libsclang"
fi

for target in $TARGETS; do
    cmake --build "$BUILD_DIR/device" --config Release --target $target -- \
        -sdk iphoneos \
        CODE_SIGNING_ALLOWED=NO
done

# Build for simulator (iphonesimulator arm64)
echo ""
echo "=== Building for simulator (iphonesimulator arm64) ==="
cmake -B "$BUILD_DIR/sim" -G Xcode $CMAKE_COMMON_OPTS

for target in $TARGETS; do
    cmake --build "$BUILD_DIR/sim" --config Release --target $target -- \
        -sdk iphonesimulator \
        CODE_SIGNING_ALLOWED=NO
done

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

# Collect all static libs to merge
merge_libs() {
    local build_path="$1"
    local sdk_pattern="$2"
    local output_lib="$3"

    local libs_to_merge=("$output_lib")

    # Always merge tlsf
    local tlsf=$(find "$build_path" -name "libtlsf.a" -path "*/$sdk_pattern/*" | head -1)
    [ -n "$tlsf" ] && libs_to_merge+=("$tlsf")

    if [ "$BUILD_SCLANG" = "ON" ]; then
        # Merge sclang and its dependencies
        local sclang=$(find "$build_path" -name "libsclang.a" -path "*/$sdk_pattern/*" | head -1)
        local yaml=$(find "$build_path" -name "libyaml.a" -path "*/$sdk_pattern/*" | head -1)
        local boost_thread=$(find "$build_path" -name "libboost_thread_lib.a" -path "*/$sdk_pattern/*" | head -1)
        local boost_po=$(find "$build_path" -name "libboost_program_options_lib.a" -path "*/$sdk_pattern/*" | head -1)
        local boost_regex=$(find "$build_path" -name "libboost_regex_lib.a" -path "*/$sdk_pattern/*" | head -1)

        [ -n "$sclang" ] && libs_to_merge+=("$sclang")
        [ -n "$yaml" ] && libs_to_merge+=("$yaml")
        [ -n "$boost_thread" ] && libs_to_merge+=("$boost_thread")
        [ -n "$boost_po" ] && libs_to_merge+=("$boost_po")
        [ -n "$boost_regex" ] && libs_to_merge+=("$boost_regex")
    fi

    if [ ${#libs_to_merge[@]} -gt 1 ]; then
        echo "Merging ${#libs_to_merge[@]} libs into $(basename "$output_lib")..."
        libtool -static -o "${output_lib}.merged" "${libs_to_merge[@]}"
        mv "${output_lib}.merged" "$output_lib"
    fi
}

merge_libs "$BUILD_DIR/device" "Release-iphoneos" "$DEVICE_LIB"
merge_libs "$BUILD_DIR/sim" "Release-iphonesimulator" "$SIM_LIB"

# Stage headers
HEADERS_DIR="$BUILD_DIR/headers"
mkdir -p "$HEADERS_DIR"
cp "$ROOT_DIR/server/scsynth/SC_iOSLibSynth.h" "$HEADERS_DIR/"
if [ "$BUILD_SCLANG" = "ON" ]; then
    cp "$ROOT_DIR/lang/SC_iOSSclang.h" "$HEADERS_DIR/"
fi

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
