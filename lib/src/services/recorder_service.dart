import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

/// Records 16 kHz mono WAV, the format Whisper reads without conversion.
class RecorderService {
  final AudioRecorder _recorder = AudioRecorder();

  Future<bool> hasPermission() => _recorder.hasPermission();

  /// Microphone level in dBFS (about -60 silent … 0 loud), every 100 ms.
  Stream<double> levels() => _recorder
      .onAmplitudeChanged(const Duration(milliseconds: 100))
      .map((amplitude) => amplitude.current);

  Future<void> start() async {
    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}/recording_${DateTime.now().millisecondsSinceEpoch}.wav';
    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 16000,
        numChannels: 1,
      ),
      path: path,
    );
  }

  /// Stops recording and returns the WAV file, or null if nothing was recorded.
  Future<File?> stop() async {
    final path = await _recorder.stop();
    return path == null ? null : File(path);
  }

  Future<void> dispose() => _recorder.dispose();
}
