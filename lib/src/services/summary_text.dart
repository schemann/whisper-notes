/// Cleans raw LLM output into a bullet list.
///
/// Small reasoning models (Qwen3) may emit a `<think>…</think>` block even with
/// thinking off; it is removed. Every non-empty line becomes a `- ` bullet.
String cleanSummary(String raw) {
  final withoutThinking = raw
      .replaceAll(RegExp(r'<think>[\s\S]*?</think>'), '')
      .replaceAll(RegExp(r'<think>[\s\S]*$'), '');
  final bullets = withoutThinking
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .map((line) => line.replaceFirst(RegExp(r'^([-*•]|\d+[.)])\s*'), ''))
      .where((line) => line.isNotEmpty)
      .map((line) => '- $line');
  return bullets.join('\n');
}
