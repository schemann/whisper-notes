import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';

/// Record/stop button with elapsed time and a live level meter.
class RecordPanel extends ConsumerStatefulWidget {
  const RecordPanel({
    super.key,
    required this.enabled,
    required this.onRecorded,
  });

  final bool enabled;
  final ValueChanged<File> onRecorded;

  @override
  ConsumerState<RecordPanel> createState() => _RecordPanelState();
}

class _RecordPanelState extends ConsumerState<RecordPanel> {
  bool _recording = false;
  Duration _elapsed = Duration.zero;
  double _level = 0;
  Timer? _timer;
  StreamSubscription<double>? _levelSub;

  @override
  void dispose() {
    _timer?.cancel();
    _levelSub?.cancel();
    super.dispose();
  }

  Future<void> _toggle() async {
    final recorder = ref.read(recorderServiceProvider);
    if (_recording) {
      _timer?.cancel();
      await _levelSub?.cancel();
      final file = await recorder.stop();
      setState(() {
        _recording = false;
        _level = 0;
      });
      if (file != null && file.existsSync()) widget.onRecorded(file);
      return;
    }
    if (!await recorder.hasPermission()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Microphone access is off. Allow it in the system settings to record.',
          ),
        ),
      );
      return;
    }
    await recorder.start();
    final started = DateTime.now();
    _timer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      setState(() => _elapsed = DateTime.now().difference(started));
    });
    // dBFS: about -60 (silence) to 0 (loud), mapped to 0..1.
    _levelSub = recorder.levels().listen((db) {
      setState(() => _level = ((db + 60) / 60).clamp(0.0, 1.0));
    });
    setState(() {
      _recording = true;
      _elapsed = Duration.zero;
    });
  }

  String get _time {
    final m = _elapsed.inMinutes.toString().padLeft(2, '0');
    final s = (_elapsed.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        children: [
          SizedBox(
            width: 96,
            height: 96,
            child: FilledButton(
              style: FilledButton.styleFrom(
                shape: const CircleBorder(),
                backgroundColor: _recording ? scheme.error : scheme.primary,
              ),
              onPressed: widget.enabled || _recording ? _toggle : null,
              child: Icon(
                _recording ? Icons.stop : Icons.mic,
                size: 40,
                semanticLabel: _recording
                    ? 'Stop recording'
                    : 'Start recording',
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _recording ? _time : 'Tap to record',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          AnimatedOpacity(
            opacity: _recording ? 1 : 0,
            duration: const Duration(milliseconds: 200),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(value: _level, minHeight: 8),
            ),
          ),
        ],
      ),
    );
  }
}
