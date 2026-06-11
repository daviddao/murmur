# Murmur

A tiny, open-source, superwhisper-style dictation app for macOS.

**Hold right ⌘ · speak · release — your words appear in whatever app you're typing in.**

- 🪶 **Minimal**: a menu bar item and a small floating waveform HUD. Nothing else.
- 🔒 **Local by default**: transcribes on-device with NVIDIA **Parakeet TDT 0.6B**
  (the same model superwhisper uses) via Core ML / [FluidAudio](https://github.com/FluidInference/FluidAudio).
  No audio ever leaves your Mac.
- ☁️ **Or your ElevenLabs subscription**: switch the engine to **ElevenLabs Scribe**
  and paste in your API key.
- ⌨️ **Push-to-talk**: hold right ⌘ (or right ⌥ / right ⌃) anywhere, in any app.
  Esc cancels. Regular ⌘-shortcuts still work.
- 📋 Pastes into the active app and **restores your clipboard** afterwards.

## Build & install

Requires macOS 14+ (Apple Silicon recommended) and Xcode command line tools.

```bash
make install   # builds build/Murmur.app and copies it to /Applications
open /Applications/Murmur.app
```

or just `make run` to try it from the build folder.

## First run

1. **Microphone** — approve the prompt.
2. **Accessibility** — approve the prompt (needed to detect the right ⌘ key
   globally and to paste text). System Settings → Privacy & Security → Accessibility.
3. With the Parakeet engine, the first launch downloads the model (~1 GB)
   from Hugging Face and caches it. The menu shows `Parakeet: ready` when done.
4. Hold right ⌘ and talk.

> Note: the app is ad-hoc signed. If you rebuild it, macOS may ask you to
> re-grant Accessibility (toggle it off/on in System Settings).

## Settings

Menu bar icon → Settings…

| Setting | Notes |
|---|---|
| Hold to dictate | Right ⌘ / right ⌥ / right ⌃ |
| Engine | Parakeet (local) or ElevenLabs (cloud) |
| Parakeet model | v3 multilingual · v2 English-only |
| ElevenLabs | API key, Scribe v1/v2, optional language hint |
| Launch at login | via SMAppService |

## How it works

`CGEventTap` watches for the right-⌘ `flagsChanged` events → `AVAudioEngine`
records and resamples to 16 kHz mono → Parakeet (Core ML) or ElevenLabs Scribe
transcribes → the text is pasted via a synthetic ⌘V with clipboard restore.

MIT licensed. No telemetry, no accounts, no subscription.
