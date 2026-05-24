import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'VolunteerHelpChat.dart';
import 'VolunteerHelpCall.dart';
import 'call_engine_service.dart';

import 'package:humantouch/pages/app_settings_store.dart';
import 'voice_accessibility_service.dart';

class VolunteerHelpInfoPage extends StatefulWidget {
  final Map<String, dynamic> volunteer;

  const VolunteerHelpInfoPage({super.key, required this.volunteer});

  @override
  State<VolunteerHelpInfoPage> createState() => _VolunteerHelpInfoPageState();
}

class _VolunteerHelpInfoPageState extends State<VolunteerHelpInfoPage> {
  DateTime? _selectedDate;
  String? _selectedTime;

  bool _loading = false;
  bool _showDateError = false;
  bool _showTimeError = false;
  bool _showDescriptionError = false;
  bool _sendingReview = false;
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

  int _selectedReviewStars = 0;

  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _reviewController = TextEditingController();

  final List<String> _defaultTimes = [
    '09:00 AM',
    '11:00 AM',
    '02:00 PM',
    '04:00 PM',
    '06:00 PM',
  ];

  bool get isArabic => AppSettingsStore.instance.isArabic;
  bool get isDarkMode => AppSettingsStore.instance.isDarkMode;

  Color get backgroundColor => Theme.of(context).scaffoldBackgroundColor;

  Color get cardColor => Theme.of(context).cardColor;

  Color get textColor =>
      Theme.of(context).textTheme.bodyLarge?.color ?? const Color(0xFF263238);

  Color get titleColor =>
      Theme.of(context).textTheme.titleLarge?.color ?? const Color(0xFF1A1A1A);

  Color get subTextColor =>
      Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.65) ??
      Colors.black54;

  Color get borderColor => Theme.of(context).dividerColor;

  String tr(String en, String ar) => isArabic ? ar : en;

  bool get isSmallScreen {
    final width = MediaQuery.maybeOf(context)?.size.width ?? 400;
    return width < 380;
  }

  Map<String, dynamic> get _fallbackVolunteerData => widget.volunteer;

  String _readString(Map<String, dynamic> data, List<String> keys,
      {String defaultValue = ''}) {
    for (final key in keys) {
      final value = data[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString();
      }
    }
    return defaultValue;
  }

  String get _volunteerId => widget.volunteer['id'].toString();

  String _volunteerNameFrom(Map<String, dynamic> data) {
    return _readString(
      data,
      ['name', 'fullName', 'username'],
      defaultValue: 'Volunteer',
    );
  }

  String _emailFrom(Map<String, dynamic> data) {
    return _readString(
      data,
      ['email', 'volunteerEmail'],
      defaultValue: '',
    );
  }

  String _helpTypeFrom(Map<String, dynamic> data) {
    return _readString(
      data,
      ['helpType', 'volunteerType', 'typeOfAssistance'],
      defaultValue: 'Daily Support',
    );
  }

  String _phoneFrom(Map<String, dynamic> data) {
    return _readString(
      data,
      ['phone', 'phoneNumber', 'mobile'],
      defaultValue: '',
    );
  }

  String _locationFrom(Map<String, dynamic> data) {
    return _readString(
      data,
      ['location', 'address', 'city', 'country'],
      defaultValue: 'Bahrain',
    );
  }

  String _bioFrom(Map<String, dynamic> data) {
    return _readString(
      data,
      ['volunteerBio', 'bio', 'about', 'aboutMe'],
      defaultValue: tr(
        'No about information added yet.',
        'لم تتم إضافة نبذة بعد.',
      ),
    );
  }

  String _skillFrom(Map<String, dynamic> data) {
    return _readString(
      data,
      ['volunteerSkill', 'skill', 'skills'],
      defaultValue: '',
    );
  }

  String _specialtyFrom(Map<String, dynamic> data) {
    return _readString(
      data,
      ['volunteerSpecialty', 'specialty', 'major'],
      defaultValue: '',
    );
  }

  bool _isVolunteerAvailableFrom(Map<String, dynamic> data) {
    return data['isAvailable'] ?? true;
  }

  List<String> _availableTimesFrom(Map<String, dynamic> data) {
    final dynamic rawTimes = data['availableTimes'] ??
        data['availabilityTimes'] ??
        data['freeTimes'];

    if (rawTimes is List && rawTimes.isNotEmpty) {
      return rawTimes.map((e) => e.toString()).toList();
    }

    return _defaultTimes;
  }

  String helpTypeText(String value) {
    switch (value) {
      case 'Medical':
        return tr('Medical', 'طبي');
      case 'Shopping':
        return tr('Shopping', 'تسوق');
      case 'Transportation':
        return tr('Transportation', 'مواصلات');
      case 'Daily Support':
        return tr('Daily Support', 'دعم يومي');
      case 'Other':
        return tr('Other', 'أخرى');
      default:
        return value;
    }
  }

  @override
  void initState() {
    super.initState();
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
    _descriptionController.dispose();
    _reviewController.dispose();
    super.dispose();
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> _volunteerStream() {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(_volunteerId)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _reviewsStream() async* {
    try {
      yield* FirebaseFirestore.instance
          .collection('volunteer_reviews')
          .where('volunteerId', isEqualTo: _volunteerId)
          .snapshots();
    } catch (e) {
      debugPrint('Reviews Error: $e');
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2035),
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaleFactor: AppSettingsStore.instance.textScale,
          ),
          child: Directionality(
            textDirection:
                isArabic ? ui.TextDirection.rtl : ui.TextDirection.ltr,
            child: child!,
          ),
        );
      },
    );

    if (picked == null) return;

    setState(() {
      _selectedDate = picked;
      _selectedTime = null;
      _showDateError = false;
    });
  }

  String _dateKey(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  Future<void> _book(Map<String, dynamic> volunteerData) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final description = _descriptionController.text.trim();

    setState(() {
      _showDateError = _selectedDate == null;
      _showTimeError = _selectedTime == null;
      _showDescriptionError = description.isEmpty;
    });

    if (_showDateError || _showTimeError || _showDescriptionError) {
      return;
    }

    setState(() => _loading = true);

    try {
      final dateKey = _dateKey(_selectedDate!);

      final volunteerDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_volunteerId)
          .get();

      final latestVolunteerData = volunteerDoc.data() ?? volunteerData;

      final bool isAvailableNow = latestVolunteerData['isAvailable'] ??
          _isVolunteerAvailableFrom(volunteerData);

      if (!isAvailableNow) {
        if (!mounted) return;

        setState(() => _loading = false);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              tr(
                'This volunteer is not available now',
                'هذا المتطوع غير متاح حالياً',
              ),
            ),
          ),
        );
        return;
      }

      final List<String> availableTimes =
          _availableTimesFrom(latestVolunteerData);

      if (availableTimes.isNotEmpty &&
          !availableTimes.contains(_selectedTime)) {
        if (!mounted) return;

        setState(() => _loading = false);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              tr(
                'This time is not within the volunteer available times',
                'هذا الوقت ليس ضمن أوقات توفر المتطوع',
              ),
            ),
          ),
        );
        return;
      }

      final conflict = await FirebaseFirestore.instance
          .collection('volunteer_requests')
          .where('volunteerId', isEqualTo: _volunteerId)
          .where('date', isEqualTo: dateKey)
          .where('time', isEqualTo: _selectedTime)
          .where('status', whereIn: ['pending', 'accepted']).get();

      if (conflict.docs.isNotEmpty) {
        if (!mounted) return;

        setState(() => _loading = false);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              tr(
                'This time is already booked. Please choose another time.',
                'هذا الوقت محجوز مسبقاً. يرجى اختيار وقت آخر.',
              ),
            ),
          ),
        );
        return;
      }

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final userData = userDoc.data() ?? {};

      await FirebaseFirestore.instance.collection('volunteer_requests').add({
        'volunteerId': _volunteerId,
        'volunteerName': _volunteerNameFrom(volunteerData),
        'patientId': user.uid,
        'patientName': userData['name'] ??
            userData['fullName'] ??
            userData['username'] ??
            'Patient',
        'date': dateKey,
        'time': _selectedTime,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'requestDateTime': Timestamp.fromDate(_selectedDate!),
        'needTitle': helpTypeText(_helpTypeFrom(volunteerData)),
        'needDescription': description,
        'location': userData['location'] ?? userData['address'] ?? '',
        'patientPhone': userData['phone'] ?? userData['phoneNumber'] ?? '',
        'patientEmail': userData['email'] ?? user.email ?? '',
        'volunteerPhone': _phoneFrom(volunteerData),
        'volunteerEmail': _emailFrom(volunteerData),
      });

      if (!mounted) return;

      setState(() {
        _loading = false;
        _selectedDate = null;
        _selectedTime = null;
        _descriptionController.clear();
        _showDateError = false;
        _showTimeError = false;
        _showDescriptionError = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(tr('Help request sent', 'تم إرسال طلب المساعدة'))),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() => _loading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr(
              'Failed to send request. Please try again.',
              'فشل إرسال الطلب. حاولي مرة أخرى.',
            ),
          ),
        ),
      );
    }
  }

  Future<void> _submitReview() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final review = _reviewController.text.trim();

    if (_selectedReviewStars == 0 || review.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr(
              'Please add rating and review',
              'يرجى إضافة التقييم والمراجعة',
            ),
          ),
        ),
      );
      return;
    }

    try {
      setState(() => _sendingReview = true);

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final userData = userDoc.data() ?? {};

      await FirebaseFirestore.instance.collection('volunteer_reviews').add({
        'volunteerId': _volunteerId,
        'patientId': user.uid,
        'patientName': userData['name'] ??
            userData['fullName'] ??
            userData['username'] ??
            'Patient',
        'stars': _selectedReviewStars,
        'review': review,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      setState(() {
        _sendingReview = false;
        _selectedReviewStars = 0;
        _reviewController.clear();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('Review added', 'تمت إضافة المراجعة'))),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() => _sendingReview = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr(
              'Failed to send review',
              'فشل إرسال المراجعة',
            ),
          ),
        ),
      );

      debugPrint('Submit Review Error: $e');
    }
  }

  void _openChat(Map<String, dynamic> volunteerData) {
    VoiceAccessibilityService.instance.stopAll();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VolunteerHelpChatPage(
          volunteerId: _volunteerId,
          volunteerName: _volunteerNameFrom(volunteerData),
        ),
      ),
    );
  }

  void _openCall(Map<String, dynamic> volunteerData) {
    VoiceAccessibilityService.instance.stopAll();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VolunteerHelpCallPage(
          volunteerId: _volunteerId,
          volunteerName: _volunteerNameFrom(volunteerData),
        ),
      ),
    );
  }

  String _formatCallStatus(String status) {
    switch (status) {
      case 'calling':
        return tr('Calling...', 'جاري الاتصال...');
      case 'ringing':
        return tr('Ringing...', 'يرن...');
      case 'accepted':
        return tr('Connected', 'متصل');
      case 'rejected':
        return tr('Rejected', 'مرفوض');
      case 'missed':
        return tr('Missed Call', 'مكالمة فائتة');
      case 'ended':
        return tr('Call Ended', 'انتهت المكالمة');
      case 'failed':
        return tr('Failed', 'فشل');
      default:
        return tr('Ready', 'جاهز');
    }
  }

  List<BoxShadow> _shadow() {
    return [
      BoxShadow(
        color: Colors.black.withOpacity(isDarkMode ? 0.18 : 0.06),
        blurRadius: 12,
        offset: const Offset(0, 5),
      ),
    ];
  }

  Widget _buildHeader() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          alignment: Alignment.bottomCenter,
          children: [
            Container(
              height: isSmallScreen ? 115 : 130,
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
                onPressed: () {
                  VoiceAccessibilityService.instance.stopAll();
                  Navigator.pop(context);
                },
                icon: Icon(
                  isArabic ? Icons.arrow_forward : Icons.arrow_back,
                  size: 28,
                  color: textColor,
                ),
              ),
              Expanded(
                child: Text(
                  tr('Volunteer Details', 'تفاصيل المتطوع'),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: isSmallScreen ? 21 : 25,
                    fontWeight: FontWeight.bold,
                    color: titleColor,
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

  Widget _sectionCard({
    required Widget child,
    EdgeInsets? padding,
  }) {
    return Container(
      width: double.infinity,
      padding: padding ?? EdgeInsets.all(isSmallScreen ? 14 : 18),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: borderColor),
        boxShadow: _shadow(),
      ),
      child: child,
    );
  }

  Widget _buildProfileCard(Map<String, dynamic> data) {
    final name = _volunteerNameFrom(data);
    final email = _emailFrom(data);
    final helpType = _helpTypeFrom(data);
    final skill = _skillFrom(data);
    final specialty = _specialtyFrom(data);

    final subtitle = specialty.isNotEmpty
        ? specialty
        : skill.isNotEmpty
            ? skill
            : helpTypeText(helpType);

    return _sectionCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: isSmallScreen ? 38 : 44,
            backgroundColor: const Color(0xFFE3F6FF),
            child: Icon(
              Icons.person,
              color: const Color(0xFF2196F3),
              size: isSmallScreen ? 42 : 48,
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  isArabic ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  textAlign: isArabic ? TextAlign.right : TextAlign.left,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: isSmallScreen ? 22 : 26,
                    fontWeight: FontWeight.bold,
                    color: titleColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  textAlign: isArabic ? TextAlign.right : TextAlign.left,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: isSmallScreen ? 14 : 15,
                    color: const Color(0xFF0277BD),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (email.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    email,
                    textAlign: isArabic ? TextAlign.right : TextAlign.left,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: isSmallScreen ? 12 : 14,
                      color: subTextColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAboutCard(Map<String, dynamic> data) {
    return _sectionCard(
      child: Column(
        crossAxisAlignment:
            isArabic ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Text(
            tr('About Me', 'نبذة عني'),
            textAlign: isArabic ? TextAlign.right : TextAlign.left,
            style: TextStyle(
              fontSize: isSmallScreen ? 17 : 19,
              fontWeight: FontWeight.bold,
              color: titleColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _bioFrom(data),
            textAlign: isArabic ? TextAlign.right : TextAlign.left,
            style: TextStyle(
              fontSize: isSmallScreen ? 14 : 16,
              color: textColor,
              height: 1.4,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _contactInfoRow(IconData icon, String title, String value,
      {bool showDivider = true}) {
    if (value.trim().isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: const Color(0xFFE3F6FF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: const Color(0xFF2196F3),
                size: 24,
              ),
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
                    style: TextStyle(
                      fontSize: isSmallScreen ? 12 : 13,
                      color: subTextColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    textAlign: isArabic ? TextAlign.right : TextAlign.left,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: isSmallScreen ? 14 : 16,
                      color: titleColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (showDivider)
          Padding(
            padding: const EdgeInsets.only(left: 60, top: 10, bottom: 10),
            child: Divider(color: borderColor, height: 1),
          ),
      ],
    );
  }

  Widget _buildContactInformationCard(Map<String, dynamic> data) {
    final available = _isVolunteerAvailableFrom(data);

    return _sectionCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment:
            isArabic ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(isSmallScreen ? 14 : 18),
            child: Column(
              crossAxisAlignment:
                  isArabic ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Text(
                  tr('Contact Information', 'معلومات التواصل'),
                  textAlign: isArabic ? TextAlign.right : TextAlign.left,
                  style: TextStyle(
                    fontSize: isSmallScreen ? 17 : 19,
                    fontWeight: FontWeight.bold,
                    color: titleColor,
                  ),
                ),
                const SizedBox(height: 14),
                _contactInfoRow(
                  Icons.phone,
                  tr('Phone', 'الهاتف'),
                  _phoneFrom(data),
                ),
                _contactInfoRow(
                  Icons.email,
                  tr('Email', 'الإيميل'),
                  _emailFrom(data),
                ),
                _contactInfoRow(
                  Icons.location_on,
                  tr('Location', 'الموقع'),
                  _locationFrom(data),
                  showDivider: false,
                ),
              ],
            ),
          ),
          Divider(color: borderColor, height: 1),
          Padding(
            padding: EdgeInsets.all(isSmallScreen ? 10 : 12),
            child: Column(
              children: [
                _buildContactButtons(data),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.circle,
                      size: 12,
                      color: available ? Colors.green : Colors.red,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      available
                          ? tr('Available', 'متاح')
                          : tr('Not Available', 'غير متاح'),
                      style: TextStyle(
                        color: available ? Colors.green : Colors.red,
                        fontSize: isSmallScreen ? 13 : 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactButtons(Map<String, dynamic> data) {
    return Row(
      children: [
        Expanded(
          child: _contactButton(
            icon: Icons.chat_bubble_outline,
            label: tr('Chat', 'محادثة'),
            onPressed: () => _openChat(data),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _contactButton(
            icon: Icons.call,
            label: tr('Call', 'اتصال'),
            onPressed: () => _openCall(data),
          ),
        ),
      ],
    );
  }

  Widget _contactButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: isSmallScreen ? 48 : 52,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: isSmallScreen ? 18 : 20),
        label: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF87CEEB),
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 52),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

  Widget _buildCallStatus() {
    return StreamBuilder<String>(
      stream: CallEngineService.instance.statusStream,
      initialData: CallEngineService.instance.callStatus,
      builder: (context, snap) {
        return Text(
          _formatCallStatus(snap.data ?? 'idle'),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.grey,
            fontSize: isSmallScreen ? 11 : 12,
          ),
        );
      },
    );
  }

  Widget _timeChip(String time) {
    final selected = _selectedTime == time;

    return InkWell(
      onTap: () {
        setState(() {
          _selectedTime = time;
          _showTimeError = false;
        });
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: isSmallScreen ? 96 : 108,
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF87CEEB) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? const Color(0xFF87CEEB) : Colors.black26,
          ),
        ),
        child: Text(
          time,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: selected ? Colors.white : titleColor,
            fontWeight: FontWeight.bold,
            fontSize: isSmallScreen ? 13 : 15,
          ),
        ),
      ),
    );
  }

  Widget _errorText(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 7),
      child: Text(
        text,
        textAlign: isArabic ? TextAlign.right : TextAlign.left,
        style: const TextStyle(
          color: Colors.red,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildBookingCard(Map<String, dynamic> data) {
    final times = _availableTimesFrom(data);
    final isAvailable = _isVolunteerAvailableFrom(data);

    return _sectionCard(
      child: Column(
        crossAxisAlignment:
            isArabic ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Text(
            tr('Book Appointment', 'حجز موعد'),
            textAlign: isArabic ? TextAlign.right : TextAlign.left,
            style: TextStyle(
              fontSize: isSmallScreen ? 17 : 19,
              fontWeight: FontWeight.bold,
              color: titleColor,
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _descriptionController,
            maxLines: 4,
            textAlign: isArabic ? TextAlign.right : TextAlign.left,
            decoration: InputDecoration(
              hintText: tr(
                'Describe the help you need...',
                'اكتب وصف المساعدة التي تحتاجها...',
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.all(14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: borderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: _showDescriptionError ? Colors.red : borderColor,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: _showDescriptionError
                      ? Colors.red
                      : const Color(0xFF87CEEB),
                  width: 1.5,
                ),
              ),
            ),
            onChanged: (_) {
              if (_showDescriptionError &&
                  _descriptionController.text.trim().isNotEmpty) {
                setState(() => _showDescriptionError = false);
              }
            },
          ),
          if (_showDescriptionError)
            _errorText(
              tr(
                'Please write the help description',
                'يرجى كتابة وصف المساعدة',
              ),
            ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: isSmallScreen ? 48 : 50,
            child: OutlinedButton.icon(
              onPressed: _pickDate,
              icon: const Icon(Icons.calendar_month),
              label: Text(
                _selectedDate == null
                    ? tr('Choose Date', 'اختر التاريخ')
                    : _dateKey(_selectedDate!),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF0277BD),
                side: BorderSide(
                  color: _showDateError ? Colors.red : Colors.black38,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
          if (_showDateError)
            _errorText(tr('Please choose date', 'يرجى اختيار التاريخ')),
          const SizedBox(height: 14),
          if (!isAvailable)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.08),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                tr(
                  'This volunteer is currently busy',
                  'هذا المتطوع مشغول حالياً',
                ),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          else if (times.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.08),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                tr(
                  'No available times for this volunteer',
                  'لا توجد أوقات متاحة لهذا المتطوع',
                ),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.orange,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          else
            Wrap(
              spacing: 12,
              runSpacing: 10,
              children: times.map(_timeChip).toList(),
            ),
          if (_showTimeError)
            _errorText(tr('Please choose time', 'يرجى اختيار الوقت')),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: isSmallScreen ? 50 : 54,
            child: ElevatedButton.icon(
              onPressed: _loading || !isAvailable ? null : () => _book(data),
              icon: _loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.volunteer_activism),
              label: Text(
                _loading
                    ? tr('Sending...', 'جاري الإرسال...')
                    : tr('Request Help', 'طلب مساعدة'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: isSmallScreen ? 15 : 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF87CEEB),
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 54),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _starsInput() {
    return Row(
      mainAxisAlignment:
          isArabic ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: List.generate(5, (index) {
        final starNumber = index + 1;
        return IconButton(
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          onPressed: () {
            setState(() {
              _selectedReviewStars = starNumber;
            });
          },
          icon: Icon(
            starNumber <= _selectedReviewStars ? Icons.star : Icons.star_border,
            color: Colors.amber,
            size: 30,
          ),
        );
      }),
    );
  }

  Widget _starsView(double rating, {double size = 18}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        return Icon(
          index < rating.round() ? Icons.star : Icons.star_border,
          color: Colors.amber,
          size: size,
        );
      }),
    );
  }

  Widget _buildReviewsCard() {
    return _sectionCard(
      child: Column(
        crossAxisAlignment:
            isArabic ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Text(
            tr('Reviews', 'المراجعات'),
            textAlign: isArabic ? TextAlign.right : TextAlign.left,
            style: TextStyle(
              fontSize: isSmallScreen ? 17 : 19,
              fontWeight: FontWeight.bold,
              color: titleColor,
            ),
          ),
          const SizedBox(height: 14),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _reviewsStream(),
            builder: (context, snapshot) {
              final docs = snapshot.data?.docs ?? [];

              double average = 0.0;
              if (docs.isNotEmpty) {
                double total = 0.0;
                for (final doc in docs) {
                  final data = doc.data();
                  total += (data['stars'] ?? 0).toDouble();
                }
                average = total / docs.length;
              }

              return Column(
                crossAxisAlignment: isArabic
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: isArabic
                        ? MainAxisAlignment.end
                        : MainAxisAlignment.start,
                    children: [
                      _starsView(average, size: 22),
                      const SizedBox(width: 8),
                      Text(
                        '${average.toStringAsFixed(1)} (${docs.length} ${tr('reviews', 'مراجعات')})',
                        style: TextStyle(
                          fontSize: isSmallScreen ? 13 : 15,
                          fontWeight: FontWeight.bold,
                          color: titleColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    tr('Add Your Review', 'أضف مراجعتك'),
                    style: TextStyle(
                      fontSize: isSmallScreen ? 15 : 16,
                      fontWeight: FontWeight.bold,
                      color: titleColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _starsInput(),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _reviewController,
                    maxLines: 3,
                    textAlign: isArabic ? TextAlign.right : TextAlign.left,
                    decoration: InputDecoration(
                      hintText: tr(
                        'Write your review...',
                        'اكتب مراجعتك...',
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.all(14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: borderColor),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: borderColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                          color: Color(0xFF87CEEB),
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: _sendingReview ? null : _submitReview,
                      icon: _sendingReview
                          ? const SizedBox(
                              width: 17,
                              height: 17,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.rate_review),
                      label: Text(
                        _sendingReview
                            ? tr('Sending...', 'جاري الإرسال...')
                            : tr('Submit Review', 'إرسال المراجعة'),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF87CEEB),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Divider(color: borderColor),
                  const SizedBox(height: 8),
                  if (snapshot.connectionState == ConnectionState.waiting)
                    const Center(child: CircularProgressIndicator())
                  else if (docs.isEmpty)
                    Text(
                      tr(
                        'No reviews yet.',
                        'لا توجد مراجعات بعد.',
                      ),
                      textAlign: isArabic ? TextAlign.right : TextAlign.left,
                      style: TextStyle(
                        color: subTextColor,
                        fontWeight: FontWeight.w500,
                      ),
                    )
                  else
                    Column(
                      children: docs.map((doc) {
                        final reviewData = doc.data();
                        final patientName =
                            reviewData['patientName']?.toString() ?? 'Patient';
                        final reviewText =
                            reviewData['review']?.toString() ?? '';
                        final stars = (reviewData['stars'] ?? 0).toDouble();

                        return Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8F8F8),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: borderColor),
                          ),
                          child: Column(
                            crossAxisAlignment: isArabic
                                ? CrossAxisAlignment.end
                                : CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: isArabic
                                    ? MainAxisAlignment.end
                                    : MainAxisAlignment.start,
                                children: [
                                  Flexible(
                                    child: Text(
                                      patientName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: titleColor,
                                        fontSize: isSmallScreen ? 13 : 15,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  _starsView(stars, size: 16),
                                ],
                              ),
                              if (reviewText.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(
                                  reviewText,
                                  textAlign: isArabic
                                      ? TextAlign.right
                                      : TextAlign.left,
                                  style: TextStyle(
                                    color: textColor,
                                    height: 1.35,
                                    fontSize: isSmallScreen ? 13 : 14,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                ],
              );
            },
          ),
        ],
      ),
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
        'Volunteer Details screen with volunteer profile, about section, contact information, chat and call buttons, availability status, appointment booking, date and time selection, request help button, and reviews.',
        'صفحة تفاصيل المتطوع تحتوي على ملف المتطوع، قسم النبذة، معلومات التواصل، أزرار المحادثة والاتصال، حالة التوفر، حجز موعد، اختيار التاريخ والوقت، زر طلب المساعدة، والمراجعات.',
      ),
      routes: {
        'volunteer': (context) => const SizedBox.shrink(),
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
            width: isSmallScreen ? 68 : 76,
            height: isSmallScreen ? 68 : 76,
            decoration: BoxDecoration(
              color: _isSpeaking
                  ? const Color(0xFF87CEEB) // Blue = reading
                  : const Color(0xFFFF5A5F), // Red = silent
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: isDarkMode
                      ? const Color(0x59000000)
                      : const Color(0x2E000000),
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
              size: isSmallScreen ? 34 : 40,
            ),
          ),
        ),
      ),
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
            child: GestureDetector(
              onTap: () => FocusScope.of(context).unfocus(),
              child: Scaffold(
                resizeToAvoidBottomInset: true,
                backgroundColor: backgroundColor,
                body: Stack(
                  children: [
                    SafeArea(
                      child:
                          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                        stream: _volunteerStream(),
                        builder: (context, snapshot) {
                          Map<String, dynamic> volunteerData =
                              Map<String, dynamic>.from(
                            _fallbackVolunteerData,
                          );

                          if (snapshot.hasData &&
                              snapshot.data!.data() != null) {
                            volunteerData.addAll(snapshot.data!.data()!);
                            volunteerData['id'] = _volunteerId;
                          }

                          return Column(
                            children: [
                              _buildHeader(),
                              Expanded(
                                child: SingleChildScrollView(
                                  keyboardDismissBehavior:
                                      ScrollViewKeyboardDismissBehavior.onDrag,
                                  padding: const EdgeInsets.fromLTRB(
                                    20,
                                    8,
                                    20,
                                    32,
                                  ),
                                  child: Column(
                                    children: [
                                      _buildProfileCard(volunteerData),
                                      const SizedBox(height: 16),
                                      _buildAboutCard(volunteerData),
                                      const SizedBox(height: 16),
                                      _buildContactInformationCard(
                                        volunteerData,
                                      ),
                                      const SizedBox(height: 16),
                                      _buildBookingCard(volunteerData),
                                      const SizedBox(height: 16),
                                      _buildReviewsCard(),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    _voiceControlButton(),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
