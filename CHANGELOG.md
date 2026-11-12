# Changelog

## 2026-11-12 — Upstream 0.21.1

| | |
|---|---|
| APK | `pdfcraft-0.21.1-arm64-v8a-20261112.apk` — sha256 in `SHA256SUMS.txt` beside the build |
| Built from | upstream `storytold/pdfcraft` @ `b503b2e62dfeec5598f344e4e287d9c9cbdb34fa` (tag `v0.21.1`) + `patches/0001-pdfcraft-android-port.patch` + `apps/pdfcraft-android/` + the patched `vendor/winit/` |
| Package | `ai.storyteller.pdfcraft` — unchanged; versionName `0.21.1`, versionCode `16782593`, minSdk 26, targetSdk 35 |
| ABI | `arm64-v8a` only |
| Signature | local test key (`.pdfcraft-signing/pdfcraft-test.jks`) |
| sha256 | `759dddba8a1394c2462065589761298c27d25183a6f7d58515235738d09f12cc` |

### Changed
- **Upstream moved from 0.20.0 to 0.21.1** (1087 commits; this tag carries the 0.21.0 major bump
  plus the 0.21.1 patch). The port's shape is unchanged: `crate::rfd` still stands in for `rfd` on
  Android (`src/rfd.rs` + `src/rfd_android.rs`), `arboard` is still not built for Android, and the
  patched `vendor/winit` (with `ImeResetCompleted` / `reset_ime_with_request`, required by the
  pinned egui-winit) is refreshed from this repository — it is not in the patch.
- **The egui pin moved with upstream** from `6d518fc` to `725a39f` (fourteen `[patch.crates-io]`
  lines). Upstream's `vendor/winit` still lacks the port's IME variant, so the worktree's copy is
  replaced wholesale from `vendor/winit` here; only `winit = { path = "vendor/winit" }` is a port
  change in `Cargo.toml`.
- **File ▸ Open keeps upstream's new filter list.** v0.21 added `open_filters()` (PDF, Images,
  Office documents, Text, All files) plus `open_picker()`, for opening Word/Excel/PowerPoint
  through LibreOffice. The port keeps that list and routes the one picker creation through
  `crate::rfd::AsyncFileDialog`, so the Android SAF picker still answers it; the three old inline
  `crate::rfd` pickers are gone, superseded by `open_picker()`.
- **Take a Snapshot follows upstream's split.** v0.21 moved the clipboard write out of
  `render_area` and into `snapshot()` (which now receives the pixels). The port re-applied its
  `all(not(target_arch = "wasm32"), not(target_os = "android"))` gate to the new `snapshot()`
  body, so a snapshot is still taken and kept in `last_snapshot` while the OS-wide image clipboard
  stays unavailable, as on the web. The new "Save as image" dialog in the same file now asks
  through `crate::rfd` too.
- **Verified:** `cargo check -p pdfcraft-android --target aarch64-linux-android` exits 0;
  `cargo apk build --release -p pdfcraft-android` produced a 29.3 MiB signed APK;
  `aapt2 dump badging` shows `ai.storyteller.pdfcraft` `0.21.1` `arm64-v8a`;
  `apksigner verify` shows v2/v3 signatures from the local test certificate; every ELF LOAD
  segment is 0x4000-aligned (16 KB); `patches/0001-pdfcraft-android-port.patch` passes
  `git apply --check` on a pristine `git archive v0.21.1` tree with `apps/pdfcraft-android/` and
  `vendor/winit` copied in, and reproduces the built tree exactly (all 31 patched files compare
  equal).

## 2026-11-09 — Upstream 0.20.0

| | |
|---|---|
| APK | `pdfcraft-0.20.0-arm64-v8a-20261109.apk` — sha256 in `SHA256SUMS.txt` beside the build |
| Built from | upstream `storytold/pdfcraft` @ `2ad7717f87ad` (tag `v0.20.0`) + `patches/0001-pdfcraft-android-port.patch` + `apps/pdfcraft-android/` + the patched `vendor/winit/` |
| Package | `ai.storyteller.pdfcraft` — unchanged; versionName `0.20.0`, versionCode `16782336`, minSdk 26, targetSdk 35 |
| ABI | `arm64-v8a` only |
| Signature | local test key (`.pdfcraft-signing/pdfcraft-test.jks`) |
| sha256 | `58028d88e9a5a8b1f0f71969458c0e4dc26946220ee724de788b76c20a37a3bf` |

### Changed
- **Upstream moved from 0.19.0 to 0.20.0** (870 commits; the 0.19.0 round was not recorded here).
  The port's shape is unchanged: the `rfd` name is still resolved inside `crates/ui-egui`
  (`src/rfd.rs` + `src/rfd_android.rs`), `arboard` is still not built for Android, and the patched
  `vendor/winit` (with `ImeResetCompleted` / `reset_ime_with_request`, required by the pinned
  egui-winit `6d518fc`) is refreshed from this repository — it is not in the patch.
- **`eframe::App::on_exit` now takes `Option<&eframe::glow::Context>`.** The shell's `impl
  eframe::App for Shell` was updated to the new signature. `pdfcraft-ui-egui` keeps upstream's
  new always-on `glow` eframe feature (its `on_exit` needs a GL context), while still excluding
  `accesskit` from the main eframe line so the shell's `android-native-activity` can coexist with it.
- **Copy with formatting (new upstream rich-text clipboard) is plain text on Android.** v0.20 added
  `app::put_rich_text` / `takes_html` and the `os_clipboard: Option<arboard::Clipboard>` field;
  `arboard` has no Android backend, so the field, its initialiser, `takes_html` and `put_rich_text`
  are all gated off `target_os = "android"` (the same shape as the existing wasm32 fallback), and
  the call falls back to `Context::copy_text` — consistent with the port's text-only clipboard.
- **`create_ui::save_optimized` merged with upstream's new re-ask flow.** Upstream added
  `destination` / `chose_first` and `ask_where_to_save_optimized`; the port keeps its
  `save_override` arm (`destination.or_else(|| self.save_override.clone())`) and the new helper
  asks through `crate::rfd::AsyncFileDialog`, so the Android SAF picker is still used.
- **Verified:** `cargo check -p pdfcraft-android --target aarch64-linux-android` exits 0;
  `cargo apk build --release -p pdfcraft-android` produced a 29.7 MB signed APK;
  `aapt2 dump badging` shows `ai.storyteller.pdfcraft` `0.20.0` `arm64-v8a`;
  `apksigner verify` shows the local test certificate; every ELF LOAD segment is 0x4000-aligned
  (16 KB); `patches/0001-pdfcraft-android-port.patch` passes `git apply --check` on a pristine
  `git archive v0.20.0` tree with `apps/pdfcraft-android/` and `vendor/winit` copied in, and
  reproduces the built tree exactly.

## 2026-11-04 — Upstream 0.18.1

| | |
|---|---|
| APK | `pdfcraft-0.18.1-arm64-v8a-20261104.apk` — sha256 in `SHA256SUMS.txt` beside the build |
| Built from | upstream `storytold/pdfcraft` @ `8bb0528bed78` (tag `v0.18.1`) + `patches/0001-pdfcraft-android-port.patch` + `apps/pdfcraft-android/` |
| Package | `ai.storyteller.pdfcraft` — unchanged; versionName `0.18.1`, versionCode `16781825`, minSdk 26, targetSdk 35 |
| ABI | `arm64-v8a` only |
| Signature | local test key (`.pdfcraft-signing/pdfcraft-test.jks`) |
| sha256 | `43c529c4bf522c0be7e2771d63fd38049570c5feafbd056967918ee3d21f20d7` |

### Changed
- **Upstream moved from 0.15.0 to 0.18.1.** The port's shape is unchanged: the `rfd` name is still resolved inside `crates/ui-egui` (`src/rfd.rs`, now part of the patch as a new file, with `src/rfd_android.rs`), `arboard` is still not built for Android, and the patched `vendor/winit` (with `ImeResetCompleted` / `reset_ime_with_request`, required by the pinned egui) is restored on top of the vendored tree — it is not in the patch itself.
- **New `os_clipboard.rs` (v0.17+) is Android-gated.** v0.17 introduced `os_clipboard` wrapping `arboard`; the module and all its call sites (`create_ui.rs`, `content_ui.rs`, `zoom_snap.rs`, `app/clipboard.rs`) now exclude `target_os = "android"`, matching the existing wasm32 fallbacks. The Android text-clipboard hook (`install_clipboard_text`) is re-added in `workflows/create_ui.rs` and re-exported from `lib.rs`.
- **Verified:** `cargo check -p pdfcraft-ui-egui` (host) and `cargo check -p pdfcraft-android --target aarch64-linux-android` pass; `cargo apk build --release -p pdfcraft-android` (6m42s) produced a 26 MB signed APK; `aapt2 dump badging` shows `ai.storyteller.pdfcraft` `0.18.1` `arm64-v8a`; `apksigner verify` v2/v3 true; all ELF LOAD segments 16 KB-aligned; `patches/0001-pdfcraft-android-port.patch` applies cleanly to pristine `v0.18.1`.


## 2026-10-30 — The system clipboard (text)

| | |
|---|---|
| APK | `pdfcraft-0.15.0-arm64-v8a-20261030.apk` — sha256 in `SHA256SUMS.txt` beside the build |
| Package | `ai.storyteller.pdfcraft` — versionName `0.15.0`, minSdk 26, targetSdk 35 |
| ABI | `arm64-v8a` only |

### Changed
- **The system clipboard works for text (`src/clipboard.rs`).** Ctrl+C/X/V now produce
  `Event::Copy`/`Cut`/`Paste` (the Android backend never reports modifiers, so `egui-winit` never
  did), Paste reads `ClipboardManager` through JNI, and `OutputCommand::CopyText` is written back
  with `ClipData.newPlainText`.
- **Create ▸ Clipboard reads text from the system clipboard.** A new
  `pdfcraft_ui_egui::install_clipboard_text(reader)` hook (in `workflows/create_ui.rs`, re-exported
  from `lib.rs`) lets the shell supply the reader; the command creates a PDF from the text. Images
  and files are still out of reach on Android, and Copy Image in Original Format still says so.

## Unreleased — 2026-10-28 (upstream 0.15.0)

| | |
|---|---|
| APK | `pdfcraft-0.15.0-arm64-v8a-20261028.apk` — built and signed locally, not published |
| Built from | upstream `storytold/pdfcraft` @ `75360d1d7db06fed974f48c914d4c04132757187` (tag `v0.15.0`, the newest stable release on 2026-10-28) + `patches/0001-pdfcraft-android-port.patch` + `apps/pdfcraft-android/` |
| Package | `ai.storyteller.pdfcraft` — unchanged; versionName `0.15.0`, versionCode `16780288`, minSdk 26, targetSdk 35 |
| ABI | `arm64-v8a` only |
| Signature | local test key (different from the published v0.1.0–v0.1.2 key) |

### Changed
- **Upstream moved from 0.6.0 to 0.15.0** (2578 commits between the pins). The port's shape is
  unchanged — the `rfd` name is still resolved inside `crates/ui-egui` rather than in `Cargo.toml`,
  because Cargo refuses a dependency whose source path differs per target — but the patch was
  re-derived against the new tree instead of being forced onto it:
  - `crates/ui-egui/src/` was reorganised upstream (`src/pickers.rs` → `src/platform/pickers.rs`,
    `src/create_ui.rs` → `src/workflows/create_ui.rs`, and so on), so the 22 patched files became
    25 (the same work, spread over the new layout).
  - The `rfd` call sites went from 42 to 50; each one now says `crate::rfd::…`.
  - `arboard` (the OS clipboard) is now used in four files rather than two, so the Android
    exclusion was applied to all of them. Copy Image in Original Format has an explicit Android
    arm that says the clipboard is out of reach instead of failing silently.
  - `egui` moved from 0.36 to 0.37, which added a `source` to `Event::MouseWheel`; the synthesised
    two-finger scroll says `MouseWheelSource::Unknown`, which keeps egui on the plain wheel path.
  - The upstream `Services` struct that the README describes no longer exists; PdfCraft reaches
    the platform through `crate::rfd` and the `PdfCraftApp` itself, which is still an
    `eframe::App`, so the shell crate's structure is unaffected.

### Not changed
- The Android package id (`ai.storyteller.pdfcraft`), the min/target SDK levels, the permissions,
  the theme resources, the icon, and every Android-specific fix in the port (picker, modifier
  keys, two-finger scrolling, preferences written while the app runs, Activity not recreated on
  configuration change).

## v0.1.2 — 2026-10-13 (Ctrl shortcuts)

| | |
|---|---|
| APK | `pdfcraft-0.6.0-arm64-v8a-20261013b.apk` (21.8 MB) — supersedes the v0.1.1 asset, same signing key |
| sha256 | `0619612b7d8cfcb76690e7d12302c463aa234d939ebece8353238e6a54f7b9ce` |
| Built from | upstream `storytold/pdfcraft` @ `3d2bdfe71ada10f6bc39afc680dce61bbf080cbc` + this repository at the commit that released it |
| Package | `ai.storyteller.pdfcraft` — versionName `0.6.0`, versionCode `16778752`, minSdk 26, targetSdk 35 |
| ABI | `arm64-v8a` only |

### Fixed
- **Ctrl+anything did nothing, while Shift+click and Shift+arrow worked.** winit's Android
  logical-key table names `Shift` and `Alt` but **not** `Control` — so a Ctrl press arrives with an
  unidentified *logical* key (egui-winit falls back to the physical one) while its physical key is
  correctly `ControlLeft`/`ControlRight`. `src/modifiers.rs` matched the logical key alone, so it
  never saw Ctrl go down: Ctrl+A, Ctrl+C, Ctrl+V, Ctrl+S, Ctrl+B and every other modifier shortcut
  was dead, and only the modifiers winit happens to name worked. The tracker now reads the physical
  key as well as the logical one, on both left and right, and keeps everything else: the per-event
  modifier copies (so a press and a click in one frame stay ordered) and `ModifiersChanged` as the
  authority (so a modifier held while the app goes to the background does not stick).
  The same tracker is in all four ports of this set; it is verified end-to-end in WordCraft
  (`Ctrl+A` selects the text, `Ctrl+B` emboldens it). This app's own shortcuts are the tablet check.

## v0.1.1 — 2026-10-13 (scrolling, modifiers, fonts, picker wording)

| | |
|---|---|
| APK | `pdfcraft-0.6.0-arm64-v8a-20261013.apk` (21.8 MB) — supersedes the v0.1.0 asset, same signing key |
| sha256 | `e6e77cf7b7516bbb4b9f297b51b31b3fec37b0cba1813e57bce9c98015936c40` |
| Built from | upstream `storytold/pdfcraft` @ `3d2bdfe71ada10f6bc39afc680dce61bbf080cbc` + this repository at the commit that released it |
| Package | `ai.storyteller.pdfcraft` — versionName `0.6.0`, versionCode `16778752`, minSdk 26, targetSdk 35 |
| ABI | `arm64-v8a` only |

### Changed
- **Two-finger scrolling.** A two-finger drag now scrolls the document (synthesised `MouseWheel`
  events from the touch centroid, with the lift event that starts the kinetic coast); one finger still
  selects and a pinch still zooms.
- **Ctrl+wheel zoom** — the shell's modifier tracker now hands its state to the touch-to-wheel bridge,
  which stamps it onto the wheel events it synthesises.

### Notes
The build was made from exactly the source in this repository (upstream pin + the patch + the port
crate) and signed with the same local test key as v0.1.0, so it installs over it.


## v0.1.0 — first published port (PdfCraft 0.6.0)

| | |
|---|---|
| APK | `pdfcraft-0.6.0-arm64-v8a-v3.apk` (21.8 MB) |
| sha256 | `6c03616ce94caf0a06532e6eac46d7e975a3483afe5baec05cdf4878cd80ad18` |
| Built from | upstream `storytold/pdfcraft` @ `3d2bdfe71ada10f6bc39afc680dce61bbf080cbc` + `patches/0001-pdfcraft-android-port.patch` + `apps/pdfcraft-android/` |
| Package | `ai.storyteller.pdfcraft` — versionName `0.6.0`, minSdk 26, targetSdk 35 |
| ABI | `arm64-v8a` only |
| Signature | throwaway local test key, not an official key |

### In this release
- Android shell crate: NativeActivity entry point, `Services` implementation, file logger, preferences
  written while the app runs (atomic), modifier-key synthesis, Activity not recreated on configuration
  change.
- **Every file dialog works**: 42 call sites moved to `crate::rfd`, which is the real `rfd` on the
  desktop and the host's own egui picker on Android — Open, Save As, export folders, OCR folders,
  attach, sign, stamps, print.
- Clipboard code that cannot exist on Android is compiled out rather than left broken; the paths that
  remain say what they can and cannot do instead of failing at runtime.
- In-app picker with cached listings, "Show all files", hidden-file count, self-explaining locked
  roots, and a chosen save path returned to the app so the document learns which file it is.
- Launcher icon, storage permissions, edge-to-edge theme variant.


### Known issues
See *Known gaps* in the [README](README.md) and [`docs/PORT-NOTES.md`](docs/PORT-NOTES.md).
