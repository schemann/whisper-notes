import 'package:whisper_ggml/whisper_ggml.dart';

import '../models/note.dart';

/// Whisper models offered in the app, with what they cost on a phone.
enum SpeechModel {
  base(WhisperModel.base, 'Base · 142 MB · fast'),
  small(WhisperModel.small, 'Small · 466 MB · more accurate');

  const SpeechModel(this.whisper, this.label);

  final WhisperModel whisper;
  final String label;
}

/// On-device speech-to-text with whisper.cpp.
///
/// whisper_ggml converts non-WAV input (WhatsApp .opus, .m4a) to 16 kHz WAV
/// with its bundled FFmpeg and runs inference off the UI isolate.
class TranscriptionService {
  TranscriptionService({WhisperController? controller})
    : _controller = controller ?? WhisperController();

  final WhisperController _controller;

  /// Downloads the model once; later calls return the cached file.
  Future<void> ensureModel(SpeechModel model) =>
      _controller.downloadModel(model.whisper);

  Future<String> transcribe({
    required String audioPath,
    required SpeechModel model,
    required NoteLanguage language,
    void Function(int percent)? onProgress,
  }) async {
    final result = await _controller.transcribe(
      model: model.whisper,
      audioPath: audioPath,
      lang: language.code,
      maxContext: 0,
      onProgress: onProgress,
    );
    final text = result?.transcription.text.trim() ?? '';
    if (text.isEmpty) {
      throw const TranscriptionException(
        'No speech was recognised in this audio.',
      );
    }
    return text;
  }
}

class TranscriptionException implements Exception {
  const TranscriptionException(this.message);

  final String message;

  @override
  String toString() => message;
}
