#!/usr/bin/env bash
# The Android cross-compile environment for this box (Linux), mirroring scripts/android-env.sh,
# which is written for the port author's Windows machine and hard-codes C:\ paths.
#
# Nothing machine-specific belongs in this file: the SDK, NDK and JDK are taken from the
# environment (or from a local override file). A local, machine-specific override can be
# sourced first, e.g.:
#
#   . /home/lk1/craft_apps/pdfcraft-android-build/android-env.local.sh
#   . scripts/android-env-linux.sh
#
# Two things have to be right for a Rust GUI app of this suite to cross-compile here:
#
#  * the linker for the target triple, because rustc links a NativeActivity cdylib, and
#  * the C toolchain, because PdfCraft's `pdfcraft-sign` builds `aws-lc-sys` (a C crypto library
#    behind aws-lc-rs) for every target that is not wasm32. `cc` looked for a bare `clang.exe`,
#    which is why the NDK's bin directory goes on PATH here and CC/AR/CXX name the NDK wrappers.
#
# NDK r27, minSdk 26 to match [package.metadata.android.sdk] in each shell's Cargo.toml: the
# wrapper is aarch64-linux-android26-clang, and a mismatch is a link error about the API level.
set -o pipefail

# rustup's bin (cargo, cargo-apk) — this box has no PATH entries by default.
export PATH="$HOME/.cargo/bin:$PATH"

# The Android SDK. Override with ANDROID_HOME / ANDROID_SDK_ROOT if they are already set.
if [ -z "${ANDROID_HOME:-}" ] && [ -z "${ANDROID_SDK_ROOT:-}" ]; then
    for candidate in "$HOME/craft_apps/tools/sdk" "$HOME/Android/Sdk" "$HOME/android/sdk"; do
        if [ -d "$candidate" ]; then
            export ANDROID_HOME="$candidate"
            break
        fi
    done
fi
export ANDROID_HOME="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}"
export ANDROID_SDK_ROOT="$ANDROID_HOME"

# The NDK. The port targets r27 (27.2.12479018); the newest installed r27 is used.
if [ -z "${ANDROID_NDK_ROOT:-}" ]; then
    for candidate in "$ANDROID_HOME"/ndk/27.* "$HOME/android"/android-ndk-r27*; do
        if [ -d "$candidate" ]; then
            export ANDROID_NDK_ROOT="$candidate"
            break
        fi
    done
fi
export ANDROID_NDK_ROOT="${ANDROID_NDK_ROOT:-}"
export ANDROID_NDK_HOME="$ANDROID_NDK_ROOT"

if [ -z "$ANDROID_NDK_ROOT" ] || [ ! -d "$ANDROID_NDK_ROOT" ]; then
    echo "android-env-linux.sh: no Android NDK found (set ANDROID_NDK_ROOT)" >&2
    return 1 2>/dev/null || exit 1
fi

# The NDK's prebuilt toolchain directory differs per host; pick the one that exists.
NDK_BIN=""
for host in linux-x86_64 linux-aarch64 darwin-x86_64; do
    if [ -d "$ANDROID_NDK_ROOT/toolchains/llvm/prebuilt/$host/bin" ]; then
        NDK_BIN="$ANDROID_NDK_ROOT/toolchains/llvm/prebuilt/$host/bin"
        break
    fi
done
if [ -z "$NDK_BIN" ]; then
    echo "android-env-linux.sh: no prebuilt NDK toolchain under $ANDROID_NDK_ROOT" >&2
    return 1 2>/dev/null || exit 1
fi
export PATH="$NDK_BIN:$PATH"

# A JDK for apksigner/aapt2 (cargo-apk runs them to build and sign the APK).
if [ -z "${JAVA_HOME:-}" ]; then
    for candidate in "$HOME/craft_apps/tools"/jdk-21* /usr/lib/jvm/*21*; do
        if [ -d "$candidate/bin" ]; then
            export JAVA_HOME="$candidate"
            break
        fi
    done
fi
export PATH="${JAVA_HOME:+$JAVA_HOME/bin:}$PATH"

# rustc links a NativeActivity cdylib, so the target needs its own linker.
export CARGO_TARGET_AARCH64_LINUX_ANDROID_LINKER="aarch64-linux-android26-clang"
# aws-lc-sys (behind aws-lc-rs) is C and needs the NDK's C toolchain.
export CC_aarch64_linux_android="aarch64-linux-android26-clang"
export CXX_aarch64_linux_android="aarch64-linux-android26-clang++"
export AR_aarch64_linux_android="llvm-ar"
export RANLIB_aarch64_linux_android="llvm-ranlib"

# The same for x86_64, which is what the emulator runs (an x86_64 guest on an x86_64 host is the
# only one WHPX can accelerate). Sideload APKs stay arm64-only; the x86_64 builds exist to be run
# in the emulator (`--target x86_64-linux-android`).
export CARGO_TARGET_X86_64_LINUX_ANDROID_LINKER="x86_64-linux-android26-clang"
export CC_x86_64_linux_android="x86_64-linux-android26-clang"
export CXX_x86_64_linux_android="x86_64-linux-android26-clang++"
export AR_x86_64_linux_android="llvm-ar"
export RANLIB_x86_64_linux_android="llvm-ranlib"

# cc-rs also looks at the bare CC/AR when building a *host* helper (aws-lc's generators), and
# falls back to whatever `clang` it finds; the NDK's clang on PATH above is that fallback.

# Android 16 requires a 16 KB page size: a native library whose ELF segments are only 4 KB
# aligned still runs, but the system shows the user a compatibility warning on a device with
# 16 KB pages, and Play will not accept an update that is not aligned.
#
# The flag has to go in RUSTFLAGS, and in exactly one token. cargo-apk does not link the cdylib
# itself: it shells out to `ndk-build`, whose `cargo_ndk()` re-encodes RUSTFLAGS into
# CARGO_ENCODED_RUSTFLAGS and appends its own `-Clink-arg=--target=...`. That encoding
# *overrides* CARGO_TARGET_<triple>_RUSTFLAGS, so the flag cannot be passed there; and it
# splits RUSTFLAGS on spaces, so a flag with a space in it is broken in two. One token, no
# spaces, in RUSTFLAGS, is what survives to the linker.
#
# With NDK r27 the result is what Android 16 wants: every LOAD segment 0x4000-aligned.
export RUSTFLAGS="${RUSTFLAGS:--Clink-arg=-Wl,-z,max-page-size=16384}"
