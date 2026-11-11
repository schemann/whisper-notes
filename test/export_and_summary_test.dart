import 'package:flutter_test/flutter_test.dart';
import 'package:whisper_notes/src/models/note.dart';
import 'package:whisper_notes/src/services/export_formatter.dart';
import 'package:whisper_notes/src/services/summary_text.dart';

void main() {
  final note = Note(
    id: '1',
    createdAt: DateTime(2026, 11, 11, 9, 5),
    source: NoteSource.shared,
    language: NoteLanguage.german,
    transcript: 'Wir treffen uns morgen um zehn.',
    summary: '- Treffen morgen um 10 Uhr',
  );
  const formatter = ExportFormatter();

  test('file name carries date, time and extension', () {
    expect(formatter.fileName(note, ExportFormat.md), 'transcript_2026-11-11_0905.md');
    expect(formatter.fileName(note, ExportFormat.txt), 'transcript_2026-11-11_0905.txt');
  });

  test('markdown export has summary and transcript sections', () {
    final md = formatter.format(note, ExportFormat.md);
    expect(md, contains('## Summary'));
    expect(md, contains('- Treffen morgen um 10 Uhr'));
    expect(md, contains('## Transcript\n\nWir treffen uns morgen um zehn.'));
  });

  test('txt export leaves out an empty summary', () {
    final txt = formatter.format(note.copyWith(summary: ''), ExportFormat.txt);
    expect(txt, isNot(contains('SUMMARY')));
    expect(txt, contains('TRANSCRIPT\nWir treffen uns morgen um zehn.'));
  });

  group('cleanSummary', () {
    test('drops a think block and normalises bullets', () {
      const raw = '<think>planning…</think>\n* Punkt eins\n2. Punkt zwei\n\n• Punkt drei';
      expect(cleanSummary(raw), '- Punkt eins\n- Punkt zwei\n- Punkt drei');
    });

    test('drops an unterminated think block', () {
      expect(cleanSummary('- Fakt\n<think>abgebrochen'), '- Fakt');
    });
  });
}
