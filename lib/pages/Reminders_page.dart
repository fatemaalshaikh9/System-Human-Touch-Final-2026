import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'Dashboard_page.dart';
import 'Profile_page.dart';
import 'Settings_page.dart';
import 'voice_accessibility_service.dart';

import 'package:humantouch/pages/app_settings_store.dart';

class RemindersPage extends StatefulWidget {
  const RemindersPage({super.key});

  @override
  State<RemindersPage> createState() => _RemindersPageState();
}

class _RemindersPageState extends State<RemindersPage> {
  String _selectedDay = '';

  bool _isSpeaking = false;

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

  final List<String> _days = const [
    'Sunday',
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
  ];

  bool get isArabic => AppSettingsStore.instance.isArabic;

  Color get backgroundColor => Theme.of(context).scaffoldBackgroundColor;

  Color get cardColor => Theme.of(context).cardColor;

  Color get textColor =>
      Theme.of(context).textTheme.bodyLarge?.color ?? const Color(0xFF333333);

  Color get subTextColor => Colors.grey;

  Color get borderColor => Colors.transparent;

  String tr(String en, String ar) => isArabic ? ar : en;

  String _dayFromDate(DateTime date) {
    switch (date.weekday) {
      case DateTime.monday:
        return 'Monday';
      case DateTime.tuesday:
        return 'Tuesday';
      case DateTime.wednesday:
        return 'Wednesday';
      case DateTime.thursday:
        return 'Thursday';
      case DateTime.friday:
        return 'Friday';
      case DateTime.saturday:
        return 'Saturday';
      case DateTime.sunday:
      default:
        return 'Sunday';
    }
  }

  String dayName(String day) {
    switch (day) {
      case 'Sunday':
        return tr('Sunday', 'الأحد');
      case 'Monday':
        return tr('Monday', 'الاثنين');
      case 'Tuesday':
        return tr('Tuesday', 'الثلاثاء');
      case 'Wednesday':
        return tr('Wednesday', 'الأربعاء');
      case 'Thursday':
        return tr('Thursday', 'الخميس');
      case 'Friday':
        return tr('Friday', 'الجمعة');
      case 'Saturday':
        return tr('Saturday', 'السبت');
      default:
        return day;
    }
  }

  @override
  void initState() {
    super.initState();
    _selectedDay = _dayFromDate(DateTime.now());
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

  @override
  void dispose() {
    AppSettingsStore.instance.removeListener(_onLanguageChanged);
    VoiceAccessibilityService.instance.stopAll();
    super.dispose();
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

  Future<bool> _showConfirmPopup({
    required String title,
    required String message,
    required IconData icon,
    required Color iconColor,
    required String confirmText,
    required String cancelText,
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
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(cancelText, style: TextStyle(color: subTextColor)),
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
                child: Text(confirmText),
              ),
            ],
          ),
        );
      },
    );

    return result ?? false;
  }

  Future<void> _showMedicationReminderPopup({
    required String title,
    required String time,
  }) async {
    await _showInfoPopup(
      title: tr('Medication Reminder', 'تذكير الدواء'),
      message: tr(
        'It is time for your medicine: $title at $time.',
        'حان وقت الدواء: $title في الساعة $time.',
      ),
      icon: Icons.medication_outlined,
      iconColor: const Color(0xFF87CEEB),
    );
  }

  Future<void> _showAppointmentReminderPopup({
    required String title,
    required String time,
  }) async {
    await _showInfoPopup(
      title: tr('Appointment Reminder', 'تذكير الموعد'),
      message: tr(
        'You have an appointment reminder: $title at $time.',
        'لديك تذكير بموعد: $title في الساعة $time.',
      ),
      icon: Icons.calendar_month_outlined,
      iconColor: Colors.orange,
    );
  }

  Future<void> _showReminderCompletedPopup({
    required String docId,
    required String title,
    required String currentStatus,
  }) async {
    if (currentStatus == 'accepted') {
      await _showInfoPopup(
        title: tr('Already Completed', 'تم بالفعل'),
        message: tr(
          'This reminder is already completed and cannot be changed to None.',
          'هذا التذكير مكتمل بالفعل ولا يمكن تغييره إلى لم يتم.',
        ),
        icon: Icons.lock_rounded,
        iconColor: Colors.green,
      );
      return;
    }

    final confirm = await _showConfirmPopup(
      title: tr('Reminder Completed', 'تم إنجاز التذكير'),
      message: tr(
        'Did you complete "$title"? Do you want to mark it as completed?',
        'هل أنجزت "$title"؟ هل تريد وضعه كمكتمل؟',
      ),
      icon: Icons.task_alt_rounded,
      iconColor: Colors.green,
      confirmText: tr('Done', 'تم'),
      cancelText: tr('Later', 'لاحقًا'),
    );

    if (!confirm) return;

    await _changeReminderStatus(docId, 'accepted');

    if (!mounted) return;

    await _showInfoPopup(
      title: tr('Completed', 'تم'),
      message: tr(
        'Reminder marked as completed successfully.',
        'تم وضع التذكير كمكتمل بنجاح.',
      ),
      icon: Icons.check_circle_rounded,
      iconColor: Colors.green,
    );
  }

  Future<void> _showReminderDetailsPopup({
    required String title,
    required String time,
    required String category,
  }) async {
    if (category.toLowerCase() == 'medicine') {
      await _showMedicationReminderPopup(title: title, time: time);
    } else if (category.toLowerCase() == 'appointment') {
      await _showAppointmentReminderPopup(title: title, time: time);
    } else {
      await _showInfoPopup(
        title: tr('Reminder', 'تذكير'),
        message: tr(
          'Reminder: $title at $time.',
          'التذكير: $title في الساعة $time.',
        ),
        icon: Icons.notifications_active_rounded,
        iconColor: const Color(0xFF87CEEB),
      );
    }
  }

  void _goBack() {
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
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
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
                  tr('Reminders', 'التذكيرات'),
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

  String _categoryText(String category) {
    switch (category.toLowerCase()) {
      case 'medicine':
        return tr('Medicine', 'دواء');
      case 'meal':
        return tr('Meal', 'وجبة');
      case 'appointment':
        return tr('Appointment', 'موعد');
      case 'others':
        return tr('Others', 'أخرى');
      default:
        return tr('Others', 'أخرى');
    }
  }

  IconData _categoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'medicine':
        return Icons.medication_outlined;
      case 'meal':
        return Icons.restaurant_outlined;
      case 'appointment':
        return Icons.calendar_month_outlined;
      case 'others':
        return Icons.more_horiz_rounded;
      default:
        return Icons.more_horiz_rounded;
    }
  }

  Widget _buildDayTab(String day) {
    final bool isSelected = _selectedDay == day;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedDay = day;
        });
      },
      child: Container(
        width: double.infinity,
        height: 50,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF69B7E8)
              : Theme.of(context).inputDecorationTheme.fillColor ??
                  const Color(0xFFE9E9E9),
          borderRadius: BorderRadius.circular(13),
          border: null,
        ),
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Text(
                dayName(day),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isSelected ? Colors.white : textColor,
                  fontSize: isArabic ? 10 : 10.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDaysSelector() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double screenWidth = constraints.maxWidth;
        final bool isPhone = screenWidth < 600;
        final double spacing = isPhone ? 4 : 10;
        final double dayWidth =
            (screenWidth - (spacing * (_days.length - 1))) / _days.length;

        return Row(
          mainAxisAlignment: isPhone
              ? MainAxisAlignment.spaceBetween
              : MainAxisAlignment.start,
          children: _days.map((day) {
            return SizedBox(
              width: dayWidth,
              child: _buildDayTab(day),
            );
          }).toList(),
        );
      },
    );
  }

  Future<void> _changeReminderStatus(String docId, String status) async {
    await FirebaseFirestore.instance.collection('reminders').doc(docId).update({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _sendMedicineNoneNotificationToCompanion({
    required Map<String, dynamic> data,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final String title = (data['title'] ?? tr('Medicine', 'دواء')).toString();
    final String time = (data['time'] ?? '').toString();
    final String patientName =
        (data['patientName'] ?? data['name'] ?? tr('Patient', 'المريض'))
            .toString();

    final usersQuery =
        await FirebaseFirestore.instance.collection('users').get();

    for (final doc in usersQuery.docs) {
      final companionData = doc.data();
      final role = (companionData['role'] ?? '').toString().toLowerCase();
      final patientUid = (companionData['patientUid'] ??
              companionData['patientId'] ??
              companionData['linkedPatientId'] ??
              '')
          .toString();

      final bool isCompanion = role == 'companion';
      final bool linkedToPatient = patientUid == user.uid || patientUid.isEmpty;

      if (!isCompanion || !linkedToPatient) continue;

      await FirebaseFirestore.instance.collection('notifications').add({
        'userId': doc.id,
        'receiverId': doc.id,
        'senderId': user.uid,
        'senderRole': 'patient',
        'patientId': user.uid,
        'patientName': patientName,
        'type': 'medicine_not_taken',
        'title': tr('Medicine Not Taken', 'لم يتم تناول الدواء'),
        'message': tr(
          '$patientName marked medicine "$title" at $time as not taken.',
          'المريض $patientName وضع الدواء "$title" في الساعة $time على أنه لم يتم تناوله.',
        ),
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Widget _statusChip(String status) {
    Color color;
    String text;

    if (status == 'accepted') {
      color = Colors.green;
      text = tr('Done', 'تم');
    } else if (status == 'none') {
      color = Colors.orange;
      text = tr('None', 'لم يتم');
    } else {
      color = Colors.grey;
      text = tr('Pending', 'قيد الانتظار');
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _smallButton({
    required String text,
    required Color color,
    required VoidCallback? onTap,
  }) {
    return SizedBox(
      height: 38,
      width: 120,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          disabledBackgroundColor: Colors.grey.shade400,
          elevation: 0,
          minimumSize: const Size(0, 38),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildReminderCard({
    required String docId,
    required Map<String, dynamic> data,
  }) {
    final String title = data['title'] ?? tr('Reminder', 'تذكير');
    final String time = data['time'] ?? '';
    final String emoji = data['emoji'] ?? '🔔';
    final String category = data['category'] ?? 'others';
    final String status = data['status'] ?? 'pending';
    final bool isDone = status == 'accepted';

    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: () {
        _showReminderDetailsPopup(
          title: title,
          time: time,
          category: category,
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: borderColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 27,
                  backgroundColor: const Color(0xFFEAF7FD),
                  child: Text(emoji, style: const TextStyle(fontSize: 25)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: isArabic
                        ? CrossAxisAlignment.end
                        : CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        textAlign: isArabic ? TextAlign.right : TextAlign.left,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Row(
                        mainAxisAlignment: isArabic
                            ? MainAxisAlignment.end
                            : MainAxisAlignment.start,
                        children: [
                          Icon(
                            _categoryIcon(category),
                            size: 16,
                            color: subTextColor,
                          ),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              '${_categoryText(category)} • $time',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: subTextColor,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _statusChip(status),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [
                _smallButton(
                  text: tr('Accept', 'تم'),
                  color: const Color(0xFF69B7E8),
                  onTap: isDone
                      ? null
                      : () {
                          _showReminderCompletedPopup(
                            docId: docId,
                            title: title,
                            currentStatus: status,
                          );
                        },
                ),
                _smallButton(
                  text: tr('None', 'لم يتم'),
                  color: Colors.orange,
                  onTap: isDone
                      ? null
                      : () async {
                          await _changeReminderStatus(docId, 'none');

                          if (category.toLowerCase() == 'medicine') {
                            await _sendMedicineNoneNotificationToCompanion(
                              data: data,
                            );
                          }

                          if (!mounted) return;

                          await _showInfoPopup(
                            title: tr('Reminder Updated', 'تم تحديث التذكير'),
                            message: category.toLowerCase() == 'medicine'
                                ? tr(
                                    'Medicine marked as not taken and companion was notified.',
                                    'تم وضع الدواء على أنه لم يتم تناوله وتم إرسال تنبيه للمرافق.',
                                  )
                                : tr(
                                    'Reminder marked as not completed.',
                                    'تم وضع التذكير على أنه لم يتم.',
                                  ),
                            icon: Icons.info_outline_rounded,
                            iconColor: Colors.orange,
                          );
                        },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _remindersStream() {
    final user = FirebaseAuth.instance.currentUser;

    return FirebaseFirestore.instance
        .collection('reminders')
        .where('patientId', isEqualTo: user?.uid ?? '')
        .where('day', isEqualTo: _selectedDay)
        .snapshots();
  }

  Widget _buildRemindersList(User? user) {
    if (user == null) {
      return Center(
        child: Text(
          tr(
            'Please login to see reminders',
            'يرجى تسجيل الدخول لعرض التذكيرات',
          ),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 17,
            color: subTextColor,
          ),
        ),
      );
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _remindersStream(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              tr(
                'Error loading reminders',
                'حدث خطأ أثناء تحميل التذكيرات',
              ),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                color: subTextColor,
              ),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              color: Color(0xFF87CEEB),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Text(
              tr(
                'No reminders for this day',
                'لا توجد تذكيرات لهذا اليوم',
              ),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                color: subTextColor,
              ),
            ),
          );
        }

        final reminders = snapshot.data!.docs.toList();

        reminders.sort((a, b) {
          final aTime = (a.data()['reminderAt'] as Timestamp?)?.toDate();
          final bTime = (b.data()['reminderAt'] as Timestamp?)?.toDate();

          if (aTime == null && bTime == null) return 0;
          if (aTime == null) return 1;
          if (bTime == null) return -1;

          return aTime.compareTo(bTime);
        });

        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 120),
          itemCount: reminders.length,
          itemBuilder: (context, index) {
            final doc = reminders[index];

            return _buildReminderCard(
              docId: doc.id,
              data: doc.data(),
            );
          },
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

    String remindersText = '';

    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user != null) {
        final snapshot = await FirebaseFirestore.instance
            .collection('reminders')
            .where('patientId', isEqualTo: user.uid)
            .where('day', isEqualTo: _selectedDay)
            .get();

        if (snapshot.docs.isNotEmpty) {
          final reminderTitles = snapshot.docs.map((doc) {
            final data = doc.data();

            final title = data['title'] ?? '';
            final time = data['time'] ?? '';

            return '$title at $time';
          }).join(', ');

          remindersText = ' Today reminders are: $reminderTitles.';
        }
      }
    } catch (_) {}

    await VoiceAccessibilityService.instance.readPageAndListen(
      context: context,
      pageText: tr(
        'Reminders screen with weekly schedule, home, profile, and settings options.$remindersText',
        'صفحة التذكيرات تحتوي على الجدول الأسبوعي وخيارات الرئيسية والملف الشخصي والإعدادات.$remindersText',
      ),
      routes: {
        'dashboard': (context) => const DashboardPage(),
        'reminders': (context) => const RemindersPage(),
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
              boxShadow: const [
                BoxShadow(
                  color: Color(0x2E000000),
                  blurRadius: 14,
                  offset: Offset(0, 6),
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
    final user = FirebaseAuth.instance.currentUser;

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
              body: Stack(
                children: [
                  SafeArea(
                    child: Column(
                      children: [
                        _buildHeader(),
                        Expanded(
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
                            color: backgroundColor,
                            child: Column(
                              crossAxisAlignment: isArabic
                                  ? CrossAxisAlignment.end
                                  : CrossAxisAlignment.start,
                              children: [
                                _buildDaysSelector(),
                                const SizedBox(height: 24),
                                Expanded(
                                  child: _buildRemindersList(user),
                                ),
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
}
