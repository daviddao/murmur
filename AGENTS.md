# AGENTS.md — working on Murmur

Guidance for AI coding agents (and humans in a hurry).

## What this is

A macOS menu bar dictation app: hold right ⌘ → record mic → transcribe
(local Parakeet via FluidAudio/Core ML, or ElevenLabs Scribe API) → paste into
the frontmost app. Swift Package Manager only — **no Xcode project**.

## Commands

```bash
swift build -c release          # compile
make app                        # build + bundle build/Murmur.app (plist, icon, ad-hoc codesign)
make run                        # build + open the app
make install                    # build + copy to /Applications
make clean                      # rm -rf .build build
.build/release/Murmur transcribe file.wav   # headless test of the Parakeet pipeline
```

There are no unit tests; validate changes with the CLI mode above plus a manual
smoke test (build, run, hold right ⌘, speak, release, check pasted text).

## Architecture (Sources/Murmur/)

| File | Role |
|---|---|
| `MurmurApp.swift` | `@main` entry. Routes `transcribe` CLI arg, else launches SwiftUI `MenuBarExtra` + `Settings` scenes. |
| `AppState.swift` | `@MainActor` coordinator + state machine (`idle → recording → transcribing → success/error`). Owns recorder, hotkey, HUD. |
| `HotkeyMonitor.swift` | CGEventTap watching `flagsChanged`/`keyDown`. Detects right-modifier hold via device-specific flag bits. Esc cancels (swallowed); other keys cancel (passed through). |
| `AudioRecorder.swift` | AVAudioEngine mic tap → resample to 16 kHz mono Float32 → `[Float]` + RMS levels for the HUD. |
| `ParakeetTranscriber.swift` | Actor wrapping FluidAudio `AsrManager`. Downloads/caches model on first use. |
| `ElevenLabs.swift` | Multipart POST to `/v1/speech-to-text` (Scribe). |
| `TextInserter.swift` | Clipboard snapshot → set text → synthetic ⌘V → restore clipboard after 0.8 s. |
| `HUD.swift` | Non-activating, click-through `NSPanel` at bottom-center + SwiftUI waveform/status capsule. |
| `MenuContent.swift` / `SettingsView.swift` | Menu bar menu and settings form. |
| `Settings.swift` | `Defaults` enum = UserDefaults read side. Keys must stay in sync with `@AppStorage` strings in the views. |
| `WAV.swift` | `[Float]` → 16-bit PCM WAV (for the ElevenLabs upload). |
| `Sound.swift` | System sound feedback (toggleable). |

Packaging lives in `scripts/`: `Info.plist` (bundle template), `build_app.sh`,
`make_icon.swift` (regenerates `AppIcon.icns`).

## Gotchas & invariants

- **FluidAudio 0.9.x API**: `AsrModels.downloadAndLoad(version:)` →
  `AsrManager(config: .default)` → `loadModels(_:)` →
  `transcribe(_, decoderState: &state)` with a **fresh `TdtDecoderState.make()`
  per utterance**. Older docs mention `initialize(models:)` / `source:` params —
  those don't exist anymore. Check `.build/checkouts/FluidAudio` before changing.
- **Audio is 16 kHz mono Float32 everywhere.** Never hand-decode audio bytes;
  go through `AVAudioConverter` (or FluidAudio's converter for files).
- **The event tap callback runs on the main run loop and must stay fast.**
  Re-enable the tap on `.tapDisabledByTimeout`. Right/left modifiers are
  distinguished by device flag bits (right ⌘ = `0x10`), not by `.maskCommand`.
- **TCC / permissions**: the app needs Microphone + Accessibility. It is
  **ad-hoc signed**, so every rebuild changes the signature and macOS may
  require re-granting Accessibility (toggle off/on). Bundle id:
  `dev.murmur.Murmur`. Don't rename it casually — users lose their grants.
- **The HUD panel must never become key/main** (`.nonactivatingPanel`,
  `ignoresMouseEvents`), otherwise focus leaves the user's app and pasting breaks.
- **AppState is `@MainActor`**; hotkey callbacks hop in via
  `MainActor.assumeIsolated` (safe: the tap runs on the main thread).
- Language mode is Swift 5 (`swift-tools-version: 5.10`) on purpose — don't
  bump to 6 without fixing the resulting strict-concurrency errors.
- Keep dependencies to exactly one: FluidAudio. No analytics, no networking
  beyond the ElevenLabs call.

## Style

- 4-space indent, no trailing whitespace, `// MARK:` sections in larger files.
- User-facing strings are short and lowercase-ish ("transcribing", "preparing model…").
- Prefer adding settings as a `Defaults` accessor + `@AppStorage` pair with the
  same string key.

## Release checklist

1. `make app` builds clean.
2. `.build/release/Murmur transcribe /tmp/test.wav` returns correct text
   (generate one: `say -o /tmp/t.aiff "hello world" && afconvert -f WAVE -d LEI16@16000 -c 1 /tmp/t.aiff /tmp/test.wav`).
3. Manual smoke test in a real text field (both engines if touched).
4. Esc-cancel, short-tap ignore, and clipboard restore still work.
