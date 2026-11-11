import 'package:flutter_edge_ai/flutter_edge_ai.dart';
import 'package:flutter_edge_ai_litertlm/flutter_edge_ai_litertlm.dart';

import '../models/note.dart';
import 'summary_text.dart';

/// On-device summary models (LiteRT-LM, Apache-2.0, no Hugging Face token).
enum SummaryModel {
  better('Qwen2.5 1.5B · 1.6 GB · better German'),
  fast('Qwen3 0.6B · 345 MB · fast, weaker');

  const SummaryModel(this.label);

  final String label;

  LiteRtLmVariant get variant => switch (this) {
    SummaryModel.better => LiteRtLmModels.qwen2_5_1_5bInstruct.q8Ekv4096,
    SummaryModel.fast => LiteRtLmModels.qwen3_0_6b.dynamicInt4,
  };

  /// Qwen3 is a reasoning model; `/no_think` switches its thinking off.
  String get promptSuffix => this == SummaryModel.fast ? ' /no_think' : '';
}

/// Summarises transcripts with a small LLM through flutter_edge_ai.
class SummaryService {
  SummaryModel? _active;

  /// Downloads [model] on first use and makes it the active model.
  Future<void> ensureModel(
    SummaryModel model, {
    void Function(int percent)? onProgress,
  }) async {
    if (_active == model) return;
    await FlutterEdgeAi.installModelFromCatalog(model.variant)
        .withProgress((progress) => onProgress?.call(progress))
        .install();
    _active = model;
  }

  Future<String> summarize(
    String transcript,
    NoteLanguage language,
    SummaryModel model,
  ) async {
    final direct = directSummary(transcript);
    if (direct != null) return direct;

    await ensureModel(model);
    final inference = await FlutterEdgeAi.getActiveModel(
      defaults: model.variant.runtimeDefaults,
      maxTokens: 4096,
    );
    try {
      final reply = language == NoteLanguage.english ? 'English' : 'German';
      final chat = await inference.openChat(
        temperature: 0.1,
        maxOutputTokens: 300,
        systemInstruction:
            'You summarise a transcribed voice message. Reply in $reply '
            'with 3 to 5 short bullet points, each a different point. Only state what the '
            'message says - never add facts, comparisons or explanations. No introduction.',
      );
      await chat.addQueryChunk(
        Message.text(
          text: 'Voice message:\n$transcript${model.promptSuffix}',
          isUser: true,
        ),
      );
      final buffer = StringBuffer();
      await for (final response in chat.generateChatResponseAsync()) {
        if (response is TextResponse) buffer.write(response.token);
      }
      return cleanSummary(buffer.toString());
    } finally {
      await inference.close();
    }
  }
}
