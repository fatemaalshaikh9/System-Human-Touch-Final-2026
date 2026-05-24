import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:ui' as ui;

import 'Reminders_page.dart';
import 'Health_page.dart';
import 'Communication_page.dart';
import 'Emergency_page.dart';
import 'Map_page.dart';
import 'VolunteerHelp_page.dart';
import 'Profile_page.dart';
import 'Settings_page.dart';
import 'voice_accessibility_service.dart';

import 'package:humantouch/pages/app_settings_store.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  String _userName = 'User';
  bool _accessibilityPopupShown = false;
  bool _voiceAssistantStarted = false;
  bool _isSpeaking = false;
  bool _isAccessibilityPopupOpen = false;

  bool get isArabic => AppSettingsStore.instance.isArabic;

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

  Color get backgroundColor => Theme.of(context).scaffoldBackgroundColor;

  Color get cardColor => Theme.of(context).cardColor;

  Color get textColor =>
      Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;

  Color get subTextColor =>
      Theme.of(context).textTheme.bodyMedium?.color ?? Colors.black54;

  Color get innerBoxColor =>
      Theme.of(context).inputDecorationTheme.fillColor ??
      const Color(0xFFF4F4F4);

  String tr(String en, String ar) {
    return isArabic ? ar : en;
  }

  @override
  void initState() {
    super.initState();
    _loadUserName();

    AppSettingsStore.instance.addListener(_onLanguageChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!_accessibilityPopupShown && mounted) {
        _accessibilityPopupShown = true;

        if (isAccessibilityVoiceEnabled) {
          _isAccessibilityPopupOpen = true;
          await VoiceAccessibilityService.instance.speak(
            tr(
              'Accessibility options popup. You can choose Later or Open Settings.',
              'نافذة خيارات الوصول. يمكنك اختيار لاحقًا أو فتح الإعدادات.',
            ),
          );
        }

        await _showAccessibilityPopup();

        _isAccessibilityPopupOpen = false;
      }

      if (mounted && isAccessibilityVoiceEnabled) {
        await _startVoiceAccessibilityAssistant();
      }
    });
  }

  Future<void> _startVoiceAccessibilityAssistant() async {
    if (!mounted) return;

    if (_voiceAssistantStarted && _isSpeaking) return;

    _voiceAssistantStarted = true;

    await VoiceAccessibilityService.instance.stopAll();

    if (!mounted) return;

    setState(() {
      _isSpeaking = true;
    });

    String remindersText = '';

    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user != null) {
        final today = _getTodayName();

        final snapshot = await FirebaseFirestore.instance
            .collection('reminders')
            .where('patientId', isEqualTo: user.uid)
            .where('day', isEqualTo: today)
            .get();

        if (snapshot.docs.isEmpty) {
          remindersText = tr(
            ' There are no reminders for today.',
            ' لا توجد تذكيرات لهذا اليوم.',
          );
        } else {
          final reminders = snapshot.docs.toList();

          reminders.sort((a, b) {
            final aData = a.data();
            final bData = b.data();

            final aDateTime = aData['reminderAt'];
            final bDateTime = bData['reminderAt'];

            if (aDateTime is Timestamp && bDateTime is Timestamp) {
              return aDateTime.toDate().compareTo(bDateTime.toDate());
            }

            final aTime = (aData['time'] ?? '').toString();
            final bTime = (bData['time'] ?? '').toString();

            return aTime.compareTo(bTime);
          });

          final reminderTitles = reminders.map((doc) {
            final data = doc.data();
            final title = (data['title'] ?? tr('Reminder', 'تذكير')).toString();
            final time = (data['time'] ?? '').toString();

            if (time.trim().isEmpty) {
              return title;
            }

            return tr('$title at $time', '$title في $time');
          }).join(', ');

          remindersText = tr(
            ' Today’s reminders are: $reminderTitles.',
            ' تذكيرات اليوم هي: $reminderTitles.',
          );
        }
      } else {
        remindersText = tr(
          ' Please log in to see reminders.',
          ' يرجى تسجيل الدخول لعرض التذكيرات.',
        );
      }
    } catch (_) {
      remindersText = tr(
        ' I could not read today’s reminders right now.',
        ' لم أتمكن من قراءة تذكيرات اليوم الآن.',
      );
    }

    if (!mounted) return;

    await VoiceAccessibilityService.instance.readPageAndListen(
      context: context,
      pageText: tr(
        'Human Touch home screen with reminders, health, communication, emergency, map, volunteer help, profile, and settings options.$remindersText You can say reminders, health, communication, emergency, map, volunteer help, profile, or settings.',
        'الصفحة الرئيسية في Human Touch تحتوي على التذكيرات والصحة والتواصل والطوارئ والخريطة ومساعدة المتطوعين والملف الشخصي والإعدادات.$remindersText يمكنك قول التذكيرات أو الصحة أو التواصل أو الطوارئ أو الخريطة أو مساعدة المتطوعين أو الملف الشخصي أو الإعدادات.',
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

  void _onLanguageChanged() {
    if (mounted) {
      setState(() {});

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (isAccessibilityVoiceEnabled) {
          _startVoiceAccessibilityAssistant();
        }
      });
    }
  }

  @override
  void dispose() {
    AppSettingsStore.instance.removeListener(_onLanguageChanged);
    VoiceAccessibilityService.instance.stopAll();
    super.dispose();
  }

  Future<void> _loadUserName() async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user != null) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (!mounted) return;

        setState(() {
          _userName = doc.data()?['name'] ?? 'User';
        });
      }
    } catch (e) {
      if (!mounted) return;
      _showInternetConnectionPopup();
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;

    if (hour < 12) {
      return tr('Good Morning', 'صباح الخير');
    } else {
      return tr('Good Evening', 'مساء الخير');
    }
  }

  String _getTodayName() {
    return DateFormat('EEEE', 'en').format(DateTime.now());
  }

  ButtonStyle _iconTapStyle() {
    return ButtonStyle(
      overlayColor: WidgetStateProperty.resolveWith<Color?>((states) {
        if (states.contains(WidgetState.pressed)) {
          return Colors.grey.withOpacity(0.20);
        }
        return null;
      }),
      padding: WidgetStateProperty.all(EdgeInsets.zero),
      minimumSize: WidgetStateProperty.all(Size.zero),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  void _goToPage(int index) {
    VoiceAccessibilityService.instance.stopAll();

    if (index == 0) return;

    if (index == 1) {
      Navigator.pushReplacementNamed(context, '/profile');
    } else if (index == 2) {
      Navigator.pushReplacementNamed(context, '/settings');
    }
  }

  Future<void> _showAppDialog({
    required String title,
    required String message,
    required IconData icon,
    required Color iconColor,
    String? confirmText,
    String? cancelText,
    VoidCallback? onConfirm,
    bool showCancel = false,
  }) async {
    if (!mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return Directionality(
          textDirection: isArabic ? ui.TextDirection.rtl : ui.TextDirection.ltr,
          child: AlertDialog(
            backgroundColor: cardColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
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
              if (showCancel)
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: Text(
                    cancelText ?? tr('Cancel', 'إلغاء'),
                    style: TextStyle(color: subTextColor),
                  ),
                ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF87CEEB),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  if (onConfirm != null) {
                    onConfirm();
                  }
                },
                child: Text(confirmText ?? tr('OK', 'حسنًا')),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showSuccessPopup(String message) {
    _showAppDialog(
      title: tr('Success', 'تم بنجاح'),
      message: message,
      icon: Icons.check_circle_rounded,
      iconColor: Colors.green,
    );
  }

  void _showInternetConnectionPopup() {
    _showAppDialog(
      title: tr('Connection Error', 'خطأ في الاتصال'),
      message: tr(
        'No internet connection or the data could not be loaded. Some services may not work properly.',
        'لا يوجد اتصال بالإنترنت أو تعذر تحميل البيانات. قد لا تعمل بعض الخدمات بشكل صحيح.',
      ),
      icon: Icons.wifi_off_rounded,
      iconColor: Colors.orange,
    );
  }

  Future<void> _showAccessibilityPopup() async {
    await _showAppDialog(
      title: tr('Accessibility Options', 'خيارات الوصول'),
      message: tr(
        'You can use accessibility features such as dark mode, larger text, and language settings from the Settings page.',
        'يمكنك استخدام ميزات الوصول مثل الوضع الليلي، تكبير الخط، وتغيير اللغة من صفحة الإعدادات.',
      ),
      icon: Icons.accessibility_new_rounded,
      iconColor: const Color(0xFF87CEEB),
      confirmText: tr('Open Settings', 'فتح الإعدادات'),
      cancelText: tr('Later', 'لاحقًا'),
      showCancel: true,
      onConfirm: () {
        VoiceAccessibilityService.instance.stopAll();

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const SettingsPage()),
        );
      },
    );
  }

  void _showEmergencyConfirmationPopup() {
    VoiceAccessibilityService.instance.stopAll();

    _showAppDialog(
      title: tr('Emergency Alert', 'تنبيه الطوارئ'),
      message: tr(
        'Do you want to open the emergency page? You can send your location and notify your companion.',
        'هل تريد فتح صفحة الطوارئ؟ يمكنك إرسال موقعك الحالي وإشعار المرافق.',
      ),
      icon: Icons.warning_amber_rounded,
      iconColor: Colors.red,
      confirmText: tr('Yes', 'نعم'),
      cancelText: tr('Cancel', 'إلغاء'),
      showCancel: true,
      onConfirm: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const EmergencyPage()),
        );
      },
    );
  }

  void _showReminderCompletedPopup({
    required String reminderId,
    required String reminderTitle,
  }) {
    VoiceAccessibilityService.instance.stopAll();

    _showAppDialog(
      title: tr('Reminder Completed', 'تم إنجاز التذكير'),
      message: tr(
        'Did you complete "$reminderTitle"? Do you want to mark it as completed?',
        'هل أنجزت "$reminderTitle"؟ هل تريد وضعه كمكتمل؟',
      ),
      icon: Icons.task_alt_rounded,
      iconColor: Colors.green,
      confirmText: tr('Done', 'تم'),
      cancelText: tr('Later', 'لاحقًا'),
      showCancel: true,
      onConfirm: () async {
        try {
          await FirebaseFirestore.instance
              .collection('reminders')
              .doc(reminderId)
              .update({
            'status': 'accepted',
            'completedAt': FieldValue.serverTimestamp(),
          });

          if (!mounted) return;

          _showSuccessPopup(
            tr(
              'Reminder marked as completed successfully.',
              'تم وضع التذكير كمكتمل بنجاح.',
            ),
          );
        } catch (e) {
          if (!mounted) return;

          _showAppDialog(
            title: tr('Error', 'خطأ'),
            message: tr(
              'Something went wrong while updating the reminder.',
              'حدث خطأ أثناء تحديث التذكير.',
            ),
            icon: Icons.error_outline_rounded,
            iconColor: Colors.red,
          );
        }
      },
    );
  }

  Widget _buildTopReminderCard() {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Container(
        width: double.infinity,
        height: 180,
        decoration: BoxDecoration(
          color: cardColor,
          boxShadow: _shadow(),
          borderRadius: BorderRadius.circular(25),
        ),
        child: Center(
          child: Text(
            tr(
              'Please login to see reminders',
              'يرجى تسجيل الدخول لعرض التذكيرات',
            ),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: subTextColor,
            ),
          ),
        ),
      );
    }

    final today = _getTodayName();

    return Container(
      width: double.infinity,
      height: 180,
      decoration: BoxDecoration(
        color: cardColor,
        boxShadow: _shadow(),
        borderRadius: BorderRadius.circular(25),
      ),
      padding: const EdgeInsets.all(18),
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('reminders')
            .where('patientId', isEqualTo: user.uid)
            .where('day', isEqualTo: today)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _showInternetConnectionPopup();
              }
            });

            return Center(
              child: Text(
                tr('Error loading reminders', 'حدث خطأ في تحميل التذكيرات'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: subTextColor,
                ),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF87CEEB)),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Text(
                tr('No reminders for today', 'لا توجد تذكيرات لهذا اليوم'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: subTextColor,
                ),
              ),
            );
          }

          final reminders = snapshot.data!.docs.toList();

          reminders.sort((a, b) {
            final aData = a.data();
            final bData = b.data();

            final aDateTime = aData['reminderAt'];
            final bDateTime = bData['reminderAt'];

            if (aDateTime is Timestamp && bDateTime is Timestamp) {
              return aDateTime.toDate().compareTo(bDateTime.toDate());
            }

            final aTime = (aData['time'] ?? '').toString();
            final bTime = (bData['time'] ?? '').toString();

            return aTime.compareTo(bTime);
          });

          return Column(
            crossAxisAlignment:
                isArabic ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Text(
                tr('Today’s Reminders', 'تذكيرات اليوم'),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.separated(
                  padding: EdgeInsets.zero,
                  itemCount: reminders.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final doc = reminders[index];
                    final data = doc.data();

                    final String emoji = data['emoji'] ?? '🔔';
                    final String title =
                        data['title'] ?? tr('Reminder', 'تذكير');
                    final String time = data['time'] ?? '';
                    final String status = data['status'] ?? 'pending';

                    return InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        _showReminderCompletedPopup(
                          reminderId: doc.id,
                          reminderTitle: title,
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: innerBoxColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                '$emoji $title • $time',
                                textAlign:
                                    isArabic ? TextAlign.right : TextAlign.left,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color:
                                      (status == 'accepted' || status == 'done')
                                          ? Colors.green
                                          : textColor,
                                  decoration:
                                      (status == 'accepted' || status == 'done')
                                          ? TextDecoration.lineThrough
                                          : TextDecoration.none,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              (status == 'accepted' || status == 'done')
                                  ? Icons.check_circle_rounded
                                  : Icons.radio_button_unchecked_rounded,
                              color: (status == 'accepted' || status == 'done')
                                  ? Colors.green
                                  : const Color(0xFF87CEEB),
                              size: 22,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFeatureItem({
    required BuildContext context,
    required String label,
    required String imagePath,
    required String routeName,
    double imageWidth = 70,
    double imageHeight = 70,
    VoidCallback? onTap,
  }) {
    void handleTap() {
      VoiceAccessibilityService.instance.stopAll();

      if (onTap != null) {
        onTap();
      } else {
        Navigator.pushNamed(context, routeName);
      }
    }

    return SizedBox(
      width: 105,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextButton(
            style: _iconTapStyle(),
            onPressed: handleTap,
            child: Container(
              width: 78,
              height: 78,
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(8),
                boxShadow: _shadow(),
              ),
              child: Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset(
                    imagePath,
                    width: imageWidth,
                    height: imageHeight,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          TextButton(
            style: _iconTapStyle(),
            onPressed: handleTap,
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bottomItem(IconData icon, String label, int index) {
    return GestureDetector(
      onTap: () => _goToPage(index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 27),
          const SizedBox(height: 3),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
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

  Widget _buildHeader() {
    return Stack(
      alignment: Alignment.topCenter,
      children: [
        Container(
          width: double.infinity,
          height: 130,
          color: const Color(0xFF87CEEB),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 100),
          child: Container(
            width: double.infinity,
            height: 41,
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(70),
                topRight: Radius.circular(70),
              ),
            ),
          ),
        ),
      ],
    );
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

  Widget _buildFeaturesGrid() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(15, 30, 15, 15),
      child: Wrap(
        alignment: WrapAlignment.spaceAround,
        runAlignment: WrapAlignment.center,
        spacing: 10,
        runSpacing: 18,
        children: [
          _buildFeatureItem(
            context: context,
            label: tr('Reminders', 'التذكيرات'),
            imagePath: 'assets/Reminder.png',
            routeName: '/reminders',
          ),
          _buildFeatureItem(
            context: context,
            label: tr('Health', 'الصحة'),
            imagePath: 'assets/Health.png',
            routeName: '/health',
            imageHeight: 60,
          ),
          _buildFeatureItem(
            context: context,
            label: tr('Communication', 'التواصل'),
            imagePath: 'assets/communication.png',
            routeName: '/communication',
            imageWidth: 100,
            imageHeight: 100,
          ),
          _buildFeatureItem(
            context: context,
            label: tr('Emergency', 'الطوارئ'),
            imagePath: 'assets/Emergency.png',
            routeName: '/emergency',
            onTap: _showEmergencyConfirmationPopup,
          ),
          _buildFeatureItem(
            context: context,
            label: tr('Map', 'الخريطة'),
            imagePath: 'assets/map.png',
            routeName: '/map',
          ),
          _buildFeatureItem(
            context: context,
            label: tr('Volunteer\nHelp', 'مساعدة\nالمتطوعين'),
            imagePath: 'assets/volunteer.png',
            routeName: '/volunteerHelp',
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: isArabic ? ui.TextDirection.rtl : ui.TextDirection.ltr,
      child: GestureDetector(
        onTap: () {
          FocusScope.of(context).unfocus();
        },
        child: Scaffold(
          backgroundColor: backgroundColor,
          body: Stack(
            children: [
              SafeArea(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight,
                        ),
                        child: Column(
                          children: [
                            _buildHeader(),
                            Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(30, 10, 30, 15),
                              child: Align(
                                alignment: isArabic
                                    ? Alignment.centerRight
                                    : Alignment.centerLeft,
                                child: Text(
                                  '${_getGreeting()}, $_userName',
                                  textAlign: isArabic
                                      ? TextAlign.right
                                      : TextAlign.left,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.bold,
                                    color: textColor,
                                  ),
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(30, 0, 30, 0),
                              child: _buildTopReminderCard(),
                            ),
                            _buildFeaturesGrid(),
                            const SizedBox(height: 90),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              _voiceControlButton(),
            ],
          ),
          bottomNavigationBar: SafeArea(
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
                  _bottomItem(
                    Icons.settings_rounded,
                    tr('Settings', 'الإعدادات'),
                    2,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
