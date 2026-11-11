import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../models/note.dart';
import '../services/transcription_service.dart';
import 'note_page.dart';
import 'record_panel.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage>
    with WidgetsBindingObserver {
  bool _processingShares = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _processShares());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _processShares();
  }

  /// Transcribes every audio file shared to the app since the last check.
  Future<void> _processShares() async {
    if (_processingShares) return;
    _processingShares = true;
    try {
      final paths = await ref.read(shareInboxProvider).takePending();
      for (final path in paths) {
        final note = await ref
            .read(notesProvider.notifier)
            .process(File(path), NoteSource.shared);
        if (note != null && mounted && path == paths.last) _open(note);
      }
    } finally {
      _processingShares = false;
    }
  }

  void _open(Note note) => Navigator.of(context)
      .push(MaterialPageRoute<void>(builder: (_) => NotePage(noteId: note.id)));

  @override
  Widget build(BuildContext context) {
    final notes = ref.watch(notesProvider);
    final job = ref.watch(jobProvider);
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Whisper Notes'),
        actions: [
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.tune),
            onPressed: () => _showSettings(context),
          ),
        ],
      ),
      body: Column(
        children: [
          RecordPanel(
            enabled: !job.isBusy,
            onRecorded: (file) async {
              final note = await ref
                  .read(notesProvider.notifier)
                  .process(file, NoteSource.recording);
              if (note != null && mounted) _open(note);
            },
          ),
          if (job.message.isNotEmpty) _StatusBanner(job: job),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Row(
              children: [
                Text('History', style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                Text(
                  '${settings.language.label} · ${settings.model.name}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Expanded(
            child: notes.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) =>
                  Center(child: Text('Could not load history: $error')),
              data: (items) => items.isEmpty
                  ? const _EmptyHistory()
                  : ListView.separated(
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (_, i) => _NoteTile(
                        note: items[i],
                        onTap: () => _open(items[i]),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  void _showSettings(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => const _SettingsSheet(),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.job});

  final JobStatus job;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: job.isError ? scheme.errorContainer : scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(job.message),
          if (job.isBusy) ...[
            const SizedBox(height: 8),
            LinearProgressIndicator(value: job.progress),
          ],
        ],
      ),
    );
  }
}

class _NoteTile extends StatelessWidget {
  const _NoteTile({required this.note, required this.onTap});

  final Note note;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final date = note.createdAt.toLocal().toString().substring(0, 16);
    return ListTile(
      leading: Icon(
        note.source == NoteSource.shared ? Icons.forward_to_inbox : Icons.mic,
      ),
      title: Text(note.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(note.summary.isEmpty ? date : '$date · summary'),
      onTap: onTap,
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) => const Center(
    child: Padding(
      padding: EdgeInsets.all(32),
      child: Text(
        'No transcripts yet.\n\nRecord something above, or share a voice message '
        'from WhatsApp to Whisper Notes.',
        textAlign: TextAlign.center,
      ),
    ),
  );
}

class _SettingsSheet extends ConsumerWidget {
  const _SettingsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Language'),
            const SizedBox(height: 8),
            SegmentedButton<NoteLanguage>(
              segments: [
                for (final l in NoteLanguage.values)
                  ButtonSegment(value: l, label: Text(l.label)),
              ],
              selected: {settings.language},
              onSelectionChanged: (s) =>
                  notifier.update(settings.copyWith(language: s.first)),
            ),
            const SizedBox(height: 16),
            const Text('Speech model'),
            RadioGroup<SpeechModel>(
              groupValue: settings.model,
              onChanged: (m) => notifier.update(settings.copyWith(model: m)),
              child: Column(
                children: [
                  for (final m in SpeechModel.values)
                    RadioListTile<SpeechModel>(value: m, title: Text(m.label)),
                ],
              ),
            ),
            SwitchListTile(
              title: const Text('Summarise automatically'),
              subtitle: const Text(
                'On-device LLM, ~345 MB download on first use',
              ),
              value: settings.summarize,
              onChanged: (v) =>
                  notifier.update(settings.copyWith(summarize: v)),
            ),
          ],
        ),
      ),
    );
  }
}
