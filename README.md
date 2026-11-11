# Whisper Notes

A Flutter app for iOS and Android that turns voice messages into text **on the
device**: record in the app, or share a WhatsApp voice message to it, and get a
transcript plus a short bullet summary. No cloud service sees your audio.

## Features

- **Share from WhatsApp** (or any app): Android share intent, iOS Share
  Extension. WhatsApp voice messages (`.opus`) are converted to 16 kHz WAV
  automatically.
- **Record in the app** with a live level meter and timer.
- **Transcription** with [whisper.cpp](https://github.com/ggml-org/whisper.cpp)
  through [`whisper_ggml`](https://pub.dev/packages/whisper_ggml).
- **Summary** in 3-5 bullets from a small on-device LLM through
  [`flutter_edge_ai`](https://pub.dev/packages/flutter_edge_ai) (LiteRT-LM).
- **History** stored locally; open, copy, delete.
- **Export** as `.txt` or `.md` through the system share sheet
  ("Save to Files", Drive, mail, ...).
- Language: German (default), English or auto-detect.

## Models

Downloaded once on first use, then cached on the device. After that the app
works offline.

| Purpose | Model | Download | Notes |
|---|---|---|---|
| Speech-to-text | Whisper `small` (default) | 466 MB | Good German; recommended |
| Speech-to-text | Whisper `base` | 142 MB | Faster, but misses words in German |
| Summary | Qwen2.5 1.5B Instruct (default) | 1.6 GB | Good German summaries |
| Summary | Qwen3 0.6B INT4 | 345 MB | Fast, but weak and prone to repeating itself |

All models are Apache-2.0 / MIT and download without a Hugging Face token.
Both choices are in the settings (top right). `medium` and `large` Whisper
models are too slow and too big for phones.

Messages under 25 words are not sent to the LLM - the summary is the message
itself, because a small model only pads a single sentence with invented
points. Repeated bullets are dropped and at most five are kept.

## Requirements

- Flutter (current stable) with Dart 3
- Android: device with Android 11+ (API 30) and arm64 - the summary runtime
  ships arm64 only, so use a real device or an arm64 emulator
- iOS: iOS 15.6+, Xcode, CocoaPods

## Build and run

```bash
flutter pub get
flutter test
flutter run            # pick the connected device
```

### iOS signing (once)

The app and its Share Extension share an App Group
(`group.dev.schemann.whispernotes`) to hand over shared files.

1. Open `ios/Runner.xcworkspace` in Xcode.
2. For both targets **Runner** and **ShareExtension**: Signing & Capabilities,
   pick your team. Change the bundle IDs (`dev.schemann.whisperNotes`,
   `dev.schemann.whisperNotes.ShareExtension`) to your own prefix.
3. Under App Groups on both targets, use one group you own and put the same
   name into `AppGroupId` in `ios/Runner/Info.plist` and
   `ios/ShareExtension/Info.plist`.

### Sharing a WhatsApp voice message

- **Android:** long-press the voice message, Share, Whisper Notes. The app
  opens and transcribes it.
- **iOS:** long-press the voice message, Forward, Share icon, Whisper Notes.
  The extension saves it; open Whisper Notes and it is transcribed right away.

## Architecture

```
lib/
  main.dart                       app setup, LLM engine registration
  src/models/note.dart            Note, NoteSource, NoteLanguage
  src/data/history_repository.dart  history as JSON (atomic writes)
  src/services/
    transcription_service.dart    whisper.cpp (model download, transcribe)
    summary_service.dart          on-device LLM summary
    summary_text.dart             cleans LLM output into bullets
    recorder_service.dart         16 kHz mono WAV recording, level meter
    share_inbox.dart              MethodChannel to the native share handlers
    export_formatter.dart         .txt / .md export
  src/app/providers.dart          Riverpod providers, processing pipeline
  src/ui/                         home, record panel, note detail
android/.../MainActivity.kt       receives ACTION_SEND audio
ios/ShareExtension/               Share Extension, writes to the App Group inbox
ios/Runner/AppDelegate.swift      hands the inbox to Dart
```

Transcription and LLM inference run off the UI isolate; the UI shows progress
for model downloads, transcription and summarising.

## Tests

```bash
flutter analyze
flutter test
```

Unit tests cover the note model, history storage (including a corrupt file),
the export formats and the summary clean-up.

## Ideas for extensions

- Live transcription while recording (`transcribeLive` in `whisper_ggml`).
- Search across the history.
- Silero VAD to cut silence before transcribing (fewer hallucinations).
