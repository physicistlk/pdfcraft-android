#!/usr/bin/env bash
# Verify a built Craft-app APK the way the skill says to: never trust `exit=0`.
#
#   usage: verify-apk-linux.sh <apk-path> <lib-name>
#   e.g.   verify-apk-linux.sh /home/lk1/craft_apps/pdfcraft-build/target/release/apk/pdfcraft.apk pdfcraft
#
# Checks the package id, the ABI, the signature, the native library's architecture and its
# exported entry points, and the manifest's `android.app.lib_name` (which must match the .so).
set -o pipefail
. "$(dirname "$0")/android-env-linux.sh"

apk="$1"
lib="$2"
if [ -z "$apk" ] || [ -z "$lib" ]; then
    echo "usage: verify-apk-linux.sh <apk-path> <lib-name>" >&2
    exit 2
fi

BT="$ANDROID_HOME/build-tools/$BT_VER"
NDK_BIN="$ANDROID_NDK_ROOT/toolchains/llvm/prebuilt/linux-x86_64/bin"
PLATFORM="$ANDROID_HOME/platforms/android-35/android.jar"

echo "######## $apk"
ls -l "$apk" 2>/dev/null || { echo "MISSING APK"; exit 1; }
echo "---- badging (package, sdk versions, ABI, launch activity):"
"$BT/aapt2" dump badging "$apk" 2>/dev/null | grep -E "^package|^sdkVersion|^targetSdkVersion|^application|native-code|^launchable-activity|uses-permission|^feature"
echo "---- signature:"
"$BT/apksigner" verify --verbose "$apk" 2>&1 | grep -E "Verified using|Verifies|DOES NOT VERIFY"
echo "---- native symbols in lib$lib.so (expect android_main + ANativeActivity_onCreate):"
SO="$(dirname "$apk")/../../aarch64-linux-android/release/lib$lib.so"
if [ -f "$SO" ]; then
    "$NDK_BIN/llvm-nm" --dynamic --defined-only "$SO" 2>/dev/null | grep -E "android_main|ANativeActivity_onCreate"
else
    echo "no $SO (build did not produce one)"
fi
echo "---- .so inside the APK:"
unzip -l "$apk" 2>/dev/null | grep -oE "lib/[a-z0-9-]+/lib[a-z]*\.so" | sort -u
echo "---- launcher activity lib_name meta-data (must match the .so name above):"
"$BT/aapt2" dump xmltree --file AndroidManifest.xml "$apk" 2>/dev/null | grep -E "android.app.lib_name" -A1 | grep -E "value"
echo "---- the fullscreen fix, resolved by attribute id against android-35 (not by style name):"
"$BT/aapt2" dump resources "$apk" 2>/dev/null | grep -A3 "style/.*Fullscreen" | head -4
ATTR=$("$BT/aapt2" dump resources "$apk" 2>/dev/null | grep -A3 "style/.*Fullscreen" | grep -oE "0x0101[0-9a-f]+" | head -1)
if [ -n "$ATTR" ]; then
    echo "  $ATTR = $("$BT/aapt2" dump resources "$PLATFORM" 2>/dev/null | grep "resource $ATTR " | grep -oE "attr/[A-Za-z]+" | head -1)"
fi
echo "---- architecture of the .so inside the APK:"
TMP=$(mktemp -d)
unzip -o -q "$apk" "lib/arm64-v8a/lib$lib.so" -d "$TMP" 2>/dev/null
if [ -f "$TMP/lib/arm64-v8a/lib$lib.so" ]; then
    file "$TMP/lib/arm64-v8a/lib$lib.so"
    readelf -h "$TMP/lib/arm64-v8a/lib$lib.so" 2>/dev/null | grep -E "Machine|Type:"
    echo "---- ELF LOAD segments (Android 16 wants 0x4000):"
    "$NDK_BIN/llvm-readelf" -lW "$TMP/lib/arm64-v8a/lib$lib.so" | grep "LOAD"
    loads=$("$NDK_BIN/llvm-readelf" -lW "$TMP/lib/arm64-v8a/lib$lib.so" | grep -c "LOAD")
    aligned=$("$NDK_BIN/llvm-readelf" -lW "$TMP/lib/arm64-v8a/lib$lib.so" | grep "LOAD" | grep -c "0x4000$")
    if [ "$loads" -gt 0 ] && [ "$aligned" -eq "$loads" ]; then
        echo "PASS  every LOAD segment is 16 KB aligned"
    else
        echo "FAIL  every LOAD segment is 16 KB aligned ($aligned of $loads)" >&2
    fi
fi
rm -rf "$TMP"
echo "---- sha256:"
sha256sum "$apk"
