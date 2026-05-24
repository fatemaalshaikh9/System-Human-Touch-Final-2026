import 'package:flutter_tts/flutter_tts.dart';
import 'app_settings_store.dart';

class AppTts {
  static final FlutterTts _tts = FlutterTts();

  static Future<void> speak(String text) async {
    await _tts.stop();

    if (AppSettingsStore.instance.isArabic) {
      await _tts.setLanguage('ar-SA');
    } else {
      await _tts.setLanguage('en-US');
    }

    await _tts.setSpeechRate(0.45);
    await _tts.setPitch(1.0);
    await _tts.setVolume(1.0);

    await _tts.speak(text);
  }

  static Future<void> stop() async {
    await _tts.stop();
  }
}
