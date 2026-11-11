/// Where a note's audio came from.
enum NoteSource { recording, shared }

/// Transcription language; `auto` lets Whisper detect it.
enum NoteLanguage {
  german('de', 'Deutsch'),
  english('en', 'English'),
  auto('auto', 'Auto');

  const NoteLanguage(this.code, this.label);

  final String code;
  final String label;
}

/// One transcribed voice message with its summary.
class Note {
  const Note({
    required this.id,
    required this.createdAt,
    required this.source,
    required this.language,
    required this.transcript,
    required this.summary,
  });

  factory Note.fromJson(Map<String, dynamic> json) => Note(
    id: json['id'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
    source: NoteSource.values.byName(json['source'] as String),
    language: NoteLanguage.values.byName(json['language'] as String),
    transcript: json['transcript'] as String,
    summary: json['summary'] as String? ?? '',
  );

  final String id;
  final DateTime createdAt;
  final NoteSource source;
  final NoteLanguage language;
  final String transcript;
  final String summary;

  /// First words of the transcript, for list tiles.
  String get title {
    final text = transcript.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (text.isEmpty) return '(empty)';
    return text.length <= 60 ? text : '${text.substring(0, 60)}…';
  }

  Note copyWith({String? summary}) => Note(
    id: id,
    createdAt: createdAt,
    source: source,
    language: language,
    transcript: transcript,
    summary: summary ?? this.summary,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'createdAt': createdAt.toIso8601String(),
    'source': source.name,
    'language': language.name,
    'transcript': transcript,
    'summary': summary,
  };
}
