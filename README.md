# PdfCraft for Android (arm64-v8a)

An unofficial Android port of **[PdfCraft](https://github.com/storytold/pdfcraft)** — the real engine
and egui interface, packaged as a NativeActivity APK for sideloading on arm64 devices.

| | |
|---|---|
| Upstream project | [`storytold/pdfcraft`](https://github.com/storytold/pdfcraft) — Apache-2.0 OR MIT |
| Pinned commit | `75360d1d` (upstream version `0.15.0`) — was `3d2bdfe` (`0.6.0`) before the update |
| Android package | `ai.storyteller.pdfcraft` |
| Published APK | `pdfcraft-0.6.0-arm64-v8a-20261013b.apk` — 21.8 MB, arm64-v8a, signed (release **v0.1.2**, 2026-10-13) |
| APK sha256 | `0619612b7d8cfcb76690e7d12302c463aa234d939ebece8353238e6a54f7b9ce` |
| Upstream files changed | 25 files (2 of them new) — see [`patches/`](patches/) |
| New port crate | `apps/pdfcraft-android/` — 1280 lines of Rust plus resources |

## What this repository is

This is **not a fork** of PdfCraft. It holds only the Android layer, so it stays small, readable,
and obviously separable from upstream:

```
apps/pdfcraft-android/     the new shell crate — copy it into your checkout of upstream
patches/                the diff against upstream — apply it after checking out the pin
docs/PORT-NOTES.md      what was changed and why, fix by fix, with how each one was checked
scripts/                cross-compile environment, build and verify scripts (from shared-android-port)
CHANGELOG.md            what is in the published APK
```

The Android layer is not a reimplementation. It is a shell crate that fills the same `Services`
struct the desktop and web shells fill, so the real engine and the real egui UI run unchanged.

## Build it

Prerequisites: Rust (rustup) with the `aarch64-linux-android` target, Android SDK + NDK r27, a
JDK 21, and `cargo install cargo-apk`.

```bash
git clone https://github.com/storytold/pdfcraft.git
cd pdfcraft
git fetch --depth 1 origin 75360d1d7db06fed974f48c914d4c04132757187
git checkout FETCH_HEAD                        # the exact commit this port targets
git apply -3 /path/to/0001-pdfcraft-android-port.patch
cp -r /path/to/pdfcraft-android apps/             # the shell crate from this repository

# any keystore of your own signs an installable APK; a throwaway test key is fine for sideloading
keytool -genkeypair -keystore ks.jks -alias pdfcraft -keyalg RSA -keysize 2048 -validity 10000 \
        -storepass android -keypass android -dname "CN=Local Test, O=Local, C=US"
export CARGO_APK_RELEASE_KEYSTORE="$PWD/ks.jks" CARGO_APK_RELEASE_KEYSTORE_PASSWORD=android
cargo apk build --release -p pdfcraft-android
```

`scripts/android-env.sh` is the cross-compile environment this port was built with (the NDK linker
and the C compiler the native dependencies need), `scripts/build-apk.sh` wraps the build, and
`scripts/verify-apk.sh` checks the artifact: `aapt2 dump badging`, `apksigner verify`, and `llvm-nm`
on the `.so` inside the APK.

## Install

```bash
adb install -r pdfcraft-0.15.0-arm64-v8a-20261028.apk
```
or copy the APK to the device and open it (installing from unknown sources must be allowed).

On first run, grant **Settings ▸ Apps ▸ PdfCraft ▸ Special access ▸ All files access** if you want
the in-app picker to reach files outside the app's own folders. Without it, Android 10+ refuses a
`read_dir` of shared storage by path, and the picker can only offer the app's own directory.

## Verification status

Everything below was checked on the machine this port was published from, in October 2026.
A tick means the check was *run*, not inferred; the wording says how far it goes.

| Claim | How it was checked | Result |
|---|---|---|
| `patches/…patch` applies to a clean checkout of the pin | fresh `git init` + `git fetch --depth 1 origin 75360d1d7db06fed974f48c914d4c04132757187` + `git apply --check` | ✅ applies cleanly |
| The assembled tree equals the tree the APK was built from | the patch in `patches/` compared byte-for-byte with `git diff` of the built worktree, and `diff -r` of the port crate in this repository against the one in that worktree | ✅ identical, nothing differing |
| The port crate compiles for Android | `cargo check -p pdfcraft-android --target aarch64-linux-android` in the tree the APK was built from | ✅ exit 0 |
| The port crate's own tests | `cargo test -p pdfcraft-android --lib` in the same tree | ✅ 15/15 pass (clipboard rewriting, modifier tracking, two-finger scrolling) |
| APK is signed and is the right artifact | `apksigner verify --verbose`, `aapt2 dump badging`, `readelf`/`llvm-nm` on the `.so` inside the APK, sha256 | ✅ v2/v3 signatures true, `native-code: 'arm64-v8a'`, ELF AArch64, package `ai.storyteller.pdfcraft` |
| Behaviour on real hardware | hand-testing on the porter's arm64 tablet | ⚠️ the fixes below were found and driven by that testing **against upstream 0.6.0**; the 0.15.0 build below has not been on a tablet — no device was connected |

**Before trusting the APK:** the source side is verified as listed above; runtime behaviour only as far
as [`docs/PORT-NOTES.md`](docs/PORT-NOTES.md) says per fix, plus the tablet testing that produced those
fixes. There is no automated device test in this repository.

## Known gaps

- **Runtime verification is hand-testing only**, plus the source-side checks in the README.
- **The system clipboard is text only.** Ctrl+C/X/V and *Create ▸ Clipboard* work with text from any
  app; `arboard` has no Android backend, so an *image* or *file* clipboard stays out of reach — Copy
  Image in Original Format says so, and `Create ▸ Clipboard` reads text (not a picture).
- **All files access is a manual grant**; without it the picker offers only the app's own directory.
- **The picker blocks a worker thread per request** (as `rfd`'s Linux backend does). Fine for a user
  answering a dialog; it is not a design for many parallel picks.
- **Build needs an NDK C toolchain** (`aws-lc-sys`), which the other ports in this set do not — see
  §7 of the notes and `scripts/android-env.sh`.


## The rest of this set

- [photocraft-android](https://github.com/kanaaka/photocraft-android) — PhotoCraft 0.7.0
- [vectorcraft-android](https://github.com/kanaaka/vectorcraft-android) — VectorCraft 0.9.0
- [wordcraft-android](https://github.com/kanaaka/wordcraft-android) — WordCraft 0.5.0
- [gridcraft-android](https://github.com/kanaaka/gridcraft-android) — GridCraft 0.5.0
- [deckcraft-android](https://github.com/kanaaka/deckcraft-android) — DeckCraft 0.5.0
- [shared-android-port](https://github.com/kanaaka/shared-android-port) — build/verify scripts + the cross-compile environment

## Credits and licence

PdfCraft is © its authors at [`storytold/pdfcraft`](https://github.com/storytold/pdfcraft) and is
dual-licensed Apache-2.0 / MIT; both licence texts are kept here. The Android layer in this
repository is an unofficial modification by [@kanaaka](https://github.com/kanaaka), carrying the
same licence. Not affiliated with or endorsed by the upstream project. See
[`ATTRIBUTION.md`](ATTRIBUTION.md).


## Android 16 build (physicistlk fork)

This fork carries the Android 16 port (arm64-v8a, 16 KB page-aligned) plus the
tablet-compatibility milestones (system clipboard, open-with/share intents, flush on
suspend, back-gesture closes dialog, trackpad wheel + pen hover, stylus pressure for
PhotoCraft, PhotoCraft crash-recovery autosave).

A signed APK for the current state is attached to the
[v2026.10.30 release](https://github.com/physicistlk/pdfcraft-android/releases/tag/v2026.10.30).

See the upstream `kanaaka` repository for the full port notes and verification details.
