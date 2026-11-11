import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/history_repository.dart';
import '../models/note.dart';
import '../services/recorder_service.dart';
import '../services/share_inbox.dart';
import '../services/summary_service.dart';
import '../services/transcription_service.dart';

final historyRepositoryProvider = Provider((ref) => HistoryRepository());
final transcriptionServiceProvider = Provider((ref) => TranscriptionService());
final summaryServiceProvider = Provider((ref) => SummaryService());
final shareInboxProvider = Provider((ref) => ShareInbox());
final recorderServiceProvider = Provider((ref) {
  final recorder = RecorderService();
  ref.onDispose(recorder.dispose);
  return recorder;
});

/// What the app is doing right now; shown as a status banner.
class JobStatus {
  const JobStatus(this.message, {this.progress, this.isError = false});

  static const idle = JobStatus('');

  final String message;
  final double? progress;
  final bool isError;

  bool get isBusy => message.isNotEmpty && !isError;
}

class Settings {
  const Settings({
    this.language = NoteLanguage.german,
    this.model = SpeechModel.base,
    this.summarize = true,
  });

  final NoteLanguage language;
  final SpeechModel model;
  final bool summarize;

  Settings copyWith({
    NoteLanguage? language,
    SpeechModel? model,
    bool? summarize,
  }) => Settings(
    language: language ?? this.language,
    model: model ?? this.model,
    summarize: summarize ?? this.summarize,
  );
}

class SettingsNotifier extends Notifier<Settings> {
  @override
  Settings build() => const Settings();

  void update(Settings settings) => state = settings;
}

final settingsProvider = NotifierProvider<SettingsNotifier, Settings>(
  SettingsNotifier.new,
);

class JobNotifier extends Notifier<JobStatus> {
  @override
  JobStatus build() => JobStatus.idle;

  void set(JobStatus status) => state = status;
}

final jobProvider = NotifierProvider<JobNotifier, JobStatus>(JobNotifier.new);

/// The note history plus the transcribe-and-summarise pipeline.
class NotesNotifier extends AsyncNotifier<List<Note>> {
  @override
  Future<List<Note>> build() => ref.read(historyRepositoryProvider).load();

  JobNotifier get _job => ref.read(jobProvider.notifier);

  /// Transcribes [audio], summarises it if enabled, and stores the note.
  Future<Note?> process(File audio, NoteSource source) async {
    final settings = ref.read(settingsProvider);
    final transcriber = ref.read(transcriptionServiceProvider);
    try {
      _job.set(JobStatus('Preparing speech model (${settings.model.name})…'));
      await transcriber.ensureModel(settings.model);
      _job.set(const JobStatus('Transcribing…', progress: 0));
      final transcript = await transcriber.transcribe(
        audioPath: audio.path,
        model: settings.model,
        language: settings.language,
        onProgress: (p) =>
            _job.set(JobStatus('Transcribing… $p %', progress: p / 100)),
      );
      var note = Note(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        createdAt: DateTime.now(),
        source: source,
        language: settings.language,
        transcript: transcript,
        summary: '',
      );
      await _store(note);
      if (settings.summarize) {
        note = await _summarize(note) ?? note;
      }
      _job.set(JobStatus.idle);
      return note;
    } on Object catch (error) {
      _job.set(JobStatus('Failed: $error', isError: true));
      return null;
    }
  }

  /// (Re)creates the summary of an existing note.
  Future<Note?> summarize(Note note) async {
    try {
      final updated = await _summarize(note);
      _job.set(JobStatus.idle);
      return updated;
    } on Object catch (error) {
      _job.set(JobStatus('Summary failed: $error', isError: true));
      return null;
    }
  }

  Future<Note?> _summarize(Note note) async {
    final summarizer = ref.read(summaryServiceProvider);
    _job.set(const JobStatus('Preparing summary model…'));
    await summarizer.ensureModel(
      onProgress: (p) => _job.set(
        JobStatus('Downloading summary model… $p %', progress: p / 100),
      ),
    );
    _job.set(const JobStatus('Summarising…'));
    final summary = await summarizer.summarize(note.transcript, note.language);
    final updated = note.copyWith(summary: summary);
    await _store(updated);
    return updated;
  }

  Future<void> delete(Note note) async {
    final notes = [...?state.value]..removeWhere((n) => n.id == note.id);
    state = AsyncData(notes);
    await ref.read(historyRepositoryProvider).save(notes);
  }

  Future<void> _store(Note note) async {
    final notes = [note, ...?state.value?.where((n) => n.id != note.id)]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    state = AsyncData(notes);
    await ref.read(historyRepositoryProvider).save(notes);
  }
}

final notesProvider = AsyncNotifierProvider<NotesNotifier, List<Note>>(
  NotesNotifier.new,
);
