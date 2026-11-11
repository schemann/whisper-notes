import 'package:flutter/services.dart';

/// Audio files shared to the app from other apps (e.g. WhatsApp voice messages).
///
/// Android: MainActivity copies ACTION_SEND / ACTION_SEND_MULTIPLE audio into the
/// cache. iOS: the Share Extension copies the file into the App Group folder.
/// Both hand the file paths over this channel.
class ShareInbox {
  static const _channel = MethodChannel('whisper_notes/share');

  /// Returns the paths of files waiting to be transcribed and clears the inbox.
  Future<List<String>> takePending() async {
    try {
      final paths = await _channel.invokeListMethod<String>('takeSharedFiles');
      return paths ?? const [];
    } on MissingPluginException {
      return const [];
    }
  }
}
