# Port notes — PdfCraft on Android

Upstream: [`storytold/pdfcraft`](https://github.com/storytold/pdfcraft) @
`75360d1d7db06fed974f48c914d4c04132757187` (v0.15.0 — was `3d2bdfe71ada10f6bc39afc680dce61bbf080cbc`, v0.6.0)
Published APK: `pdfcraft-0.6.0-arm64-v8a-v3.apk` (v0.1.0–v0.1.2, upstream 0.6.0);
local build against upstream 0.15.0: `pdfcraft-0.15.0-arm64-v8a-20261028.apk`

The port is `apps/pdfcraft-android/` (`src/lib.rs` 289 lines, `src/file_picker.rs` 403,
`src/modifiers.rs` 202, `src/prefs_watch.rs` 134, `src/clipboard.rs`) plus **22 upstream files** — the
largest patch in this set, and almost all of it is one problem: PdfCraft calls `rfd` directly instead
of going through a `Services` seam, and `rfd` does not exist on Android.

## 2026-10-30 — Trackpad wheel + pen hover (`vendor/winit`)

This port previously used the git winit, whose Android backend dropped `MotionAction::Scroll`
and `MotionAction::HoverMove`. It now vendors the same patched winit the WordCraft and
DeckCraft ports ship (copied into `vendor/winit/`, with `Cargo.toml` resolving winit from
it), so the backend forwards those events. The `Cargo.toml` change joins this port's patch
(26 tracked files).

## 2026-10-30 — Flush preferences on suspend (`raw_input_hook`)

A lost-focus frame now writes `ui.json` with `store_now`, so a swipe from Recents (or a paused
Activity being killed) no longer takes the preferences with it.

## 2026-10-30 — Open-with and share intents (`src/intents.rs`)

**The complaint:** a PDF tapped in a file manager, or shared from another app, never reached PdfCraft;
and there was no way to hand the current document to another app.

`src/intents.rs` covers the half that does not need `startActivityForResult`:

- **Incoming `ACTION_VIEW`** — the launching URI is read at startup and copied out of a
  `content://` URI into the cache directory; the shell opens it on its first frame (`open_path`).
- **Incoming `ACTION_SEND`** — `EXTRA_TEXT` and `EXTRA_STREAM` are handled the same way.
- **Outgoing `ACTION_SEND`** — `intents::share_text` starts a chooser; `share_file` is provided but
  needs a `FileProvider` entry to work on Android 7+.

The launching intent is read in `android_main` and consumed once in `Shell::logic`.

**Scope:** opening a file handed to the app, and sharing text. SAF pickers remain deferred (no
`startActivityForResult` in `android-activity` 0.6.1); the in-app picker is still the way to open
or save.

**Checked:** the module's host test passes, the crate compiles for `aarch64-linux-android`, and the
host suite is 16/16. The JNI intent path has not run on a device.

## 2026-10-30 — The system clipboard (`src/clipboard.rs`)

**The complaint:** copy and paste worked only *inside* the app, and *Create ▸ Clipboard* always said
the clipboard was empty — even with text on it.

This port had no clipboard at all: `arboard` is compiled out on Android (§4), and winit's Android
backend has no clipboard either, so `egui-winit` kept its in-app simulated clipboard. Modifiers are
not reported by the backend either (§5), so `egui-winit` never turned Ctrl+C/X/V into
`Event::Copy`/`Cut`/`Paste` — the keys arrived as ordinary presses and no clipboard event was ever
produced.

`src/clipboard.rs` supplies four pieces, and a small hook in the UI crate:

- `install(&app)` — this thread's Activity handle, captured before `run_native`.
- `shortcuts(raw)` — in `raw_input_hook`, after the touch bridge: a plain Ctrl+C/X/V becomes
  `Event::Copy`/`Cut`/`Paste` and the press is consumed, as on the desktop. Ctrl+V reads the
  **system** clipboard and pushes nothing when it is empty. Ctrl+Shift/Ctrl+Alt go to the app.
- `publish(ctx)` — after the app's `ui`: every `OutputCommand::CopyText` this frame is written with
  `ClipData.newPlainText` + `setPrimaryClip`, and left in the command list so egui-winit's in-app
  copy still happens.
- `text()` — the read half.

The hook is a new `pdfcraft_ui_egui::install_clipboard_text(reader)` (in `workflows/create_ui.rs`,
re-exported from `lib.rs`): *Create ▸ Clipboard* is a menu command with no host handle in scope, so
the shell installs its reader once and `read_clipboard()` on Android asks it for text. It returns
`Clip::Text`, and the existing create-from-text path does the rest. Images still have no Android
reader, so a text clip is the only thing that command can now take — which is more than before.

A clipboard read Android refuses (Android 10+ allows reads only while the app is focused) is logged
and cleared, and answers "nothing".

**Scope:** plain text. Copying an image as an image, and Copy Image in Original Format as a *file*,
remain out of reach on Android (§4); the app already says so.

**Checked:** eight unit tests in `clipboard.rs` plus the UI crate's existing suite pass on the host;
`cargo check -p pdfcraft-android --target aarch64-linux-android` is clean. The JNI path has not run on
a device — none was connected for this build.

## 1. The shell crate

`pdfcraft_ui_egui::Services` is a struct of `Option<Box<dyn Fn…>>` fields deriving `Default`; the
desktop binary and the browser shell fill it their own way, and this is the third. Load-bearing in
every port of this set:

- **`[lib] name = "pdfcraft"` + `crate-type = ["cdylib"]`** → `lib/arm64-v8a/libpdfcraft.so`, and the
  injected `android.app.lib_name` meta-data is the artifact name with `-` → `_`. A mismatch installs
  and then dies on launch.
- **`options.android_app = Some(app)`** — `eframe::run_native` errors without it.
- **A file logger in the app's own data directory**, because `logcat` needs adb and a sideloaded build
  has none.
- **Preferences under `internal_data_path()`**, written while the app runs (§5).

## 2. `rfd` has no Android backend — why the name is resolved *inside* the crate

`rfd`'s `backend.rs` compiles no module for a target that is neither Linux/BSD, macOS, Windows nor
wasm32: the `FilePickerDialogImpl` family is declared and nothing implements it, so the build stops at
the first call with `the trait bound FileDialog: FilePickerDialogImpl is not satisfied`. Android's own
picker is not a substitute, because the Storage Access Framework needs `startActivityForResult`, which
`android-activity` 0.6 does not expose.

The obvious fix — swap in a stand-in crate called `rfd` under a target table — is refused by Cargo:

```
Dependency 'rfd' has different source paths depending on the build target.
Each dependency must have a single canonical source path irrespective of build target.
```

So the name is resolved one hop inside the crate instead. `crates/ui-egui/src/rfd.rs` (new) is the real
`rfd` wherever it exists — `pub use ::rfd::*`, the same crate, same types, same behaviour — and on
Android it is `rfd_android.rs` (new), a drop-in for the small part this crate uses:
`AsyncFileDialog` with its filters and its four `pick_*`/`save_file` futures, and `FileHandle`.

All 42 call sites across 20 files now say `crate::rfd::…`. That is the whole of the patch's bulk, and
it is mechanical: the calls are unchanged, only what answers them is.

## 3. How a picker answer gets back

`pickers.rs` creates the dialog future on the UI thread (macOS shows the panel there) and blocks a
worker thread on it. The port keeps that shape exactly:

1. `pick_file()` / `save_file()` / … **register the request with the host immediately** — `ask` is
   called during `ui`, the only moment with an egui frame to draw in — and return a future waiting on
   a channel.
2. The shell draws the picker with egui and answers on that channel when the user chooses or cancels
   (an empty answer already means cancelled to `pickers.rs`).
3. The worker wakes, queues the pick, and wakes the window; the app uses it on a later frame.

Blocking that worker is deliberate: it is a dedicated thread, which is what `rfd`'s own Linux backend
does, and polling the channel from `poll` would need a waker the picker has no way to reach. When no
picker is installed — a test, or a host that forgot — the request is "cancelled" immediately with an
error in the log, because waiting for a dialog that can never be drawn looks exactly like a hang.

The picker drawing rules are the ones the sibling ports share: sized from `ctx.content_rect()`,
enlarged padding for fingers, a repaint requested while open, listings and readability probes cached
per visit rather than per frame, locked roots left tappable so they can name the permission and the
Settings path, the filter shown as the union of every extension asked for with **"Show all files"**
and a count of the hidden ones, and a save answer of `dir.join(name)` so the app's atomic write finds
its parent.

## 4. The two other crates with no Android backend

- **`arboard`** (the OS clipboard) fails with `cannot find Set in module platform`. It is dropped from
  the Android build entirely (`[target.'cfg(all(not(target_os = "android"), not(target_arch = "wasm32")))'.dependencies]`),
  and the places that ask for a clipboard keep the branch the browser build already takes — the
  snapshot is still taken, and an *image or file* clipboard is simply out of reach.
  **Text is different since 2026-10-30:** the shell supplies a JNI reader (below), so *Create ▸
  Clipboard* reads text from the system clipboard and *Ctrl+C/X/V* work in text fields.
- **`eframe` itself, declared twice.** `accesskit` and `android-native-activity` are mutually
  exclusive in eframe (`compile_error!("`accesskit` feature is only available with
  `android-game-activity`")`), and Cargo takes features as a **union over the whole graph** — so
  `accesskit` has to be gone from *this* crate for the pair never to meet, not merely absent from the
  shell's manifest. `[target.'cfg(not(target_os = "android"))'.dependencies]` keeps it on the desktop.

## 5. Preferences, and the modifier keys the platform never reports

- **`prefs_watch`**: the desktop writes its preferences on the way out; Android never gives that
  moment, so a swipe from Recents took them with it. The shell writes `ui.json` and `prefs.json` from
  the frame loop — change-detected, at most every two seconds, atomically (temp file + rename, so a
  kill mid-write cannot leave truncated JSON).
- **`modifiers.rs`**: winit's Android backend emits only six window events and never
  `ModifiersChanged`; `egui-winit` reads modifiers from that event and nowhere else, and egui carries
  them as an *event*, so `ctx.input(|i| i.modifiers)` is the all-false default for the entire run —
  Ctrl+S, Ctrl+Z and Shift-click are dead. The key events do arrive, so the shell tracks the modifiers
  in `raw_input_hook` and re-injects them (held state, stamped onto every `Key`/`PointerButton` event,
  one `ModifiersChanged` per frame), carrying state **between** frames because the press and the click
  usually land in different ones.
- **`config_changes`** in the APK metadata, so rotation, docking, split-screen resize, density and
  font-scale changes do not recreate the Activity — a recreated Activity destroys the native window
  while the render thread lives on, which is a blank surface.

## 6. No quit hook to wire

PdfCraft has no *File ▸ Exit*; quitting is the window closing (macOS Dock, a Recents swipe, or the
system back gesture). So the stale-`ViewportCommand::Close` problem its siblings fixed does not arise
here — there is no in-app exit path to end the process from. Preferences survive the kill because they
are written while the app runs (§5), and the shell's own save-on-exit is still there for the clean
path.

## 7. Build note: the C toolchain (this is the one app in the set that needs it)

PdfCraft's `pdfcraft-sign` builds `aws-lc-sys` — a C cryptography library behind `aws-lc-rs` — for
every target that is not wasm32. `cc` looks for a bare `clang.exe` and fails; the NDK's `bin`
directory has to be on `PATH` and `CC`/`CXX`/`AR`/`RANLIB` have to name the NDK wrappers for the
target. `scripts/android-env.sh` is that environment, and it is why the build script exists in this
repository rather than a one-liner: `aarch64-linux-android26-clang.cmd` must match
`min_sdk_version = 26`, or the link fails with an API-level error.

## 8. Permissions, icon, theme

`MANAGE_EXTERNAL_STORAGE` (granted by hand under Settings ▸ Special access; Google Play restricts it
to file-manager-class apps, which does not apply to a sideload), `READ_MEDIA_IMAGES` for Android 13+,
and the legacy storage permissions capped with `max_sdk_version`. `res/values/styles.xml` carries the
same two-variant edge-to-edge theme as the siblings — `targetSdkVersion 35` puts the app under a
transparent status bar on Android 15, and winit 0.30 has no safe-area API — and `res/mipmap-*` carries
the launcher icon.

## Upstream files this port changes (25)

| Group | Files | Change |
|---|---|---|
| `crates/ui-egui/Cargo.toml` | 1 | `eframe` declared twice (`accesskit` off for Android), `rfd`/`arboard` moved to a non-Android target table |
| `crates/ui-egui/src/lib.rs` | 1 | `pub mod rfd;` added; `install_clipboard_text` re-exported for Android |
| `crates/ui-egui/src/rfd.rs`, `rfd_android.rs` | 2 | **new** — the name `crate::rfd`: real `rfd` off-Android, host-backed stand-in on it |
| call sites in `actions_ui, combine_ui, comment_props, content_ui, create_ui, editing, export_ui, files, fill_sign, folders_ui, marks_ui, measure_ui, ocr_ui, pickers, print_ui, sign_ui, stamps_ui, zoom_snap` | 18 | `rfd::` → `crate::rfd::`; `arboard` uses `cfg`-gated to the branch the web build already takes |

> Against upstream **0.15.0** the same work touches **25** files: upstream reorganised
> `crates/ui-egui/src/` into sub-folders (`src/pickers.rs` → `src/platform/pickers.rs`,
> `src/create_ui.rs` → `src/workflows/create_ui.rs`, `src/zoom_snap.rs` → `src/canvas/zoom_snap.rs`,
> `src/sign_ui.rs` → `src/tools/sign_ui.rs`, `src/files.rs` → `src/workflows/files.rs`, …), so the
> call sites moved with it. See §9.

## 2026-10-13 — Two-finger scrolling (and the wheel Android never sends)

**The complaint:** on the tablet a finger drag selected text instead of moving the page, and there was
no way to scroll at all.

**Why:** every app in this suite scrolls from `egui::Event::MouseWheel` — `WordCraft`'s `scroll.rs` is
explicit about the contract (pixel deltas move the page 1:1, `TouchPhase::End` on the last event is the
"fingers lifted" signal that starts the kinetic coast, wheel notches count as three lines). None of
that runs on Android, because winit's Android backend has no mouse and therefore emits no wheel
events at all (`src/platform_impl/android/mod.rs` sends six window events and a wheel is not one of
them). Touch arrives as `WindowEvent::Touch`, which egui-winit forwards as `egui::Event::Touch` *and*
turns into an emulated mouse pointer — so a finger drags a selection and the page never moves.

**The change — `src/touch_scroll.rs` (new, 231 lines, 3 tests), wired into the shell's
`raw_input_hook`:**

- one finger: untouched, so dragging still selects — the emulated pointer works as before;
- two or more fingers: the centroid's movement becomes `Event::MouseWheel` with
  `MouseWheelUnit::Point` and `TouchPhase::Move`;
- a final `TouchPhase::End` wheel event when the fingers lift, which is what makes the app coast to a
  stop instead of stopping dead;
- while a two-finger gesture is live the emulated **pointer button** events are dropped, or the first
  finger would drag a selection across the page at the same time as it scrolls. Pointer *position*
  events are kept, because the apps only scroll while the pointer is over the canvas;
- the touch events themselves stay in the batch: egui's pinch handling reads them, so a pinch still
  zooms and a two-finger *pan* moves nothing but the page.

**Ctrl+wheel zoom** works too, which is why `modifiers.rs`'s `apply()` now returns the state it tracked
(`egui::Modifiers`) instead of nothing: the bridge stamps it onto the wheel event it synthesises, and
the touch events carry it as well.

**Checked:** the three tests in `touch_scroll.rs` (one-finger pass-through, two-finger centroid →
wheel, the lift event) run on the host with `cargo test -p pdfcraft-android`; the shell compiles for
`aarch64-linux-android`; and the string table of the `.so` inside the released APK carries the module.
On-device behaviour is the porter's tablet test, not an automated one.

## 2026-10-13 — `modifiers.rs` returns the tracked state

`apply(&mut self, raw)` now returns the `egui::Modifiers` it folded into the frame's events. The
synthesised two-finger wheel event has to carry modifiers itself (Ctrl+wheel is zoom in these apps,
plain wheel is scroll), and only the tracker knows them, so the state is handed back rather than
recomputed. Nothing else about the modifier handling changed.
## 2026-10-13 — Ctrl shortcuts: the tracker reads the physical key too

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

## 9. The move from upstream 0.6.0 to 0.15.0 (2026-10-28)

The port's shape survives the jump; the patch had to be re-derived rather than forced. What
changed upstream, and what the port did about it:

| Upstream change | What the port did |
|---|---|
| `crates/ui-egui/src/` reorganised into sub-folders (`app/`, `dialogs/`, `editing/`, `home/`, `platform/`, `tools/`, `workflows/`) — `src/pickers.rs` became `src/platform/pickers.rs`, `src/create_ui.rs` became `src/workflows/create_ui.rs`, `src/zoom_snap.rs` became `src/canvas/zoom_snap.rs` | The same 22 files of work were re-applied at the new paths: 25 files in the patch (22 changed + `rfd.rs` + `rfd_android.rs` new, of which 2 are counted in the 25). |
| The `rfd` call sites went from 42 to 50 (new workflows added) | Each new call site was rewritten to `crate::rfd::…` exactly like the old ones; the shim needed no new API, because upstream still only uses `AsyncFileDialog::new`, `add_filter`, `set_title`, `set_file_name`, `set_directory`, `pick_file`, `pick_files`, `pick_folder`, `save_file` and `FileHandle` — all of which the Android stand-in already implements. |
| `arboard` (the OS clipboard) is now used in **four** files, not two: `canvas/image_pick.rs`, `canvas/zoom_snap.rs`, `tools/content_ui.rs`, `workflows/create_ui.rs` | All four are `cfg`-gated away from Android, as the two were before. Copy Image in Original Format needed a third arm (`put_file_on_clipboard`): on Android it says the clipboard is out of reach rather than failing at runtime, and the three helpers it alone used (`clipboard_dir`, `is_copied_image_name`, `write_clipboard_file`) are gated with it, so the Android build has no dead code. |
| `egui` 0.36 → 0.37 | `Event::MouseWheel` gained a `source` field. The synthesised two-finger scroll says `MouseWheelSource::Unknown`, which keeps egui on the plain wheel path (the one 0.36 had for every wheel) instead of the trackpad smoothing, which expects a device that reports its own phase. |
| The `Services` struct the README describes no longer exists | PdfCraft never used it: it reaches the platform through `crate::rfd` and through `PdfCraftApp`, which is still an `eframe::App`. The shell crate's structure (`Shell` forwarding to the app, `raw_input_hook`, `logic`, `save`) is unaffected. |
| `crates/ui-egui/Cargo.toml` gained `accesskit` in the `eframe` features and a `clipboard` feature | The double declaration was kept and extended with `clipboard`: `accesskit` off for Android, on everywhere else. `rfd` and `arboard` moved to a `cfg(all(not(target_os = "android"), not(target_arch = "wasm32")))` table. |
| The build environment needs an NDK C toolchain (`aws-lc-sys`) — unchanged | `scripts/android-env-linux.sh` was added, because `scripts/android-env.sh` is the port author's Windows/MSYS file with `C:\` paths hard-coded. The Linux script takes the SDK/NDK/JDK from the environment and has no machine-specific path in it. |

What did **not** change: the Android package id, the min/target SDK levels, the permissions, the
theme resources, the icon, and every Android-specific fix in the port (the picker, the modifier
tracker, two-finger scrolling, the preferences written while the app runs, the Activity that is
not recreated on a configuration change).

## What is deliberately *not* in the patch

`Cargo.lock` is excluded on purpose: it moves only because the port crate is a new workspace member,
and `cargo` regenerates it on the first build. The patch contains only changes that matter to a reader
— every tracked file the port touches, plus any new file that has to live inside an upstream directory.

## Not verified here

The APK attached to **v0.1.2** was built from exactly this tree on 2026-10-13 (upstream pin + the patch + the port crate), and the checks in the README's verification table were run against it. What that does *not* buy is a runtime claim: it was not launched on a device or emulator as part of publishing, so every behavioural statement below rests on the hand-testing the porter did on an arm64 tablet. The fixes came from
the porter's hand-testing on an arm64 tablet; there is no automated device test here, so "verified" in
the README means the source-side checks listed there plus that testing.
