import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/note.dart';

/// Stores the note history as one JSON file in the app's documents folder.
class HistoryRepository {
  HistoryRepository({Future<Directory> Function()? directory})
    : _directory = directory ?? getApplicationDocumentsDirectory;

  final Future<Directory> Function() _directory;

  Future<File> _file() async => File('${(await _directory()).path}/notes.json');

  /// Returns all notes, newest first; an unreadable file yields an empty list.
  Future<List<Note>> load() async {
    final file = await _file();
    if (!file.existsSync()) return [];
    try {
      final data = jsonDecode(await file.readAsString()) as List<dynamic>;
      return data
          .map((item) => Note.fromJson(item as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } on FormatException {
      return [];
    }
  }

  /// Writes the notes atomically (temp file, then rename).
  Future<void> save(List<Note> notes) async {
    final file = await _file();
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(jsonEncode(notes.map((n) => n.toJson()).toList()));
    await temp.rename(file.path);
  }
}
