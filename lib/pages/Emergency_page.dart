import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_sms/flutter_sms.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'Dashboard_page.dart';
import 'Profile_page.dart';
import 'Settings_page.dart';

import 'package:humantouch/pages/app_settings_store.dart';
import 'voice_accessibility_service.dart';

class EmergencyPage extends StatefulWidget {
  const EmergencyPage({super.key});

  @override
  State<EmergencyPage> createState() => _EmergencyPageState();
}

class VolunteerContact {
  final String id;
  final String name;
  final String phone;
  final double latitude;
  final double longitude;
  final bool available;

  const VolunteerContact({
    required this.id,
    required this.name,
    required this.phone,
    required this.latitude,
    required this.longitude,
    required this.available,
  });
}

class _EmergencyPageState extends State<EmergencyPage> {
  bool _isSending = false;
  bool _isLoadingSettings = true;
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

  String _statusMessage = '';
  String _companionPhone = '';
  String _companionId = '';
  String _companionName = '';
  String _patientName = 'Patient';

  bool _callCompanion = true;
  bool _sendSmsToCompanion = true;
  bool _alertNearbyVolunteers = true;

  bool get isArabic => AppSettingsStore.instance.isArabic;

  Color get backgroundColor => Theme.of(context).scaffoldBackgroundColor;

  Color get cardColor => Theme.of(context).cardColor;

  Color get textColor =>
      Theme.of(context).textTheme.bodyLarge?.color ?? const Color(0xFF1A1A1A);

  Color get subTextColor => const Color(0xFF666666);

  Color get blueColor => const Color(0xFF87CEEB);

  Color get darkTextColor =>
      Theme.of(context).textTheme.bodyLarge?.color ?? const Color(0xFF1A1A1A);

  Color get infoBoxColor =>
      Theme.of(context).inputDecorationTheme.fillColor ??
      const Color(0xFFF5FBFF);

  String tr(String en, String ar) {
    return isArabic ? ar : en;
  }

  @override
  void initState() {
    super.initState();
    _loadEmergencySettingsFromFirebase();
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

  String _textFromMap(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString().trim();
      }
    }
    return '';
  }

  double _doubleFromMap(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];
      if (value == null) continue;

      if (value is num) return value.toDouble();

      final parsed = double.tryParse(value.toString());
      if (parsed != null) return parsed;
    }
    return 0;
  }

  String _normalizePhone(String phone) {
    return phone.replaceAll(RegExp(r'[^0-9+]'), '').trim();
  }

  Future<Map<String, dynamic>?> _findCompanionData(
    Map<String, dynamic> patientData,
  ) async {
    final firestore = FirebaseFirestore.instance;

    final directCompanionId = _textFromMap(patientData, [
      'companionId',
      'companionUid',
      'linkedCompanionId',
      'selectedCompanionId',
    ]);

    if (directCompanionId.isNotEmpty) {
      final companionDoc =
          await firestore.collection('users').doc(directCompanionId).get();

      final companionData = companionDoc.data();

      if (companionData != null) {
        return {
          'id': companionDoc.id,
          ...companionData,
        };
      }
    }

    final patientEmail = _textFromMap(patientData, ['email']);
    final patientPhone = _textFromMap(patientData, ['phone', 'phoneNumber']);

    QuerySnapshot<Map<String, dynamic>>? companionSnapshot;

    if (patientEmail.isNotEmpty) {
      companionSnapshot = await firestore
          .collection('users')
          .where('role', isEqualTo: 'companion')
          .where('patientEmail', isEqualTo: patientEmail)
          .limit(1)
          .get();

      if (companionSnapshot.docs.isNotEmpty) {
        final doc = companionSnapshot.docs.first;
        return {'id': doc.id, ...doc.data()};
      }
    }

    if (patientPhone.isNotEmpty) {
      companionSnapshot = await firestore
          .collection('users')
          .where('role', isEqualTo: 'companion')
          .where('patientPhone', isEqualTo: patientPhone)
          .limit(1)
          .get();

      if (companionSnapshot.docs.isNotEmpty) {
        final doc = companionSnapshot.docs.first;
        return {'id': doc.id, ...doc.data()};
      }
    }

    return null;
  }

  Future<void> _loadEmergencySettingsFromFirebase() async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        if (!mounted) return;
        setState(() => _isLoadingSettings = false);
        return;
      }

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final patientData = doc.data() ?? {};

      final companionData = await _findCompanionData(patientData);

      final directPhone = _textFromMap(patientData, [
        'companionPhone',
        'companionPhoneNumber',
        'emergencyPhone',
        'emergencyContactPhone',
      ]);

      final firebaseCompanionPhone = companionData == null
          ? ''
          : _textFromMap(companionData, [
              'phone',
              'phoneNumber',
              'companionPhone',
              'mobile',
            ]);

      if (!mounted) return;

      setState(() {
        _patientName = _textFromMap(patientData, [
          'name',
          'fullName',
          'username',
        ]);

        if (_patientName.trim().isEmpty) {
          _patientName = user.displayName?.trim().isNotEmpty == true
              ? user.displayName!.trim()
              : 'Patient';
        }

        _companionId = companionData == null
            ? _textFromMap(patientData, [
                'companionId',
                'companionUid',
                'linkedCompanionId',
              ])
            : (companionData['id'] ?? '').toString();

        _companionName = companionData == null
            ? _textFromMap(patientData, ['companionName'])
            : _textFromMap(companionData, [
                'name',
                'fullName',
                'username',
              ]);

        _companionPhone = _normalizePhone(
          firebaseCompanionPhone.isNotEmpty
              ? firebaseCompanionPhone
              : directPhone,
        );

        _callCompanion = patientData['callCompanion'] ?? true;
        _sendSmsToCompanion = patientData['sendSmsToCompanion'] ?? true;
        _alertNearbyVolunteers = patientData['alertNearbyVolunteers'] ?? true;
        _isLoadingSettings = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoadingSettings = false;
        _statusMessage = tr(
          'Failed to load emergency settings.',
          'فشل تحميل إعدادات الطوارئ.',
        );
      });
    }
  }

  void _goToPage(int index) {
    if (index == 0) {
      Navigator.pushReplacementNamed(context, '/dashboard');
    } else if (index == 1) {
      Navigator.pushReplacementNamed(context, '/profile');
    } else if (index == 2) {
      Navigator.pushReplacementNamed(context, '/settings');
    }
  }

  void _goBack() {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      Navigator.pushReplacementNamed(context, '/dashboard');
    }
  }

  Future<bool> _showConfirmDialog({
    required String title,
    required String message,
    required IconData icon,
    required Color iconColor,
    String? confirmText,
    String? cancelText,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
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
                    color: darkTextColor,
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
                  style: TextStyle(color: blueColor),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: iconColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
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

  Future<void> _showInfoDialog({
    required String title,
    required String message,
    required IconData icon,
    required Color iconColor,
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
                    color: darkTextColor,
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
                  backgroundColor: blueColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
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

  Future<void> _showLoadingDialog({
    required String title,
    required String message,
  }) async {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Directionality(
          textDirection: isArabic ? ui.TextDirection.rtl : ui.TextDirection.ltr,
          child: AlertDialog(
            backgroundColor: cardColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: blueColor),
                const SizedBox(height: 18),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: darkTextColor,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: subTextColor,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _closeDialogIfOpen() {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  Future<bool> _showEmergencyConfirmationPopup() async {
    return _showConfirmDialog(
      title: tr('Emergency Confirmation', 'تأكيد الطوارئ'),
      message: tr(
        'Do you want to send an emergency alert? Your current location may be shared with your companion and nearest volunteer.',
        'هل تريد إرسال تنبيه الطوارئ؟ قد يتم مشاركة موقعك الحالي مع المرافق وأقرب متطوع.',
      ),
      icon: Icons.warning_amber_rounded,
      iconColor: Colors.red,
      confirmText: tr('Send SOS', 'إرسال SOS'),
      cancelText: tr('Cancel', 'إلغاء'),
    );
  }

  Future<bool> _showCallConfirmationPopup() async {
    return _showConfirmDialog(
      title: tr('Call Confirmation', 'تأكيد الاتصال'),
      message: tr(
        'Do you want to call your companion now?',
        'هل تريد الاتصال بالمرافق الآن؟',
      ),
      icon: Icons.phone_rounded,
      iconColor: Colors.green,
      confirmText: tr('Call', 'اتصال'),
      cancelText: tr('Skip', 'تخطي'),
    );
  }

  Future<void> _showLocationPermissionPopup() async {
    await _showInfoDialog(
      title: tr('Location Permission', 'إذن الموقع'),
      message: tr(
        'The app needs location access to send your current location during emergencies.',
        'يحتاج التطبيق إلى إذن الموقع لإرسال موقعك الحالي أثناء الطوارئ.',
      ),
      icon: Icons.location_on_rounded,
      iconColor: Colors.orange,
    );
  }

  Future<void> _showSmsCallPermissionPopup() async {
    await _showInfoDialog(
      title: tr('SMS / Call Permission', 'إذن الرسائل والاتصال'),
      message: tr(
        'The app may open SMS or phone call services to contact your companion during emergencies.',
        'قد يفتح التطبيق خدمة الرسائل أو الاتصال للتواصل مع المرافق أثناء الطوارئ.',
      ),
      icon: Icons.sms_rounded,
      iconColor: blueColor,
    );
  }

  Future<void> _showEmergencySentSuccessfullyPopup(String message) async {
    await _showInfoDialog(
      title: tr('Emergency Sent Successfully', 'تم إرسال الطوارئ بنجاح'),
      message: message,
      icon: Icons.check_circle_rounded,
      iconColor: Colors.green,
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

  Future<Position> _getCurrentLocation() async {
    final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      await _showLocationPermissionPopup();
      throw Exception(tr(
        'Location services are disabled.',
        'خدمات الموقع غير مفعلة.',
      ));
    }

    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      await _showLocationPermissionPopup();
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      throw Exception(tr(
        'Location permission denied.',
        'تم رفض إذن الموقع.',
      ));
    }

    if (permission == LocationPermission.deniedForever) {
      await _showLocationPermissionPopup();
      throw Exception(tr(
        'Location permission denied forever.',
        'تم رفض إذن الموقع بشكل دائم.',
      ));
    }

    await _showLoadingDialog(
      title: tr('Sending Location', 'جاري إرسال الموقع'),
      message: tr(
        'Getting your current location for the emergency alert...',
        'جاري تحديد موقعك الحالي لتنبيه الطوارئ...',
      ),
    );

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );

    if (mounted) {
      _closeDialogIfOpen();
    }

    return position;
  }

  Future<List<VolunteerContact>> _loadVolunteersFromFirebase() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'volunteer')
        .where('isAvailable', isEqualTo: true)
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();

      return VolunteerContact(
        id: doc.id,
        name: _textFromMap(data, ['name', 'fullName', 'username']).isEmpty
            ? 'Volunteer'
            : _textFromMap(data, ['name', 'fullName', 'username']),
        phone: _normalizePhone(_textFromMap(data, [
          'phone',
          'phoneNumber',
          'mobile',
        ])),
        latitude: _doubleFromMap(data, ['latitude', 'lat']),
        longitude: _doubleFromMap(data, ['longitude', 'lng', 'lon']),
        available: data['isAvailable'] ?? data['available'] ?? false,
      );
    }).where((volunteer) {
      return volunteer.phone.trim().isNotEmpty &&
          volunteer.latitude != 0 &&
          volunteer.longitude != 0;
    }).toList();
  }

  Future<VolunteerContact?> _findNearestVolunteer(
    Position patientPosition,
  ) async {
    final availableVolunteers = await _loadVolunteersFromFirebase();

    if (availableVolunteers.isEmpty) return null;

    VolunteerContact nearest = availableVolunteers.first;

    double nearestDistance = Geolocator.distanceBetween(
      patientPosition.latitude,
      patientPosition.longitude,
      nearest.latitude,
      nearest.longitude,
    );

    for (final volunteer in availableVolunteers.skip(1)) {
      final distance = Geolocator.distanceBetween(
        patientPosition.latitude,
        patientPosition.longitude,
        volunteer.latitude,
        volunteer.longitude,
      );

      if (distance < nearestDistance) {
        nearestDistance = distance;
        nearest = volunteer;
      }
    }

    return nearest;
  }

  Future<void> _callCompanionPhone(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);

    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw Exception(tr(
        'Could not place call to companion.',
        'تعذر الاتصال بالمرافق.',
      ));
    }
  }

  Future<void> _sendEmergencySms({
    required List<String> recipients,
    required String message,
  }) async {
    await sendSMS(message: message, recipients: recipients);
  }

  Future<void> _saveEmergencyLog({
    required Position position,
    VolunteerContact? nearestVolunteer,
    required String status,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance.collection('emergency_logs').add({
      'userId': user.uid,
      'latitude': position.latitude,
      'longitude': position.longitude,
      'patientName': _patientName,
      'companionId': _companionId,
      'companionName': _companionName,
      'companionPhone': _companionPhone,
      'callCompanion': _callCompanion,
      'sendSmsToCompanion': _sendSmsToCompanion,
      'alertNearbyVolunteers': _alertNearbyVolunteers,
      'nearestVolunteerId': nearestVolunteer?.id ?? '',
      'nearestVolunteerName': nearestVolunteer?.name ?? '',
      'nearestVolunteerPhone': nearestVolunteer?.phone ?? '',
      'status': status,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _sendNotificationToNearestVolunteer({
    required VolunteerContact volunteer,
    required Position position,
    required String locationText,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance.collection('notifications').add({
      'type': 'emergency',
      'title': isArabic ? 'تنبيه طوارئ' : 'Emergency Alert',
      'message': isArabic
          ? 'المريض $_patientName يحتاج مساعدة عاجلة. اضغط لعرض الموقع.'
          : 'Patient $_patientName needs urgent help. Open to view location.',
      'patientId': user.uid,
      'patientName': _patientName,
      'volunteerId': volunteer.id,
      'volunteerName': volunteer.name,
      'locationUrl': locationText,
      'latitude': position.latitude,
      'longitude': position.longitude,
      'isRead': false,
      'status': 'unread',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _sendNotificationToCompanion({
    required Position position,
    required String locationText,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance.collection('notifications').add({
      'type': 'emergency_companion_alert',
      'title':
          isArabic ? 'تنبيه طوارئ من المريض' : 'Emergency Alert from Patient',
      'message': isArabic
          ? 'المريض $_patientName يحتاج مساعدة فورية. رقم المرافق: $_companionPhone'
          : 'Patient $_patientName needs immediate help. Companion number: $_companionPhone',
      'patientId': user.uid,
      'patientName': _patientName,
      'companionId': _companionId,
      'companionName': _companionName,
      'companionPhone': _companionPhone,
      'receiverRole': 'companion',
      'receiverId': _companionId,
      'locationUrl': locationText,
      'latitude': position.latitude,
      'longitude': position.longitude,
      'isRead': false,
      'status': 'unread',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _showCallingCompanionPopup() async {
    await _showInfoDialog(
      title: tr(
        'Calling Companion',
        'جاري الاتصال بالمرافق',
      ),
      message: tr(
        'Companion: ${_companionName.trim().isEmpty ? 'Companion' : _companionName}\nNumber: $_companionPhone',
        'المرافق: ${_companionName.trim().isEmpty ? 'المرافق' : _companionName}\nالرقم: $_companionPhone',
      ),
      icon: Icons.phone_rounded,
      iconColor: Colors.green,
    );
  }

  Future<void> _triggerSOS() async {
    if (_isSending) return;

    final confirmEmergency = await _showEmergencyConfirmationPopup();
    if (!confirmEmergency) return;

    await _loadEmergencySettingsFromFirebase();

    if (_companionPhone.trim().isEmpty) {
      await _showInfoDialog(
        title: tr('Missing Companion Number', 'رقم المرافق غير موجود'),
        message: tr(
          'Please add companion phone number in settings first.',
          'يرجى إضافة رقم هاتف المرافق في الإعدادات أولاً.',
        ),
        icon: Icons.phone_disabled_rounded,
        iconColor: Colors.red,
      );
      return;
    }

    await _showSmsCallPermissionPopup();

    setState(() {
      _isSending = true;
      _statusMessage = tr(
        'Preparing emergency alert...',
        'جاري تجهيز تنبيه الطوارئ...',
      );
    });

    try {
      final position = await _getCurrentLocation();

      VolunteerContact? nearestVolunteer;

      if (_alertNearbyVolunteers) {
        setState(() {
          _statusMessage = tr(
            'Finding nearest volunteer...',
            'جاري البحث عن أقرب متطوع...',
          );
        });

        nearestVolunteer = await _findNearestVolunteer(position);
      }

      final locationText =
          'https://maps.google.com/?q=${position.latitude},${position.longitude}';

      final companionMessage = isArabic
          ? '''
تنبيه طوارئ من Human Touch.
قد يحتاج المريض إلى مساعدة فورية.

الموقع الحالي:
$locationText
'''
          : '''
Emergency alert from Human Touch.
The patient may need immediate help.

Current location:
$locationText
''';

      String volunteerMessage = isArabic
          ? '''
تنبيه طوارئ من Human Touch.
قد يحتاج مريض قريب إلى مساعدة عاجلة.

الموقع الحالي:
$locationText
'''
          : '''
Emergency alert from Human Touch.
A nearby patient may need urgent assistance.

Current location:
$locationText
''';

      if (nearestVolunteer != null) {
        volunteerMessage += isArabic
            ? '\nالمتطوع الأقرب: ${nearestVolunteer.name}'
            : '\nNearest volunteer selected: ${nearestVolunteer.name}';
      }

      await _sendNotificationToCompanion(
        position: position,
        locationText: locationText,
      );

      if (_callCompanion) {
        setState(() {
          _statusMessage = tr(
            'Calling companion directly...',
            'جاري الاتصال بالمرافق مباشرة...',
          );
        });

        await _showCallingCompanionPopup();
        await _callCompanionPhone(_companionPhone);
      }

      if (_sendSmsToCompanion) {
        setState(() {
          _statusMessage = tr(
            'Sending SMS to companion...',
            'جاري إرسال رسالة للمرافق...',
          );
        });

        await _sendEmergencySms(
          recipients: [_companionPhone],
          message: companionMessage,
        );
      }

      if (_alertNearbyVolunteers && nearestVolunteer != null) {
        setState(() {
          _statusMessage = tr(
            'Sending notification to nearest volunteer...',
            'جاري إرسال إشعار لأقرب متطوع...',
          );
        });

        await _sendNotificationToNearestVolunteer(
          volunteer: nearestVolunteer,
          position: position,
          locationText: locationText,
        );
      }

      String finalStatus = tr(
        'Emergency action completed.',
        'تم تنفيذ إجراء الطوارئ.',
      );

      if (_alertNearbyVolunteers && nearestVolunteer == null) {
        finalStatus = tr(
          'Emergency sent to companion. No available volunteer found.',
          'تم إرسال الطوارئ للمرافق. لا يوجد متطوع متاح.',
        );
      }

      await _saveEmergencyLog(
        position: position,
        nearestVolunteer: nearestVolunteer,
        status: finalStatus,
      );

      if (!mounted) return;

      setState(() {
        _statusMessage = finalStatus;
      });

      await _showEmergencySentSuccessfullyPopup(finalStatus);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _statusMessage =
            tr('Emergency failed: ', 'فشل إجراء الطوارئ: ') + e.toString();
      });

      await _showInfoDialog(
        title: tr('Emergency Failed', 'فشل إجراء الطوارئ'),
        message: _statusMessage,
        icon: Icons.error_outline_rounded,
        iconColor: Colors.red,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  Widget _buildTopHeader() {
    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        Container(
          height: 130,
          width: double.infinity,
          color: blueColor,
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
    );
  }

  Widget _buildHeaderTitle() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      child: Row(
        children: [
          IconButton(
            onPressed: _goBack,
            icon: Icon(
              isArabic ? Icons.arrow_forward : Icons.arrow_back,
              color: textColor,
              size: 30,
            ),
          ),
          Expanded(
            child: Text(
              tr('Emergency', 'الطوارئ'),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: textColor,
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildInfoRow({required IconData icon, required String text}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: blueColor, size: 24),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            textAlign: isArabic ? TextAlign.right : TextAlign.left,
            style: TextStyle(
              color: darkTextColor,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmergencyInfoBox() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          color: infoBoxColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: Theme.of(context).dividerColor,
            width: 1,
          ),
          boxShadow: _shadow(),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildInfoRow(
              icon: Icons.phone_rounded,
              text: tr(
                'Call companion immediately',
                'الاتصال بالمرافق فوراً',
              ),
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
              icon: Icons.sms_outlined,
              text: tr(
                'SMS to companion, call companion, and notify volunteer',
                'إرسال SMS للمرافق، الاتصال بالمرافق، وإشعار المتطوع',
              ),
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
              icon: Icons.location_on_rounded,
              text: tr(
                'Use current location to find nearest volunteer',
                'استخدام الموقع الحالي للعثور على أقرب متطوع',
              ),
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
              icon: Icons.wifi_off_rounded,
              text: tr(
                'Emergency notification is saved in Firebase for volunteers',
                'يتم حفظ إشعار الطوارئ في Firebase للمتطوعين',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSosButton(double screenWidth) {
    final double size = screenWidth < 360 ? 210 : 250;

    return Center(
      child: GestureDetector(
        onTap: _triggerSOS,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: cardColor,
            boxShadow: const [
              BoxShadow(
                blurRadius: 20,
                color: Color(0x40000000),
                offset: Offset(0, 8),
              ),
            ],
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.redAccent.withOpacity(0.25),
              width: 2,
            ),
          ),
          child: Center(
            child: _isSending
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(
                        width: 38,
                        height: 38,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          color: Colors.red,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        tr('Sending...', 'جاري الإرسال...'),
                        style: const TextStyle(
                          color: Colors.red,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'SOS',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.red,
                          fontSize: 52,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        tr('EMERGENCY', 'طوارئ'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.red,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildBodyContent() {
    if (_isLoadingSettings) {
      return Center(
        child: CircularProgressIndicator(color: blueColor),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildTopHeader(),
                _buildHeaderTitle(),
                const SizedBox(height: 20),
                Icon(
                  Icons.warning_rounded,
                  color: Colors.redAccent,
                  size: constraints.maxWidth < 360 ? 65 : 80,
                ),
                const SizedBox(height: 8),
                Text(
                  tr('Emergency', 'الطوارئ'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  child: Text(
                    tr(
                      'Press SOS to send emergency',
                      'اضغط SOS لإرسال تنبيه الطوارئ',
                    ),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: subTextColor, fontSize: 18),
                  ),
                ),
                const SizedBox(height: 25),
                _buildSosButton(constraints.maxWidth),
                const SizedBox(height: 24),
                _buildEmergencyInfoBox(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(40, 14, 40, 30),
                  child: Text(
                    _statusMessage.isEmpty
                        ? tr(
                            'Your current location and emergency message will be shared based on your emergency settings.',
                            'سيتم مشاركة موقعك الحالي ورسالة الطوارئ حسب إعدادات الطوارئ الخاصة بك.',
                          )
                        : _statusMessage,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: subTextColor, fontSize: 14),
                  ),
                ),
              ],
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
        'Emergency screen with SOS emergency button. Press the SOS button to send an emergency alert. Features include calling the companion, sending SMS to the companion and nearest volunteer, finding the nearest volunteer using current location, and working without internet. Home, profile, and settings options are available.',
        'صفحة الطوارئ تحتوي على زر SOS للطوارئ. اضغط زر SOS لإرسال تنبيه طوارئ. تشمل المميزات الاتصال بالمرافق، وإرسال رسالة للمرافق وأقرب متطوع، والعثور على أقرب متطوع باستخدام الموقع الحالي، والعمل بدون إنترنت. تتوفر أيضًا خيارات الرئيسية والملف الشخصي والإعدادات.',
      ),
      routes: {
        'dashboard': (context) => const DashboardPage(),
        'emergency': (context) => const EmergencyPage(),
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

  Widget _buildBottomNavigation() {
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 12,
        ),
        decoration: BoxDecoration(
          color: blueColor,
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
                backgroundColor: backgroundColor,
                bottomNavigationBar: _buildBottomNavigation(),
                body: Stack(
                  children: [
                    SafeArea(
                      child: _buildBodyContent(),
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
