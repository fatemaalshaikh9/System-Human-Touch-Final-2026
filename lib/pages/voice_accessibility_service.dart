import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'app_settings_store.dart';

class VoiceAccessibilityService {
  static final VoiceAccessibilityService instance =
      VoiceAccessibilityService._internal();

  VoiceAccessibilityService._internal();

  final FlutterTts _tts = FlutterTts();
  final stt.SpeechToText _speech = stt.SpeechToText();

  bool _isListening = false;

  Future<void> init() async {
    final isArabic = AppSettingsStore.instance.isArabic;

    await _tts.setLanguage(isArabic ? 'ar-SA' : 'en-US');
    await _tts.setSpeechRate(0.45);
    await _tts.setPitch(1.0);
    await _tts.setVolume(1.0);
    await _tts.awaitSpeakCompletion(true);
  }

  Future<void> speak(String text) async {
    await _tts.stop();
    await _tts.speak(text);
  }

  Future<void> stopAll() async {
    _isListening = false;
    await _tts.stop();
    await _speech.stop();
    await _speech.cancel();
  }

  Future<void> readPageAndListen({
    required BuildContext context,
    required String pageText,
    required Map<String, WidgetBuilder> routes,
  }) async {
    await stopAll();
    await init();

    final isArabic = AppSettingsStore.instance.isArabic;

    final instruction = isArabic
        ? '$pageText. بعد سماع الخيارات، قل اسم الصفحة التي تريد الذهاب إليها.'
        : '$pageText. After hearing the options, say the page you want to open.';

    await speak(instruction);

    if (!context.mounted) return;

    final available = await _speech.initialize(
      onStatus: (status) async {
        if (status == 'done' && _isListening) {
          _isListening = false;

          await speak(
            isArabic
                ? 'لم أسمع أي أمر صوتي.'
                : 'I did not hear any voice command.',
          );
        }
      },
      onError: (error) async {
        _isListening = false;

        await speak(
          isArabic
              ? 'حدث خطأ أثناء الاستماع.'
              : 'An error happened while listening.',
        );
      },
    );

    if (!available) {
      await speak(
        isArabic
            ? 'عذرًا، لم أتمكن من تشغيل الميكروفون.'
            : 'Sorry, I could not start the microphone.',
      );
      return;
    }

    await speak(
      isArabic
          ? 'أنا أسمعك الآن. قل اسم الصفحة.'
          : 'I am listening now. Say the page name.',
    );

    _isListening = true;

    if (!context.mounted || !_isListening) return;

    await _speech.listen(
      localeId: isArabic ? 'ar_SA' : 'en_US',
      listenFor: const Duration(seconds: 8),
      pauseFor: const Duration(seconds: 3),
      cancelOnError: true,
      partialResults: false,
      onResult: (result) async {
        if (!result.finalResult) return;

        _isListening = false;

        final command = result.recognizedWords.toLowerCase().trim();

        debugPrint('Voice Command: $command');

        await _handleCommand(
          context: context,
          command: command,
          routes: routes,
        );
      },
    );
  }

  Future<void> _handleCommand({
    required BuildContext context,
    required String command,
    required Map<String, WidgetBuilder> routes,
  }) async {
    await _speech.stop();

    String? routeKey;
    String? actionMessage;

    if (command.contains('الرئيسية') ||
        command.contains('الرئيسيه') ||
        command.contains('الصفحة الرئيسية') ||
        command.contains('الصفحه الرئيسيه') ||
        command.contains('dashboard') ||
        command.contains('home')) {
      routeKey = 'dashboard';
    } else if (command.contains('الصحة') ||
        command.contains('الصحه') ||
        command.contains('health')) {
      routeKey = 'health';
    } else if (command.contains('التذكيرات') ||
        command.contains('تذكيرات') ||
        command.contains('تذكير') ||
        command.contains('reminder') ||
        command.contains('reminders')) {
      routeKey = 'reminders';
    } else if (command.contains('الطوارئ') ||
        command.contains('طوارئ') ||
        command.contains('emergency') ||
        command.contains('sos')) {
      routeKey = 'emergency';
    } else if (command.contains('التواصل') ||
        command.contains('اتواصل') ||
        command.contains('communication') ||
        command.contains('chat') ||
        command.contains('talk')) {
      routeKey = 'communication';
    } else if (command.contains('ai companion') ||
        command.contains('ai chat') ||
        command.contains('companion chat') ||
        command.contains('المساعد الذكي') ||
        command.contains('الذكاء الاصطناعي') ||
        command.contains('محادثة الذكاء')) {
      routeKey = 'communication';
      actionMessage = AppSettingsStore.instance.isArabic
          ? 'افتح صفحة التواصل ثم اضغط زر المساعد الذكي أسفل الصفحة.'
          : 'Open Communication, then press the AI companion button at the bottom.';
    } else if (command.contains('talk for me') ||
        command.contains('تحدث بدلاً عني') ||
        command.contains('تحدث بدلا عني') ||
        command.contains('تكلم بدالي')) {
      routeKey = 'communication';
      actionMessage = AppSettingsStore.instance.isArabic
          ? 'افتح صفحة التواصل ثم اضغط زر تحدث بدلاً عني.'
          : 'Open Communication, then press Talk For Me.';
    } else if (command.contains('smart situation') ||
        command.contains('situation mode') ||
        command.contains('تحليل الموقف') ||
        command.contains('الموقف الذكي')) {
      routeKey = 'communication';
      actionMessage = AppSettingsStore.instance.isArabic
          ? 'افتح صفحة التواصل ثم اكتب رسالتك في وضع تحليل الموقف الذكي.'
          : 'Open Communication, then type your message in Smart Situation Mode.';
    } else if (command.contains('الخريطة') ||
        command.contains('خريطه') ||
        command.contains('الموقع') ||
        command.contains('map') ||
        command.contains('location')) {
      routeKey = 'map';
    } else if (command.contains('مساعدة المتطوعين') ||
        command.contains('مساعده المتطوعين') ||
        command.contains('volunteer help') ||
        command.contains('volunteers') ||
        command.contains('volunteer')) {
      routeKey = 'volunteer';
    } else if (command.contains('تفاصيل المتطوع') ||
        command.contains('معلومات المتطوع') ||
        command.contains('volunteer details') ||
        command.contains('volunteer information')) {
      routeKey = 'volunteerInfo';
    } else if (command.contains('about') ||
        command.contains('about human touch') ||
        command.contains('عن') ||
        command.contains('عن التطبيق') ||
        command.contains('عن human touch')) {
      routeKey = 'settings';
      actionMessage = AppSettingsStore.instance.isArabic
          ? 'افتح الإعدادات ثم اختر عن Human Touch.'
          : 'Open Settings then choose About Human Touch.';
    } else if (command.contains('contact') ||
        command.contains('contact us') ||
        command.contains('تواصل') ||
        command.contains('تواصل معنا') ||
        command.contains('اتصل')) {
      routeKey = 'settings';
      actionMessage = AppSettingsStore.instance.isArabic
          ? 'افتح الإعدادات ثم اختر تواصل معنا.'
          : 'Open Settings then choose Contact Us.';
    } else if (command.contains('privacy') ||
        command.contains('privacy policy') ||
        command.contains('الخصوصية') ||
        command.contains('سياسة الخصوصية')) {
      routeKey = 'settings';
      actionMessage = AppSettingsStore.instance.isArabic
          ? 'افتح الإعدادات ثم اختر سياسة الخصوصية.'
          : 'Open Settings then choose Privacy Policy.';
    } else if (command.contains('الملف الشخصي') ||
        command.contains('الملف') ||
        command.contains('بروفايل') ||
        command.contains('profile')) {
      routeKey = 'profile';
    } else if (command.contains('الإعدادات') ||
        command.contains('الاعدادات') ||
        command.contains('اعدادات') ||
        command.contains('settings')) {
      routeKey = 'settings';
    } else if (command.contains('login') ||
        command.contains('log in') ||
        command.contains('تسجيل الدخول') ||
        command.contains('دخول') ||
        command.contains('لوق ان')) {
      routeKey = 'login';
    } else if (command.contains('create account') ||
        command.contains('sign up') ||
        command.contains('signup') ||
        command.contains('إنشاء حساب') ||
        command.contains('انشاء حساب') ||
        command.contains('تسجيل') ||
        command.contains('حساب جديد')) {
      routeKey = 'signup';
    } else if (command.contains('patient') ||
        command.contains('مريض') ||
        command.contains('المريض')) {
      routeKey = 'patient';
    } else if (command.contains('companion') ||
        command.contains('مرافق') ||
        command.contains('المرافق')) {
      routeKey = 'companion';
    }

    final isArabic = AppSettingsStore.instance.isArabic;

    if (routeKey != null && routes.containsKey(routeKey)) {
      await speak(
        actionMessage ?? (isArabic ? 'جارٍ فتح الصفحة.' : 'Opening the page.'),
      );

      if (!context.mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: routes[routeKey]!),
      );
    } else {
      await speak(
        isArabic
            ? 'لم أفهم اسم الصفحة. حاول مرة أخرى.'
            : 'I did not understand the page name. Please try again.',
      );
    }
  }
}
