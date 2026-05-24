import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'Dashboard_page.dart';
import 'Profile_page.dart';
import 'Settings_page.dart';
import 'services/gemini_service.dart';

import 'package:humantouch/pages/app_settings_store.dart';
import 'voice_accessibility_service.dart';

class HealthPage extends StatefulWidget {
  const HealthPage({super.key});

  @override
  State<HealthPage> createState() => _HealthPageState();
}

class _HealthPageState extends State<HealthPage> {
  String _selectedMood = 'Happy';
  String _userName = 'User';
  bool _showAllActivities = false;
  bool _watchConnected = false;
  bool _isLoadingDailyHealth = false;
  bool _isSpeaking = false;
  DateTime _selectedActivityDate = DateTime.now();

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
      Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;

  Color get subTextColor =>
      Theme.of(context).textTheme.bodyMedium?.color ?? Colors.black87;

  Color get lightCardColor => const Color(0xFFD9F3FF);

  String tr(String en, String ar) => isArabic ? ar : en;

  String moodName(String mood) {
    switch (mood) {
      case 'Happy':
        return tr('Happy', 'سعيد');
      case 'Calm':
        return tr('Calm', 'هادئ');
      case 'Tired':
        return tr('Tired', 'متعب');
      case 'Sad':
        return tr('Sad', 'حزين');
      case 'Stressed':
        return tr('Stressed', 'متوتر');
      case 'Anxious':
        return tr('Anxious', 'قلق');
      case 'Angry':
        return tr('Angry', 'غاضب');
      case 'Sick':
        return tr('Sick', 'مريض');
      default:
        return mood;
    }
  }

  String activityTitle(String title) {
    switch (title) {
      case 'Heart':
        return tr('Heart', 'القلب');
      case 'Sleep':
        return tr('Sleep', 'النوم');
      case 'Walk':
        return tr('Walk', 'المشي');
      case 'Exercise':
        return tr('Exercise', 'الرياضة');
      case 'Water':
        return tr('Water', 'الماء');
      default:
        return title;
    }
  }

  String unitName(String unit) {
    switch (unit) {
      case 'BPM':
        return tr('BPM', 'نبضة/دقيقة');
      case 'Hours':
        return tr('Hours', 'ساعات');
      case 'Steps':
        return tr('Steps', 'خطوة');
      case 'Minutes':
        return tr('Minutes', 'دقائق');
      case 'Cups':
        return tr('Cups', 'أكواب');
      default:
        return unit;
    }
  }

  final List<HealthMood> _moods = const [
    HealthMood(label: 'Happy', emoji: '😊', color: Color(0xFFFDFFB6)),
    HealthMood(label: 'Calm', emoji: '😌', color: Color(0xFF9BF6FF)),
    HealthMood(label: 'Tired', emoji: '🥱', color: Color(0xFFFFC6FF)),
    HealthMood(label: 'Sad', emoji: '😔', color: Color(0xFFFFADAD)),
    HealthMood(label: 'Stressed', emoji: '😣', color: Color(0xFFCAFFBF)),
    HealthMood(label: 'Anxious', emoji: '😟', color: Color(0xFFD7C0FF)),
    HealthMood(label: 'Angry', emoji: '😡', color: Color(0xFFFFD6A5)),
    HealthMood(label: 'Sick', emoji: '🤒', color: Color(0xFFCDEAC0)),
  ];

  late List<HealthActivity> _activities =
      List<HealthActivity>.from(_defaultActivities());

  static List<HealthActivity> _defaultActivities() {
    return [
      HealthActivity(
        title: 'Heart',
        value: 0,
        goal: 120,
        unit: 'BPM',
        emoji: '❤️',
        color: Color(0xFFFFADAD),
      ),
      HealthActivity(
        title: 'Sleep',
        value: 0,
        goal: 8,
        unit: 'Hours',
        emoji: '😴',
        color: Color(0xFF9BF6FF),
      ),
      HealthActivity(
        title: 'Walk',
        value: 0,
        goal: 8000,
        unit: 'Steps',
        emoji: '👟',
        color: Color(0xFFFFC6FF),
      ),
      HealthActivity(
        title: 'Exercise',
        value: 0,
        goal: 60,
        unit: 'Minutes',
        emoji: '🏋️',
        color: Color(0xFFFDFFB6),
      ),
      HealthActivity(
        title: 'Water',
        value: 0,
        goal: 8,
        unit: 'Cups',
        emoji: '💧',
        color: Color(0xFFCAFFBF),
      ),
    ];
  }

  @override
  void initState() {
    super.initState();
    _loadUserDataFromFirebase();
    AppSettingsStore.instance.addListener(_onLanguageChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (mounted && isAccessibilityVoiceEnabled) {
        await _startVoiceAccessibilityAssistant();
      }
    });
  }

  void _onLanguageChanged() {
    if (mounted) setState(() {});
  }

  String _dateKey(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  bool get _isSelectedDateToday {
    return _isSameDay(_selectedActivityDate, DateTime.now());
  }

  String _selectedDateTitle() {
    final today = DateTime.now();
    final yesterday = today.subtract(const Duration(days: 1));

    if (_isSameDay(_selectedActivityDate, today)) {
      return tr('Today', 'اليوم');
    }

    if (_isSameDay(_selectedActivityDate, yesterday)) {
      return tr('Yesterday', 'أمس');
    }

    return '${_selectedActivityDate.day}/${_selectedActivityDate.month}/${_selectedActivityDate.year}';
  }

  void _applyActivitiesFromList(List<dynamic> savedActivities) {
    final defaults = _defaultActivities();

    _activities = defaults.map((defaultItem) {
      final matched = savedActivities.where((item) {
        if (item is! Map) return false;
        return item['title'] == defaultItem.title;
      }).toList();

      if (matched.isEmpty) return defaultItem;

      final item = matched.first as Map;
      final value = item['value'];
      final goal = item['goal'];

      return HealthActivity(
        title: defaultItem.title,
        value: value is num ? value.toDouble() : defaultItem.value,
        goal: goal is num ? goal.toDouble() : defaultItem.goal,
        unit: (item['unit'] ?? defaultItem.unit).toString(),
        emoji: (item['emoji'] ?? defaultItem.emoji).toString(),
        color: defaultItem.color,
      );
    }).toList();
  }

  Future<void> _loadDailyHealthData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() {
      _isLoadingDailyHealth = true;
    });

    try {
      final dateKey = _dateKey(_selectedActivityDate);

      final doc = await FirebaseFirestore.instance
          .collection('health_daily_activities')
          .doc('${user.uid}_$dateKey')
          .get();

      if (!mounted) return;

      setState(() {
        if (doc.exists && doc.data() != null) {
          final data = doc.data()!;
          final savedMood = data['moodLabel'];
          final savedWatchConnected = data['watchConnected'];
          final savedActivities = data['activities'];

          if (savedMood != null && savedMood.toString().trim().isNotEmpty) {
            _selectedMood = savedMood.toString();
          }

          _watchConnected = savedWatchConnected == true;

          if (savedActivities is List) {
            _applyActivitiesFromList(savedActivities);
          } else {
            _activities = List<HealthActivity>.from(_defaultActivities());
          }
        } else {
          _activities = List<HealthActivity>.from(_defaultActivities());
          _watchConnected = false;

          if (_isSelectedDateToday) {
            _selectedMood = 'Happy';
          }
        }

        _isLoadingDailyHealth = false;
      });
    } catch (e) {
      debugPrint('Error loading daily health data: $e');

      if (!mounted) return;

      setState(() {
        _activities = List<HealthActivity>.from(_defaultActivities());
        _watchConnected = false;
        _isLoadingDailyHealth = false;
      });
    }
  }

  Future<void> _pickActivityDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedActivityDate,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Directionality(
          textDirection: isArabic ? ui.TextDirection.rtl : ui.TextDirection.ltr,
          child: Theme(
            data: Theme.of(context).copyWith(
              colorScheme: const ColorScheme.light(
                primary: Color(0xFF87CEEB),
                onPrimary: Colors.white,
                onSurface: Colors.black,
              ),
            ),
            child: child!,
          ),
        );
      },
    );

    if (picked == null) return;

    setState(() {
      _selectedActivityDate = DateTime(picked.year, picked.month, picked.day);
    });

    await _loadDailyHealthData();
  }

  @override
  void dispose() {
    AppSettingsStore.instance.removeListener(_onLanguageChanged);
    VoiceAccessibilityService.instance.stopAll();
    super.dispose();
  }

  Future<void> _loadUserDataFromFirebase() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!mounted) return;

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;

        final name = data['name'] ?? data['fullName'] ?? data['username'];
        final mood = data['patientMoodLabel'];

        setState(() {
          if (name != null && name.toString().trim().isNotEmpty) {
            _userName = name.toString();
          }

          if (mood != null && mood.toString().trim().isNotEmpty) {
            _selectedMood = mood.toString();
          }
        });
      }

      await _loadDailyHealthData();
    } catch (e) {
      debugPrint('Error loading user data: $e');
    }
  }

  String _getGreeting() {
    final int hour = DateTime.now().hour;
    return hour < 12
        ? tr('Good Morning', 'صباح الخير')
        : tr('Good Evening', 'مساء الخير');
  }

  Future<void> _showHealthPopup({
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
            content: SingleChildScrollView(
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: subTextColor,
                  fontSize: 15,
                  height: 1.5,
                ),
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

  Future<void> _showMedicationReminderPopup() async {
    await _showHealthPopup(
      title: tr('Medication Reminder', 'تذكير الدواء'),
      message: tr(
        'Do not forget to take your medicine on time. Check your reminders for today.',
        'لا تنسَ تناول الدواء في وقته. تحقق من تذكيراتك لهذا اليوم.',
      ),
      icon: Icons.medication_rounded,
      iconColor: const Color(0xFF87CEEB),
    );
  }

  Future<void> _showMedicationWarningPopup() async {
    await _showHealthPopup(
      title: tr('Medication Warning', 'تنبيه الدواء'),
      message: tr(
        'No medicine has been marked as taken yet. Please take it if it is due, or contact your companion if you need help.',
        'لم يتم تسجيل تناول الدواء بعد. يرجى تناوله إذا حان موعده، أو التواصل مع المرافق إذا كنت تحتاج مساعدة.',
      ),
      icon: Icons.warning_amber_rounded,
      iconColor: Colors.orange,
    );
  }

  Future<void> _showAppointmentReminderPopup() async {
    await _showHealthPopup(
      title: tr('Appointment Reminder', 'تذكير الموعد'),
      message: tr(
        'You may have an upcoming appointment. Please check your appointment reminders and prepare early.',
        'قد يكون لديك موعد قريب. يرجى التحقق من تذكيرات المواعيد والاستعداد مبكرًا.',
      ),
      icon: Icons.event_available_rounded,
      iconColor: Colors.purple,
    );
  }

  Future<void> _showSaveChangesPopup(String message) async {
    await _showHealthPopup(
      title: tr('Saved Successfully', 'تم الحفظ بنجاح'),
      message: message,
      icon: Icons.check_circle_rounded,
      iconColor: Colors.green,
    );
  }

  Future<void> _showHealthTipPopup(HealthTip tip) async {
    await _showHealthPopup(
      title: '${tip.emoji} ${tip.title}',
      message:
          '${tip.personName} • ${isArabic && tip.personType == 'Volunteer' ? 'متطوع' : tip.personType}\n\n${tip.fullTip}',
      icon: Icons.lightbulb_rounded,
      iconColor: const Color(0xFF87CEEB),
    );
  }

  Widget _buildHealthPopupActionsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: _shadow(),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment:
            isArabic ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Text(
            tr('Health Alerts', 'تنبيهات الصحة'),
            style: TextStyle(
              color: textColor,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final bool small = constraints.maxWidth < 360;

              if (small) {
                return Column(
                  children: [
                    _smallAlertButton(
                      icon: Icons.medication_rounded,
                      label: tr('Medicine', 'دواء'),
                      onTap: _showMedicationReminderPopup,
                    ),
                    const SizedBox(height: 8),
                    _smallAlertButton(
                      icon: Icons.warning_amber_rounded,
                      label: tr('Warning', 'تنبيه'),
                      onTap: _showMedicationWarningPopup,
                    ),
                    const SizedBox(height: 8),
                    _smallAlertButton(
                      icon: Icons.event_available_rounded,
                      label: tr('Appointment', 'موعد'),
                      onTap: _showAppointmentReminderPopup,
                    ),
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(
                    child: _smallAlertButton(
                      icon: Icons.medication_rounded,
                      label: tr('Medicine', 'دواء'),
                      onTap: _showMedicationReminderPopup,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _smallAlertButton(
                      icon: Icons.warning_amber_rounded,
                      label: tr('Warning', 'تنبيه'),
                      onTap: _showMedicationWarningPopup,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _smallAlertButton(
                      icon: Icons.event_available_rounded,
                      label: tr('Appointment', 'موعد'),
                      onTap: _showAppointmentReminderPopup,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _smallAlertButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF87CEEB),
          side: const BorderSide(color: Color(0xFF87CEEB)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _activitiesAsMap() {
    return _activities.map((item) {
      return {
        'title': item.title,
        'value': item.value,
        'goal': item.goal,
        'unit': item.unit,
        'emoji': item.emoji,
      };
    }).toList();
  }

  Future<void> _sendHealthUpdateToLinkedCompanions({
    required String patientId,
    required String patientName,
    required String updateType,
    required String message,
    String? moodLabel,
    String? moodEmoji,
  }) async {
    final companions = await FirebaseFirestore.instance
        .collection('users')
        .where('patientUid', isEqualTo: patientId)
        .get();

    for (final companionDoc in companions.docs) {
      final companionData = companionDoc.data();

      if ((companionData['role'] ?? '').toString() != 'companion') {
        continue;
      }

      try {
        await FirebaseFirestore.instance.collection('notifications').add({
          'userId': companionDoc.id,
          'receiverId': companionDoc.id,
          'senderId': patientId,
          'senderRole': 'patient',
          'patientId': patientId,
          'patientName': patientName,
          'type': 'health_update',
          'updateType': updateType,
          'title': tr('Patient Health Updated', 'تم تحديث حالة المريض'),
          'message': message,
          'moodLabel': moodLabel ?? _selectedMood,
          'moodEmoji': moodEmoji ?? '',
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });

        await FirebaseFirestore.instance
            .collection('users')
            .doc(companionDoc.id)
            .set({
          'linkedPatientLastHealthUpdate': message,
          'linkedPatientLastHealthUpdateType': updateType,
          'linkedPatientLastHealthUpdateAt': FieldValue.serverTimestamp(),
          'linkedPatientMoodLabel': moodLabel ?? _selectedMood,
          'linkedPatientMoodEmoji': moodEmoji ?? '',
          'linkedPatientActivities': _activitiesAsMap(),
          'linkedPatientHealthDate': _dateKey(_selectedActivityDate),
        }, SetOptions(merge: true));
      } catch (e) {
        debugPrint('Error sending health update to companion: $e');
      }
    }
  }

  Future<void> _saveHealthSnapshotToFirebase({
    required String updateType,
    required String message,
    String? moodLabel,
    String? moodEmoji,
  }) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('Please login first', 'يرجى تسجيل الدخول أولاً')),
        ),
      );
      return;
    }

    final String dateKey = _dateKey(_selectedActivityDate);

    final dailyHealthData = {
      'patientId': user.uid,
      'patientName': _userName,
      'dateKey': dateKey,
      'date': Timestamp.fromDate(
        DateTime(
          _selectedActivityDate.year,
          _selectedActivityDate.month,
          _selectedActivityDate.day,
        ),
      ),
      'moodLabel': moodLabel ?? _selectedMood,
      'moodEmoji': moodEmoji ?? '',
      'activities': _activitiesAsMap(),
      'watchConnected': _watchConnected,
      'lastUpdateMessage': message,
      'lastUpdateType': updateType,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    await FirebaseFirestore.instance
        .collection('health_daily_activities')
        .doc('${user.uid}_$dateKey')
        .set(dailyHealthData, SetOptions(merge: true));

    if (_isSelectedDateToday) {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'patientMoodLabel': moodLabel ?? _selectedMood,
        'patientMoodEmoji': moodEmoji ?? '',
        'patientMoodTime': FieldValue.serverTimestamp(),
        'healthActivities': _activitiesAsMap(),
        'healthLastUpdateMessage': message,
        'healthLastUpdateType': updateType,
        'healthLastUpdatedAt': FieldValue.serverTimestamp(),
        'healthDateKey': dateKey,
        'watchConnected': _watchConnected,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await FirebaseFirestore.instance.collection('health_updates').add({
        'patientId': user.uid,
        'patientName': _userName,
        'updateType': updateType,
        'message': message,
        'moodLabel': moodLabel ?? _selectedMood,
        'moodEmoji': moodEmoji ?? '',
        'activities': _activitiesAsMap(),
        'watchConnected': _watchConnected,
        'dateKey': dateKey,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await _sendHealthUpdateToLinkedCompanions(
        patientId: user.uid,
        patientName: _userName,
        updateType: updateType,
        message: message,
        moodLabel: moodLabel,
        moodEmoji: moodEmoji,
      );
    }
  }

  Future<void> _saveMoodForCompanion(HealthMood mood) async {
    try {
      final String message = tr(
        '${mood.emoji} Mood updated to ${moodName(mood.label)}',
        '${mood.emoji} تم تحديث المزاج إلى ${moodName(mood.label)}',
      );

      setState(() {
        _selectedMood = mood.label;
      });

      await _saveHealthSnapshotToFirebase(
        updateType: 'mood',
        message: message,
        moodLabel: mood.label,
        moodEmoji: mood.emoji,
      );

      if (!mounted) return;

      await _showSaveChangesPopup(
        tr(
          '${mood.emoji} Mood saved and sent to companion',
          '${mood.emoji} تم حفظ المزاج وإرساله للمرافق',
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr('Error saving mood: $e', 'حدث خطأ أثناء حفظ المزاج: $e'),
          ),
        ),
      );
    }
  }

  void _openTipDetails(HealthTip tip) {
    _showHealthTipPopup(tip);
  }

  void _openAIQuestions() {
    VoiceAccessibilityService.instance.stopAll();

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AIQuestionsPage()),
    );
  }

  void _openManualActivityDialog(int index) {
    if (!_isSelectedDateToday) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr(
              'Previous days are view-only. Choose today to update activity.',
              'الأيام السابقة للعرض فقط. اختر اليوم لتحديث النشاط.',
            ),
          ),
        ),
      );
      return;
    }

    final item = _activities[index];
    final controller =
        TextEditingController(text: item.value.toInt().toString());

    showDialog(
      context: context,
      builder: (context) {
        return Directionality(
          textDirection: isArabic ? ui.TextDirection.rtl : ui.TextDirection.ltr,
          child: AlertDialog(
            backgroundColor: cardColor,
            title: Text(
              tr(
                'Update ${activityTitle(item.title)}',
                'تحديث ${activityTitle(item.title)}',
              ),
              style: TextStyle(color: textColor),
            ),
            content: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              style: TextStyle(color: textColor),
              decoration: InputDecoration(
                labelText: unitName(item.unit),
                labelStyle: TextStyle(color: subTextColor),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: Theme.of(context).dividerColor,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide:
                      const BorderSide(color: Color(0xFF87CEEB), width: 2),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(tr('Cancel', 'إلغاء')),
              ),
              TextButton(
                onPressed: () async {
                  final newValue = double.tryParse(controller.text.trim());

                  if (newValue == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          tr(
                            'Please enter a valid number',
                            'يرجى إدخال رقم صحيح',
                          ),
                        ),
                      ),
                    );
                    return;
                  }

                  setState(() {
                    final updatedActivities =
                        List<HealthActivity>.from(_activities);

                    updatedActivities[index] = HealthActivity(
                      title: item.title,
                      value: newValue,
                      goal: item.goal,
                      unit: item.unit,
                      emoji: item.emoji,
                      color: item.color,
                    );

                    _activities = updatedActivities;
                  });

                  Navigator.pop(context);

                  try {
                    await _saveHealthSnapshotToFirebase(
                      updateType: 'activity',
                      message: tr(
                        '${activityTitle(item.title)} updated to ${newValue.toStringAsFixed(newValue % 1 == 0 ? 0 : 1)} ${unitName(item.unit)}',
                        'تم تحديث ${activityTitle(item.title)} إلى ${newValue.toStringAsFixed(newValue % 1 == 0 ? 0 : 1)} ${unitName(item.unit)}',
                      ),
                    );

                    if (!mounted) return;

                    await _showSaveChangesPopup(
                      tr(
                        '${activityTitle(item.title)} updated successfully and sent to companion.',
                        'تم تحديث ${activityTitle(item.title)} بنجاح وإرساله للمرافق.',
                      ),
                    );
                  } catch (e) {
                    if (!mounted) return;

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          tr(
                            'Error saving activity: $e',
                            'حدث خطأ أثناء حفظ النشاط: $e',
                          ),
                        ),
                      ),
                    );
                  }
                },
                child: Text(tr('Save', 'حفظ')),
              ),
            ],
          ),
        );
      },
    );
  }

  void _openWatchQrScanner() {
    VoiceAccessibilityService.instance.stopAll();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WatchQrScannerPage(
          onScanned: () {
            _simulateWatchSync();
          },
        ),
      ),
    );
  }

  Future<void> _simulateWatchSync() async {
    if (!_isSelectedDateToday) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr(
              'You can connect or update the watch only for today.',
              'يمكن ربط أو تحديث الساعة لليوم فقط.',
            ),
          ),
        ),
      );
      return;
    }

    setState(() {
      _watchConnected = true;

      _activities = [
        const HealthActivity(
          title: 'Heart',
          value: 82,
          goal: 120,
          unit: 'BPM',
          emoji: '❤️',
          color: Color(0xFFFFADAD),
        ),
        const HealthActivity(
          title: 'Sleep',
          value: 7.5,
          goal: 8,
          unit: 'Hours',
          emoji: '😴',
          color: Color(0xFF9BF6FF),
        ),
        const HealthActivity(
          title: 'Walk',
          value: 6350,
          goal: 8000,
          unit: 'Steps',
          emoji: '👟',
          color: Color(0xFFFFC6FF),
        ),
        const HealthActivity(
          title: 'Exercise',
          value: 45,
          goal: 60,
          unit: 'Minutes',
          emoji: '🏋️',
          color: Color(0xFFFDFFB6),
        ),
        const HealthActivity(
          title: 'Water',
          value: 6,
          goal: 8,
          unit: 'Cups',
          emoji: '💧',
          color: Color(0xFFCAFFBF),
        ),
      ];
    });

    try {
      await _saveHealthSnapshotToFirebase(
        updateType: 'watch_sync',
        message: tr(
          'Smart watch connected and activity updated automatically',
          'تم ربط الساعة وتحديث النشاط تلقائياً',
        ),
      );

      if (!mounted) return;

      await _showSaveChangesPopup(
        tr(
          'Smart watch connected, activity updated, and sent to companion',
          'تم ربط الساعة وتحديث النشاط وإرساله للمرافق',
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr('Error saving watch data: $e',
                'حدث خطأ أثناء حفظ بيانات الساعة: $e'),
          ),
        ),
      );
    }
  }

  Widget _buildActivityModeCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: _shadow(),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment:
            isArabic ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Text(
            tr('Activity Tracking Method', 'طريقة تتبع النشاط'),
            style: TextStyle(
              color: textColor,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _watchConnected
                ? tr(
                    'Smart watch is connected. Data updates automatically.',
                    'الساعة الذكية مربوطة. البيانات تتحدث تلقائياً.',
                  )
                : tr(
                    'You can update activity manually or connect a smart watch using QR code.',
                    'يمكنك تحديث النشاط يدوياً أو ربط ساعة ذكية باستخدام رمز QR.',
                  ),
            textAlign: isArabic ? TextAlign.right : TextAlign.left,
            style: TextStyle(
              color: subTextColor,
              fontSize: 14,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final bool small = constraints.maxWidth < 350;

              if (small) {
                return Column(
                  children: [
                    _manualButton(),
                    const SizedBox(height: 10),
                    _scanButton(),
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: _manualButton()),
                  const SizedBox(width: 10),
                  Expanded(child: _scanButton()),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _manualButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _isSelectedDateToday
            ? () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      tr(
                        'Tap any activity card below to update it manually',
                        'اضغط على أي بطاقة نشاط بالأسفل لتحديثها يدوياً',
                      ),
                    ),
                  ),
                );
              }
            : null,
        icon: const Icon(Icons.edit_rounded),
        label: Text(
          tr('Manual', 'يدوي'),
          overflow: TextOverflow.ellipsis,
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF87CEEB),
          side: const BorderSide(color: Color(0xFF87CEEB)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
    );
  }

  Widget _scanButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isSelectedDateToday ? _openWatchQrScanner : null,
        icon: Icon(
          _watchConnected ? Icons.watch_rounded : Icons.qr_code_scanner_rounded,
        ),
        label: Text(
          _watchConnected ? tr('Connected', 'مربوطة') : tr('Scan QR', 'مسح QR'),
          overflow: TextOverflow.ellipsis,
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF87CEEB),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
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
        MaterialPageRoute(builder: (context) => const DashboardPage()),
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
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(40)),
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
                  tr('Health', 'الصحة'),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
              ),
              const SizedBox(width: 48),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActivityDateSelector() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(22),
        boxShadow: _shadow(),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.calendar_month_rounded,
            color: Color(0xFF87CEEB),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  isArabic ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Text(
                  tr('Activity Date', 'تاريخ النشاط'),
                  style: TextStyle(
                    color: subTextColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _selectedDateTitle(),
                  textAlign: isArabic ? TextAlign.right : TextAlign.left,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: _pickActivityDate,
            icon: const Icon(Icons.history_rounded),
            label: Text(
              tr('View Days', 'الأيام السابقة'),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  String _activityStatusText(HealthActivity item) {
    switch (item.title) {
      case 'Heart':
        if (item.value == 0) {
          return tr('Not updated yet', 'لم يتم التحديث بعد');
        }

        if (item.value < 60) {
          return tr('Low Heart Rate', 'نبض منخفض');
        }

        if (item.value <= 100) {
          return tr('Normal Heart Rate', 'نبض طبيعي');
        }

        if (item.value <= 130) {
          return tr('High Heart Rate', 'نبض مرتفع');
        }

        return tr('Critical Heart Rate', 'نبض خطير');

      case 'Sleep':
        if (item.value == 0) {
          return tr('Not updated yet', 'لم يتم التحديث بعد');
        }

        if (item.value < 5) {
          return tr('Sleep Deprived', 'حرمان من النوم');
        }

        if (item.value < 7) {
          return tr('Low Sleep', 'نوم قليل');
        }

        if (item.value < 9) {
          return tr('Good Sleep', 'نوم جيد');
        }

        if (item.value <= 11) {
          return tr('Excellent Sleep', 'نوم ممتاز');
        }

        return tr('Oversleeping', 'نوم زائد');

      case 'Walk':
        if (item.value == 0) {
          return tr('Start Walking', 'ابدأ بالمشي');
        }

        if (item.value < 3000) {
          return tr('Keep Moving', 'استمر بالحركة');
        }

        if (item.value < item.goal) {
          return tr('Good Progress', 'تقدم جيد');
        }

        return tr('Goal Achieved', 'تم تحقيق الهدف');

      case 'Exercise':
        if (item.value == 0) {
          return tr('No Exercise Yet', 'لا توجد رياضة بعد');
        }

        if (item.value < 20) {
          return tr('Need More Exercise', 'تحتاج رياضة أكثر');
        }

        if (item.value < item.goal) {
          return tr('Good Exercise', 'رياضة جيدة');
        }

        return tr('Excellent Activity', 'نشاط ممتاز');

      case 'Water':
        if (item.value == 0) {
          return tr('Drink Water', 'اشرب ماء');
        }

        if (item.value < 4) {
          return tr('Dehydrated', 'جفاف');
        }

        if (item.value < item.goal) {
          return tr('Drink More Water', 'اشرب ماء أكثر');
        }

        if (item.value <= 10) {
          return tr('Well Hydrated', 'ترطيب ممتاز');
        }

        return tr('Overhydrated', 'شرب ماء زائد');

      default:
        return tr('Updated', 'تم التحديث');
    }
  }

  Widget _buildProgressActivity(HealthActivity item) {
    final int index = _activities.indexOf(item);
    final double progress = (item.value / item.goal).clamp(0.0, 1.0);

    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: () => _openManualActivityDialog(index),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: item.color,
          borderRadius: BorderRadius.circular(24),
          boxShadow: _shadow(),
        ),
        child: Row(
          children: [
            Text(item.emoji, style: const TextStyle(fontSize: 36)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: isArabic
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          activityTitle(item.title),
                          textAlign:
                              isArabic ? TextAlign.right : TextAlign.left,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.black,
                          ),
                        ),
                      ),
                      if (_isSelectedDateToday)
                        const Icon(
                          Icons.edit_rounded,
                          size: 18,
                          color: Colors.black54,
                        )
                      else
                        const Icon(
                          Icons.visibility_rounded,
                          size: 18,
                          color: Colors.black54,
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: progress,
                    minHeight: 9,
                    backgroundColor: Colors.white.withOpacity(0.65),
                    valueColor: const AlwaysStoppedAnimation(Color(0xFF87CEEB)),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${item.value.toStringAsFixed(item.value % 1 == 0 ? 0 : 1)} / ${item.goal.toInt()} ${unitName(item.unit)}',
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.black87,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${tr('Status', 'الحالة')}: ${_activityStatusText(item)}',
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.black87,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAIButton() {
    return SizedBox(
      width: 82,
      height: 82,
      child: FloatingActionButton(
        onPressed: _openAIQuestions,
        backgroundColor: Colors.transparent,
        elevation: 0,
        shape: const CircleBorder(),
        child: Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            color: const Color(0xFF87CEEB),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.18),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Center(
            child: Text('🤖', style: TextStyle(fontSize: 38)),
          ),
        ),
      ),
    );
  }

  Widget _buildHealthTipsFromFirebase() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('healthTips')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(22),
              boxShadow: _shadow(),
            ),
            child: Text(
              tr('Could not load health tips.', 'تعذر تحميل النصائح الصحية.'),
              style: TextStyle(fontSize: 15, color: textColor),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(color: Color(0xFF87CEEB)),
            ),
          );
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(24),
              boxShadow: _shadow(),
            ),
            child: Text(
              tr(
                'No health tips yet. When a volunteer writes a tip, it will appear here.',
                'لا توجد نصائح صحية بعد. عندما يكتب المتطوع نصيحة، ستظهر هنا.',
              ),
              style: TextStyle(
                fontSize: 15,
                color: subTextColor,
                height: 1.4,
              ),
            ),
          );
        }

        return Column(
          children: docs.map((doc) {
            final data = doc.data();

            final tip = HealthTip(
              id: doc.id,
              personName: (data['volunteerName'] ??
                      data['personName'] ??
                      data['name'] ??
                      'Volunteer')
                  .toString(),
              personType: (data['personType'] ?? 'Volunteer').toString(),
              title: (data['title'] ?? 'Health Tip').toString(),
              shortTip: (data['shortTip'] ??
                      data['description'] ??
                      data['tip'] ??
                      'No details available.')
                  .toString(),
              fullTip: (data['fullTip'] ??
                      data['description'] ??
                      data['tip'] ??
                      data['shortTip'] ??
                      'No details available.')
                  .toString(),
              category: (data['category'] ?? 'Health').toString(),
              emoji: (data['emoji'] ?? '💙').toString(),
              imageUrl: (data['imageUrl'] ?? '').toString(),
              createdAt: data['createdAt'],
            );

            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: InkWell(
                borderRadius: BorderRadius.circular(28),
                onTap: () => _openTipDetails(tip),
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: lightCardColor,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: _shadow(),
                    border: Border.all(
                        color: Theme.of(context).dividerColor, width: 1),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (tip.imageUrl.isNotEmpty) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Image.network(
                            tip.imageUrl,
                            width: double.infinity,
                            height: 170,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                width: double.infinity,
                                height: 120,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: Center(
                                  child: Text(
                                    tr('Image could not load',
                                        'تعذر تحميل الصورة'),
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: subTextColor),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: isArabic
                                  ? CrossAxisAlignment.end
                                  : CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 34,
                                      height: 34,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.volunteer_activism,
                                        size: 20,
                                        color: textColor,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        '${tip.personName} • ${isArabic && tip.personType == 'Volunteer' ? 'متطوع' : tip.personType}',
                                        textAlign: isArabic
                                            ? TextAlign.right
                                            : TextAlign.left,
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: textColor,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  tip.title,
                                  textAlign: isArabic
                                      ? TextAlign.right
                                      : TextAlign.left,
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 2,
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    color: textColor,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  tip.shortTip,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: isArabic
                                      ? TextAlign.right
                                      : TextAlign.left,
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: subTextColor,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  tip.category,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: const Color(0xFF5D6D7E),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(tip.emoji, style: const TextStyle(fontSize: 44)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
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
        'Health screen with mood selection, daily activity tracking, health monitoring cards, health tips, and AI Health Check. The AI Health Check asks health and mood questions step by step, including mood, daily activity, energy level, physical condition, sleep quality, and support needs. You can move between questions using previous and next buttons, then finish the AI Health Check to receive a result based on your answers. Home, profile, and settings options are available.',
        'صفحة الصحة تحتوي على اختيار المزاج، وتتبع النشاط اليومي، وبطاقات مراقبة الصحة، والنصائح الصحية، وفحص الصحة بالذكاء الاصطناعي. فحص الصحة بالذكاء الاصطناعي يسأل أسئلة الصحة والمزاج خطوة بخطوة، وتشمل المزاج، والنشاط اليومي، ومستوى الطاقة، والحالة الجسدية، وجودة النوم، واحتياجات الدعم. يمكنك الانتقال بين الأسئلة باستخدام أزرار السابق والتالي، ثم إنهاء فحص الصحة بالذكاء الاصطناعي للحصول على نتيجة بناءً على إجاباتك. تتوفر أيضًا خيارات الرئيسية والملف الشخصي والإعدادات.',
      ),
      routes: {
        'dashboard': (context) => const DashboardPage(),
        'health': (context) => const HealthPage(),
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

  @override
  Widget build(BuildContext context) {
    final activitiesToShow =
        _showAllActivities ? _activities : _activities.take(3).toList();

    return Directionality(
      textDirection: isArabic ? ui.TextDirection.rtl : ui.TextDirection.ltr,
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Scaffold(
          backgroundColor: backgroundColor,
          floatingActionButton: _buildAIButton(),
          body: Stack(
            children: [
              SafeArea(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    _buildHeader(),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                      child: Column(
                        crossAxisAlignment: isArabic
                            ? CrossAxisAlignment.end
                            : CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${_getGreeting()}, $_userName',
                            textAlign:
                                isArabic ? TextAlign.right : TextAlign.left,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w600,
                              color: textColor,
                            ),
                          ),
                          const SizedBox(height: 28),
                          Text(
                            tr(
                              'How are you feeling today?',
                              'كيف تشعر اليوم؟',
                            ),
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: textColor,
                            ),
                          ),
                          const SizedBox(height: 12),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: _moods.map((mood) {
                                final bool isSelected =
                                    _selectedMood == mood.label;

                                return Padding(
                                  padding: const EdgeInsets.only(right: 16),
                                  child: GestureDetector(
                                    onTap: () => _saveMoodForCompanion(mood),
                                    child: SizedBox(
                                      width: 76,
                                      child: Column(
                                        children: [
                                          Container(
                                            width: 68,
                                            height: 68,
                                            decoration: BoxDecoration(
                                              color: mood.color,
                                              borderRadius:
                                                  BorderRadius.circular(18),
                                              border: Border.all(
                                                color: isSelected
                                                    ? const Color(0xFF87CEEB)
                                                    : Colors.transparent,
                                                width: 2,
                                              ),
                                            ),
                                            child: Center(
                                              child: Text(
                                                mood.emoji,
                                                style: const TextStyle(
                                                    fontSize: 30),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            moodName(mood.label),
                                            textAlign: TextAlign.center,
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 1,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: textColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                          const SizedBox(height: 32),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _isSelectedDateToday
                                      ? tr('Today\'s Activity', 'نشاط اليوم')
                                      : tr('Previous Activity', 'نشاط سابق'),
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600,
                                    color: textColor,
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: () {
                                  setState(() {
                                    _showAllActivities = !_showAllActivities;
                                  });
                                },
                                child: Text(
                                  _showAllActivities
                                      ? tr('See less', 'عرض أقل')
                                      : tr('See more', 'عرض المزيد'),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    color: Color(0xFF87CEEB),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _buildActivityDateSelector(),
                          if (_isSelectedDateToday) _buildActivityModeCard(),
                          if (_isLoadingDailyHealth)
                            const Padding(
                              padding: EdgeInsets.all(24),
                              child: Center(
                                child: CircularProgressIndicator(
                                  color: Color(0xFF87CEEB),
                                ),
                              ),
                            )
                          else
                            ...activitiesToShow.map(_buildProgressActivity),
                          const SizedBox(height: 6),
                          Text(
                            tr('Health Tips', 'نصائح صحية'),
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: textColor,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildHealthTipsFromFirebase(),
                          const SizedBox(height: 90),
                        ],
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
  }
}

class WatchQrScannerPage extends StatefulWidget {
  final VoidCallback onScanned;

  const WatchQrScannerPage({
    super.key,
    required this.onScanned,
  });

  @override
  State<WatchQrScannerPage> createState() => _WatchQrScannerPageState();
}

class _WatchQrScannerPageState extends State<WatchQrScannerPage> {
  bool _isScanned = false;

  bool get isArabic => AppSettingsStore.instance.isArabic;

  Color get backgroundColor => Theme.of(context).scaffoldBackgroundColor;

  Color get textColor =>
      Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;

  Color get subTextColor =>
      Theme.of(context).textTheme.bodyMedium?.color ?? Colors.black54;

  String tr(String en, String ar) => isArabic ? ar : en;

  void _goBack() {
    VoiceAccessibilityService.instance.stopAll();

    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HealthPage()),
      );
    }
  }

  void _handleScan(BarcodeCapture capture) {
    if (_isScanned) return;
    if (capture.barcodes.isEmpty) return;

    final code = capture.barcodes.first.rawValue;
    if (code == null || code.trim().isEmpty) return;

    setState(() {
      _isScanned = true;
    });

    widget.onScanned();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          tr(
            'QR scanned successfully. Smart watch connected.',
            'تم مسح رمز QR بنجاح وربط الساعة الذكية.',
          ),
        ),
      ),
    );

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: isArabic ? ui.TextDirection.rtl : ui.TextDirection.ltr,
      child: Scaffold(
        backgroundColor: backgroundColor,
        appBar: AppBar(
          backgroundColor: const Color(0xFF87CEEB),
          elevation: 0,
          foregroundColor: Colors.white,
          leading: IconButton(
            onPressed: _goBack,
            icon: Icon(
              isArabic ? Icons.arrow_forward : Icons.arrow_back,
              color: Colors.white,
            ),
          ),
          title: Text(
            tr('Scan Watch QR', 'مسح QR الساعة'),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        body: Column(
          children: [
            Expanded(
              flex: 4,
              child: MobileScanner(
                onDetect: _handleScan,
              ),
            ),
            Expanded(
              flex: 2,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(22),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.qr_code_scanner_rounded,
                      size: 46,
                      color: Color(0xFF87CEEB),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      tr(
                        'Point the camera at the watch QR code to connect activity data automatically.',
                        'وجّه الكاميرا إلى رمز QR الخاص بالساعة لربط بيانات النشاط تلقائياً.',
                      ),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 16,
                        height: 1.4,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      tr(
                        'For demo, any QR code will connect the watch.',
                        'للديمو، أي رمز QR سيقوم بربط الساعة.',
                      ),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: subTextColor,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class HealthMood {
  final String label;
  final String emoji;
  final Color color;

  const HealthMood({
    required this.label,
    required this.emoji,
    required this.color,
  });
}

class HealthActivity {
  final String title;
  final double value;
  final double goal;
  final String unit;
  final String emoji;
  final Color color;

  const HealthActivity({
    required this.title,
    required this.value,
    required this.goal,
    required this.unit,
    required this.emoji,
    required this.color,
  });
}

class HealthTip {
  final String id;
  final String personName;
  final String personType;
  final String title;
  final String shortTip;
  final String fullTip;
  final String category;
  final String emoji;
  final String imageUrl;
  final dynamic createdAt;

  const HealthTip({
    required this.id,
    required this.personName,
    required this.personType,
    required this.title,
    required this.shortTip,
    required this.fullTip,
    required this.category,
    required this.emoji,
    required this.imageUrl,
    required this.createdAt,
  });
}

class HealthTipDetailsPage extends StatelessWidget {
  final HealthTip tip;

  const HealthTipDetailsPage({
    super.key,
    required this.tip,
  });

  bool get isArabic => AppSettingsStore.instance.isArabic;

  String tr(String en, String ar) => isArabic ? ar : en;

  String _formatDate(dynamic createdAt) {
    try {
      if (createdAt is Timestamp) {
        final date = createdAt.toDate();
        return '${date.day}/${date.month}/${date.year}';
      }
      return '';
    } catch (_) {
      return '';
    }
  }

  void _goBack(BuildContext context) {
    VoiceAccessibilityService.instance.stopAll();

    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HealthPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateText = _formatDate(tip.createdAt);

    final Color backgroundColor = Theme.of(context).scaffoldBackgroundColor;

    final Color cardColor = const Color(0xFFD9F3FF);

    final Color textColor =
        Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;

    final Color subTextColor = const Color(0xFF5D6D7E);

    return Directionality(
      textDirection: isArabic ? ui.TextDirection.rtl : ui.TextDirection.ltr,
      child: Scaffold(
        backgroundColor: backgroundColor,
        appBar: AppBar(
          backgroundColor: const Color(0xFF87CEEB),
          elevation: 0,
          foregroundColor: Colors.white,
          leading: IconButton(
            onPressed: () => _goBack(context),
            icon: Icon(
              isArabic ? Icons.arrow_forward : Icons.arrow_back,
              size: 28,
              color: Colors.white,
            ),
          ),
          title: Text(
            tr('Tip Details', 'تفاصيل النصيحة'),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Theme.of(context).dividerColor,
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment:
                  isArabic ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (tip.imageUrl.isNotEmpty) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.network(
                      tip.imageUrl,
                      width: double.infinity,
                      height: 220,
                      fit: BoxFit.cover,
                      errorBuilder: (
                        context,
                        error,
                        stackTrace,
                      ) {
                        return Container(
                          width: double.infinity,
                          height: 140,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Center(
                            child: Text(
                              tr(
                                'Image could not load',
                                'تعذر تحميل الصورة',
                              ),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: subTextColor,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                Text(
                  tip.emoji,
                  style: const TextStyle(fontSize: 54),
                ),
                const SizedBox(height: 12),
                Text(
                  '${tip.personName} • ${isArabic && tip.personType == 'Volunteer' ? 'متطوع' : tip.personType}',
                  textAlign: isArabic ? TextAlign.right : TextAlign.left,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
                if (dateText.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    dateText,
                    style: TextStyle(
                      fontSize: 13,
                      color: subTextColor,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Text(
                  tip.title,
                  textAlign: isArabic ? TextAlign.right : TextAlign.left,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  tip.category,
                  style: TextStyle(
                    fontSize: 15,
                    color: subTextColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  tip.fullTip,
                  textAlign: isArabic ? TextAlign.right : TextAlign.left,
                  style: TextStyle(
                    fontSize: 17,
                    color: subTextColor,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AIQuestionsPage extends StatefulWidget {
  const AIQuestionsPage({super.key});

  @override
  State<AIQuestionsPage> createState() => _AIQuestionsPageState();
}

class _AIQuestionsPageState extends State<AIQuestionsPage> {
  int _currentIndex = 0;
  final List<String?> _answers = List.filled(6, null);
  int _selectedMoodLevel = 2;

  bool get isArabic => AppSettingsStore.instance.isArabic;

  Color get backgroundColor => Theme.of(context).scaffoldBackgroundColor;

  Color get cardColor => Theme.of(context).cardColor;

  Color get textColor =>
      Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;

  Color get subTextColor => false ? Colors.white70 : const Color(0xFF5D6D7E);

  String tr(String en, String ar) => isArabic ? ar : en;

  late final List<AIQuestion> _questions = [
    AIQuestion(
      title: tr('How is your mood?', 'كيف مزاجك؟'),
      subtitle: tr(
        'Choose the emoji that best describes your mood today.',
        'اختر الإيموجي الذي يصف مزاجك اليوم.',
      ),
      type: AIQuestionType.emojiMood,
      options: const ['😒', '🙂', '😜'],
    ),
    AIQuestion(
      title: tr('How was your day?', 'كيف كان يومك؟'),
      subtitle: tr(
        'Did you experience anything out of the ordinary?',
        'هل حدث معك شيء غير معتاد؟',
      ),
      type: AIQuestionType.options,
      options: [
        tr('Incredible 😇', 'رائع جداً 😇'),
        tr('Great 😃', 'ممتاز 😃'),
        tr('Good 🙂', 'جيد 🙂'),
        tr('Okay 🙁', 'عادي 🙁'),
        tr('Really Bad 😞', 'سيء جداً 😞'),
      ],
    ),
    AIQuestion(
      title: tr('How is your energy level right now?', 'كيف مستوى طاقتك الآن؟'),
      subtitle: tr(
        'Did you notice anything affecting your energy today?',
        'هل لاحظت شيئاً أثر على طاقتك اليوم؟',
      ),
      type: AIQuestionType.options,
      options: [
        tr('High ⚡', 'عالية ⚡'),
        tr('Medium 🙂', 'متوسطة 🙂'),
        tr('Low 😴', 'منخفضة 😴'),
        tr('Exhausted 🛌', 'مرهق 🛌'),
      ],
    ),
    AIQuestion(
      title: tr('How are you feeling physically?', 'كيف تشعر جسدياً؟'),
      subtitle: tr(
        'Did you experience any unusual physical symptoms?',
        'هل شعرت بأي أعراض جسدية غير معتادة؟',
      ),
      type: AIQuestionType.options,
      options: [
        tr('Excellent 💪', 'ممتاز 💪'),
        tr('Good 🙂', 'جيد 🙂'),
        tr('Okay 😐', 'عادي 😐'),
        tr('Not well 🤒', 'لست بخير 🤒'),
      ],
    ),
    AIQuestion(
      title:
          tr('Did you sleep well last night?', 'هل نمت جيداً الليلة الماضية؟'),
      subtitle: tr(
        'Did anything disturb your sleep or make it different than usual?',
        'هل كان هناك شيء أزعج نومك أو جعله مختلفاً عن المعتاد؟',
      ),
      type: AIQuestionType.options,
      options: [
        tr('Excellent 🌙', 'ممتاز 🌙'),
        tr('Good 🙂', 'جيد 🙂'),
        tr('Okay 😐', 'عادي 😐'),
        tr('Poor 😴', 'ضعيف 😴'),
      ],
    ),
    AIQuestion(
      title: tr(
        'Do you need any help or support today?',
        'هل تحتاج إلى مساعدة أو دعم اليوم؟',
      ),
      subtitle: tr(
        'Is there anything specific you need help with today?',
        'هل يوجد شيء محدد تحتاج مساعدة فيه اليوم؟',
      ),
      type: AIQuestionType.options,
      options: [
        tr('Yes ✅', 'نعم ✅'),
        tr('Maybe 🤔', 'ربما 🤔'),
        tr('No ❌', 'لا ❌'),
      ],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _answers[0] = tr('Good 🙂', 'جيد 🙂');
    AppSettingsStore.instance.addListener(_onSettingsChanged);
  }

  void _onSettingsChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    AppSettingsStore.instance.removeListener(_onSettingsChanged);
    super.dispose();
  }

  void _nextQuestion() {
    final AIQuestion question = _questions[_currentIndex];

    if (question.type == AIQuestionType.emojiMood) {
      if (_selectedMoodLevel == 1) {
        _answers[_currentIndex] = tr('Bad 😒', 'سيء 😒');
      } else if (_selectedMoodLevel == 2) {
        _answers[_currentIndex] = tr('Good 🙂', 'جيد 🙂');
      } else {
        _answers[_currentIndex] = tr('Very Happy 😜', 'سعيد جداً 😜');
      }
    }

    if (question.type == AIQuestionType.options &&
        _answers[_currentIndex] == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('Please choose an answer', 'يرجى اختيار إجابة')),
        ),
      );
      return;
    }

    if (_currentIndex < _questions.length - 1) {
      setState(() {
        _currentIndex++;
      });
    } else {
      _showResult();
    }
  }

  void _previousQuestion() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
      });
    } else {
      _goBack();
    }
  }

  Future<void> _saveAIReport(String resultMessage) async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) return;

      await FirebaseFirestore.instance.collection('health_ai_reports').add({
        'userId': user.uid,
        'moodAnswer': _answers[0] ?? '',
        'dayAnswer': _answers[1] ?? '',
        'energyAnswer': _answers[2] ?? '',
        'physicalAnswer': _answers[3] ?? '',
        'sleepAnswer': _answers[4] ?? '',
        'helpAnswer': _answers[5] ?? '',
        'resultMessage': resultMessage,
        'createdAt': FieldValue.serverTimestamp(),
        'reportType': 'daily',
      });
    } catch (e) {
      debugPrint('Error saving AI report: $e');
    }
  }

  String _buildAiHealthPrompt() {
    return '''
You are Human Touch AI Health Assistant inside an assistive mobile application.

The user answered a short daily health check.
Analyze the answers and generate a personalized result based ONLY on these answers.

Important rules:
- Reply in ${isArabic ? 'Arabic' : 'English'}.
- Be warm, clear, short, and supportive.
- Do not use fixed generic sentences.
- Do not diagnose diseases.
- Do not pretend to be a doctor.
- Give practical safe advice based on the answers.
- If the answers show serious discomfort, low energy, poor sleep, or needing help, recommend contacting the companion or using emergency help if urgent.
- Keep the result between 4 and 6 short lines.

User answers:
1. Mood: ${_answers[0] ?? 'Not answered'}
2. Day: ${_answers[1] ?? 'Not answered'}
3. Energy level: ${_answers[2] ?? 'Not answered'}
4. Physical feeling: ${_answers[3] ?? 'Not answered'}
5. Sleep quality: ${_answers[4] ?? 'Not answered'}
6. Support needed: ${_answers[5] ?? 'Not answered'}

Write the AI health result now.
''';
  }

  Future<String> _generateAiHealthResult() async {
    try {
      final prompt = _buildAiHealthPrompt();

      final aiReply = await GeminiService.generateReply(
        userMessage: prompt,
        isArabic: isArabic,
        selectedMood: _answers[0] ?? '',
        selectedPlace: 'Health AI',
        conversationHistory: [
          {
            'sender': 'user',
            'text': prompt,
          },
        ],
        aiType: 'health',
      );

      if (aiReply.trim().isEmpty || aiReply.startsWith('AI Error:')) {
        return tr(
          'AI could not analyze your answers right now. Please try again.',
          'لم يتمكن الذكاء الاصطناعي من تحليل إجاباتك الآن. حاول مرة أخرى.',
        );
      }

      return aiReply.trim();
    } catch (e) {
      debugPrint('AI Health Result Error: $e');

      return tr(
        'AI is currently unavailable. Please try again.',
        'الذكاء الاصطناعي غير متوفر حالياً. حاول مرة أخرى.',
      );
    }
  }

  Future<void> _showResult() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Directionality(
          textDirection: isArabic ? ui.TextDirection.rtl : ui.TextDirection.ltr,
          child: AlertDialog(
            backgroundColor: cardColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(color: Color(0xFF87CEEB)),
                const SizedBox(height: 18),
                Text(
                  tr(
                    'Analyzing your answers...',
                    'جاري تحليل إجاباتك...',
                  ),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    final resultMessage = await _generateAiHealthResult();

    await _saveAIReport(resultMessage);

    if (!mounted) return;

    Navigator.pop(context);

    showDialog(
      context: context,
      builder: (context) {
        return Directionality(
          textDirection: isArabic ? ui.TextDirection.rtl : ui.TextDirection.ltr,
          child: AlertDialog(
            backgroundColor: cardColor,
            title: Center(
              child: Text(
                tr('AI Result', 'نتيجة الذكاء الاصطناعي'),
                style: TextStyle(color: textColor),
              ),
            ),
            content: SingleChildScrollView(
              child: Text(
                resultMessage,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  height: 1.4,
                  color: subTextColor,
                ),
              ),
            ),
            actionsAlignment: MainAxisAlignment.center,
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context);
                },
                child: Text(tr('Done', 'تم')),
              ),
            ],
          ),
        );
      },
    );
  }

  void _needHelp() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const CompanionChatPage(),
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
        MaterialPageRoute(builder: (context) => const HealthPage()),
      );
    }
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
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(40)),
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
                  tr('AI Health Check', 'الفحص الصحي الذكي'),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
              ),
              const SizedBox(width: 48),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final AIQuestion question = _questions[_currentIndex];
    final double progress = (_currentIndex + 1) / _questions.length;

    return Directionality(
      textDirection: isArabic ? ui.TextDirection.rtl : ui.TextDirection.ltr,
      child: Scaffold(
        backgroundColor: backgroundColor,
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(18, 10, 18, 25),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: MediaQuery.of(context).size.height * 0.72,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          tr(
                            'Question ${_currentIndex + 1}/6',
                            'السؤال ${_currentIndex + 1}/6',
                          ),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15,
                            color: subTextColor,
                          ),
                        ),
                        const SizedBox(height: 10),
                        LinearProgressIndicator(
                          value: progress,
                          minHeight: 8,
                          backgroundColor: false
                              ? const Color(0xFF2A2A2A)
                              : const Color(0xFFE2E7EC),
                          valueColor: const AlwaysStoppedAnimation(
                            Color(0xFF87CEEB),
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        const SizedBox(height: 45),
                        Text(
                          question.title,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          question.subtitle,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: subTextColor,
                          ),
                        ),
                        const SizedBox(height: 30),
                        if (question.type == AIQuestionType.emojiMood)
                          _buildMoodEmojiSelector(question)
                        else
                          _buildOptions(question),
                        const SizedBox(height: 45),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final bool small = constraints.maxWidth < 360;

                            if (small) {
                              return Column(
                                children: [
                                  _whiteButton(
                                    text: tr(
                                      'Previous Question',
                                      'السؤال السابق',
                                    ),
                                    onTap: _previousQuestion,
                                  ),
                                  const SizedBox(height: 10),
                                  _blueButton(
                                    text: _currentIndex == _questions.length - 1
                                        ? tr('Finish', 'إنهاء')
                                        : tr(
                                            'Next Question',
                                            'السؤال التالي',
                                          ),
                                    onTap: _nextQuestion,
                                  ),
                                ],
                              );
                            }

                            return Row(
                              children: [
                                Expanded(
                                  child: _whiteButton(
                                    text: tr(
                                      'Previous Question',
                                      'السؤال السابق',
                                    ),
                                    onTap: _previousQuestion,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _blueButton(
                                    text: _currentIndex == _questions.length - 1
                                        ? tr('Finish', 'إنهاء')
                                        : tr(
                                            'Next Question',
                                            'السؤال التالي',
                                          ),
                                    onTap: _nextQuestion,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        _blueButton(
                          text: tr('Need Help?', 'تحتاج مساعدة؟'),
                          onTap: _needHelp,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMoodEmojiSelector(AIQuestion question) {
    final double moodProgress = _selectedMoodLevel / 3;

    return Column(
      children: [
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 18,
          runSpacing: 16,
          children: List.generate(question.options.length, (index) {
            final int level = index + 1;
            final bool selected = _selectedMoodLevel == level;

            return GestureDetector(
              onTap: () {
                setState(() {
                  _selectedMoodLevel = level;

                  if (level == 1) {
                    _answers[0] = tr('Bad 😒', 'سيء 😒');
                  } else if (level == 2) {
                    _answers[0] = tr('Good 🙂', 'جيد 🙂');
                  } else {
                    _answers[0] = tr('Very Happy 😜', 'سعيد جداً 😜');
                  }
                });
              },
              child: Column(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: selected ? 76 : 64,
                    height: selected ? 76 : 64,
                    decoration: BoxDecoration(
                      color: selected
                          ? const Color(0xFFD9F3FF)
                          : false
                              ? const Color(0xFF2A2A2A)
                              : Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: selected
                            ? const Color(0xFF87CEEB)
                            : false
                                ? Colors.white12
                                : const Color(0xFFE2E7EC),
                        width: selected ? 3 : 1,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        question.options[index],
                        style: TextStyle(fontSize: selected ? 42 : 36),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: selected ? 42 : 0,
                    height: 5,
                    decoration: BoxDecoration(
                      color: const Color(0xFF87CEEB),
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ],
              ),
            );
          }),
        ),
        const SizedBox(height: 26),
        LinearProgressIndicator(
          value: moodProgress,
          minHeight: 10,
          backgroundColor:
              false ? const Color(0xFF2A2A2A) : const Color(0xFFE2E7EC),
          valueColor: const AlwaysStoppedAnimation(Color(0xFF87CEEB)),
          borderRadius: BorderRadius.circular(20),
        ),
      ],
    );
  }

  Widget _buildOptions(AIQuestion question) {
    return Column(
      children: question.options.map((option) {
        final bool selected = _answers[_currentIndex] == option;

        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () {
              setState(() {
                _answers[_currentIndex] = option;
              });
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
              decoration: BoxDecoration(
                color: selected ? const Color(0xFFD9F3FF) : cardColor,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: selected
                      ? const Color(0xFF87CEEB)
                      : false
                          ? Colors.white12
                          : const Color(0xFFE2E7EC),
                  width: 2,
                ),
              ),
              child: Text(
                option,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 17,
                  color: selected ? const Color(0xFF5D6D7E) : subTextColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _blueButton({required String text, required VoidCallback onTap}) {
    return SizedBox(
      height: 50,
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF87CEEB),
          foregroundColor: Colors.white,
          elevation: 4,
          shadowColor: Colors.black26,
          minimumSize: const Size(0, 50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _whiteButton({required String text, required VoidCallback onTap}) {
    return SizedBox(
      height: 50,
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF87CEEB),
          side: const BorderSide(color: Color(0xFF87CEEB), width: 2),
          minimumSize: const Size(0, 50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

class CompanionChatPage extends StatefulWidget {
  const CompanionChatPage({super.key});

  @override
  State<CompanionChatPage> createState() => _CompanionChatPageState();
}

class _CompanionChatPageState extends State<CompanionChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool _isLoadingChat = true;
  bool _isSending = false;

  String _currentUserId = '';
  String _currentUserName = 'User';
  String _currentUserRole = 'patient';

  String _patientId = '';
  String _companionId = '';
  String _chatId = '';

  String _otherUserId = '';
  String _otherName = 'Companion';
  String _otherRole = 'companion';
  String _otherImageBase64 = '';
  String _otherImageUrl = '';
  bool _otherOnline = false;

  bool get isArabic => AppSettingsStore.instance.isArabic;

  Color get backgroundColor => Theme.of(context).scaffoldBackgroundColor;

  Color get cardColor => Theme.of(context).cardColor;

  Color get textColor =>
      Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;

  Color get subTextColor => false ? Colors.white70 : const Color(0xFF5D6D7E);

  String tr(String en, String ar) => isArabic ? ar : en;

  @override
  void initState() {
    super.initState();
    AppSettingsStore.instance.addListener(_onSettingsChanged);
    _loadChatInfo();
  }

  void _onSettingsChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    AppSettingsStore.instance.removeListener(_onSettingsChanged);
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String _readString(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString().trim();
      }
    }
    return '';
  }

  bool _readBool(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];
      if (value is bool) return value;
      if (value != null) {
        final text = value.toString().toLowerCase().trim();
        if (text == 'true' || text == 'online' || text == 'active') return true;
      }
    }
    return false;
  }

  String _safeChatId(String first, String second) {
    final ids = [first, second]
        .where((id) => id.trim().isNotEmpty)
        .map((id) => id.trim())
        .toList()
      ..sort();

    if (ids.length == 2) return '${ids[0]}_${ids[1]}';
    if (ids.length == 1) return '${ids[0]}_companion_chat';
    return 'unknown_companion_chat';
  }

  DateTime _timeFromDynamic(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  Future<String> _findBestPatientForCompanion(String companionId) async {
    final currentDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(companionId)
        .get();

    final currentData = currentDoc.data() ?? <String, dynamic>{};

    final savedPatientId = _readString(
      currentData,
      ['patientUid', 'patientId', 'linkedPatientId', 'patientUID'],
    );

    if (savedPatientId.isNotEmpty) return savedPatientId;

    final patientCandidates = <String>{};

    final fields = ['companionId', 'companionUid', 'linkedCompanionId'];
    for (final field in fields) {
      final query = await FirebaseFirestore.instance
          .collection('users')
          .where(field, isEqualTo: companionId)
          .get();

      for (final doc in query.docs) {
        final role =
            _readString(doc.data(), ['role', 'userRole']).toLowerCase();
        if (role.isEmpty || role == 'patient') {
          patientCandidates.add(doc.id);
        }
      }
    }

    if (patientCandidates.length == 1) return patientCandidates.first;

    final chatQuery = await FirebaseFirestore.instance
        .collection('patient_chats')
        .where('participants', arrayContains: companionId)
        .get();

    QueryDocumentSnapshot<Map<String, dynamic>>? bestChat;

    for (final doc in chatQuery.docs) {
      final data = doc.data();
      final patientId = _readString(data, ['patientId', 'patientUid']);

      if (patientId.isEmpty) continue;
      if (patientCandidates.isNotEmpty &&
          !patientCandidates.contains(patientId)) {
        continue;
      }

      if (bestChat == null ||
          _timeFromDynamic(data['lastMessageAt'] ?? data['updatedAt']).isAfter(
            _timeFromDynamic(bestChat.data()['lastMessageAt'] ??
                bestChat.data()['updatedAt']),
          )) {
        bestChat = doc;
      }
    }

    if (bestChat != null) {
      return _readString(bestChat.data(), ['patientId', 'patientUid']);
    }

    if (patientCandidates.isNotEmpty) return patientCandidates.first;

    return '';
  }

  Future<String> _findBestCompanionForPatient({
    required String patientId,
    required Map<String, dynamic> patientData,
  }) async {
    final savedCompanionId = _readString(
      patientData,
      ['companionId', 'companionUid', 'linkedCompanionId', 'companionUID'],
    );

    if (savedCompanionId.isNotEmpty) return savedCompanionId;

    final companionCandidates = <String>{};

    final fields = ['patientUid', 'patientId', 'linkedPatientId', 'patientUID'];
    for (final field in fields) {
      final query = await FirebaseFirestore.instance
          .collection('users')
          .where(field, isEqualTo: patientId)
          .get();

      for (final doc in query.docs) {
        final role =
            _readString(doc.data(), ['role', 'userRole']).toLowerCase();
        if (role.isEmpty || role == 'companion') {
          companionCandidates.add(doc.id);
        }
      }
    }

    final chatQuery = await FirebaseFirestore.instance
        .collection('patient_chats')
        .where('participants', arrayContains: patientId)
        .get();

    QueryDocumentSnapshot<Map<String, dynamic>>? bestChat;

    for (final doc in chatQuery.docs) {
      final data = doc.data();
      final companionId = _readString(data, ['companionId', 'companionUid']);

      if (companionId.isEmpty) continue;

      final bool companionIsCandidate = companionCandidates.isEmpty ||
          companionCandidates.contains(companionId);
      final bool lastMessageFromCompanion =
          _readString(data, ['lastSenderRole']).toLowerCase() == 'companion';

      if (!companionIsCandidate && !lastMessageFromCompanion) continue;

      if (bestChat == null) {
        bestChat = doc;
        continue;
      }

      final bestData = bestChat.data();
      final bestLastFromCompanion =
          _readString(bestData, ['lastSenderRole']).toLowerCase() ==
              'companion';

      if (lastMessageFromCompanion && !bestLastFromCompanion) {
        bestChat = doc;
        continue;
      }

      if (lastMessageFromCompanion == bestLastFromCompanion &&
          _timeFromDynamic(data['lastMessageAt'] ?? data['updatedAt']).isAfter(
            _timeFromDynamic(
                bestData['lastMessageAt'] ?? bestData['updatedAt']),
          )) {
        bestChat = doc;
      }
    }

    if (bestChat != null) {
      final companionId =
          _readString(bestChat.data(), ['companionId', 'companionUid']);
      if (companionId.isNotEmpty) return companionId;
    }

    if (companionCandidates.length == 1) return companionCandidates.first;

    if (companionCandidates.isNotEmpty) return companionCandidates.first;

    return '';
  }

  Future<void> _loadChatInfo() async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        if (!mounted) return;
        setState(() => _isLoadingChat = false);
        return;
      }

      _currentUserId = user.uid;

      final currentDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final currentData = currentDoc.data() ?? <String, dynamic>{};

      final currentName = _readString(
        currentData,
        ['name', 'fullName', 'username', 'displayName'],
      );
      _currentUserName = currentName.isNotEmpty ? currentName : 'User';

      final currentRole = _readString(currentData, ['role', 'userRole']);
      _currentUserRole =
          currentRole.isNotEmpty ? currentRole.toLowerCase().trim() : 'patient';

      if (_currentUserRole == 'companion') {
        _companionId = user.uid;
        _patientId = await _findBestPatientForCompanion(user.uid);
        _otherUserId = _patientId;
        _otherRole = 'patient';
      } else {
        _patientId = user.uid;
        _companionId = await _findBestCompanionForPatient(
          patientId: user.uid,
          patientData: currentData,
        );
        _otherUserId = _companionId;
        _otherRole = 'companion';
      }

      _chatId = _safeChatId(_patientId, _companionId);

      debugPrint('HEALTH CHAT CURRENT USER: $_currentUserId');
      debugPrint('HEALTH CHAT PATIENT ID: $_patientId');
      debugPrint('HEALTH CHAT COMPANION ID: $_companionId');
      debugPrint('HEALTH CHAT ID: $_chatId');

      if (_otherUserId.isNotEmpty) {
        final otherDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(_otherUserId)
            .get();

        final otherData = otherDoc.data() ?? <String, dynamic>{};

        final otherName = _readString(
          otherData,
          ['name', 'fullName', 'username', 'displayName'],
        );

        _otherName = otherName.isNotEmpty
            ? otherName
            : (_otherRole == 'companion' ? 'Companion' : 'Patient');

        _otherImageBase64 = _readString(
          otherData,
          ['profileImageBase64', 'imageBase64', 'photoBase64'],
        );

        _otherImageUrl = _readString(
          otherData,
          ['profileImageUrl', 'photoUrl', 'imageUrl', 'profilePhotoUrl'],
        );

        _otherOnline = _readBool(
          otherData,
          ['isOnline', 'online', 'isActive', 'active'],
        );

        // Save the link on both accounts so next time both pages open the same chat.
        if (_patientId.isNotEmpty && _companionId.isNotEmpty) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(_patientId)
              .set({
            'companionId': _companionId,
            'linkedCompanionId': _companionId,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

          await FirebaseFirestore.instance
              .collection('users')
              .doc(_companionId)
              .set({
            'patientUid': _patientId,
            'linkedPatientId': _patientId,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
      } else {
        _otherName = tr('No companion linked', 'لا يوجد مرافق مرتبط');
        _otherOnline = false;
      }

      if (_patientId.isNotEmpty && _companionId.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('patient_chats')
            .doc(_chatId)
            .set({
          'chatId': _chatId,
          'patientId': _patientId,
          'companionId': _companionId,
          'participants': [_patientId, _companionId]
              .where((id) => id.trim().isNotEmpty)
              .toList(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (e) {
      debugPrint('Error loading patient chat info: $e');
    }

    if (!mounted) return;
    setState(() => _isLoadingChat = false);
  }

  ImageProvider? _avatarProvider() {
    try {
      if (_otherImageBase64.trim().isNotEmpty) {
        String cleanBase64 = _otherImageBase64.trim();
        if (cleanBase64.contains(',')) {
          cleanBase64 = cleanBase64.split(',').last;
        }
        return MemoryImage(base64Decode(cleanBase64));
      }

      if (_otherImageUrl.trim().isNotEmpty) {
        return NetworkImage(_otherImageUrl.trim());
      }
    } catch (e) {
      debugPrint('Error loading chat avatar: $e');
    }

    return null;
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _messagesStream() {
    return FirebaseFirestore.instance
        .collection('patient_chats')
        .doc(_chatId)
        .collection('messages')
        .orderBy('createdAt', descending: false)
        .snapshots();
  }

  String _formatTime(dynamic value) {
    try {
      if (value is Timestamp) {
        final date = value.toDate();
        final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
        final minute = date.minute.toString().padLeft(2, '0');
        final period = date.hour >= 12 ? 'PM' : 'AM';
        return '$hour:$minute $period';
      }
    } catch (_) {}
    return '';
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending) return;

    if (_otherUserId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr(
              'No linked companion found for this patient.',
              'لا يوجد مرافق مرتبط بهذا المريض.',
            ),
          ),
        ),
      );
      return;
    }

    setState(() => _isSending = true);

    try {
      final messageData = {
        // Keep both keys so this chat works with the companion page
        // that reads "message" and the patient page that reads "text".
        'text': text,
        'message': text,
        'senderId': _currentUserId,
        'senderName': _currentUserName,
        'senderRole': _currentUserRole,
        'receiverId': _otherUserId,
        'receiverName': _otherName,
        'receiverRole': _otherRole,
        'patientId': _patientId,
        'companionId': _companionId,
        'createdAt': FieldValue.serverTimestamp(),
        'isRead': false,
      };

      await FirebaseFirestore.instance
          .collection('patient_chats')
          .doc(_chatId)
          .collection('messages')
          .add(messageData);

      await FirebaseFirestore.instance
          .collection('patient_chats')
          .doc(_chatId)
          .set({
        'lastMessage': text,
        'lastSenderId': _currentUserId,
        'lastSenderRole': _currentUserRole,
        'lastMessageAt': FieldValue.serverTimestamp(),
        'patientId': _patientId,
        'companionId': _companionId,
        'participants': [_patientId, _companionId]
            .where((id) => id.trim().isNotEmpty)
            .toList(),
      }, SetOptions(merge: true));

      await FirebaseFirestore.instance.collection('notifications').add({
        'userId': _otherUserId,
        'receiverId': _otherUserId,
        'senderId': _currentUserId,
        'senderName': _currentUserName,
        'senderRole': _currentUserRole,
        'type': 'companion_chat_message',
        'title': tr('New Health Message', 'رسالة صحية جديدة'),
        'message': text,
        'chatId': _chatId,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      _messageController.clear();

      Future.delayed(const Duration(milliseconds: 250), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      debugPrint('Error sending patient chat message: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr(
              'Could not send message. Check Firestore rules.',
              'تعذر إرسال الرسالة. تأكد من صلاحيات Firestore.',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _goBack() {
    VoiceAccessibilityService.instance.stopAll();

    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HealthPage()),
      );
    }
  }

  Widget _buildHeader() {
    final avatar = _avatarProvider();

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
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(40)),
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
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
              const SizedBox(width: 8),
              Stack(
                clipBehavior: Clip.none,
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: const Color(0xFFE3F6FF),
                    backgroundImage: avatar,
                    child: avatar == null
                        ? Icon(
                            _otherRole == 'companion'
                                ? Icons.support_agent_rounded
                                : Icons.person_rounded,
                            color: const Color(0xFF2196F3),
                            size: 30,
                          )
                        : null,
                  ),
                  Positioned(
                    right: 1,
                    bottom: 1,
                    child: Container(
                      width: 15,
                      height: 15,
                      decoration: BoxDecoration(
                        color: _otherOnline ? Colors.green : Colors.red,
                        shape: BoxShape.circle,
                        border: Border.all(color: backgroundColor, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: isArabic
                      ? CrossAxisAlignment.end
                      : CrossAxisAlignment.start,
                  children: [
                    Text(
                      _otherName,
                      textAlign: isArabic ? TextAlign.right : TextAlign.left,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _otherOnline
                          ? tr('Online', 'متصل')
                          : tr('Offline', 'غير متصل'),
                      textAlign: isArabic ? TextAlign.right : TextAlign.left,
                      style: TextStyle(
                        color: _otherOnline ? Colors.green : Colors.red,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 48),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> data) {
    final isMe = data['senderId'] == _currentUserId;
    final text = (data['text'] ?? data['message'] ?? '').toString();
    final time = _formatTime(data['createdAt']);

    return Align(
      alignment: isMe
          ? (isArabic ? Alignment.centerLeft : Alignment.centerRight)
          : (isArabic ? Alignment.centerRight : Alignment.centerLeft),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width > 700
              ? 520
              : MediaQuery.of(context).size.width * 0.76,
        ),
        decoration: BoxDecoration(
          color: isMe ? const Color(0xFF87CEEB) : cardColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(isMe ? 20 : 6),
            bottomRight: Radius.circular(isMe ? 6 : 20),
          ),
          border:
              !isMe ? Border.all(color: Theme.of(context).dividerColor) : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.07),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment:
              isArabic ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              text,
              textAlign: isArabic ? TextAlign.right : TextAlign.left,
              style: TextStyle(
                color: isMe ? Colors.white : textColor,
                fontSize: 15,
                height: 1.4,
              ),
            ),
            if (time.isNotEmpty) ...[
              const SizedBox(height: 5),
              Text(
                time,
                style: TextStyle(
                  color: isMe ? Colors.white70 : subTextColor,
                  fontSize: 11,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMessages() {
    if (_isLoadingChat) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF87CEEB)),
      );
    }

    if (_otherUserId.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            tr(
              'No linked companion was found. Please link a companion first.',
              'لم يتم العثور على مرافق مرتبط. يرجى ربط مرافق أولاً.',
            ),
            textAlign: TextAlign.center,
            style: TextStyle(color: subTextColor, fontSize: 16),
          ),
        ),
      );
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _messagesStream(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              tr('Could not load messages.', 'تعذر تحميل الرسائل.'),
              style: TextStyle(color: subTextColor),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF87CEEB)),
          );
        }

        final messages = snapshot.data?.docs ?? [];

        if (messages.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                tr(
                  'Start the conversation with your companion. Your companion will reply here directly.',
                  'ابدأ المحادثة مع المرافق. سيرد المرافق هنا مباشرة.',
                ),
                textAlign: TextAlign.center,
                style: TextStyle(color: subTextColor, fontSize: 16),
              ),
            ),
          );
        }

        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
          itemCount: messages.length,
          itemBuilder: (context, index) {
            return _buildMessageBubble(messages[index].data());
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: isArabic ? ui.TextDirection.rtl : ui.TextDirection.ltr,
      child: Scaffold(
        backgroundColor: backgroundColor,
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(child: _buildMessages()),
              SafeArea(
                top: false,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 18),
                  decoration: BoxDecoration(
                    color: cardColor,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(
                          0.08,
                        ),
                        blurRadius: 12,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          enabled: !_isLoadingChat && _otherUserId.isNotEmpty,
                          textAlign:
                              isArabic ? TextAlign.right : TextAlign.left,
                          style: TextStyle(color: textColor),
                          minLines: 1,
                          maxLines: 4,
                          decoration: InputDecoration(
                            hintText: tr(
                              'Write a message...',
                              'اكتب رسالة...',
                            ),
                            hintStyle: TextStyle(color: subTextColor),
                            filled: true,
                            fillColor: Theme.of(context)
                                    .inputDecorationTheme
                                    .fillColor ??
                                const Color(0xFFF4F4F4),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(22),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          onSubmitted: (_) => _sendMessage(),
                        ),
                      ),
                      const SizedBox(width: 10),
                      CircleAvatar(
                        radius: 25,
                        backgroundColor: const Color(0xFF87CEEB),
                        child: IconButton(
                          onPressed: _isSending ? null : _sendMessage,
                          icon: _isSending
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(
                                  Icons.send_rounded,
                                  color: Colors.white,
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
      ),
    );
  }
}

enum AIQuestionType { emojiMood, options }

class AIQuestion {
  final String title;
  final String subtitle;
  final AIQuestionType type;
  final List<String> options;

  const AIQuestion({
    required this.title,
    required this.subtitle,
    required this.type,
    required this.options,
  });
}
