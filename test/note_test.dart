import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:whisper_notes/src/data/history_repository.dart';
import 'package:whisper_notes/src/models/note.dart';

Note _note(String id, DateTime createdAt, {String transcript = 'Hallo Welt'}) =>
    Note(
      id: id,
      createdAt: createdAt,
      source: NoteSource.shared,
      language: NoteLanguage.german,
      transcript: transcript,
      summary: '- Gruß',
    );

void main() {
  test('note survives a JSON round trip', () {
    final note = _note('1', DateTime(2026, 11, 11, 10, 30));
    final copy = Note.fromJson(note.toJson());
    expect(copy.toJson(), note.toJson());
  });

  test('title is shortened and whitespace collapsed', () {
    final note = _note('1', DateTime(2026), transcript: '  ${'wort ' * 30}  ');
    expect(note.title.length, 61);
    expect(note.title.endsWith('…'), isTrue);
    expect(_note('2', DateTime(2026), transcript: '   ').title, '(empty)');
  });

  test('history repository saves and loads newest first', () async {
    final dir = await Directory.systemTemp.createTemp('notes_test');
    addTearDown(() => dir.delete(recursive: true));
    final repo = HistoryRepository(directory: () async => dir);

    expect(await repo.load(), isEmpty);
    await repo.save([
      _note('old', DateTime(2026, 1, 1)),
      _note('new', DateTime(2026, 6, 1)),
    ]);
    final loaded = await repo.load();
    expect(loaded.map((n) => n.id), ['new', 'old']);
  });

  test('a corrupt history file loads as empty', () async {
    final dir = await Directory.systemTemp.createTemp('notes_test');
    addTearDown(() => dir.delete(recursive: true));
    await File('${dir.path}/notes.json').writeAsString('{not json');
    expect(await HistoryRepository(directory: () async => dir).load(), isEmpty);
  });
}
