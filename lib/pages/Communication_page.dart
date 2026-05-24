import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'Dashboard_page.dart';
import 'Profile_page.dart';
import 'Settings_page.dart';
import 'Emergency_page.dart';
import 'Reminders_page.dart';
import 'Health_page.dart';
import 'Map_page.dart';
import 'VolunteerHelp_page.dart';
import 'voice_accessibility_service.dart';
import 'services/gemini_service.dart';

import 'package:humantouch/pages/app_settings_store.dart';

class CommunicationPage extends StatefulWidget {
  const CommunicationPage({super.key});

  @override
  State<CommunicationPage> createState() => _CommunicationPageState();
}

class _CommunicationPageState extends State<CommunicationPage> {
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _aiChatController = TextEditingController();

  final FlutterTts _flutterTts = FlutterTts();

  String _selectedPlace = 'Transport';
  String _selectedMood = 'Calm';
  String _detectedSituation = 'General';
  String _generatedMessage = '';
  bool _isEmergency = false;
  bool _isSaving = false;
  bool _isSpeaking = false;

  // AI Companion conversation memory.
  // This makes the chat continue naturally instead of replying as separate fixed messages.

  bool get isAccessibilityVoiceEnabled {
    final settings = AppSettingsStore.instance as dynamic;

    try {
      if (settings.isAccessibilityVoiceEnabled == true) return true;
    } catch (_) {}

    try {
      if (settings.accessibilityVoiceEnabled == true) return true;
    } catch (_) {}

    try {
      if (settings.voiceAccessibilityEnabled == true) return true;
    } catch (_) {}

    try {
      if (settings.accessibilityVoice == true) return true;
    } catch (_) {}

    return false;
  }

  bool get isArabic => AppSettingsStore.instance.isArabic;

  Color get backgroundColor => Theme.of(context).scaffoldBackgroundColor;

  Color get cardColor => Theme.of(context).cardColor;

  Color get textColor =>
      Theme.of(context).textTheme.bodyLarge?.color ?? const Color(0xFF333333);

  Color get subTextColor => const Color(0xFF777777);

  Color get fieldColor =>
      Theme.of(context).inputDecorationTheme.fillColor ??
      const Color(0xFFF3F7FA);

  String tr(String en, String ar) {
    return isArabic ? ar : en;
  }

  String placeName(String place) {
    switch (place) {
      case 'Hospital':
        return tr('Hospital', 'المستشفى');
      case 'Restaurant':
        return tr('Restaurant', 'المطعم');
      case 'Street':
        return tr('Street', 'الشارع');
      case 'Transport':
        return tr('Transport', 'المواصلات');
      case 'Shopping':
        return tr('Shopping', 'التسوق');
      default:
        return place;
    }
  }

  String moodName(String mood) {
    switch (mood) {
      case 'Calm':
        return tr('Calm', 'هادئ');
      case 'Happy':
        return tr('Happy', 'سعيد');
      case 'Sad':
        return tr('Sad', 'حزين');
      case 'Anxious':
        return tr('Anxious', 'متوتر');
      case 'Tired':
        return tr('Tired', 'متعب');
      case 'Angry':
        return tr('Angry', 'غاضب');
      default:
        return mood;
    }
  }

  final List<Map<String, String>> _aiMessages = [
    {
      'sender': 'ai',
      'text': 'Hi 🤍 I am here if you want to talk or need support.',
    },
  ];
  final List<Map<String, dynamic>> _places = const [
    {
      'name': 'Hospital',
      'emoji': '🏥',
      'phrasesEn': [
        'I am not feeling well.',
        'I need medical assistance.',
        'Please call a nurse.',
        'I feel dizzy.',
      ],
      'phrasesAr': [
        'أنا لا أشعر أنني بخير.',
        'أحتاج إلى مساعدة طبية.',
        'يرجى استدعاء الممرضة.',
        'أشعر بالدوار.',
      ],
    },
    {
      'name': 'Restaurant',
      'emoji': '🍽️',
      'phrasesEn': [
        'I need water please.',
        'I want to order food.',
        'Can you help me read the menu?',
        'I have food allergies.',
      ],
      'phrasesAr': [
        'أحتاج ماء من فضلك.',
        'أريد طلب الطعام.',
        'هل يمكنك مساعدتي في قراءة القائمة؟',
        'لدي حساسية من بعض الأطعمة.',
      ],
    },
    {
      'name': 'Street',
      'emoji': '🚶',
      'phrasesEn': [
        'Can you help me cross the street?',
        'I need directions.',
        'I am lost.',
        'Please help me find a safe place.',
      ],
      'phrasesAr': [
        'هل يمكنك مساعدتي في عبور الشارع؟',
        'أحتاج إلى الاتجاهات.',
        'أنا تائه.',
        'يرجى مساعدتي في العثور على مكان آمن.',
      ],
    },
    {
      'name': 'Transport',
      'emoji': '🚌',
      'phrasesEn': [
        'Is this the right bus?',
        'Please tell me when we arrive.',
        'I need help getting in.',
        'Can you help me find my seat?',
      ],
      'phrasesAr': [
        'هل هذه الحافلة الصحيحة؟',
        'يرجى إخباري عند الوصول.',
        'أحتاج مساعدة في الصعود.',
        'هل يمكنك مساعدتي في العثور على مقعدي؟',
      ],
    },
    {
      'name': 'Shopping',
      'emoji': '🛒',
      'phrasesEn': [
        'I need help finding this item.',
        'How much does this cost?',
        'Can you help me carry this?',
        'I want to pay.',
      ],
      'phrasesAr': [
        'أحتاج مساعدة في العثور على هذا المنتج.',
        'كم سعر هذا؟',
        'هل يمكنك مساعدتي في حمل هذا؟',
        'أريد الدفع.',
      ],
    },
  ];

  final List<Map<String, String>> _moods = const [
    {'label': 'Calm', 'emoji': '😌'},
    {'label': 'Happy', 'emoji': '😊'},
    {'label': 'Sad', 'emoji': '😢'},
    {'label': 'Anxious', 'emoji': '😰'},
    {'label': 'Tired', 'emoji': '😴'},
    {'label': 'Angry', 'emoji': '😡'},
  ];

  final Map<String, List<String>> _moodActivitiesEn = const {
    'Calm': [
      'Take a short walk for 5 minutes.',
      'Listen to soft music.',
      'Drink water and relax.',
    ],
    'Happy': [
      'Share your feeling with someone.',
      'Do a small creative activity.',
      'Write one good thing about today.',
    ],
    'Sad': [
      'Talk to your companion or AI friend.',
      'Take slow deep breaths.',
      'Watch something comforting.',
    ],
    'Anxious': [
      'Try 4 deep breaths slowly.',
      'Hold something soft or comforting.',
      'Sit in a quiet place for 2 minutes.',
    ],
    'Tired': [
      'Rest for a few minutes.',
      'Drink water.',
      'Do gentle stretching.',
    ],
    'Angry': [
      'Pause and count to 10.',
      'Move to a calm place.',
      'Tell someone: I need a moment.',
    ],
  };

  final Map<String, List<String>> _moodActivitiesAr = const {
    'Calm': [
      'خذ نزهة قصيرة لمدة 5 دقائق.',
      'استمع إلى موسيقى هادئة.',
      'اشرب الماء واسترخِ.',
    ],
    'Happy': [
      'شارك شعورك مع شخص قريب.',
      'قم بنشاط إبداعي بسيط.',
      'اكتب شيئاً جميلاً حدث اليوم.',
    ],
    'Sad': [
      'تحدث مع المرافق أو المساعد الذكي.',
      'خذ نفساً عميقاً ببطء.',
      'شاهد شيئاً يريحك.',
    ],
    'Anxious': [
      'خذ 4 أنفاس عميقة ببطء.',
      'امسك شيئاً ناعماً أو مريحاً.',
      'اجلس في مكان هادئ لمدة دقيقتين.',
    ],
    'Tired': [
      'استرح لبضع دقائق.',
      'اشرب الماء.',
      'قم بتمارين تمدد خفيفة.',
    ],
    'Angry': [
      'توقف وعد إلى 10.',
      'انتقل إلى مكان هادئ.',
      'قل لشخص: أحتاج لحظة.',
    ],
  };

  Map<String, dynamic> get selectedPlaceData {
    return _places.firstWhere((place) => place['name'] == _selectedPlace);
  }

  @override
  void initState() {
    super.initState();
    AppSettingsStore.instance.addListener(_onLanguageChanged);

    _loadAiChatMessages();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (mounted && isAccessibilityVoiceEnabled) {
        await _startVoiceAccessibilityAssistant();
      }
    });
  }

  void _onLanguageChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _showInfoPopup({
    required String title,
    required String message,
    required IconData icon,
    required Color iconColor,
  }) async {
    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (context) {
        return Directionality(
          textDirection: isArabic ? ui.TextDirection.rtl : ui.TextDirection.ltr,
          child: AlertDialog(
            backgroundColor: cardColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            title: Column(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: iconColor.withOpacity(0.15),
                  child: Icon(icon, color: iconColor, size: 32),
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            content: Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: subTextColor,
                fontSize: 15,
                height: 1.5,
              ),
            ),
            actionsAlignment: MainAxisAlignment.center,
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF87CEEB),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: () => Navigator.pop(context),
                child: Text(tr('OK', 'حسنًا')),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<bool> _showConfirmPopup({
    required String title,
    required String message,
    required IconData icon,
    required Color iconColor,
    String? confirmText,
    String? cancelText,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return Directionality(
          textDirection: isArabic ? ui.TextDirection.rtl : ui.TextDirection.ltr,
          child: AlertDialog(
            backgroundColor: cardColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            title: Column(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: iconColor.withOpacity(0.15),
                  child: Icon(icon, color: iconColor, size: 32),
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            content: Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: subTextColor,
                fontSize: 15,
                height: 1.5,
              ),
            ),
            actionsAlignment: MainAxisAlignment.center,
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(
                  cancelText ?? tr('Cancel', 'إلغاء'),
                  style: TextStyle(color: subTextColor),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: iconColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: () => Navigator.pop(context, true),
                child: Text(confirmText ?? tr('Yes', 'نعم')),
              ),
            ],
          ),
        );
      },
    );

    return result ?? false;
  }

  Future<void> _showAiSuggestionPopup() async {
    if (_isEmergency) {
      final goEmergency = await _showConfirmPopup(
        title: tr('AI Suggestion', 'اقتراح الذكاء الاصطناعي'),
        message: tr(
          'This message looks like an emergency. Do you want to open the Emergency page?',
          'يبدو أن هذه الرسالة حالة طارئة. هل تريد فتح صفحة الطوارئ؟',
        ),
        icon: Icons.warning_amber_rounded,
        iconColor: Colors.red,
        confirmText: tr('Open Emergency', 'فتح الطوارئ'),
        cancelText: tr('Stay Here', 'البقاء هنا'),
      );

      if (goEmergency && mounted) {
        VoiceAccessibilityService.instance.stopAll();

        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const EmergencyPage()),
        );
      }
    } else {
      await _showInfoPopup(
        title: tr('AI Suggestion', 'اقتراح الذكاء الاصطناعي'),
        message: tr(
          'AI generated a clear message based on your place, mood, and situation.',
          'أنشأ الذكاء الاصطناعي رسالة واضحة بناءً على المكان والحالة والمزاج.',
        ),
        icon: Icons.auto_awesome_rounded,
        iconColor: const Color(0xFF87CEEB),
      );
    }
  }

  Future<void> _showVoicePermissionPopup() async {
    await _showInfoPopup(
      title: tr('Voice Permission', 'إذن الصوت'),
      message: tr(
        'The app will use voice output to read the message aloud for easier communication.',
        'سيستخدم التطبيق إخراج الصوت لقراءة الرسالة بصوت عالٍ لتسهيل التواصل.',
      ),
      icon: Icons.record_voice_over_rounded,
      iconColor: const Color(0xFF87CEEB),
    );
  }

  Future<bool> _showTextToSpeechConfirmationPopup() async {
    return _showConfirmPopup(
      title: tr('Text To Speech', 'تحويل النص إلى صوت'),
      message: tr(
        'Do you want the app to read this message out loud?',
        'هل تريد أن يقرأ التطبيق هذه الرسالة بصوت عالٍ؟',
      ),
      icon: Icons.volume_up_rounded,
      iconColor: const Color(0xFF87CEEB),
      confirmText: tr('Read', 'قراءة'),
      cancelText: tr('Cancel', 'إلغاء'),
    );
  }

  Future<void> _showNeedHelpPopup() async {
    final openEmergency = await _showConfirmPopup(
      title: tr('Need Help?', 'هل تحتاج مساعدة؟'),
      message: tr(
        'You can talk to the AI companion or open the Emergency page if the situation is urgent.',
        'يمكنك التحدث مع المساعد الذكي أو فتح صفحة الطوارئ إذا كانت الحالة عاجلة.',
      ),
      icon: Icons.help_outline_rounded,
      iconColor: Colors.orange,
      confirmText: tr('Open Emergency', 'فتح الطوارئ'),
      cancelText: tr('Cancel', 'إلغاء'),
    );

    if (openEmergency && mounted) {
      VoiceAccessibilityService.instance.stopAll();

      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const EmergencyPage()),
      );
    }
  }

  Future<void> _saveCommunicationLog({
    required String inputText,
    required String generatedMessage,
    required String situation,
    required bool isEmergency,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance.collection('communication_logs').add({
      'userId': user.uid,
      'place': _selectedPlace,
      'mood': _selectedMood,
      'inputText': inputText,
      'generatedMessage': generatedMessage,
      'detectedSituation': situation,
      'isEmergency': isEmergency,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _saveAiChatMessage({
    required String sender,
    required String text,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance.collection('communication_ai_chats').add({
      'userId': user.uid,
      'sender': sender,
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _loadAiChatMessages() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('communication_ai_chats')
          .where('userId', isEqualTo: user.uid)
          .get();

      final docs = snapshot.docs.toList();
      docs.sort((a, b) {
        final aTime = a.data()['createdAt'];
        final bTime = b.data()['createdAt'];

        if (aTime is Timestamp && bTime is Timestamp) {
          return aTime.compareTo(bTime);
        }
        return 0;
      });

      final loadedMessages = docs
          .map((doc) {
            final data = doc.data();
            return {
              'sender': data['sender']?.toString() ?? 'ai',
              'text': data['text']?.toString() ?? '',
            };
          })
          .where((message) => (message['text'] ?? '').trim().isNotEmpty)
          .toList();

      if (!mounted || loadedMessages.isEmpty) return;

      setState(() {
        _aiMessages
          ..clear()
          ..addAll(loadedMessages);
      });
    } catch (e) {
      debugPrint('Failed to load AI chat messages: $e');
    }
  }

  Future<void> _readMoodActivities(String mood) async {
    if (!isAccessibilityVoiceEnabled) return;

    final activities = isArabic
        ? (_moodActivitiesAr[mood] ?? [])
        : (_moodActivitiesEn[mood] ?? []);

    if (activities.isEmpty) return;

    final text = tr(
      'Activities for ${moodName(mood)} mood are: ${activities.join(' ')}',
      'أنشطة حالة ${moodName(mood)} هي: ${activities.join(' ')}',
    );

    await VoiceAccessibilityService.instance.speak(text);
  }

  Future<void> _saveMoodActivityLog() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final activities = isArabic
        ? (_moodActivitiesAr[_selectedMood] ?? [])
        : (_moodActivitiesEn[_selectedMood] ?? []);

    await FirebaseFirestore.instance.collection('communication_mood_logs').add({
      'userId': user.uid,
      'selectedMood': _selectedMood,
      'place': _selectedPlace,
      'suggestedActivities': activities,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _speakMessage() async {
    if (_generatedMessage.isEmpty) return;

    await _showVoicePermissionPopup();

    final confirm = await _showTextToSpeechConfirmationPopup();
    if (!confirm) return;

    await _flutterTts.stop();
    await _flutterTts.setLanguage(isArabic ? 'ar-SA' : 'en-US');
    await _flutterTts.setSpeechRate(0.45);
    await _flutterTts.setPitch(1.0);
    await _flutterTts.speak(_generatedMessage);

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance.collection('communication_tts_logs').add({
      'userId': user.uid,
      'place': _selectedPlace,
      'mood': _selectedMood,
      'spokenText': _generatedMessage,
      'detectedSituation': _detectedSituation,
      'isEmergency': _isEmergency,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _analyzeSituation() async {
    final text = _messageController.text.toLowerCase().trim();

    String situation = 'General';
    bool emergency = false;
    String result = '';

    if (text.contains('تعبان') ||
        text.contains('مريض') ||
        text.contains('دوخة') ||
        text.contains('dizzy') ||
        text.contains('sick') ||
        text.contains('pain') ||
        text.contains('tired')) {
      situation = 'Medical';
      result = tr(
        'Hello, I am at the ${placeName(_selectedPlace)}. I am not feeling well and I need medical assistance please.',
        'مرحباً، أنا في ${placeName(_selectedPlace)}. لا أشعر أنني بخير وأحتاج إلى مساعدة طبية من فضلك.',
      );
    } else if (text.contains('طوارئ') ||
        text.contains('ساعدوني') ||
        text.contains('اختنق') ||
        text.contains('emergency') ||
        text.contains('help now') ||
        text.contains('can’t breathe')) {
      situation = 'Emergency';
      emergency = true;
      result = tr(
        'This is an emergency. I need help immediately. Please call my companion or emergency services.',
        'هذه حالة طوارئ. أحتاج إلى مساعدة فوراً. يرجى الاتصال بالمرافق أو خدمات الطوارئ.',
      );
    } else if (text.contains('ضايع') ||
        text.contains('lost') ||
        text.contains('direction') ||
        text.contains('مكان')) {
      situation = 'Lost / Direction';
      result = tr(
        'Hello, I am at the ${placeName(_selectedPlace)} and I need help with directions. Can you guide me please?',
        'مرحباً، أنا في ${placeName(_selectedPlace)} وأحتاج مساعدة في الاتجاهات. هل يمكنك إرشادي من فضلك؟',
      );
    } else if (text.contains('اكل') ||
        text.contains('ماي') ||
        text.contains('hungry') ||
        text.contains('water') ||
        text.contains('food')) {
      situation = 'Daily Need';
      result = tr(
        'Hello, I am at the ${placeName(_selectedPlace)}. I need help with food or water please.',
        'مرحباً، أنا في ${placeName(_selectedPlace)}. أحتاج مساعدة في الطعام أو الماء من فضلك.',
      );
    } else {
      result = tr(
        'Hello, I am at the ${placeName(_selectedPlace)}. ${_messageController.text.trim().isEmpty ? 'I need assistance' : _messageController.text.trim()}. Can you help me please?',
        'مرحباً، أنا في ${placeName(_selectedPlace)}. ${_messageController.text.trim().isEmpty ? 'أحتاج إلى مساعدة' : _messageController.text.trim()}. هل يمكنك مساعدتي من فضلك؟',
      );
    }

    if (_selectedMood == 'Anxious') {
      result += tr(
        ' I feel anxious, so please speak slowly and calmly.',
        ' أشعر بالتوتر، لذلك يرجى التحدث ببطء وهدوء.',
      );
    } else if (_selectedMood == 'Sad') {
      result += tr(
        ' I feel sad and I may need extra support.',
        ' أشعر بالحزن وقد أحتاج إلى دعم إضافي.',
      );
    } else if (_selectedMood == 'Tired') {
      result += tr(
        ' I feel tired and I may need time to respond.',
        ' أشعر بالتعب وقد أحتاج إلى وقت للرد.',
      );
    } else if (_selectedMood == 'Angry') {
      result += tr(
        ' I feel upset, please give me a moment.',
        ' أشعر بالانزعاج، يرجى إعطائي لحظة.',
      );
    }

    setState(() {
      _detectedSituation = situation;
      _isEmergency = emergency;
      _generatedMessage = result;
      _isSaving = true;
    });

    try {
      await _saveCommunicationLog(
        inputText: _messageController.text.trim(),
        generatedMessage: result,
        situation: situation,
        isEmergency: emergency,
      );

      if (mounted) {
        await _showAiSuggestionPopup();
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _talkForMe() async {
    await _showNeedHelpPopup();

    final result = tr(
      'Hello, I need assistance. I may not be able to speak clearly. Please be patient and help me communicate.',
      'مرحباً، أحتاج إلى مساعدة. قد لا أستطيع التحدث بوضوح. يرجى التحلي بالصبر ومساعدتي على التواصل.',
    );

    setState(() {
      _detectedSituation = 'Talk For Me';
      _isEmergency = false;
      _generatedMessage = result;
      _isSaving = true;
    });

    try {
      await _saveCommunicationLog(
        inputText: 'Talk For Me',
        generatedMessage: result,
        situation: 'Talk For Me',
        isEmergency: false,
      );

      if (mounted) {
        await _showAiSuggestionPopup();
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _emergencyMessage() async {
    final result = tr(
      'This is an emergency. I need help immediately. Please call my companion or emergency services.',
      'هذه حالة طوارئ. أحتاج إلى مساعدة فوراً. يرجى الاتصال بالمرافق أو خدمات الطوارئ.',
    );

    setState(() {
      _detectedSituation = 'Emergency';
      _isEmergency = true;
      _generatedMessage = result;
      _isSaving = true;
    });

    try {
      await _saveCommunicationLog(
        inputText: 'Emergency',
        generatedMessage: result,
        situation: 'Emergency',
        isEmergency: true,
      );

      if (mounted) {
        await _showAiSuggestionPopup();
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _copyMessage() {
    if (_generatedMessage.isEmpty) return;

    Clipboard.setData(ClipboardData(text: _generatedMessage));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(tr('Message copied', 'تم نسخ الرسالة')),
        backgroundColor: const Color(0xFF87CEEB),
      ),
    );
  }

  void _showLargeText() {
    if (_generatedMessage.isEmpty) return;

    showDialog(
      context: context,
      builder: (context) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaleFactor: AppSettingsStore.instance.textScale,
          ),
          child: Directionality(
            textDirection:
                isArabic ? ui.TextDirection.rtl : ui.TextDirection.ltr,
            child: Dialog(
              backgroundColor: cardColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: const Color(0xFF87CEEB).withOpacity(0.2),
                      child: const Icon(
                        Icons.open_in_full_rounded,
                        color: Color(0xFF87CEEB),
                        size: 30,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      tr('Large Text', 'النص المكبر'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      _generatedMessage,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        height: 1.4,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF87CEEB),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(120, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: Text(tr('Close', 'إغلاق')),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _openAiCompanion() async {
    await VoiceAccessibilityService.instance.stopAll();

    if (_aiMessages.length == 1 && _aiMessages.first['sender'] == 'ai') {
      _aiMessages.first['text'] = tr(
        'Hi, I am your AI companion. You can talk to me if you feel lonely, worried, tired, or need help.',
        'مرحباً، أنا المساعد الذكي. يمكنك التحدث معي إذا شعرت بالوحدة أو القلق أو التعب أو احتجت إلى مساعدة.',
      );
    }

    await _showInfoPopup(
      title: tr('AI Suggestion', 'اقتراح الذكاء الاصطناعي'),
      message: tr(
        'You can talk to the AI companion anytime you feel lonely or need help.',
        'يمكنك التحدث مع المساعد الذكي في أي وقت تشعر فيه بالوحدة أو تحتاج إلى مساعدة.',
      ),
      icon: Icons.smart_toy_rounded,
      iconColor: const Color(0xFF87CEEB),
    );

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaleFactor: AppSettingsStore.instance.textScale,
          ),
          child: Directionality(
            textDirection:
                isArabic ? ui.TextDirection.rtl : ui.TextDirection.ltr,
            child: StatefulBuilder(
              builder: (context, setModalState) {
                Future<void> sendMessage() async {
                  final text = _aiChatController.text.trim();
                  if (text.isEmpty) return;

                  setModalState(() {
                    _aiMessages.add({'sender': 'user', 'text': text});
                    _aiChatController.clear();
                  });

                  await _saveAiChatMessage(sender: 'user', text: text);

                  String reply;

                  try {
                    reply = await GeminiService.generateReply(
                      userMessage: text,
                      isArabic: isArabic,
                      selectedMood: _selectedMood,
                      selectedPlace: '',
                      conversationHistory: _aiMessages,
                    );
                  } catch (_) {
                    reply = tr(
                      'Sorry, the AI service is unavailable right now. I am still here with you. Please try again.',
                      'عذراً، خدمة الذكاء الاصطناعي غير متاحة حالياً. أنا ما زلت هنا معك. يرجى المحاولة مرة أخرى.',
                    );
                  }

                  setModalState(() {
                    _aiMessages.add({'sender': 'ai', 'text': reply});
                  });

                  await _saveAiChatMessage(sender: 'ai', text: reply);

                  if (reply.toLowerCase().contains('emergency') ||
                      reply.contains('طوارئ') ||
                      text.toLowerCase().contains('emergency') ||
                      text.contains('طوارئ') ||
                      text.contains('خطر') ||
                      text.contains('ساعدني')) {
                    if (mounted) {
                      await _showInfoPopup(
                        title: tr('AI Suggestion', 'اقتراح الذكاء الاصطناعي'),
                        message: tr(
                          'This sounds urgent. Please use the Emergency page if you need immediate help.',
                          'يبدو أن الحالة عاجلة. يرجى استخدام صفحة الطوارئ إذا كنت تحتاج مساعدة فورية.',
                        ),
                        icon: Icons.warning_amber_rounded,
                        iconColor: Colors.red,
                      );
                    }
                  }
                }

                return Container(
                  height: MediaQuery.of(context).size.height * 0.78,
                  padding: EdgeInsets.only(
                    left: 18,
                    right: 18,
                    top: 18,
                    bottom: MediaQuery.of(context).viewInsets.bottom + 18,
                  ),
                  decoration: BoxDecoration(
                    color: backgroundColor,
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(35)),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 55,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        tr('🤖 AI Companion', '🤖 المساعد الذكي'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        tr(
                          'Talk to me anytime you feel lonely or need help',
                          'تحدث معي في أي وقت تشعر فيه بالوحدة أو تحتاج للمساعدة',
                        ),
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, color: subTextColor),
                      ),
                      const SizedBox(height: 18),
                      Expanded(
                        child: ListView.builder(
                          itemCount: _aiMessages.length,
                          itemBuilder: (context, index) {
                            final msg = _aiMessages[index];
                            final isUser = msg['sender'] == 'user';

                            return Align(
                              alignment: isUser
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.all(14),
                                constraints: BoxConstraints(
                                  maxWidth:
                                      MediaQuery.of(context).size.width * 0.72,
                                ),
                                decoration: BoxDecoration(
                                  color: isUser
                                      ? const Color(0xFF87CEEB)
                                      : cardColor,
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: _shadow(),
                                ),
                                child: Text(
                                  msg['text']!,
                                  textAlign: isArabic
                                      ? TextAlign.right
                                      : TextAlign.left,
                                  style: TextStyle(
                                    fontSize: 14.5,
                                    height: 1.4,
                                    color: isUser ? Colors.white : textColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _aiChatController,
                              textAlign:
                                  isArabic ? TextAlign.right : TextAlign.left,
                              style: TextStyle(color: textColor),
                              decoration: InputDecoration(
                                hintText: tr('Type here...', 'اكتب هنا...'),
                                filled: true,
                                fillColor: cardColor,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(22),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                              onSubmitted: (_) => sendMessage(),
                            ),
                          ),
                          const SizedBox(width: 10),
                          CircleAvatar(
                            radius: 27,
                            backgroundColor: const Color(0xFF87CEEB),
                            child: IconButton(
                              onPressed: sendMessage,
                              icon: const Icon(
                                Icons.send_rounded,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Future<void> _startVoiceAccessibilityAssistant() async {
    if (!mounted) return;

    await VoiceAccessibilityService.instance.stopAll();

    setState(() {
      _isSpeaking = true;
    });

    await VoiceAccessibilityService.instance.readPageAndListen(
      context: context,
      pageText: tr(
        'Communication screen with location phrases, mood activities, Smart Situation Mode, Talk For Me, Emergency, and AI Companion. When you choose a mood, the screen reader reads the suggested activities for that mood. When you press the AI button, opens a chat with the AI companion, where you can type and send messages anytime you feel lonely or need help.',
        'صفحة التواصل تحتوي على عبارات حسب الموقع، وأنشطة حسب المزاج، ووضع تحليل الموقف الذكي، وخاصية تحدث بدلاً عني، والطوارئ، والمساعد الذكي. عندما تختار مزاجًا، يقرأ قارئ الشاشة الأنشطة المقترحة لهذا المزاج. وعند الضغط على زر الذكاء الاصطناعي، تفتح محادثة مع المساعد الذكي حيث يمكنك الكتابة وإرسال الرسائل في أي وقت تشعر فيه بالوحدة أو تحتاج إلى مساعدة.',
      ),
      routes: {
        'dashboard': (context) => const DashboardPage(),
        'health': (context) => const HealthPage(),
        'reminders': (context) => const RemindersPage(),
        'emergency': (context) => const EmergencyPage(),
        'communication': (context) => const CommunicationPage(),
        'map': (context) => const MapPage(),
        'volunteer': (context) => const VolunteerHelpPage(),
        'profile': (context) => const ProfilePage(),
        'settings': (context) => const SettingsPage(),
      },
    );

    if (!mounted) return;

    setState(() {
      _isSpeaking = false;
    });
  }

  Future<void> _stopSpeaking() async {
    await VoiceAccessibilityService.instance.stopAll();

    if (!mounted) return;

    setState(() {
      _isSpeaking = false;
    });
  }

  Future<void> _toggleVoiceButton() async {
    if (_isSpeaking) {
      await _stopSpeaking();
    } else {
      await _startVoiceAccessibilityAssistant();
    }
  }

  Widget _voiceControlButton() {
    return Positioned(
      left: 18,
      bottom: 18,
      child: Semantics(
        button: true,
        label: _isSpeaking
            ? tr('Stop voice reading', 'إيقاف القراءة الصوتية')
            : tr('Read this page again', 'إعادة قراءة الصفحة'),
        child: GestureDetector(
          onTap: _toggleVoiceButton,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: _isSpeaking
                  ? const Color(0xFF87CEEB)
                  : const Color(0xFFFF5A5F),
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Icon(
              _isSpeaking
                  ? Icons.record_voice_over_rounded
                  : Icons.volume_off_rounded,
              color: Colors.white,
              size: 40,
            ),
          ),
        ),
      ),
    );
  }

  void _goBack() {
    VoiceAccessibilityService.instance.stopAll();

    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const DashboardPage()),
      );
    }
  }

  void _goToPage(int index) {
    VoiceAccessibilityService.instance.stopAll();

    if (index == 0) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const DashboardPage()),
      );
    } else if (index == 1) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const ProfilePage()),
      );
    } else if (index == 2) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const SettingsPage()),
      );
    }
  }

  @override
  void dispose() {
    AppSettingsStore.instance.removeListener(_onLanguageChanged);
    VoiceAccessibilityService.instance.stopAll();
    _messageController.dispose();
    _aiChatController.dispose();
    _flutterTts.stop();
    super.dispose();
  }

  Widget _buildHeader() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          alignment: Alignment.bottomCenter,
          children: [
            Container(
              height: 130,
              width: double.infinity,
              color: const Color(0xFF87CEEB),
            ),
            Container(
              height: 40,
              width: double.infinity,
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(40),
                ),
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
          child: Row(
            children: [
              IconButton(
                onPressed: _goBack,
                icon: Icon(
                  isArabic ? Icons.arrow_forward : Icons.arrow_back,
                  size: 28,
                  color: textColor,
                ),
              ),
              Expanded(
                child: Text(
                  tr('Communication', 'التواصل'),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
              ),
              IconButton(
                onPressed: _showNeedHelpPopup,
                icon: Icon(
                  Icons.help_outline_rounded,
                  size: 28,
                  color: textColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final phrases = isArabic
        ? selectedPlaceData['phrasesAr'] as List<String>
        : selectedPlaceData['phrasesEn'] as List<String>;

    final activities = isArabic
        ? (_moodActivitiesAr[_selectedMood] ?? [])
        : (_moodActivitiesEn[_selectedMood] ?? []);

    return AnimatedBuilder(
      animation: AppSettingsStore.instance,
      builder: (context, _) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaleFactor: AppSettingsStore.instance.textScale,
          ),
          child: Directionality(
            textDirection:
                isArabic ? ui.TextDirection.rtl : ui.TextDirection.ltr,
            child: Scaffold(
              backgroundColor: backgroundColor,
              floatingActionButton: FloatingActionButton.large(
                backgroundColor: const Color(0xFF87CEEB),
                elevation: 8,
                onPressed: _openAiCompanion,
                child: const Text('🤖', style: TextStyle(fontSize: 38)),
              ),
              floatingActionButtonLocation:
                  FloatingActionButtonLocation.endFloat,
              body: Stack(
                children: [
                  SafeArea(
                    child: Column(
                      children: [
                        _buildHeader(),
                        Expanded(
                          child: SingleChildScrollView(
                            keyboardDismissBehavior:
                                ScrollViewKeyboardDismissBehavior.onDrag,
                            padding: const EdgeInsets.all(18),
                            child: Column(
                              crossAxisAlignment: isArabic
                                  ? CrossAxisAlignment.end
                                  : CrossAxisAlignment.start,
                              children: [
                                _sectionTitle(
                                  tr('Where are you now?', 'أين أنت الآن؟'),
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  height: 170,
                                  child: ListView.separated(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: _places.length,
                                    separatorBuilder: (_, __) =>
                                        const SizedBox(width: 12),
                                    itemBuilder: (context, index) {
                                      final place = _places[index];
                                      final isSelected =
                                          place['name'] == _selectedPlace;

                                      return GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            _selectedPlace = place['name'];
                                            _generatedMessage = '';
                                            _detectedSituation = 'General';
                                            _isEmergency = false;
                                          });
                                        },
                                        child: AnimatedContainer(
                                          duration:
                                              const Duration(milliseconds: 250),
                                          width: 120,
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: isSelected
                                                ? const Color(0xFF87CEEB)
                                                : cardColor,
                                            borderRadius:
                                                BorderRadius.circular(24),
                                            boxShadow: _shadow(),
                                          ),
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceEvenly,
                                            children: [
                                              Text(
                                                place['emoji'],
                                                style: const TextStyle(
                                                    fontSize: 34),
                                              ),
                                              const SizedBox(height: 8),
                                              Flexible(
                                                child: FittedBox(
                                                  fit: BoxFit.scaleDown,
                                                  child: Text(
                                                    placeName(place['name']),
                                                    textAlign: TextAlign.center,
                                                    maxLines: 2,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: isSelected
                                                          ? Colors.white
                                                          : textColor,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(height: 24),
                                _sectionTitle(
                                  tr(
                                    'Suggested phrases for ${placeName(_selectedPlace)}',
                                    'عبارات مقترحة لـ ${placeName(_selectedPlace)}',
                                  ),
                                ),
                                const SizedBox(height: 12),
                                LayoutBuilder(
                                  builder: (context, constraints) {
                                    final isSmall = constraints.maxWidth < 360;

                                    return GridView.builder(
                                      shrinkWrap: true,
                                      physics:
                                          const NeverScrollableScrollPhysics(),
                                      itemCount: phrases.length,
                                      gridDelegate:
                                          SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: isSmall ? 1 : 2,
                                        mainAxisSpacing: 12,
                                        crossAxisSpacing: 12,
                                        childAspectRatio: isSmall ? 3.0 : 1.65,
                                      ),
                                      itemBuilder: (context, index) {
                                        return GestureDetector(
                                          onTap: () {
                                            setState(() {
                                              _messageController.text =
                                                  phrases[index];
                                              _generatedMessage =
                                                  phrases[index];
                                              _detectedSituation =
                                                  'Quick Phrase';
                                              _isEmergency = false;
                                            });
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.all(14),
                                            decoration: BoxDecoration(
                                              color: cardColor,
                                              borderRadius:
                                                  BorderRadius.circular(22),
                                              boxShadow: _shadow(),
                                            ),
                                            child: Center(
                                              child: Text(
                                                phrases[index],
                                                textAlign: TextAlign.center,
                                                maxLines: 3,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontSize: 14.5,
                                                  fontWeight: FontWeight.w600,
                                                  color: textColor,
                                                ),
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    );
                                  },
                                ),
                                const SizedBox(height: 24),
                                _sectionTitle(
                                    tr('How do you feel?', 'كيف تشعر؟')),
                                const SizedBox(height: 12),
                                SizedBox(
                                  height: 82,
                                  child: ListView.separated(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: _moods.length,
                                    separatorBuilder: (_, __) =>
                                        const SizedBox(width: 10),
                                    itemBuilder: (context, index) {
                                      final mood = _moods[index];
                                      final selected =
                                          mood['label'] == _selectedMood;

                                      return GestureDetector(
                                        onTap: () async {
                                          final selectedMood = mood['label']!;

                                          setState(() {
                                            _selectedMood = selectedMood;
                                          });

                                          await _saveMoodActivityLog();
                                          await _readMoodActivities(
                                              selectedMood);
                                        },
                                        child: AnimatedContainer(
                                          duration:
                                              const Duration(milliseconds: 220),
                                          width: 82,
                                          decoration: BoxDecoration(
                                            color: selected
                                                ? const Color(0xFF87CEEB)
                                                : cardColor,
                                            borderRadius:
                                                BorderRadius.circular(22),
                                            boxShadow: _shadow(),
                                          ),
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                mood['emoji']!,
                                                style: const TextStyle(
                                                  fontSize: 27,
                                                ),
                                              ),
                                              const SizedBox(height: 5),
                                              Text(
                                                moodName(mood['label']!),
                                                textAlign: TextAlign.center,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  color: selected
                                                      ? Colors.white
                                                      : textColor,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(height: 14),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: cardColor,
                                    borderRadius: BorderRadius.circular(24),
                                    boxShadow: _shadow(),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: isArabic
                                        ? CrossAxisAlignment.end
                                        : CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        tr(
                                          'Activities for ${moodName(_selectedMood)} mood',
                                          'أنشطة لحالة ${moodName(_selectedMood)}',
                                        ),
                                        textAlign: isArabic
                                            ? TextAlign.right
                                            : TextAlign.left,
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: textColor,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      ...activities.map(
                                        (activity) => Padding(
                                          padding:
                                              const EdgeInsets.only(bottom: 8),
                                          child: Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              const Text('✨ '),
                                              Expanded(
                                                child: Text(
                                                  activity,
                                                  textAlign: isArabic
                                                      ? TextAlign.right
                                                      : TextAlign.left,
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    height: 1.4,
                                                    color: subTextColor,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 24),
                                _sectionTitle(
                                  tr('Quick Talk For Me', 'التحدث السريع'),
                                ),
                                const SizedBox(height: 12),
                                LayoutBuilder(
                                  builder: (context, constraints) {
                                    final isSmall = constraints.maxWidth < 360;

                                    if (isSmall) {
                                      return Column(
                                        children: [
                                          _quickModeCard(
                                            emoji: '👤',
                                            title: tr('Talk For Me',
                                                'تحدث بدلاً عني'),
                                            subtitle: tr(
                                                'One tap help', 'مساعدة بضغطة'),
                                            color: const Color(0xFFE8F6FF),
                                            onTap: _talkForMe,
                                          ),
                                          const SizedBox(height: 12),
                                          _quickModeCard(
                                            emoji: '🚨',
                                            title: tr('Emergency', 'طوارئ'),
                                            subtitle: tr('Need help now',
                                                'أحتاج مساعدة'),
                                            color: const Color(0xFFFFE7E7),
                                            onTap: _emergencyMessage,
                                          ),
                                        ],
                                      );
                                    }

                                    return Row(
                                      children: [
                                        Expanded(
                                          child: _quickModeCard(
                                            emoji: '👤',
                                            title: tr('Talk For Me',
                                                'تحدث بدلاً عني'),
                                            subtitle: tr(
                                                'One tap help', 'مساعدة بضغطة'),
                                            color: const Color(0xFFE8F6FF),
                                            onTap: _talkForMe,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: _quickModeCard(
                                            emoji: '🚨',
                                            title: tr('Emergency', 'طوارئ'),
                                            subtitle: tr('Need help now',
                                                'أحتاج مساعدة'),
                                            color: const Color(0xFFFFE7E7),
                                            onTap: _emergencyMessage,
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                                const SizedBox(height: 24),
                                _sectionTitle(
                                  tr(
                                    'Smart Situation Mode',
                                    'وضع تحليل الموقف الذكي',
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: cardColor,
                                    borderRadius: BorderRadius.circular(26),
                                    boxShadow: _shadow(),
                                  ),
                                  child: Column(
                                    children: [
                                      TextField(
                                        controller: _messageController,
                                        minLines: 3,
                                        maxLines: 5,
                                        textAlign: isArabic
                                            ? TextAlign.right
                                            : TextAlign.left,
                                        style: TextStyle(color: textColor),
                                        decoration: InputDecoration(
                                          hintText: tr(
                                            'Example: I feel dizzy / تعبان / I need water...',
                                            'مثال: أشعر بالدوار / تعبان / أحتاج ماء...',
                                          ),
                                          filled: true,
                                          fillColor: fieldColor,
                                          border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(20),
                                            borderSide: BorderSide.none,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      SizedBox(
                                        width: double.infinity,
                                        height: 55,
                                        child: ElevatedButton.icon(
                                          onPressed: _isSaving
                                              ? null
                                              : _analyzeSituation,
                                          icon: const Text(
                                            '🧠',
                                            style: TextStyle(fontSize: 22),
                                          ),
                                          label: Text(
                                            _isSaving
                                                ? tr('Saving...',
                                                    'جاري الحفظ...')
                                                : tr(
                                                    'Analyze & Generate Message',
                                                    'تحليل وإنشاء رسالة',
                                                  ),
                                            textAlign: TextAlign.center,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                const Color(0xFF87CEEB),
                                            foregroundColor: Colors.white,
                                            elevation: 0,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(22),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (_generatedMessage.isNotEmpty) ...[
                                  const SizedBox(height: 24),
                                  _sectionTitle(
                                    tr('AI Message Result',
                                        'نتيجة الرسالة الذكية'),
                                  ),
                                  const SizedBox(height: 12),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(18),
                                    decoration: BoxDecoration(
                                      color: _isEmergency
                                          ? const Color(0xFFFFF0F0)
                                          : cardColor,
                                      borderRadius: BorderRadius.circular(26),
                                      border: Border.all(
                                        color: _isEmergency
                                            ? Colors.redAccent
                                            : Colors.transparent,
                                        width: 1.5,
                                      ),
                                      boxShadow: _shadow(),
                                    ),
                                    child: Column(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 14,
                                            vertical: 8,
                                          ),
                                          decoration: BoxDecoration(
                                            color: _isEmergency
                                                ? Colors.redAccent
                                                : const Color(0xFFE8F6FF),
                                            borderRadius:
                                                BorderRadius.circular(18),
                                          ),
                                          child: Text(
                                            tr(
                                              'Detected: $_detectedSituation',
                                              'تم التعرف على الحالة: $_detectedSituation',
                                            ),
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              color: _isEmergency
                                                  ? Colors.white
                                                  : const Color(0xFF2B8DBD),
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          _generatedMessage,
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w700,
                                            height: 1.5,
                                            color: textColor,
                                          ),
                                        ),
                                        const SizedBox(height: 18),
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 8,
                                          alignment: WrapAlignment.center,
                                          children: [
                                            _actionButton(
                                              icon: Icons.volume_up_rounded,
                                              text: tr('Read', 'قراءة'),
                                              onTap: _speakMessage,
                                            ),
                                            _actionButton(
                                              icon: Icons.copy_rounded,
                                              text: tr('Copy', 'نسخ'),
                                              onTap: _copyMessage,
                                            ),
                                            _actionButton(
                                              icon: Icons.open_in_full_rounded,
                                              text: tr('Large', 'تكبير'),
                                              onTap: _showLargeText,
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 100),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _voiceControlButton(),
                ],
              ),
              bottomNavigationBar: _buildBottomNavigation(),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBottomNavigation() {
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF87CEEB),
          borderRadius: BorderRadius.circular(30),
          boxShadow: _shadow(),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _bottomItem(Icons.home_rounded, tr('Home', 'الرئيسية'), 0),
            _bottomItem(Icons.person_rounded, tr('Profile', 'الملف'), 1),
            _bottomItem(Icons.settings_rounded, tr('Settings', 'الإعدادات'), 2),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Align(
      alignment: isArabic ? Alignment.centerRight : Alignment.centerLeft,
      child: Text(
        title,
        textAlign: isArabic ? TextAlign.right : TextAlign.left,
        style: TextStyle(
          fontSize: 19,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
      ),
    );
  }

  Widget _quickModeCard({
    required String emoji,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 170,
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(26),
          boxShadow: _shadow(),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 30)),
            const SizedBox(height: 10),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 5),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: subTextColor),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String text,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: 115,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 17),
        label: Text(
          text,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFE8F6FF),
          foregroundColor: const Color(0xFF2B8DBD),
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 13),
          minimumSize: const Size(0, 45),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
    );
  }

  Widget _bottomItem(IconData icon, String label, int index) {
    return Flexible(
      child: GestureDetector(
        onTap: () => _goToPage(index),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 27),
            const SizedBox(height: 3),
            Text(
              label,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<BoxShadow> _shadow() {
    return [
      BoxShadow(
        color: Colors.black.withOpacity(0.08),
        blurRadius: 12,
        offset: const Offset(0, 5),
      ),
    ];
  }
}
