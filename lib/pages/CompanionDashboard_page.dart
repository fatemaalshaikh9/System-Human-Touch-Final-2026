import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

import 'Profile_page.dart';
import 'Settings_page.dart';
import 'RemindersCompanion_page.dart';

import 'package:humantouch/pages/app_settings_store.dart';

class CompanionReminder {
  final String id;
  final String title;
  final String time;
  final String day;
  final String emoji;
  final String status;

  CompanionReminder({
    required this.id,
    required this.title,
    required this.time,
    required this.day,
    required this.emoji,
    required this.status,
  });

  factory CompanionReminder.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return CompanionReminder(
      id: doc.id,
      title: (data['title'] ?? '').toString(),
      time: (data['time'] ?? '').toString(),
      day: (data['day'] ?? '').toString(),
      emoji: (data['emoji'] ?? '⏰').toString(),
      status: (data['status'] ?? 'pending').toString(),
    );
  }
}

class HealthAIReport {
  final String id;
  final String moodAnswer;
  final String dayAnswer;
  final String energyAnswer;
  final String physicalAnswer;
  final String sleepAnswer;
  final String helpAnswer;
  final String resultMessage;
  final dynamic createdAt;

  HealthAIReport({
    required this.id,
    required this.moodAnswer,
    required this.dayAnswer,
    required this.energyAnswer,
    required this.physicalAnswer,
    required this.sleepAnswer,
    required this.helpAnswer,
    required this.resultMessage,
    required this.createdAt,
  });

  factory HealthAIReport.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return HealthAIReport(
      id: doc.id,
      moodAnswer: (data['moodAnswer'] ?? '').toString(),
      dayAnswer: (data['dayAnswer'] ?? '').toString(),
      energyAnswer: (data['energyAnswer'] ?? '').toString(),
      physicalAnswer: (data['physicalAnswer'] ?? '').toString(),
      sleepAnswer: (data['sleepAnswer'] ?? '').toString(),
      helpAnswer: (data['helpAnswer'] ?? '').toString(),
      resultMessage: (data['resultMessage'] ?? '').toString(),
      createdAt: data['createdAt'],
    );
  }
}

class PatientDashboardProfile {
  final String name;
  final bool isActive;
  final String statusText;
  final String mood;
  final String location;
  final String phoneNumber;
  final int heartRate;
  final int sleepHours;
  final int waterCups;
  final int exerciseMinutes;
  final int walkSteps;
  final String lastUpdated;

  PatientDashboardProfile({
    required this.name,
    required this.isActive,
    required this.statusText,
    required this.mood,
    required this.location,
    required this.phoneNumber,
    required this.heartRate,
    required this.sleepHours,
    required this.waterCups,
    required this.exerciseMinutes,
    required this.walkSteps,
    required this.lastUpdated,
  });
}

class CompanionDashboardPage extends StatefulWidget {
  const CompanionDashboardPage({super.key});

  @override
  State<CompanionDashboardPage> createState() => _CompanionDashboardPageState();
}

class _CompanionDashboardPageState extends State<CompanionDashboardPage> {
  String _lastUpdated = '';

  bool _isLoading = true;
  bool _isLinkedToPatient = false;

  String companionName = 'Companion';
  String patientName = 'Patient';
  String patientUid = '';

  bool patientIsActive = false;
  String patientStatus = 'Non-active';
  String mood = 'Calm 😊';
  String location = 'Manama';
  String patientPhoneNumber = '';
  int heartRate = 0;
  int sleepHours = 0;
  int waterCups = 0;
  int exerciseMinutes = 0;
  int walkSteps = 0;

  String _selectedReport = 'Daily';

  bool get isArabic => AppSettingsStore.instance.isArabic;

  Color get _backgroundColor => Theme.of(context).scaffoldBackgroundColor;

  Color get _cardColor => Theme.of(context).cardColor;

  Color get _textColor =>
      Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black87;

  Color get _subTextColor => Colors.black54;

  Color get _softCardColor =>
      Theme.of(context).inputDecorationTheme.fillColor ??
      const Color(0xFFEAF8FD);

  Color get _chartLabelColor => Colors.black54;

  String tr(String en, String ar) {
    return isArabic ? ar : en;
  }

  @override
  void initState() {
    super.initState();
    _loadCompanionAndPatientData();

    AppSettingsStore.instance.addListener(_onLanguageChanged);
  }

  void _onLanguageChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadCompanionAndPatientData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _isLinkedToPatient = false;
        });
        return;
      }

      final companionDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!mounted) return;

      if (!companionDoc.exists) {
        setState(() {
          _isLoading = false;
          _isLinkedToPatient = false;
        });
        return;
      }

      final companionData = companionDoc.data() ?? {};

      companionName = (companionData['name'] ?? 'Companion').toString();
      patientUid = (companionData['patientUid'] ?? '').toString();

      if (patientUid.trim().isEmpty) {
        final linkedPatientCode =
            (companionData['linkedPatientCode'] ?? '').toString();

        if (linkedPatientCode.isNotEmpty) {
          final patientQuery = await FirebaseFirestore.instance
              .collection('users')
              .where('patientLinkCode', isEqualTo: linkedPatientCode)
              .limit(1)
              .get();

          if (patientQuery.docs.isNotEmpty) {
            patientUid = patientQuery.docs.first.id;

            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .set({'patientUid': patientUid}, SetOptions(merge: true));
          }
        }
      }

      if (!mounted) return;

      if (patientUid.trim().isEmpty) {
        setState(() {
          _isLoading = false;
          _isLinkedToPatient = false;
        });
        return;
      }

      final patientDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(patientUid)
          .get();

      if (!mounted) return;

      if (!patientDoc.exists) {
        setState(() {
          _isLoading = false;
          _isLinkedToPatient = false;
        });
        return;
      }

      final patientData = patientDoc.data() ?? {};

      final profile = _profileFromMap(patientData);

      setState(() {
        _applyProfileToLocalState(profile);
        _isLoading = false;
        _isLinkedToPatient = true;
      });
    } catch (e) {
      debugPrint('Error loading companion/patient data: $e');

      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _isLinkedToPatient = false;
      });
    }
  }

  Stream<List<CompanionReminder>> _patientRemindersStream() {
    if (patientUid.isEmpty) return const Stream.empty();

    return FirebaseFirestore.instance
        .collection('reminders')
        .where('userId', isEqualTo: patientUid)
        .snapshots()
        .map((snapshot) {
      final reminders =
          snapshot.docs.map((doc) => CompanionReminder.fromDoc(doc)).toList();

      reminders.sort((a, b) => a.time.compareTo(b.time));
      return reminders;
    });
  }

  Stream<List<HealthAIReport>> _healthAIReportsStream() {
    if (patientUid.isEmpty) return const Stream.empty();

    return FirebaseFirestore.instance
        .collection('health_ai_reports')
        .where('userId', isEqualTo: patientUid)
        .orderBy('createdAt', descending: true)
        .limit(30)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => HealthAIReport.fromDoc(doc)).toList();
    });
  }

  Stream<PatientDashboardProfile> _patientProfileStream() {
    if (patientUid.isEmpty) return const Stream.empty();

    return FirebaseFirestore.instance
        .collection('users')
        .doc(patientUid)
        .snapshots()
        .map((doc) {
      final data = doc.data() ?? {};
      return _profileFromMap(data);
    });
  }

  bool _boolFromDynamic(dynamic value) {
    if (value is bool) return value;

    final text = value.toString().trim().toLowerCase();

    return text == 'true' ||
        text == 'active' ||
        text == 'online' ||
        text == '1' ||
        text == 'yes';
  }

  int _intFromDynamic(dynamic value, {int defaultValue = 0}) {
    if (value is int) return value;
    if (value is double) return value.round();

    return int.tryParse(value.toString()) ?? defaultValue;
  }

  String _formatFirestoreTime(dynamic value) {
    if (value == null) return tr('Not updated yet', 'لم يتم التحديث بعد');

    DateTime? dateTime;

    if (value is Timestamp) {
      dateTime = value.toDate();
    } else if (value is DateTime) {
      dateTime = value;
    } else {
      dateTime = DateTime.tryParse(value.toString());
    }

    if (dateTime == null) return value.toString();

    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  PatientDashboardProfile _profileFromMap(Map<String, dynamic> data) {
    final bool active = _boolFromDynamic(
      data['isActive'] ??
          data['active'] ??
          data['accountActive'] ??
          data['patientActive'],
    );

    final String status = active ? 'Active' : 'Non-active';

    final String profileMood =
        (data['patientMoodEmoji'] != null && data['patientMoodLabel'] != null)
            ? '${data['patientMoodEmoji']} ${data['patientMoodLabel']}'
            : (data['mood'] ?? data['patientMood'] ?? 'No mood').toString();

    return PatientDashboardProfile(
      name: (data['name'] ?? data['fullName'] ?? 'Patient').toString(),
      isActive: active,
      statusText: status,
      mood: profileMood,
      location: (data['location'] ?? data['address'] ?? 'Unknown').toString(),
      phoneNumber: (data['phone'] ??
              data['phoneNumber'] ??
              data['mobile'] ??
              data['contactNumber'] ??
              '')
          .toString(),
      heartRate: _intFromDynamic(
        data['heartRate'] ?? data['heart_rate'] ?? data['bpm'],
      ),
      sleepHours: _intFromDynamic(
        data['sleepHours'] ?? data['sleep'] ?? data['sleepHoursToday'],
      ),
      waterCups: _intFromDynamic(
        data['waterCups'] ?? data['water'] ?? data['waterIntake'],
      ),
      exerciseMinutes: _intFromDynamic(
        data['exerciseMinutes'] ??
            data['exercise'] ??
            data['exerciseMinutesToday'],
      ),
      walkSteps: _intFromDynamic(
        data['walkSteps'] ?? data['steps'] ?? data['walkingSteps'],
      ),
      lastUpdated: _formatFirestoreTime(
        data['lastUpdated'] ??
            data['updatedAt'] ??
            data['lastActiveAt'] ??
            data['profileUpdatedAt'],
      ),
    );
  }

  void _applyProfileToLocalState(PatientDashboardProfile profile) {
    patientName = profile.name;
    patientIsActive = profile.isActive;
    patientStatus = profile.statusText;
    mood = profile.mood;
    location = profile.location;
    patientPhoneNumber = profile.phoneNumber;
    heartRate = profile.heartRate;
    sleepHours = profile.sleepHours;
    waterCups = profile.waterCups;
    exerciseMinutes = profile.exerciseMinutes;
    walkSteps = profile.walkSteps;
    _lastUpdated = profile.lastUpdated;
  }

  @override
  void dispose() {
    AppSettingsStore.instance.removeListener(_onLanguageChanged);
    super.dispose();
  }

  String getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return tr('Good Morning', 'صباح الخير');
    if (hour < 17) return tr('Good Afternoon', 'مساء الخير');
    return tr('Good Evening', 'مساء الخير');
  }

  String _statusText(String status) {
    final text = status.toLowerCase();

    if (text.contains('active') && !text.contains('non')) {
      return tr('Active', 'نشط');
    }

    return tr('Non-active', 'غير نشط');
  }

  String _reminderStatusText(dynamic status) {
    final text = status.toString().toLowerCase();

    if (text.contains('done') || text.contains('accepted')) {
      return tr('Done', 'تم');
    }

    if (text.contains('missed') || text.contains('none')) {
      return tr('Missed', 'فائت');
    }

    return tr('Pending', 'قيد الانتظار');
  }

  bool _isDoneStatus(dynamic status) {
    final text = status.toString().toLowerCase();
    return text.contains('done') || text.contains('accepted');
  }

  bool _isMissedStatus(dynamic status) {
    final text = status.toString().toLowerCase();
    return text.contains('missed') || text.contains('none');
  }

  int _doneCount(List<CompanionReminder> reminders) {
    return reminders.where((item) => _isDoneStatus(item.status)).length;
  }

  int _missedCount(List<CompanionReminder> reminders) {
    return reminders.where((item) => _isMissedStatus(item.status)).length;
  }

  double _careProgress(
    List<CompanionReminder> reminders,
    List<HealthAIReport> aiReports,
  ) {
    int completed = 0;
    int total = 0;

    // 1) Reminders
    if (reminders.isNotEmpty) {
      total++;
      completed += (_doneCount(reminders) / reminders.length * 100).round();
    }

    // 2) Sleep
    total++;
    if (sleepHours >= 7) {
      completed += 100;
    } else if (sleepHours >= 5) {
      completed += 60;
    } else if (sleepHours > 0) {
      completed += 30;
    }

    // 3) Mood
    total++;
    final moodText = mood.toLowerCase();
    if (moodText.contains('happy') ||
        moodText.contains('calm') ||
        moodText.contains('good') ||
        moodText.contains('😊') ||
        moodText.contains('😌')) {
      completed += 100;
    } else if (moodText.contains('sad') ||
        moodText.contains('angry') ||
        moodText.contains('anxious') ||
        moodText.contains('😢') ||
        moodText.contains('😡') ||
        moodText.contains('😰')) {
      completed += 40;
    } else {
      completed += 70;
    }

    // 4) Activity: walk, exercise, water
    total++;
    int activityScore = 0;
    if (walkSteps >= 3000) activityScore += 35;
    if (exerciseMinutes >= 20) activityScore += 35;
    if (waterCups >= 6) activityScore += 30;
    completed += activityScore.clamp(0, 100);

    // 5) AI Health Check
    total++;
    if (aiReports.isNotEmpty) {
      final latest = aiReports.first;
      final hasRisk = latest.helpAnswer.toLowerCase().contains('yes') ||
          latest.resultMessage.toLowerCase().contains('risk') ||
          latest.resultMessage.toLowerCase().contains('emergency') ||
          latest.resultMessage.toLowerCase().contains('attention');

      completed += hasRisk ? 45 : 100;
    } else {
      completed += 50;
    }

    // 6) Missed alerts / emergency
    total++;
    final hasMissedAlerts = _missedCount(reminders) > 0;
    completed += hasMissedAlerts ? 30 : 100;

    if (total == 0) return 0;
    return (completed / (total * 100)).clamp(0.0, 1.0);
  }

  Color _progressColor(double progress) {
    final percent = progress * 100;

    if (percent >= 80) return Colors.green;
    if (percent >= 50) return Colors.orange;
    return Colors.red;
  }

  Color _statusColor(String status) {
    final text = status.toLowerCase();
    return text.contains('active') && !text.contains('non')
        ? Colors.green
        : Colors.red;
  }

  Color _reminderStatusColor(dynamic status) {
    if (_isDoneStatus(status)) return Colors.green;
    if (_isMissedStatus(status)) return Colors.red;
    return Colors.orange;
  }

  List<Map<String, dynamic>> _generateAiInsights(
    List<CompanionReminder> reminders,
    List<HealthAIReport> aiReports,
  ) {
    final missed = _missedCount(reminders);
    final progress = _careProgress(reminders, aiReports);
    final latestAIReport = aiReports.isNotEmpty ? aiReports.first : null;

    if (latestAIReport != null &&
        (latestAIReport.helpAnswer.toLowerCase().contains('yes') ||
            latestAIReport.resultMessage.toLowerCase().contains('risk') ||
            latestAIReport.resultMessage.toLowerCase().contains('attention'))) {
      return [
        {
          'icon': Icons.psychology_alt_rounded,
          'color': Colors.orange,
          'title': tr('AI Health Check Alert', 'تنبيه الفحص الصحي الذكي'),
          'message': latestAIReport.resultMessage.isEmpty
              ? tr(
                  'AI Health Check needs attention. Please review the latest patient report.',
                  'الفحص الصحي الذكي يحتاج إلى متابعة. يرجى مراجعة آخر تقرير للمريض.',
                )
              : latestAIReport.resultMessage,
        },
      ];
    }

    if (missed >= 2) {
      return [
        {
          'icon': Icons.warning_amber_rounded,
          'color': Colors.red,
          'title': tr('High Attention Needed', 'يحتاج إلى انتباه عالي'),
          'message': tr(
            '$patientName missed multiple reminders today. Please check in with the patient.',
            'المريض $patientName فوّت عدة تذكيرات اليوم. يرجى الاطمئنان عليه.',
          ),
        },
      ];
    }

    if (heartRate > 110) {
      return [
        {
          'icon': Icons.favorite,
          'color': Colors.red,
          'title': tr('Health Risk Detected', 'تم اكتشاف خطر صحي'),
          'message': tr(
            'Heart rate is higher than normal. Monitor $patientName closely.',
            'معدل ضربات القلب أعلى من الطبيعي. راقب $patientName بعناية.',
          ),
        },
      ];
    }

    if (sleepHours > 0 && sleepHours < 5) {
      return [
        {
          'icon': Icons.bedtime,
          'color': Colors.orange,
          'title': tr('Low Sleep', 'قلة النوم'),
          'message': tr(
            '$patientName may feel tired today because sleep hours are low.',
            'قد يشعر $patientName بالتعب اليوم بسبب قلة ساعات النوم.',
          ),
        },
      ];
    }

    if (progress < 0.5 && reminders.isNotEmpty) {
      return [
        {
          'icon': Icons.trending_down,
          'color': Colors.orange,
          'title': tr('Low Daily Progress', 'انخفاض التقدم اليومي'),
          'message': tr(
            'Daily care progress is low. The patient may need extra support today.',
            'تقدم الرعاية اليومية منخفض. قد يحتاج المريض إلى دعم إضافي اليوم.',
          ),
        },
      ];
    }

    return [
      {
        'icon': Icons.check_circle,
        'color': Colors.green,
        'title': tr('Active Monitoring', 'المتابعة نشطة'),
        'message': tr(
          '$patientName has no urgent alerts today. Continue monitoring reminders and health updates.',
          'لا توجد تنبيهات عاجلة على $patientName اليوم. استمر في متابعة التذكيرات والتحديثات الصحية.',
        ),
      },
    ];
  }

  void _goToPage(int index) {
    if (index == 0) return;

    if (index == 1) {
      Navigator.pushReplacementNamed(context, '/profile');
    } else if (index == 2) {
      Navigator.pushReplacementNamed(context, '/settings');
    }
  }

  Widget _buildTopHeader() {
    return Stack(
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
            color: _backgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
          ),
        ),
      ],
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
          color: _textColor,
        ),
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(22),
        boxShadow: _shadow(),
      ),
      child: DefaultTextStyle(
        style: TextStyle(color: _textColor, fontSize: 14),
        child: child,
      ),
    );
  }

  Widget _buildNotLinkedView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Center(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: _cardColor,
            borderRadius: BorderRadius.circular(24),
            boxShadow: _shadow(),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.link_off_rounded,
                size: 70,
                color: Color(0xFF87CEEB),
              ),
              const SizedBox(height: 16),
              Text(
                tr('No Patient Linked', 'لا يوجد مريض مرتبط'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: _textColor,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                tr(
                  'You need to link your account with a patient first to view health updates, reminders, alerts, location, reports, and quick actions.',
                  'يجب ربط حسابك بالمريض أولاً لعرض التحديثات الصحية، التذكيرات، التنبيهات، الموقع، التقارير، والإجراءات السريعة.',
                ),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: _subTextColor,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const ProfilePage()),
                    );
                  },
                  icon: const Icon(Icons.person, color: Colors.white),
                  label: Text(
                    tr('Go to Profile', 'الانتقال إلى الملف'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF87CEEB),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
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

  Widget _healthItem(IconData icon, String title, String value) {
    return SizedBox(
      width: 95,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: const Color(0xFF87CEEB), size: 30),
          const SizedBox(height: 6),
          Text(
            value,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: _textColor,
            ),
          ),
          Text(
            title,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
            style: TextStyle(color: _subTextColor, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Future<void> _callPhoneNumber(String phoneNumber) async {
    final cleanedPhone = phoneNumber.trim();

    if (cleanedPhone.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr(
              'Patient phone number is not available.',
              'رقم هاتف المريض غير متوفر.',
            ),
          ),
        ),
      );
      return;
    }

    final uri = Uri(scheme: 'tel', path: cleanedPhone);

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr(
              'Could not open the phone dialer.',
              'تعذر فتح الاتصال.',
            ),
          ),
        ),
      );
    }
  }

  Widget _quickActionCard({
    required IconData icon,
    required String title,
    required String description,
    required VoidCallback onTap,
    Color iconColor = const Color(0xFF2D9CDB),
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _softCardColor,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          crossAxisAlignment:
              isArabic ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 27),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: isArabic ? TextAlign.right : TextAlign.left,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: _textColor,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              description,
              textAlign: isArabic ? TextAlign.right : TextAlign.left,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                height: 1.3,
                color: _subTextColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportTab(String title, String label) {
    final selected = _selectedReport == title;

    return Flexible(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedReport = title;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF87CEEB) : _softCardColor,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Center(
            child: Text(
              label,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              style: TextStyle(
                color: selected ? Colors.white : _textColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSimpleBarChart(List<int> values, List<String> labels) {
    return SizedBox(
      height: 160,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List.generate(values.length, (index) {
            final value = values[index];
            final double barHeight = value.toDouble().clamp(8.0, 100.0);

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    '$value%',
                    style: TextStyle(fontSize: 11, color: _chartLabelColor),
                  ),
                  const SizedBox(height: 5),
                  Container(
                    width: 24,
                    height: barHeight,
                    decoration: BoxDecoration(
                      color: _progressColor(value / 100),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    width: 45,
                    child: Text(
                      labels[index],
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: _subTextColor),
                    ),
                  ),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _aiReportSummary(HealthAIReport? report) {
    if (report == null) {
      return Text(
        tr('No AI Health Check report yet.', 'لا يوجد تقرير فحص صحي ذكي بعد.'),
        style: TextStyle(color: _subTextColor),
      );
    }

    return Column(
      crossAxisAlignment:
          isArabic ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(
          tr('AI Health Check Summary', 'ملخص الفحص الصحي الذكي'),
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: _textColor,
          ),
        ),
        const SizedBox(height: 10),
        Text('${tr('Mood', 'المزاج')}: ${report.moodAnswer}'),
        Text('${tr('Day', 'اليوم')}: ${report.dayAnswer}'),
        Text('${tr('Energy', 'الطاقة')}: ${report.energyAnswer}'),
        Text('${tr('Physical', 'الحالة الجسدية')}: ${report.physicalAnswer}'),
        Text('${tr('Sleep', 'النوم')}: ${report.sleepAnswer}'),
        Text('${tr('Help Needed', 'هل يحتاج مساعدة')}: ${report.helpAnswer}'),
        const SizedBox(height: 10),
        Text(
          report.resultMessage,
          textAlign: isArabic ? TextAlign.right : TextAlign.left,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: _textColor,
          ),
        ),
      ],
    );
  }

  Widget _buildDailyReport(
    List<CompanionReminder> reminders,
    List<HealthAIReport> aiReports,
  ) {
    final progress = _careProgress(reminders, aiReports);
    final done = _doneCount(reminders);
    final missed = _missedCount(reminders);
    final pending = reminders.length - done - missed;

    final latestAIReport = aiReports.isNotEmpty ? aiReports.first : null;

    return Column(
      crossAxisAlignment:
          isArabic ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(
          tr('Today Summary', 'ملخص اليوم'),
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: _textColor,
          ),
        ),
        const SizedBox(height: 10),
        Text(
            '${tr('Total Reminders', 'إجمالي التذكيرات')}: ${reminders.length}'),
        Text('${tr('Completed Reminders', 'التذكيرات المكتملة')}: $done'),
        Text('${tr('Pending Reminders', 'التذكيرات المعلقة')}: $pending'),
        Text('${tr('Missed Reminders', 'التذكيرات الفائتة')}: $missed'),
        Text(
            '${tr('Daily Progress', 'التقدم اليومي')}: ${(progress * 100).round()}%'),
        const SizedBox(height: 18),
        _aiReportSummary(latestAIReport),
      ],
    );
  }

  Widget _buildWeeklyReport(
    double progress,
    List<HealthAIReport> aiReports,
  ) {
    final today = (progress * 100).round();

    final int totalReports = aiReports.length;
    final int helpNeededCount = aiReports
        .where((report) => report.helpAnswer.toLowerCase().contains('yes'))
        .length;

    final int lowEnergyCount = aiReports.where((report) {
      final text = report.energyAnswer.toLowerCase();
      return text.contains('low') || text.contains('exhausted');
    }).length;

    final int poorSleepCount = aiReports
        .where((report) => report.sleepAnswer.toLowerCase().contains('poor'))
        .length;

    final latestAIReport = aiReports.isNotEmpty ? aiReports.first : null;

    return Column(
      crossAxisAlignment:
          isArabic ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(
          tr('Weekly Summary', 'ملخص الأسبوع'),
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: _textColor,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          tr(
            'This chart shows care progress during the week.',
            'يوضح هذا المخطط تقدم الرعاية خلال الأسبوع.',
          ),
        ),
        const SizedBox(height: 16),
        _buildSimpleBarChart(
          [0, 0, 0, 0, 0, 0, today],
          isArabic
              ? [
                  'الأحد',
                  'الاثنين',
                  'الثلاثاء',
                  'الأربعاء',
                  'الخميس',
                  'الجمعة',
                  'اليوم'
                ]
              : ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Today'],
        ),
        const SizedBox(height: 18),
        Text(
          tr('AI Weekly Health Summary', 'ملخص الصحة الذكي الأسبوعي'),
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: _textColor,
          ),
        ),
        const SizedBox(height: 10),
        Text(
            '${tr('Total AI reports this week', 'إجمالي تقارير الذكاء لهذا الأسبوع')}: $totalReports'),
        Text(
            '${tr('Help needed reports', 'تقارير تحتاج مساعدة')}: $helpNeededCount'),
        Text(
            '${tr('Low energy reports', 'تقارير انخفاض الطاقة')}: $lowEnergyCount'),
        Text(
            '${tr('Poor sleep reports', 'تقارير النوم الضعيف')}: $poorSleepCount'),
        const SizedBox(height: 12),
        _aiReportSummary(latestAIReport),
      ],
    );
  }

  Widget _buildMonthlyReport(
    double progress,
    List<HealthAIReport> aiReports,
  ) {
    final current = (progress * 100).round();

    final int totalReports = aiReports.length;
    final int helpNeededCount = aiReports
        .where((report) => report.helpAnswer.toLowerCase().contains('yes'))
        .length;

    final int notWellCount = aiReports.where((report) {
      return report.physicalAnswer.toLowerCase().contains('not well');
    }).length;

    final int badDayCount = aiReports.where((report) {
      final text = report.dayAnswer.toLowerCase();
      return text.contains('bad') || text.contains('okay');
    }).length;

    final latestAIReport = aiReports.isNotEmpty ? aiReports.first : null;

    return Column(
      crossAxisAlignment:
          isArabic ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(
          tr('Monthly Summary', 'ملخص الشهر'),
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: _textColor,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          tr(
            'This chart shows monthly care progress overview.',
            'يوضح هذا المخطط نظرة عامة على تقدم الرعاية الشهري.',
          ),
        ),
        const SizedBox(height: 16),
        _buildSimpleBarChart(
          [0, 0, 0, current],
          isArabic
              ? ['أسبوع 1', 'أسبوع 2', 'أسبوع 3', 'الآن']
              : ['W1', 'W2', 'W3', 'Now'],
        ),
        const SizedBox(height: 18),
        Text(
          tr('AI Monthly Health Summary', 'ملخص الصحة الذكي الشهري'),
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: _textColor,
          ),
        ),
        const SizedBox(height: 10),
        Text(
            '${tr('Total AI reports this month', 'إجمالي تقارير الذكاء لهذا الشهر')}: $totalReports'),
        Text(
            '${tr('Help needed reports', 'تقارير تحتاج مساعدة')}: $helpNeededCount'),
        Text(
            '${tr('Physical concern reports', 'تقارير القلق الجسدي')}: $notWellCount'),
        Text(
            '${tr('Difficult/okay day reports', 'تقارير الأيام الصعبة أو العادية')}: $badDayCount'),
        const SizedBox(height: 12),
        _aiReportSummary(latestAIReport),
      ],
    );
  }

  Widget _buildReportContent(
    List<CompanionReminder> reminders,
    List<HealthAIReport> aiReports,
  ) {
    final progress = _careProgress(reminders, aiReports);

    if (_selectedReport == 'Weekly') {
      return _buildWeeklyReport(progress, aiReports.take(7).toList());
    }

    if (_selectedReport == 'Monthly') {
      return _buildMonthlyReport(progress, aiReports);
    }

    return _buildDailyReport(reminders, aiReports);
  }

  Widget _buildLinkedDashboard(
    List<CompanionReminder> reminders,
    List<HealthAIReport> aiReports,
  ) {
    final missedReminders =
        reminders.where((item) => _isMissedStatus(item.status)).toList();

    final progress = _careProgress(reminders, aiReports);
    final progressPercent = (progress * 100).round();
    final progressColor = _progressColor(progress);
    final aiInsights = _generateAiInsights(reminders, aiReports);

    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        crossAxisAlignment:
            isArabic ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Text(
            '${getGreeting()}, $companionName 👋',
            textAlign: isArabic ? TextAlign.right : TextAlign.left,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 25,
              fontWeight: FontWeight.bold,
              color: _textColor,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            tr(
              'Here is $patientName\'s latest update',
              'هذه آخر تحديثات $patientName',
            ),
            textAlign: isArabic ? TextAlign.right : TextAlign.left,
            style: TextStyle(fontSize: 16, color: _subTextColor),
          ),
          _card(
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 32,
                  backgroundColor: Color(0xFFEAF8FD),
                  child: Icon(
                    Icons.person,
                    size: 38,
                    color: Color(0xFF2D9CDB),
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: isArabic
                        ? CrossAxisAlignment.end
                        : CrossAxisAlignment.start,
                    children: [
                      Text(
                        patientName,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: _textColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: isArabic
                            ? MainAxisAlignment.end
                            : MainAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.circle,
                            size: 12,
                            color: _statusColor(patientStatus),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              _statusText(patientStatus),
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: _textColor),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${tr('Last update', 'آخر تحديث')}: $_lastUpdated',
                        style: TextStyle(
                          color: _subTextColor,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _sectionTitle(tr('Alerts', 'التنبيهات')),
          if (missedReminders.isEmpty)
            _card(
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      tr(
                        'No urgent alerts. Patient is doing well today.',
                        'لا توجد تنبيهات عاجلة. المريض بحالة جيدة اليوم.',
                      ),
                      style: TextStyle(fontSize: 15, color: _textColor),
                    ),
                  ),
                ],
              ),
            )
          else
            _card(
              child: Column(
                crossAxisAlignment: isArabic
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: missedReminders.map((item) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.warning_amber_rounded,
                          color: Colors.red,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            tr(
                              '${item.title} was missed at ${item.time}',
                              'تم تفويت ${item.title} في ${item.time}',
                            ),
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: _textColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          const SizedBox(height: 18),
          _sectionTitle(tr('Health Summary', 'ملخص الصحة')),
          _card(
            child: Wrap(
              alignment: WrapAlignment.spaceAround,
              runSpacing: 16,
              spacing: 12,
              children: [
                _healthItem(
                  Icons.favorite,
                  tr('Heart Rate', 'نبض القلب'),
                  '$heartRate BPM',
                ),
                _healthItem(Icons.mood, tr('Mood', 'المزاج'), mood),
                _healthItem(
                  Icons.bedtime,
                  tr('Sleep', 'النوم'),
                  '$sleepHours ${tr('Hours', 'ساعات')}',
                ),
                _healthItem(
                  Icons.water_drop,
                  tr('Water', 'الماء'),
                  '$waterCups ${tr('cups', 'أكواب')}',
                ),
                _healthItem(
                  Icons.fitness_center,
                  tr('Exercise', 'الرياضة'),
                  '$exerciseMinutes ${tr('min', 'دقيقة')}',
                ),
                _healthItem(
                  Icons.directions_walk,
                  tr('Walk', 'المشي'),
                  '$walkSteps ${tr('steps', 'خطوة')}',
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _sectionTitle(tr('Daily Care Progress', 'تقدم الرعاية اليومية')),
          _card(
            child: Column(
              crossAxisAlignment:
                  isArabic ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Text(
                  tr(
                    '$progressPercent% completed today',
                    'تم إنجاز $progressPercent% اليوم',
                  ),
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: progressColor,
                  ),
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: progress,
                  minHeight: 11,
                  borderRadius: BorderRadius.circular(20),
                  backgroundColor: Colors.grey,
                  color: progressColor,
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _sectionTitle(tr('Today Reminders', 'تذكيرات اليوم')),
          if (reminders.isEmpty)
            _card(
              child: Text(
                tr('No reminders added yet.', 'لا توجد تذكيرات مضافة بعد.'),
                style: TextStyle(color: _subTextColor),
              ),
            )
          else
            Column(
              children: reminders.take(3).map((item) {
                return _card(
                  child: Row(
                    children: [
                      Text(item.emoji, style: const TextStyle(fontSize: 30)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: isArabic
                              ? CrossAxisAlignment.end
                              : CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: _textColor,
                              ),
                            ),
                            Text(
                              '${item.day} - ${item.time}',
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                              style: TextStyle(color: _subTextColor),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: _reminderStatusColor(item.status)
                              .withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _reminderStatusText(item.status),
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: _reminderStatusColor(item.status),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          const SizedBox(height: 10),
          Align(
            alignment: isArabic ? Alignment.centerLeft : Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () {
                Navigator.pushNamed(context, '/companionReminders');
              },
              icon: const Icon(Icons.edit_calendar),
              label: Text(tr('Manage Reminders', 'إدارة التذكيرات')),
            ),
          ),
          const SizedBox(height: 18),
          _sectionTitle(tr('Location', 'الموقع')),
          _card(
            child: Row(
              children: [
                const Icon(Icons.location_on, color: Colors.red, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    tr(
                      '$patientName is currently near $location',
                      '$patientName حالياً بالقرب من $location',
                    ),
                    style: TextStyle(fontSize: 16, color: _textColor),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _sectionTitle(tr('AI Insights', 'تحليلات الذكاء الاصطناعي')),
          Column(
            children: aiInsights.map((insight) {
              return _card(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(insight['icon'], color: insight['color'], size: 34),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: isArabic
                            ? CrossAxisAlignment.end
                            : CrossAxisAlignment.start,
                        children: [
                          Text(
                            insight['title'],
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: insight['color'],
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            insight['message'],
                            textAlign:
                                isArabic ? TextAlign.right : TextAlign.left,
                            style: TextStyle(fontSize: 14, color: _textColor),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 18),
          _sectionTitle(tr('Quick Actions', 'إجراءات سريعة')),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final bool smallScreen = constraints.maxWidth < 360;
              final bool wideScreen = constraints.maxWidth >= 900;

              return GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: smallScreen ? 1 : (wideScreen ? 4 : 2),
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                childAspectRatio:
                    smallScreen ? 2.25 : (wideScreen ? 1.65 : 1.15),
                children: [
                  _quickActionCard(
                    icon: Icons.call_rounded,
                    title: tr('Call Patient', 'الاتصال بالمريض'),
                    description: tr(
                      'Contact the patient directly in case you need to check on them.',
                      'اتصل بالمريض مباشرة للاطمئنان عليه عند الحاجة.',
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CallPatientPage(
                            patientName: patientName,
                            phoneNumber: patientPhoneNumber,
                          ),
                        ),
                      );
                    },
                  ),
                  _quickActionCard(
                    icon: Icons.chat_bubble_rounded,
                    title: tr('Message', 'الرسائل'),
                    description: tr(
                      'Send a quick message to the patient or start a chat.',
                      'أرسل رسالة سريعة أو ابدأ محادثة مع المريض.',
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CompanionPatientChatPage(
                            patientUid: patientUid,
                            patientName: patientName,
                            companionName: companionName,
                          ),
                        ),
                      );
                    },
                  ),
                  _quickActionCard(
                    icon: Icons.warning_amber_rounded,
                    iconColor: Colors.red,
                    title: tr('Emergency Actions', 'إجراءات الطوارئ'),
                    description: tr(
                      'Access emergency contacts, live location, and urgent patient information.',
                      'الوصول إلى جهات الطوارئ والموقع المباشر ومعلومات المريض المهمة.',
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CompanionEmergencyPage(
                            patientName: patientName,
                            phoneNumber: patientPhoneNumber,
                            location: location,
                            heartRate: heartRate,
                            mood: mood,
                            patientStatus: patientStatus,
                            lastUpdated: _lastUpdated,
                          ),
                        ),
                      );
                    },
                  ),
                  _quickActionCard(
                    icon: Icons.add_alert_rounded,
                    title: tr('Add Reminder', 'إضافة تذكير'),
                    description: tr(
                      'Create a medicine, meal, or appointment reminder for the patient.',
                      'إنشاء تذكير دواء أو وجبة أو موعد للمريض.',
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CompanionRemindersPage(),
                        ),
                      );
                    },
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 18),
          _sectionTitle(tr('Daily Report', 'التقرير اليومي')),
          _card(
            child: Column(
              children: [
                Row(
                  children: [
                    _buildReportTab('Daily', tr('Daily', 'يومي')),
                    const SizedBox(width: 8),
                    _buildReportTab('Weekly', tr('Weekly', 'أسبوعي')),
                    const SizedBox(width: 8),
                    _buildReportTab('Monthly', tr('Monthly', 'شهري')),
                  ],
                ),
                const SizedBox(height: 18),
                _buildReportContent(reminders, aiReports),
              ],
            ),
          ),
          const SizedBox(height: 25),
        ],
      ),
    );
  }

  Widget _buildLinkedDashboardWithStream() {
    return StreamBuilder<PatientDashboardProfile>(
      stream: _patientProfileStream(),
      builder: (context, profileSnapshot) {
        if (profileSnapshot.connectionState == ConnectionState.waiting &&
            profileSnapshot.data == null) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF87CEEB)),
          );
        }

        if (profileSnapshot.hasData) {
          _applyProfileToLocalState(profileSnapshot.data!);
        }

        return StreamBuilder<List<CompanionReminder>>(
          stream: _patientRemindersStream(),
          builder: (context, remindersSnapshot) {
            if (remindersSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: Color(0xFF87CEEB)),
              );
            }

            final reminders = remindersSnapshot.data ?? [];

            return StreamBuilder<List<HealthAIReport>>(
              stream: _healthAIReportsStream(),
              builder: (context, aiSnapshot) {
                final aiReports = aiSnapshot.data ?? [];

                return _buildLinkedDashboard(reminders, aiReports);
              },
            );
          },
        );
      },
    );
  }

  Widget _buildBodyContent() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFF87CEEB),
        ),
      );
    }

    if (!_isLinkedToPatient) {
      return _buildNotLinkedView();
    }

    return _buildLinkedDashboardWithStream();
  }

  Widget _responsiveBodyWrapper(Widget child, BoxConstraints constraints) {
    // Full-width layout for web/tablet screens instead of locking the page
    // inside a small mobile-width container.
    return SizedBox(
      width: double.infinity,
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
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
              backgroundColor: _backgroundColor,
              body: SafeArea(
                child: Column(
                  children: [
                    _buildTopHeader(),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return _responsiveBodyWrapper(
                            ConstrainedBox(
                              constraints: BoxConstraints(
                                minHeight: constraints.maxHeight,
                              ),
                              child: _buildBodyContent(),
                            ),
                            constraints,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              bottomNavigationBar: _buildBottomNavigation(),
            ),
          ),
        );
      },
    );
  }
}

class HumanTouchPageShell extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? bottomBar;

  const HumanTouchPageShell({
    super.key,
    required this.title,
    required this.child,
    this.bottomBar,
  });

  Widget _topHeader(BuildContext context) {
    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        Container(
          height: 130,
          width: double.infinity,
          color: const Color(0xFF87CEEB),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.maybePop(context),
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                  ),
                  Expanded(
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
          ),
        ),
        Container(
          height: 40,
          width: double.infinity,
          decoration: const BoxDecoration(
            color: Color(0xFFF4F4F4),
            borderRadius: BorderRadius.vertical(top: Radius.circular(40)),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F4F4),
      body: Column(
        children: [
          _topHeader(context),
          Expanded(child: child),
        ],
      ),
      bottomNavigationBar: bottomBar,
    );
  }
}

class CallPatientPage extends StatelessWidget {
  final String patientName;
  final String phoneNumber;

  const CallPatientPage({
    super.key,
    required this.patientName,
    required this.phoneNumber,
  });

  Future<void> _callPatient(BuildContext context) async {
    final cleanedPhone = phoneNumber.trim();

    if (cleanedPhone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Patient phone number is not available.')),
      );
      return;
    }

    final uri = Uri(scheme: 'tel', path: cleanedPhone);

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the phone dialer.')),
      );
    }
  }

  Widget _infoCard({
    required IconData icon,
    required String title,
    required String subtitle,
    Color iconColor = const Color(0xFF2D9CDB),
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: iconColor.withOpacity(0.12),
            child: Icon(icon, color: iconColor, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black54,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayPhone =
        phoneNumber.trim().isEmpty ? 'No phone number saved' : phoneNumber;

    return HumanTouchPageShell(
      title: 'Call Patient',
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          children: [
            _infoCard(
              icon: Icons.person_rounded,
              title: patientName,
              subtitle: 'Patient profile selected for direct contact.',
            ),
            const SizedBox(height: 16),
            _infoCard(
              icon: Icons.phone_rounded,
              title: 'Phone Number',
              subtitle: displayPhone,
            ),
            const SizedBox(height: 26),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton.icon(
                onPressed: () => _callPatient(context),
                icon: const Icon(Icons.call, color: Colors.white),
                label: const Text(
                  'Call Now',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2D9CDB),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CompanionPatientChatPage extends StatefulWidget {
  final String patientUid;
  final String patientName;
  final String companionName;

  const CompanionPatientChatPage({
    super.key,
    required this.patientUid,
    required this.patientName,
    required this.companionName,
  });

  @override
  State<CompanionPatientChatPage> createState() =>
      _CompanionPatientChatPageState();
}

class _CompanionPatientChatPageState extends State<CompanionPatientChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool _isSending = false;

  String get _currentUserId => FirebaseAuth.instance.currentUser?.uid ?? '';

  String get _chatId {
    final ids = [_currentUserId, widget.patientUid]
        .where((id) => id.trim().isNotEmpty)
        .map((id) => id.trim())
        .toList()
      ..sort();

    if (ids.length == 2) return '${ids[0]}_${ids[1]}';
    if (ids.length == 1) return '${ids[0]}_companion_chat';
    return 'unknown_companion_chat';
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  bool _boolFromDynamic(dynamic value) {
    if (value is bool) return value;

    final text = value.toString().trim().toLowerCase();

    return text == 'true' ||
        text == 'active' ||
        text == 'online' ||
        text == '1' ||
        text == 'yes';
  }

  bool _isUserOnline(Map<String, dynamic> data) {
    return _boolFromDynamic(
      data['isActive'] ??
          data['active'] ??
          data['online'] ??
          data['isOnline'] ??
          data['accountActive'] ??
          data['patientActive'],
    );
  }

  String _displayNameFromData(Map<String, dynamic> data) {
    final name = (data['name'] ?? data['fullName'] ?? data['username'] ?? '')
        .toString()
        .trim();

    return name.isEmpty ? widget.patientName : name;
  }

  String _imageFromData(Map<String, dynamic> data) {
    return (data['profileImageBase64'] ??
            data['profileImage'] ??
            data['imageBase64'] ??
            data['photoBase64'] ??
            data['photoUrl'] ??
            data['profileImageUrl'] ??
            '')
        .toString()
        .trim();
  }

  Widget _profileAvatar(String imageValue, bool isOnline) {
    Widget imageChild;

    if (imageValue.isNotEmpty && imageValue.startsWith('http')) {
      imageChild = ClipOval(
        child: Image.network(
          imageValue,
          width: 58,
          height: 58,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const Icon(
            Icons.person_rounded,
            color: Color(0xFF2D9CDB),
            size: 32,
          ),
        ),
      );
    } else if (imageValue.isNotEmpty) {
      try {
        imageChild = ClipOval(
          child: Image.memory(
            base64Decode(imageValue),
            width: 58,
            height: 58,
            fit: BoxFit.cover,
          ),
        );
      } catch (_) {
        imageChild = const Icon(
          Icons.person_rounded,
          color: Color(0xFF2D9CDB),
          size: 32,
        );
      }
    } else {
      imageChild = const Icon(
        Icons.person_rounded,
        color: Color(0xFF2D9CDB),
        size: 32,
      );
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        CircleAvatar(
          radius: 29,
          backgroundColor: const Color(0xFFEAF8FD),
          child: imageChild,
        ),
        Positioned(
          right: 1,
          bottom: 2,
          child: Container(
            width: 13,
            height: 13,
            decoration: BoxDecoration(
              color: isOnline ? Colors.green : Colors.red,
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFF4F4F4), width: 2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _chatHeader(Map<String, dynamic> patientData) {
    final displayName = _displayNameFromData(patientData);
    final isOnline = _isUserOnline(patientData);
    final imageValue = _imageFromData(patientData);

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
              decoration: const BoxDecoration(
                color: Color(0xFFF4F4F4),
                borderRadius: BorderRadius.vertical(top: Radius.circular(40)),
              ),
            ),
          ],
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          color: const Color(0xFFF4F4F4),
          child: Row(
            children: [
              IconButton(
                onPressed: () => Navigator.maybePop(context),
                icon: const Icon(Icons.arrow_back, size: 28),
              ),
              const SizedBox(width: 8),
              _profileAvatar(imageValue, isOnline),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isOnline ? 'Online' : 'Offline',
                      style: TextStyle(
                        color: isOnline ? Colors.green : Colors.red,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();

    if (text.isEmpty ||
        _isSending ||
        _currentUserId.isEmpty ||
        widget.patientUid.isEmpty) {
      return;
    }

    setState(() => _isSending = true);

    try {
      final chatRef =
          FirebaseFirestore.instance.collection('patient_chats').doc(_chatId);

      final messageData = {
        'text': text,
        'message': text,
        'senderId': _currentUserId,
        'senderName': widget.companionName,
        'senderRole': 'companion',
        'receiverId': widget.patientUid,
        'receiverName': widget.patientName,
        'receiverRole': 'patient',
        'patientId': widget.patientUid,
        'companionId': _currentUserId,
        'createdAt': FieldValue.serverTimestamp(),
        'isRead': false,
      };

      final participants = ([_currentUserId, widget.patientUid]
          .where((id) => id.trim().isNotEmpty)
          .map((id) => id.trim())
          .toList()
        ..sort());

      await chatRef.set({
        'chatId': _chatId,
        'patientId': widget.patientUid,
        'companionId': _currentUserId,
        'participants': participants,
        'lastMessage': text,
        'lastSenderId': _currentUserId,
        'lastSenderRole': 'companion',
        'lastMessageAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await chatRef.collection('messages').add(messageData);

      await FirebaseFirestore.instance.collection('notifications').add({
        'userId': widget.patientUid,
        'receiverId': widget.patientUid,
        'senderId': _currentUserId,
        'senderName': widget.companionName,
        'senderRole': 'companion',
        'type': 'companion_chat_message',
        'title': 'New message from companion',
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
      debugPrint('Error sending companion message: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not send message. Check Firestore rules.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> _patientDocStream() {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(widget.patientUid)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _messagesStream() {
    if (_currentUserId.isEmpty || widget.patientUid.isEmpty) {
      return const Stream.empty();
    }

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

  Widget _messageBubble(Map<String, dynamic> data) {
    final isMe = data['senderId'] == _currentUserId;
    final message = (data['text'] ?? data['message'] ?? '').toString();
    final time = _formatTime(data['createdAt']);

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 430),
        margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 18),
        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 14),
        decoration: BoxDecoration(
          color: isMe ? const Color(0xFF87CEEB) : const Color(0xFFEAF8FD),
          borderRadius: BorderRadius.circular(18),
          border: isMe ? null : Border.all(color: Colors.black12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              message,
              textAlign: isMe ? TextAlign.right : TextAlign.left,
              style: TextStyle(
                color: isMe ? Colors.white : Colors.black87,
                fontSize: 14.5,
                height: 1.35,
              ),
            ),
            if (time.isNotEmpty) const SizedBox(height: 4),
            if (time.isNotEmpty)
              Text(
                time,
                style: TextStyle(
                  color: isMe ? Colors.white70 : Colors.blueGrey,
                  fontSize: 10.5,
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.patientUid.trim().isEmpty) {
      return const HumanTouchPageShell(
        title: 'Message',
        child: Center(child: Text('Patient account is not linked.')),
      );
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _patientDocStream(),
      builder: (context, patientSnapshot) {
        final patientData = patientSnapshot.data?.data() ?? {};

        return Scaffold(
          backgroundColor: const Color(0xFFF4F4F4),
          body: Column(
            children: [
              _chatHeader(patientData),
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _messagesStream(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF87CEEB),
                        ),
                      );
                    }

                    final messages = snapshot.data?.docs ?? [];

                    if (messages.isEmpty) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'No messages yet. Send a quick message to start the chat.',
                            textAlign: TextAlign.center,
                            style:
                                TextStyle(color: Colors.black54, fontSize: 15),
                          ),
                        ),
                      );
                    }

                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (_scrollController.hasClients) {
                        _scrollController.jumpTo(
                          _scrollController.position.maxScrollExtent,
                        );
                      }
                    });

                    return ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        return _messageBubble(messages[index].data());
                      },
                    );
                  },
                ),
              ),
              SafeArea(
                top: false,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                  color: Colors.white,
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          minLines: 1,
                          maxLines: 4,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _sendMessage(),
                          decoration: InputDecoration(
                            hintText: 'Write a message...',
                            filled: true,
                            fillColor: const Color(0xFFF4F4F4),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 14,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(18),
                              borderSide: BorderSide.none,
                            ),
                          ),
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
                              : const Icon(Icons.send, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class CompanionEmergencyPage extends StatelessWidget {
  final String patientName;
  final String phoneNumber;
  final String location;
  final int heartRate;
  final String mood;
  final String patientStatus;
  final String lastUpdated;

  const CompanionEmergencyPage({
    super.key,
    required this.patientName,
    required this.phoneNumber,
    required this.location,
    required this.heartRate,
    required this.mood,
    required this.patientStatus,
    required this.lastUpdated,
  });

  Future<void> _callPhone(BuildContext context, String number) async {
    final cleanedPhone = number.trim();

    if (cleanedPhone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Phone number is not available.')),
      );
      return;
    }

    final uri = Uri(scheme: 'tel', path: cleanedPhone);

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the phone dialer.')),
      );
    }
  }

  Widget _emergencyCard({
    required IconData icon,
    required String title,
    required String subtitle,
    Color iconColor = const Color(0xFF2D9CDB),
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 25,
              backgroundColor: iconColor.withOpacity(0.12),
              child: Icon(icon, color: iconColor, size: 27),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color:
                          iconColor == Colors.red ? Colors.red : Colors.black87,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Colors.black54,
                      height: 1.35,
                      fontSize: 14,
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

  Color _statusColor() {
    final text = patientStatus.toLowerCase();
    return text.contains('active') && !text.contains('non')
        ? Colors.green
        : Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    final displayPhone =
        phoneNumber.trim().isEmpty ? 'No phone number saved' : phoneNumber;

    return HumanTouchPageShell(
      title: 'Emergency Actions',
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          children: [
            _emergencyCard(
              icon: Icons.warning_amber_rounded,
              iconColor: Colors.red,
              title: 'Urgent Support',
              subtitle:
                  'Access emergency contacts, live location, and urgent patient information.',
            ),
            _emergencyCard(
              icon: Icons.person_rounded,
              title: 'Patient',
              subtitle: patientName,
            ),
            _emergencyCard(
              icon: Icons.circle,
              iconColor: _statusColor(),
              title: 'Current Status',
              subtitle: '$patientStatus • Last update: $lastUpdated',
            ),
            _emergencyCard(
              icon: Icons.phone_rounded,
              title: 'Emergency Contact',
              subtitle: displayPhone,
              onTap: () => _callPhone(context, phoneNumber),
            ),
            _emergencyCard(
              icon: Icons.location_on_rounded,
              iconColor: Colors.red,
              title: 'Live Location',
              subtitle: location.isEmpty ? 'No location available' : location,
            ),
            _emergencyCard(
              icon: Icons.favorite_rounded,
              iconColor: heartRate > 110 ? Colors.red : const Color(0xFF2D9CDB),
              title: 'Urgent Patient Information',
              subtitle: 'Heart Rate: $heartRate BPM\nMood: $mood',
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton.icon(
                onPressed: () => _callPhone(context, phoneNumber),
                icon: const Icon(Icons.call, color: Colors.white),
                label: const Text(
                  'Call Patient Now',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
