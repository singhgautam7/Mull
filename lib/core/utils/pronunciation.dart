import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// On-device speech for the speaker button, through Android's own
/// TextToSpeech engine via a method channel in `MainActivity.kt`. UK voice,
/// speed from settings. Nothing leaves the phone.
class Pronunciation {
  const Pronunciation();

  static const MethodChannel _channel = MethodChannel('com.grs.dictionary/tts');

  Future<void> speak(String word, {required double rate}) async {
    try {
      await _channel.invokeMethod<bool>('speak', <String, Object>{'text': word, 'rate': rate});
    } on PlatformException {
      // No engine on this device: the button simply does nothing.
    } on MissingPluginException {
      // Tests and non-Android hosts.
    }
  }
}

final Provider<Pronunciation> pronunciationProvider = Provider<Pronunciation>(
  (Ref ref) => const Pronunciation(),
);
