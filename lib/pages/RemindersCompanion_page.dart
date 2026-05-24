import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'Profile_page.dart';
import 'Settings_page.dart';
import 'CompanionDashboard_page.dart';
import 'services/reminder_notification_service.dart';
import 'package:humantouch/pages/app_settings_store.dart';

class CompanionRemindersPage extends StatefulWidget {
  const CompanionRemindersPage({super.key});

  @override
  State<CompanionRemindersPage> createState() => _CompanionRemindersPageState();
}

class _CompanionRemindersPageState extends State<CompanionRemindersPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _timeController = TextEditingController();
  final TextEditingController _emojiController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _otherReminderController =
      TextEditingController();

  String _selectedCategory = 'medicine';
  String? _editingReminderId;

  late String _selectedDateText;

  bool _notification = true;
  bool _sound = true;
  bool _isSaving = false;

  DateTime _selectedTime = DateTime.now();
  DateTime _selectedDate = DateTime.now();

  String _selectedEmoji = '💊';

  bool get isArabic => AppSettingsStore.instance.isArabic;

  String tr(String en, String ar) => isArabic ? ar : en;

  Color get backgroundColor => Theme.of(context).scaffoldBackgroundColor;

  Color get textColor =>
      Theme.of(context).textTheme.bodyLarge?.color ?? const Color(0xFF333333);

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
            backgroundColor: Colors.white,
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
                  style: const TextStyle(
                    color: Color(0xFF333333),
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
                style: const TextStyle(
                  color: Color(0xFF777777),
                  fontSize: 15,
                  height: 1.5,
                ),
              ),
            ),
            actionsAlignment: MainAxisAlignment.center,
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF69B7E8),
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
            backgroundColor: Colors.white,
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
                  style: const TextStyle(
                    color: Color(0xFF333333),
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
                style: const TextStyle(
                  color: Color(0xFF777777),
                  fontSize: 15,
                  height: 1.5,
                ),
              ),
            ),
            actionsAlignment: MainAxisAlignment.center,
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(
                  cancelText,
                  style: const TextStyle(color: Color(0xFF777777)),
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
                child: Text(confirmText),
              ),
            ],
          ),
        );
      },
    );

    return result ?? false;
  }

  Future<void> _showAddReminderSuccessPopup() async {
    await _showInfoPopup(
      title: tr('Reminder Added', 'تمت إضافة التذكير'),
      message: tr(
        'The reminder was added successfully and will appear for the patient.',
        'تمت إضافة التذكير بنجاح وسيظهر للمريض.',
      ),
      icon: Icons.check_circle_rounded,
      iconColor: Colors.green,
    );
  }

  Future<void> _showEditReminderSavedPopup() async {
    await _showInfoPopup(
      title: tr('Reminder Updated', 'تم تحديث التذكير'),
      message: tr(
        'The reminder changes were saved successfully.',
        'تم حفظ تعديلات التذكير بنجاح.',
      ),
      icon: Icons.edit_calendar_rounded,
      iconColor: const Color(0xFF69B7E8),
    );
  }

  Future<bool> _showDeleteConfirmationPopup({
    required String title,
  }) async {
    return _showConfirmPopup(
      title: tr('Delete Reminder', 'حذف التذكير'),
      message: tr(
        'Are you sure you want to delete "$title"? This action cannot be undone.',
        'هل أنت متأكد من حذف "$title"؟ لا يمكن التراجع عن هذا الإجراء.',
      ),
      icon: Icons.delete_outline_rounded,
      iconColor: Colors.redAccent,
      confirmText: tr('Delete', 'حذف'),
      cancelText: tr('Cancel', 'إلغاء'),
    );
  }

  Future<void> _showDeleteSuccessPopup() async {
    await _showInfoPopup(
      title: tr('Reminder Deleted', 'تم حذف التذكير'),
      message: tr(
        'The reminder was deleted successfully.',
        'تم حذف التذكير بنجاح.',
      ),
      icon: Icons.check_circle_rounded,
      iconColor: Colors.green,
    );
  }

  final List<String> _emojiList = const [
    '💊',
    '🍽️',
    '📅',
    '❤️',
    '😊',
    '😴',
    '🏃‍♀️',
    '🧘‍♀️',
    '🚰',
    '🩺',
    '🌞',
    '⭐',
    '✅',
    '⏰',
    '📝',
    '🧠',
    '🍎',
    '🚶‍♀️',
  ];

  final List<String> _categories = const [
    'medicine',
    'meal',
    'appointment',
    'others',
  ];

  final List<String> _weekDays = const [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  final List<String> _shortWeekDays = const [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  final List<String> _months = const [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  @override
  void initState() {
    super.initState();
    AppSettingsStore.instance.addListener(_onLanguageChanged);

    _selectedDateText = _formatDate(_selectedDate);
    _dateController.text = _selectedDateText;
    _emojiController.text = _selectedEmoji;
  }

  void _onLanguageChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    AppSettingsStore.instance.removeListener(_onLanguageChanged);

    _titleController.dispose();
    _timeController.dispose();
    _emojiController.dispose();
    _dateController.dispose();
    _otherReminderController.dispose();

    super.dispose();
  }

  String _dayName(DateTime date) {
    return _weekDays[date.weekday - 1];
  }

  String _dayNameText(String day) {
    switch (day) {
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
      case 'Sunday':
        return tr('Sunday', 'الأحد');
      default:
        return day;
    }
  }

  String _shortDayNameText(String day) {
    switch (day) {
      case 'Mon':
        return tr('Mon', 'الأثنين');
      case 'Tue':
        return tr('Tue', 'الثلاثاء');
      case 'Wed':
        return tr('Wed', 'الأربعاء');
      case 'Thu':
        return tr('Thu', 'الخميس');
      case 'Fri':
        return tr('Fri', 'الجمعة');
      case 'Sat':
        return tr('Sat', 'السبت');
      case 'Sun':
        return tr('Sun', 'الأحد');
      default:
        return day;
    }
  }

  String _monthNameText(String month) {
    switch (month) {
      case 'January':
        return tr('January', 'يناير');
      case 'February':
        return tr('February', 'فبراير');
      case 'March':
        return tr('March', 'مارس');
      case 'April':
        return tr('April', 'أبريل');
      case 'May':
        return tr('May', 'مايو');
      case 'June':
        return tr('June', 'يونيو');
      case 'July':
        return tr('July', 'يوليو');
      case 'August':
        return tr('August', 'أغسطس');
      case 'September':
        return tr('September', 'سبتمبر');
      case 'October':
        return tr('October', 'أكتوبر');
      case 'November':
        return tr('November', 'نوفمبر');
      case 'December':
        return tr('December', 'ديسمبر');
      default:
        return month;
    }
  }

  List<DateTime> _currentWeekDates() {
    final DateTime monday = _selectedDate.subtract(
      Duration(days: _selectedDate.weekday - 1),
    );

    return List.generate(7, (index) {
      return DateTime(monday.year, monday.month, monday.day + index);
    });
  }

  String _formatDate(DateTime date) {
    final String dayName = _dayNameText(_weekDays[date.weekday - 1]);
    final String monthName = _monthNameText(_months[date.month - 1]);
    final String dayNumber = date.day.toString().padLeft(2, '0');

    return '$dayName, $dayNumber $monthName ${date.year}';
  }

  DateTime _selectedReminderDateTime() {
    return DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );
  }

  Future<Map<String, dynamic>?> _getLinkedPatientData() async {
    final companion = FirebaseAuth.instance.currentUser;
    if (companion == null) return null;

    final usersRef = FirebaseFirestore.instance.collection('users');

    try {
      final companionDoc = await usersRef.doc(companion.uid).get();
      final companionData = companionDoc.data() ?? {};

      final String linkedPatientId = (companionData['patientUid'] ??
              companionData['patientId'] ??
              companionData['linkedPatientUid'] ??
              companionData['linkedPatientId'] ??
              '')
          .toString()
          .trim();

      if (linkedPatientId.isNotEmpty) {
        final patientDoc = await usersRef.doc(linkedPatientId).get();

        if (patientDoc.exists) {
          final data = patientDoc.data() ?? {};

          return {
            'uid': patientDoc.id,
            'patientUid': patientDoc.id,
            'patientId': patientDoc.id,
            'name': (data['name'] ??
                    data['fullName'] ??
                    data['username'] ??
                    tr('Patient', 'المريض'))
                .toString(),
            'email': (data['email'] ?? '').toString(),
            'fcmToken': (data['fcmToken'] ?? data['token'] ?? '').toString(),
          };
        }
      }

      final String linkedPatientCode =
          (companionData['linkedPatientCode'] ?? '').toString().trim();

      if (linkedPatientCode.isNotEmpty) {
        final patientByCode = await usersRef
            .where('patientLinkCode', isEqualTo: linkedPatientCode)
            .where('role', isEqualTo: 'patient')
            .limit(1)
            .get();

        if (patientByCode.docs.isNotEmpty) {
          final doc = patientByCode.docs.first;
          final data = doc.data();

          await usersRef.doc(companion.uid).set({
            'patientUid': doc.id,
            'patientId': doc.id,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

          return {
            'uid': doc.id,
            'patientUid': doc.id,
            'patientId': doc.id,
            'name': (data['name'] ??
                    data['fullName'] ??
                    data['username'] ??
                    tr('Patient', 'المريض'))
                .toString(),
            'email': (data['email'] ?? '').toString(),
            'fcmToken': (data['fcmToken'] ?? data['token'] ?? '').toString(),
          };
        }
      }
    } catch (e) {
      debugPrint('Error reading companion linked patient: $e');
    }

    final List<Query<Map<String, dynamic>>> queries = [
      usersRef.where('companionUid', isEqualTo: companion.uid).limit(1),
      usersRef.where('linkedCompanionUid', isEqualTo: companion.uid).limit(1),
      usersRef.where('companionId', isEqualTo: companion.uid).limit(1),
    ];

    if ((companion.email ?? '').trim().isNotEmpty) {
      queries.add(
        usersRef
            .where('companionEmail', isEqualTo: companion.email!.trim())
            .limit(1),
      );
    }

    for (final query in queries) {
      try {
        final snapshot = await query.get();
        if (snapshot.docs.isNotEmpty) {
          final doc = snapshot.docs.first;
          final data = doc.data();

          return {
            'uid': doc.id,
            'patientUid': doc.id,
            'patientId': doc.id,
            'name': (data['name'] ??
                    data['fullName'] ??
                    data['username'] ??
                    tr('Patient', 'المريض'))
                .toString(),
            'email': (data['email'] ?? '').toString(),
            'fcmToken': (data['fcmToken'] ?? data['token'] ?? '').toString(),
          };
        }
      } catch (e) {
        debugPrint('Error finding linked patient: $e');
      }
    }

    return null;
  }

  Future<void> _createPatientNotification({
    required String patientId,
    required String title,
    required DateTime reminderDateTime,
    required bool isUpdate,
  }) async {
    final companion = FirebaseAuth.instance.currentUser;
    if (companion == null) return;

    await FirebaseFirestore.instance.collection('notifications').add({
      'userId': patientId,
      'patientId': patientId,
      'receiverId': patientId,
      'senderId': companion.uid,
      'senderRole': 'companion',
      'type': isUpdate ? 'reminder_updated' : 'reminder_added',
      'title': isUpdate
          ? tr('Reminder Updated', 'تم تحديث التذكير')
          : tr('New Reminder Added', 'تمت إضافة تذكير جديد'),
      'message': isUpdate
          ? tr(
              'Your companion updated the reminder "$title".',
              'قام المرافق بتحديث التذكير "$title".',
            )
          : tr(
              'Your companion added a new reminder "$title".',
              'قام المرافق بإضافة تذكير جديد "$title".',
            ),
      'reminderTitle': title,
      'reminderAt': Timestamp.fromDate(reminderDateTime),
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _remindersStream() {
    final user = FirebaseAuth.instance.currentUser;

    return FirebaseFirestore.instance
        .collection('reminders')
        .where('userId', isEqualTo: user?.uid ?? '')
        .snapshots();
  }

  void _pickDate() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime(2035),
      builder: (context, child) {
        return Directionality(
          textDirection: isArabic ? ui.TextDirection.rtl : ui.TextDirection.ltr,
          child: Theme(
            data: Theme.of(context).copyWith(
              colorScheme: const ColorScheme.light(
                primary: Color(0xFF69B7E8),
                onPrimary: Colors.white,
                onSurface: Colors.black,
              ),
            ),
            child: child!,
          ),
        );
      },
    );

    if (pickedDate != null) {
      setState(() {
        _selectedDate = pickedDate;
        _selectedDateText = _formatDate(pickedDate);
        _dateController.text = _selectedDateText;
      });
    }
  }

  void _pickTime() async {
    final TimeOfDay initialTime = TimeOfDay(
      hour: _selectedTime.hour,
      minute: _selectedTime.minute,
    );

    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (context, child) {
        return Directionality(
          textDirection: isArabic ? ui.TextDirection.rtl : ui.TextDirection.ltr,
          child: Theme(
            data: Theme.of(context).copyWith(
              colorScheme: const ColorScheme.light(
                primary: Color(0xFF69B7E8),
                onPrimary: Colors.white,
                onSurface: Colors.black,
              ),
            ),
            child: child!,
          ),
        );
      },
    );

    if (pickedTime != null) {
      final now = DateTime.now();

      setState(() {
        _selectedTime = DateTime(
          now.year,
          now.month,
          now.day,
          pickedTime.hour,
          pickedTime.minute,
        );

        _timeController.text = MaterialLocalizations.of(
          context,
        ).formatTimeOfDay(pickedTime, alwaysUse24HourFormat: false);
      });
    }
  }

  void _goBack() {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const CompanionDashboardPage()),
      );
    }
  }

  void _goToPage(int index) {
    if (index == 0) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const CompanionDashboardPage()),
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

  Widget _buildBottomNavigation() {
    return Container(
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
    );
  }

  Widget _buildHeader() {
    return Column(
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
                child: Center(
                  child: Text(
                    tr('Reminders', 'التذكيرات'),
                    style: TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
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
    switch (category) {
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
    switch (category) {
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

  void _clearForm() {
    setState(() {
      _editingReminderId = null;
      _titleController.clear();
      _timeController.clear();
      _otherReminderController.clear();

      _selectedEmoji = '💊';
      _emojiController.text = _selectedEmoji;

      _selectedCategory = 'medicine';
      _selectedDate = DateTime.now();
      _selectedDateText = _formatDate(_selectedDate);
      _dateController.text = _selectedDateText;

      _notification = true;
      _sound = true;
      _selectedTime = DateTime.now();
    });
  }

  void _fillFormForEdit(String docId, Map<String, dynamic> data) {
    setState(() {
      _editingReminderId = docId;

      _selectedCategory = data['category'] ?? 'medicine';

      _titleController.text = data['title'] ?? '';
      _timeController.text = data['time'] ?? '';

      if (_selectedCategory == 'others') {
        _otherReminderController.text = data['title'] ?? '';
      } else {
        _otherReminderController.clear();
      }

      _selectedEmoji = data['emoji'] ?? '💊';
      _emojiController.text = _selectedEmoji;

      _selectedDateText = data['dateText'] ?? data['day'] ?? '';
      _dateController.text = _selectedDateText;

      _notification = data['notification'] ?? true;
      _sound = data['sound'] ?? true;

      final reminderAt = data['reminderAt'];
      if (reminderAt is Timestamp) {
        final dateTime = reminderAt.toDate();
        _selectedDate = DateTime(dateTime.year, dateTime.month, dateTime.day);
        _selectedTime = dateTime;
        _selectedDateText = _formatDate(_selectedDate);
        _dateController.text = _selectedDateText;

        final timeOfDay = TimeOfDay.fromDateTime(dateTime);
        _timeController.text = timeOfDay.format(context);
      }
    });

    _showReminderForm();
  }

  Future<void> _saveReminder() async {
    if (!_formKey.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('Please login first', 'يرجى تسجيل الدخول أولاً')),
        ),
      );
      return;
    }

    final String reminderTitle = _selectedCategory == 'others'
        ? _otherReminderController.text.trim()
        : _titleController.text.trim();

    setState(() {
      _isSaving = true;
    });

    try {
      final linkedPatient = await _getLinkedPatientData();

      if (linkedPatient == null) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              tr(
                'No linked patient found. Please link a patient account first.',
                'لم يتم العثور على مريض مرتبط. يرجى ربط حساب المريض أولاً.',
              ),
            ),
          ),
        );
        return;
      }

      final String patientId = (linkedPatient['uid'] ??
              linkedPatient['patientUid'] ??
              linkedPatient['patientId'] ??
              '')
          .toString();
      final String patientName = linkedPatient['name'].toString();
      final DateTime reminderDateTime = _selectedReminderDateTime();
      final bool wasEditing = _editingReminderId != null;

      final Map<String, dynamic> reminderData = {
        'userId': user.uid,
        'companionId': user.uid,
        'createdBy': user.uid,
        'createdByRole': 'companion',
        'patientId': patientId,
        'patientUid': patientId,
        'patientName': patientName,
        'title': reminderTitle,
        'time': _timeController.text.trim(),
        'day': _dayName(_selectedDate),
        'dateText': _dateController.text.trim(),
        'emoji': _selectedEmoji,
        'category': _selectedCategory,
        'notification': _notification,
        'sound': _sound,
        'status': 'pending',
        'reminderAt': Timestamp.fromDate(reminderDateTime),
        'remindBeforeMinutes': 10,
        'notifyBefore': true,
        'notifyPatientOnCreate': true,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (_editingReminderId == null) {
        reminderData['createdAt'] = FieldValue.serverTimestamp();

        await FirebaseFirestore.instance
            .collection('reminders')
            .add(reminderData);
      } else {
        await FirebaseFirestore.instance
            .collection('reminders')
            .doc(_editingReminderId)
            .update(reminderData);
      }

      if (_notification) {
        await _createPatientNotification(
          patientId: patientId,
          title: reminderTitle,
          reminderDateTime: reminderDateTime,
          isUpdate: wasEditing,
        );
      }
      await ReminderNotificationService.scheduleReminderNotification(
        reminderId: _editingReminderId ?? reminderTitle,
        title: reminderTitle,
        body: tr(
          'Reminder time is coming soon',
          'اقترب وقت التذكير',
        ),
        reminderDateTime: reminderDateTime,
        sound: _sound,
        minutesBefore: 10,
      );

      if (!mounted) return;

      Navigator.pop(context);
      _clearForm();

      if (wasEditing) {
        await _showEditReminderSavedPopup();
      } else {
        await _showAddReminderSuccessPopup();
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr('Error saving reminder: $e', 'حدث خطأ أثناء حفظ التذكير: $e'),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _deleteReminder(String docId, String title) async {
    final confirmDelete = await _showDeleteConfirmationPopup(title: title);

    if (!confirmDelete) return;

    await FirebaseFirestore.instance
        .collection('reminders')
        .doc(docId)
        .delete();

    if (!mounted) return;

    await _showDeleteSuccessPopup();
  }

  void _showEmojiPicker(StateSetter modalSetState) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) {
        return Directionality(
          textDirection: isArabic ? ui.TextDirection.rtl : ui.TextDirection.ltr,
          child: Container(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
            height: 310,
            child: Column(
              crossAxisAlignment:
                  isArabic ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Text(
                  tr('Choose Emoji', 'اختر رمزاً'),
                  style: const TextStyle(
                    color: Color(0xFF333333),
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: GridView.builder(
                    itemCount: _emojiList.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 6,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                    ),
                    itemBuilder: (context, index) {
                      final emoji = _emojiList[index];

                      return GestureDetector(
                        onTap: () {
                          modalSetState(() {
                            _selectedEmoji = emoji;
                            _emojiController.text = emoji;
                          });
                          setState(() {
                            _selectedEmoji = emoji;
                            _emojiController.text = emoji;
                          });
                          Navigator.pop(context);
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: _selectedEmoji == emoji
                                ? const Color(0xFFEAF7FD)
                                : const Color(0xFFF4F4F4),
                            border: Border.all(
                              color: _selectedEmoji == emoji
                                  ? const Color(0xFF69B7E8)
                                  : Colors.transparent,
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Center(
                            child: Text(
                              emoji,
                              style: const TextStyle(fontSize: 28),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showReminderForm() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return Directionality(
          textDirection: isArabic ? ui.TextDirection.rtl : ui.TextDirection.ltr,
          child: StatefulBuilder(
            builder: (context, modalSetState) {
              return Container(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 22,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 22,
                ),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                ),
                child: Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _editingReminderId == null
                              ? tr('Add Reminder', 'إضافة تذكير')
                              : tr('Edit Reminder', 'تعديل التذكير'),
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF333333),
                          ),
                        ),
                        const SizedBox(height: 18),
                        if (_selectedCategory != 'others')
                          _buildInput(
                            label: tr('Reminder Title', 'عنوان التذكير'),
                            controller: _titleController,
                            icon: Icons.title,
                          ),
                        if (_selectedCategory != 'others')
                          const SizedBox(height: 12),
                        _buildTimeInput(),
                        const SizedBox(height: 12),
                        _buildEmojiInput(modalSetState),
                        const SizedBox(height: 12),
                        _buildDateInput(),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: _selectedCategory,
                          decoration: _inputDecoration(
                            label: tr('Category', 'التصنيف'),
                            icon: Icons.category_outlined,
                          ),
                          items: _categories.map((category) {
                            return DropdownMenuItem(
                              value: category,
                              child: Text(_categoryText(category)),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (value == null) return;

                            modalSetState(() {
                              _selectedCategory = value;
                              if (_selectedCategory != 'others') {
                                _otherReminderController.clear();
                              }
                            });

                            setState(() {
                              _selectedCategory = value;
                              if (_selectedCategory != 'others') {
                                _otherReminderController.clear();
                              }
                            });
                          },
                        ),
                        if (_selectedCategory == 'others') ...[
                          const SizedBox(height: 12),
                          _buildInput(
                            label: tr(
                              'Write your reminder',
                              'اكتب التذكير',
                            ),
                            controller: _otherReminderController,
                            icon: Icons.edit_note_rounded,
                          ),
                        ],
                        const SizedBox(height: 14),
                        SwitchListTile(
                          value: _notification,
                          activeColor: const Color(0xFF69B7E8),
                          title: Text(tr('Notification', 'الإشعار')),
                          onChanged: (value) {
                            modalSetState(() {
                              _notification = value;
                            });
                            setState(() {
                              _notification = value;
                            });
                          },
                        ),
                        SwitchListTile(
                          value: _sound,
                          activeColor: const Color(0xFF69B7E8),
                          title: Text(tr('Sound', 'الصوت')),
                          onChanged: (value) {
                            modalSetState(() {
                              _sound = value;
                            });
                            setState(() {
                              _sound = value;
                            });
                          },
                        ),
                        const SizedBox(height: 15),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: _isSaving ? null : _saveReminder,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF69B7E8),
                              disabledBackgroundColor: Colors.grey,
                              minimumSize: const Size(0, 52),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                            child: _isSaving
                                ? const CircularProgressIndicator(
                                    color: Colors.white,
                                  )
                                : Text(
                                    _editingReminderId == null
                                        ? tr('Add', 'إضافة')
                                        : tr('Update', 'تحديث'),
                                    style: const TextStyle(
                                      fontSize: 18,
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: const Color(0xFF69B7E8)),
      filled: true,
      fillColor: const Color(0xFFF5F5F5),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
    );
  }

  Widget _buildInput({
    required String label,
    required TextEditingController controller,
    required IconData icon,
  }) {
    return TextFormField(
      controller: controller,
      textAlign: isArabic ? TextAlign.right : TextAlign.left,
      decoration: _inputDecoration(label: label, icon: icon),
      validator: (value) {
        if ((value ?? '').trim().isEmpty) {
          return tr('Required', 'مطلوب');
        }
        return null;
      },
    );
  }

  Widget _buildEmojiInput(StateSetter modalSetState) {
    return TextFormField(
      controller: _emojiController,
      readOnly: true,
      textAlign: isArabic ? TextAlign.right : TextAlign.left,
      onTap: () => _showEmojiPicker(modalSetState),
      decoration: _inputDecoration(
        label: tr('Emoji', 'الرمز'),
        icon: Icons.emoji_emotions_outlined,
      ).copyWith(
        suffixIcon: const Icon(
          Icons.keyboard_arrow_down_rounded,
          color: Color(0xFF69B7E8),
        ),
      ),
      validator: (value) {
        if ((value ?? '').trim().isEmpty) {
          return tr('Please select emoji', 'يرجى اختيار رمز');
        }
        return null;
      },
    );
  }

  Widget _buildTimeInput() {
    return TextFormField(
      controller: _timeController,
      readOnly: true,
      textAlign: isArabic ? TextAlign.right : TextAlign.left,
      onTap: _pickTime,
      decoration: _inputDecoration(
        label: tr('Time', 'الوقت'),
        icon: Icons.access_time,
      ).copyWith(
        suffixIcon: const Icon(
          Icons.keyboard_arrow_down_rounded,
          color: Color(0xFF69B7E8),
        ),
      ),
      validator: (value) {
        if ((value ?? '').trim().isEmpty) {
          return tr('Please select time', 'يرجى اختيار الوقت');
        }
        return null;
      },
    );
  }

  Widget _buildDateInput() {
    return TextFormField(
      controller: _dateController,
      readOnly: true,
      textAlign: isArabic ? TextAlign.right : TextAlign.left,
      onTap: _pickDate,
      decoration: _inputDecoration(
        label: tr('Day / Date', 'اليوم / التاريخ'),
        icon: Icons.calendar_month_outlined,
      ).copyWith(
        suffixIcon: const Icon(
          Icons.keyboard_arrow_down_rounded,
          color: Color(0xFF69B7E8),
        ),
      ),
      validator: (value) {
        if ((value ?? '').trim().isEmpty) {
          return tr('Please select day', 'يرجى اختيار اليوم');
        }
        return null;
      },
    );
  }

  Widget _buildWeekDayTab(
    DateTime date,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> reminders,
  ) {
    final String dateText = _formatDate(date);
    final bool isSelected = dateText == _selectedDateText;

    final int reminderCount = reminders.where((doc) {
      final data = doc.data();
      return data['dateText'] == dateText;
    }).length;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedDate = date;
            _selectedDateText = dateText;
            _dateController.text = _selectedDateText;
          });
        },
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 2),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color:
                isSelected ? const Color(0xFF69B7E8) : const Color(0xFFE9E9E9),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              Text(
                _shortDayNameText(_shortWeekDays[date.weekday - 1]),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : const Color(0xFF333333),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${date.day}',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : const Color(0xFF333333),
                ),
              ),
              const SizedBox(height: 4),
              CircleAvatar(
                radius: 9,
                backgroundColor: isSelected ? Colors.white : Colors.transparent,
                child: Text(
                  '$reminderCount',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isSelected
                        ? const Color(0xFF69B7E8)
                        : const Color(0xFF777777),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWeekSelector(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> reminders,
  ) {
    final weekDates = _currentWeekDates();

    return Column(
      crossAxisAlignment:
          isArabic ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(
          tr('This Week', 'هذا الأسبوع'),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF333333),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: weekDates
              .map((date) => _buildWeekDayTab(date, reminders))
              .toList(),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: _pickDate,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: _shadow(),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.calendar_month_outlined,
                  color: Color(0xFF69B7E8),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _selectedDateText,
                    textAlign: isArabic ? TextAlign.right : TextAlign.left,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF333333),
                    ),
                  ),
                ),
                const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: Color(0xFF69B7E8),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Container(
      width: 55,
      height: 55,
      margin: const EdgeInsets.only(left: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF69B7E8),
        borderRadius: BorderRadius.circular(18),
      ),
      child: IconButton(
        onPressed: onTap,
        icon: Icon(icon, color: Colors.white, size: 28),
      ),
    );
  }

  Widget _buildReminderCard(String docId, Map<String, dynamic> data) {
    final String title = data['title'] ?? tr('Reminder', 'تذكير');
    final String time = data['time'] ?? '';
    final String emoji = data['emoji'] ?? '🔔';
    final String category = data['category'] ?? 'others';
    final String dateText = data['dateText'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 27,
            backgroundColor: const Color(0xFFEAF7FD),
            child: Text(emoji, style: const TextStyle(fontSize: 25)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  isArabic ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  textAlign: isArabic ? TextAlign.right : TextAlign.left,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF333333),
                  ),
                ),
                const SizedBox(height: 5),
                Row(
                  mainAxisAlignment: isArabic
                      ? MainAxisAlignment.end
                      : MainAxisAlignment.start,
                  children: [
                    Icon(_categoryIcon(category), size: 16, color: Colors.grey),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        '${_categoryText(category)} • $time',
                        textAlign: isArabic ? TextAlign.right : TextAlign.left,
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 13,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  dateText,
                  textAlign: isArabic ? TextAlign.right : TextAlign.left,
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _fillFormForEdit(docId, data),
            icon: const Icon(Icons.edit_outlined, color: Color(0xFF69B7E8)),
          ),
          IconButton(
            onPressed: () => _deleteReminder(docId, title),
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Directionality(
      textDirection: isArabic ? ui.TextDirection.rtl : ui.TextDirection.ltr,
      child: Scaffold(
        backgroundColor: backgroundColor,
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _remindersStream(),
                builder: (context, snapshot) {
                  final reminders = snapshot.data?.docs ?? [];

                  final selectedReminders = reminders.where((doc) {
                    final data = doc.data();
                    return data['dateText'] == _selectedDateText;
                  }).toList();

                  return Expanded(
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(18, 8, 18, 10),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              _buildActionButton(
                                icon: Icons.add,
                                onTap: () {
                                  _clearForm();
                                  _showReminderForm();
                                },
                              ),
                              _buildActionButton(
                                icon: Icons.edit_note,
                                onTap: () {
                                  if (selectedReminders.isNotEmpty) {
                                    final doc = selectedReminders.first;
                                    _fillFormForEdit(doc.id, doc.data());
                                  }
                                },
                              ),
                              _buildActionButton(
                                icon: Icons.delete_outline,
                                onTap: () {
                                  if (selectedReminders.isNotEmpty) {
                                    final doc = selectedReminders.first;
                                    final data = doc.data();
                                    final title = (data['title'] ??
                                            tr('Reminder', 'تذكير'))
                                        .toString();
                                    _deleteReminder(doc.id, title);
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.fromLTRB(18, 10, 18, 10),
                            color: backgroundColor,
                            child: Column(
                              crossAxisAlignment: isArabic
                                  ? CrossAxisAlignment.end
                                  : CrossAxisAlignment.start,
                              children: [
                                _buildWeekSelector(reminders),
                                const SizedBox(height: 24),
                                Expanded(
                                  child: user == null
                                      ? Center(
                                          child: Text(
                                            tr(
                                              'Please login first',
                                              'يرجى تسجيل الدخول أولاً',
                                            ),
                                            style: const TextStyle(
                                              fontSize: 17,
                                              color: Colors.grey,
                                            ),
                                          ),
                                        )
                                      : snapshot.connectionState ==
                                              ConnectionState.waiting
                                          ? const Center(
                                              child: CircularProgressIndicator(
                                                color: Color(0xFF69B7E8),
                                              ),
                                            )
                                          : selectedReminders.isEmpty
                                              ? Center(
                                                  child: Text(
                                                    tr(
                                                      'No reminders for this day',
                                                      'لا توجد تذكيرات لهذا اليوم',
                                                    ),
                                                    style: const TextStyle(
                                                      fontSize: 17,
                                                      color: Colors.grey,
                                                    ),
                                                  ),
                                                )
                                              : ListView.builder(
                                                  itemCount:
                                                      selectedReminders.length,
                                                  itemBuilder:
                                                      (context, index) {
                                                    final doc =
                                                        selectedReminders[
                                                            index];
                                                    return _buildReminderCard(
                                                      doc.id,
                                                      doc.data(),
                                                    );
                                                  },
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
              ),
            ],
          ),
        ),
        bottomNavigationBar: _buildBottomNavigation(),
      ),
    );
  }
}
