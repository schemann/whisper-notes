import '../models/note.dart';

/// File formats a note can be exported as.
enum ExportFormat { txt, md }

/// Turns a note into the text of an export file.
class ExportFormatter {
  const ExportFormatter();

  String fileName(Note note, ExportFormat format) {
    final d = note.createdAt;
    String two(int v) => v.toString().padLeft(2, '0');
    final stamp =
        '${d.year}-${two(d.month)}-${two(d.day)}_${two(d.hour)}${two(d.minute)}';
    return 'transcript_$stamp.${format.name}';
  }

  String format(Note note, ExportFormat format) {
    final date = note.createdAt.toLocal().toString().substring(0, 16);
    final source = note.source == NoteSource.shared
        ? 'Shared voice message'
        : 'Recording';
    final hasSummary = note.summary.trim().isNotEmpty;
    if (format == ExportFormat.md) {
      return [
        '# Transcript',
        '',
        '*$date · $source · ${note.language.label}*',
        if (hasSummary) ...['', '## Summary', '', note.summary.trim()],
        '',
        '## Transcript',
        '',
        note.transcript.trim(),
        '',
      ].join('\n');
    }
    return [
      'Transcript - $date - $source - ${note.language.label}',
      if (hasSummary) ...['', 'SUMMARY', note.summary.trim()],
      '',
      'TRANSCRIPT',
      note.transcript.trim(),
      '',
    ].join('\n');
  }
}
