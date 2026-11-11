import 'package:flutter_edge_ai/flutter_edge_ai.dart';
import 'package:flutter_edge_ai_litertlm/flutter_edge_ai_litertlm.dart';

import '../models/note.dart';
import 'summary_text.dart';

/// On-device summaries with a small LLM (Qwen3 0.6B, INT4, ~345 MB, Apache-2.0,
/// no Hugging Face token needed) through flutter_edge_ai / LiteRT-LM.
class SummaryService {
  static final _variant = LiteRtLmModels.qwen3_0_6b.dynamicInt4;

  bool _installed = false;

  /// Downloads the model on first use; later calls only activate it.
  Future<void> ensureModel({void Function(int percent)? onProgress}) async {
    if (_installed) return;
    await FlutterEdgeAi.installModelFromCatalog(_variant)
        .withProgress((progress) => onProgress?.call(progress))
        .install();
    _installed = true;
  }

  Future<String> summarize(String transcript, NoteLanguage language) async {
    await ensureModel();
    final model = await FlutterEdgeAi.getActiveModel(
      defaults: _variant.runtimeDefaults,
      maxTokens: 4096,
    );
    try {
      final reply = language == NoteLanguage.english
          ? 'English'
          : 'the language of the text';
      final chat = await model.openChat(
        temperature: 0.2,
        maxOutputTokens: 300,
        systemInstruction:
            'You summarise voice messages. Reply with 3 to 5 short bullet '
            'points in $reply. Only use facts from the text; no introduction.',
      );
      await chat.addQueryChunk(
        Message.text(text: '$transcript /no_think', isUser: true),
      );
      final buffer = StringBuffer();
      await for (final response in chat.generateChatResponseAsync()) {
        if (response is TextResponse) buffer.write(response.token);
      }
      return cleanSummary(buffer.toString());
    } finally {
      await model.close();
    }
  }
}
