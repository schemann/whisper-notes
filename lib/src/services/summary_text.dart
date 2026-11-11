/// Transcripts shorter than this are not sent to the LLM: a small model only
/// pads a one-sentence message with invented bullets.
const minWordsForSummary = 25;

/// Most bullets a summary keeps.
const maxSummaryBullets = 5;

/// Returns the summary for a transcript too short to summarise (the message
/// itself as one bullet), or null when the LLM should summarise it.
String? directSummary(String transcript) {
  final words = transcript
      .trim()
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty);
  if (words.length >= minWordsForSummary) return null;
  return words.isEmpty ? '' : '- ${words.join(' ')}';
}

/// Cleans raw LLM output into a bullet list.
///
/// Removes `<think>…</think>` blocks (Qwen3 can emit one even with thinking
/// off), turns every non-empty line into a `- ` bullet, drops repeated bullets
/// (small models loop) and keeps at most [maxSummaryBullets].
String cleanSummary(String raw) {
  final withoutThinking = raw
      .replaceAll(RegExp(r'<think>[\s\S]*?</think>'), '')
      .replaceAll(RegExp(r'<think>[\s\S]*$'), '');
  final seen = <String>{};
  final bullets = withoutThinking
      .split('\n')
      .map((line) => line.trim())
      .map(
        (line) => line.replaceFirst(RegExp(r'^([-*•]|\d+[.)])\s*'), '').trim(),
      )
      .where((line) => line.isNotEmpty)
      .where((line) => seen.add(line.toLowerCase()))
      .take(maxSummaryBullets)
      .map((line) => '- $line');
  return bullets.join('\n');
}
