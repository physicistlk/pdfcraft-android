#!/usr/bin/env bash
# Build and sign one Craft-app Android APK (Linux).
#
#   usage: build-apk-linux.sh <build-dir> <crate> [features...]
#   e.g.   build-apk-linux.sh /home/lk1/craft_apps/pdfcraft-build pdfcraft-android
#
# The Windows original (scripts/build-apk.sh) hard-codes C:\ paths and a keystore under the
# port author's home; this one takes the build tree as an argument and reads the signing material
# from the environment, so no password is ever written into a tracked file.
#
# Environment this box needs (Rust 1.99 via rustup, no PATH entries by default):
#   * $HOME/.cargo/bin                — cargo, cargo-apk
#   * the Android SDK + NDK r27.2     — ANDROID_HOME and friends
#   * the Temurin JDK 21              — apksigner runs on it
# and the APK is signed with the keystore named by CARGO_APK_RELEASE_KEYSTORE (a local test key
# kept outside both repositories), so `cargo apk build --release` produces a signed APK rather
# than a debug-signed one.
set -o pipefail

repo="$1"
crate="$2"
shift 2
if [ -z "$repo" ] || [ -z "$crate" ]; then
    echo "usage: build-apk-linux.sh <build-dir> <crate> [features...]" >&2
    exit 2
fi

# One place for the toolchain environment: rustup's bin, the JDK, the SDK/NDK, and the C
# cross-compiler aws-lc-sys needs. That file says why each piece is there.
. "$(dirname "$0")/android-env-linux.sh"

cd "$repo" || exit 1
echo "=== building $crate in $repo ($(date -u +%Y-%m-%dT%H:%M:%SZ)) ==="
cargo apk build --release -p "$crate" --target aarch64-linux-android "$@"
status=$?
echo "=== $crate exit=$status ($(date -u +%Y-%m-%dT%H:%M:%SZ)) ==="
exit $status
