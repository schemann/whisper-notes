import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../app/providers.dart';
import '../models/note.dart';
import '../services/export_formatter.dart';

/// Transcript and summary of one note, with copy, export and delete.
class NotePage extends ConsumerWidget {
  const NotePage({super.key, required this.noteId});

  final String noteId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notes = ref.watch(notesProvider).value ?? const <Note>[];
    final job = ref.watch(jobProvider);
    final note = notes.where((n) => n.id == noteId).firstOrNull;
    if (note == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Note not found.')),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(note.createdAt.toLocal().toString().substring(0, 16)),
        actions: [
          PopupMenuButton<ExportFormat>(
            tooltip: 'Export',
            icon: const Icon(Icons.ios_share),
            onSelected: (format) => _export(context, note, format),
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: ExportFormat.txt,
                child: Text('Export as .txt'),
              ),
              PopupMenuItem(
                value: ExportFormat.md,
                child: Text('Export as .md'),
              ),
            ],
          ),
          IconButton(
            tooltip: 'Delete',
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _delete(context, ref, note),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (job.message.isNotEmpty) ...[
            Text(job.message),
            if (job.isBusy) LinearProgressIndicator(value: job.progress),
            const SizedBox(height: 16),
          ],
          _Section(
            title: 'Summary',
            text: note.summary,
            emptyText: 'No summary yet.',
            action: TextButton.icon(
              onPressed: job.isBusy
                  ? null
                  : () => ref.read(notesProvider.notifier).summarize(note),
              icon: const Icon(Icons.auto_awesome),
              label: Text(note.summary.isEmpty ? 'Summarise' : 'Redo'),
            ),
          ),
          const SizedBox(height: 24),
          _Section(title: 'Transcript', text: note.transcript, emptyText: ''),
        ],
      ),
    );
  }

  Future<void> _export(
    BuildContext context,
    Note note,
    ExportFormat format,
  ) async {
    const formatter = ExportFormatter();
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/${formatter.fileName(note, format)}');
    await file.writeAsString(formatter.format(note, format));
    final box = context.mounted
        ? context.findRenderObject() as RenderBox?
        : null;
    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile(
            file.path,
            mimeType: format == ExportFormat.md
                ? 'text/markdown'
                : 'text/plain',
          ),
        ],
        sharePositionOrigin: box == null
            ? null
            : box.localToGlobal(Offset.zero) & box.size,
      ),
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, Note note) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete this transcript?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(notesProvider.notifier).delete(note);
    if (context.mounted) Navigator.of(context).pop();
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.text,
    required this.emptyText,
    this.action,
  });

  final String title;
  final String text;
  final String emptyText;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const Spacer(),
            ?action,
            if (text.isNotEmpty)
              IconButton(
                tooltip: 'Copy $title',
                icon: const Icon(Icons.copy),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: text));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(SnackBar(content: Text('$title copied')));
                  }
                },
              ),
          ],
        ),
        const SizedBox(height: 8),
        SelectableText(text.isEmpty ? emptyText : text),
      ],
    );
  }
}
