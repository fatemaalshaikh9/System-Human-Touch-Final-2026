import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'Dashboard_page.dart';
import 'Profile_page.dart';
import 'Login_page.dart';
import 'voice_accessibility_service.dart';

import 'package:humantouch/pages/app_settings_store.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  late TextEditingController _companionPhoneController;

  String _name = '';
  String _email = '';
  String _profileImageBase64 = '';
  String _userRole = 'patient';

  bool _darkMode = false;
  bool _notifications = true;
  bool _locationSharing = true;
  bool _accessibilityVoice = true;
  bool _callCompanion = true;
  bool _sendSmsToCompanion = true;
  bool _alertNearbyVolunteers = true;

  bool _isPatientLinkedToCompanion = false;

  String _language = 'en';
  double _textScale = 1.0;
  bool _isLoading = true;
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

  static const String humanTouchEmail = 'info@humantouchapp.site';

  bool get isArabic => AppSettingsStore.instance.isArabic;

  String tr(String en, String ar) {
    return isArabic ? ar : en;
  }

  Color get _backgroundColor => Theme.of(context).scaffoldBackgroundColor;

  Color get _cardColor => Theme.of(context).cardColor;

  Color get _profileCardColor => Theme.of(context).scaffoldBackgroundColor;

  Color get _textColor =>
      Theme.of(context).textTheme.bodyLarge?.color ?? const Color(0xFF14181B);

  Color get _subTextColor => const Color(0xFF57636C);

  Color get _fieldColor =>
      Theme.of(context).inputDecorationTheme.fillColor ?? Colors.white;

  Color get _dividerColor => Theme.of(context).dividerColor;

  bool get isSmallScreen {
    final width = MediaQuery.maybeOf(context)?.size.width ?? 400;
    return width < 380;
  }

  @override
  void initState() {
    super.initState();
    _companionPhoneController = TextEditingController();
    _loadUserSettings();
  }

  @override
  void dispose() {
    VoiceAccessibilityService.instance.stopAll();
    _companionPhoneController.dispose();
    super.dispose();
  }

  Future<void> _loadUserSettings() async {
    final user = _auth.currentUser;
    final prefs = await SharedPreferences.getInstance();

    final localLanguage = prefs.getString('language') ?? 'en';
    await AppSettingsStore.instance.changeLanguage(localLanguage);

    if (user == null) {
      final savedDarkMode = prefs.getBool('darkMode') ?? false;
      final savedTextScale = prefs.getDouble('textScale') ?? 1.0;
      final savedAccessibilityVoice =
          prefs.getBool('accessibilityVoice') ?? true;

      await AppSettingsStore.instance.setDarkMode(savedDarkMode);
      await AppSettingsStore.instance.setTextScale(savedTextScale);
      await AppSettingsStore.instance
          .setAccessibilityVoice(savedAccessibilityVoice);

      if (!mounted) return;
      setState(() {
        _language = localLanguage;
        _darkMode = savedDarkMode;
        _textScale = savedTextScale;
        _accessibilityVoice = savedAccessibilityVoice;
        _isLoading = false;
      });
      return;
    }

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      final data = doc.data() ?? {};

      final savedLanguage =
          (data['language'] ?? prefs.getString('language') ?? 'en').toString();

      await AppSettingsStore.instance.changeLanguage(savedLanguage);
      await prefs.setString('language', savedLanguage);

      final savedDarkMode =
          data['darkMode'] ?? prefs.getBool('darkMode') ?? false;

      double savedTextScale = 1.0;
      final textScaleValue = data['textScale'];

      if (textScaleValue is num) {
        savedTextScale = textScaleValue.toDouble();
      } else {
        savedTextScale = prefs.getDouble('textScale') ?? 1.0;
      }

      final savedAccessibilityVoice = data['accessibilityVoice'] ??
          prefs.getBool('accessibilityVoice') ??
          true;

      await AppSettingsStore.instance.setDarkMode(savedDarkMode == true);
      await AppSettingsStore.instance.setTextScale(savedTextScale);
      await AppSettingsStore.instance.setAccessibilityVoice(
        savedAccessibilityVoice == true,
      );

      if (!mounted) return;

      setState(() {
        _name = (data['name'] ?? data['fullName'] ?? data['username'] ?? '')
            .toString();
        _email = (data['email'] ?? user.email ?? '').toString();
        _profileImageBase64 =
            (data['profileImageBase64'] ?? data['image'] ?? '').toString();

        _userRole = (data['role'] ?? 'patient').toString();

        _darkMode = savedDarkMode == true;
        _notifications = data['notifications'] ?? true;
        _locationSharing = data['locationSharing'] ?? true;
        _accessibilityVoice = savedAccessibilityVoice == true;
        _callCompanion = data['callCompanion'] ?? true;
        _sendSmsToCompanion = data['sendSmsToCompanion'] ?? true;
        _alertNearbyVolunteers = data['alertNearbyVolunteers'] ?? true;

        _language = savedLanguage;
        _textScale = savedTextScale;

        _companionPhoneController.text =
            (data['companionPhone'] ?? '').toString();

        _isPatientLinkedToCompanion = _userRole == 'patient' &&
            ((data['companionUid'] ?? '').toString().isNotEmpty ||
                (data['linkedCompanionUid'] ?? '').toString().isNotEmpty ||
                (data['companionPhone'] ?? '').toString().isNotEmpty);

        _isLoading = false;
      });

      if (_userRole == 'patient' && isAccessibilityVoiceEnabled) {
        await _startVoiceAccessibilityAssistant();
      }
    } catch (e) {
      debugPrint('Error loading settings: $e');

      final savedDarkMode = prefs.getBool('darkMode') ?? false;
      final savedTextScale = prefs.getDouble('textScale') ?? 1.0;
      final savedAccessibilityVoice =
          prefs.getBool('accessibilityVoice') ?? true;

      await AppSettingsStore.instance.setDarkMode(savedDarkMode);
      await AppSettingsStore.instance.setTextScale(savedTextScale);
      await AppSettingsStore.instance
          .setAccessibilityVoice(savedAccessibilityVoice);

      if (!mounted) return;

      setState(() {
        _language = localLanguage;
        _darkMode = savedDarkMode;
        _textScale = savedTextScale;
        _accessibilityVoice = savedAccessibilityVoice;
        _name = user.displayName ?? '';
        _email = user.email ?? '';
        _isLoading = false;
      });

      if (_userRole == 'patient' && isAccessibilityVoiceEnabled) {
        await _startVoiceAccessibilityAssistant();
      }
    }
  }

  Future<void> _updateSetting(String field, dynamic value) async {
    final user = _auth.currentUser;
    final prefs = await SharedPreferences.getInstance();

    if (field == 'language') {
      await prefs.setString('language', value.toString());
    }

    if (field == 'darkMode') {
      await prefs.setBool('darkMode', value == true);
    }

    if (field == 'textScale') {
      await prefs.setDouble('textScale', (value as num).toDouble());
    }

    if (field == 'accessibilityVoice') {
      await prefs.setBool('accessibilityVoice', value == true);
    }

    if (user == null) return;

    try {
      await _firestore.collection('users').doc(user.uid).set({
        field: value,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error updating setting $field: $e');
    }
  }

  Future<void> _openEmail() async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: humanTouchEmail,
      query: 'subject=Human Touch Support',
    );

    if (await canLaunchUrl(emailUri)) {
      await launchUrl(emailUri);
    } else {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr(
              'Could not open email app',
              'تعذر فتح تطبيق البريد الإلكتروني',
            ),
          ),
        ),
      );
    }
  }

  Future<void> _logout() async {
    await VoiceAccessibilityService.instance.stopAll();
    await FirebaseAuth.instance.signOut();

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()),
      (route) => false,
    );
  }

  void _goToPage(int index) {
    VoiceAccessibilityService.instance.stopAll();

    if (index == 0) {
      Navigator.pushReplacementNamed(context, '/dashboard');
    } else if (index == 1) {
      Navigator.pushReplacementNamed(context, '/profile');
    }
  }

  String get _settingsReaderText => tr(
        'Settings screen. Account settings section. You can switch dark mode on or off, manage notifications, enable accessibility voice, control location sharing, change language between English and Arabic, adjust text size to small, medium, or large, and open accessibility options. Human Touch section. You can open About Human Touch, Contact Us, or Privacy Policy.',
        'صفحة الإعدادات. قسم إعدادات الحساب. يمكنك تشغيل أو إيقاف الوضع الداكن، وإدارة الإشعارات، وتفعيل صوت الوصول، والتحكم في مشاركة الموقع، وتغيير اللغة بين الإنجليزية والعربية، وضبط حجم النص إلى صغير أو متوسط أو كبير، وفتح خيارات الوصول. قسم Human Touch. يمكنك فتح عن Human Touch، أو تواصل معنا، أو سياسة الخصوصية.',
      );

  String get _aboutReaderText => tr(
        'About Human Touch. Human Touch is a smart and user-friendly mobile application designed to support people with disabilities in their daily lives. The app helps users manage reminders, communicate more easily, access emergency support, and connect with volunteers and companions. Human Touch aims to improve independence, safety, and accessibility through simple and helpful digital solutions.',
        'عن Human Touch. Human Touch هو تطبيق ذكي وسهل الاستخدام مصمم لدعم الأشخاص ذوي الإعاقة في حياتهم اليومية. يساعد التطبيق المستخدمين على إدارة التذكيرات، والتواصل بسهولة أكبر، والوصول إلى دعم الطوارئ، والتواصل مع المتطوعين والمرافقين. يهدف Human Touch إلى تحسين الاستقلالية والسلامة وإمكانية الوصول من خلال حلول رقمية بسيطة ومفيدة.',
      );

  String get _contactReaderText => tr(
        'Contact Us screen. We are here to support you. You can contact the Human Touch Team by email at info@humantouchapp.site.',
        'صفحة تواصل معنا. نحن هنا لدعمك. يمكنك التواصل مع فريق Human Touch عبر البريد الإلكتروني info@humantouchapp.site.',
      );

  String get _privacyReaderText => tr(
        'Privacy Policy screen. Effective date May 11, 2026. This Privacy Policy explains how Human Touch collects, uses, protects, and stores user information. Information collection and use section. The application may collect user information such as name, email address, and phone number when creating an account, contacting support, or using features like reminders, volunteer assistance, and emergency contacts. Automatically collected information section. The application may collect operation logs, last login time, device information, and notification identifiers to improve service quality and user experience. The application does not collect browsing activity outside the app, access photos or contacts without permission, or collect sensitive personal data unless required for approved features. Use of information section. Human Touch uses collected information to improve app functionality, manage reminders, provide emergency and volunteer support, improve communication tools, send notifications, and enhance security. Third-party services section. The application may use services such as Google Play Services, Firebase Authentication and Database, and push notification providers. Data sharing and disclosure section. Information may only be shared for legal compliance, user protection, secure backend support, or emergency situations when emergency assistance is activated. Opt-out rights section. Users can disable notifications, revoke permissions such as location or microphone access, uninstall the application, or request account and data deletion. Data retention policy section. Reminder data, emergency contacts, and notification settings may remain stored while the account is active. Children’s privacy section. The application is not intended for children under 13 without parental supervision. Security measures section. Human Touch protects user data through encryption, restricted access controls, and regular security monitoring. Privacy policy updates section. Users may be notified about important privacy policy updates through the application or email. Consent section. By using Human Touch, users agree to the collection and processing of information described in this Privacy Policy. Contact section. For privacy-related questions or concerns, contact info@humantouchapp.site. Service provider: Human Touch Team.',
        'صفحة سياسة الخصوصية. تاريخ السريان 11 مايو 2026. توضح سياسة الخصوصية كيف يجمع Human Touch معلومات المستخدم ويستخدمها ويحميها ويخزنها. قسم جمع المعلومات واستخدامها. قد يجمع التطبيق معلومات مثل الاسم والبريد الإلكتروني ورقم الهاتف عند إنشاء الحساب أو التواصل مع الدعم أو استخدام ميزات مثل التذكيرات ومساعدة المتطوعين وجهات اتصال الطوارئ. قسم المعلومات التي يتم جمعها تلقائياً. قد يجمع التطبيق سجلات التشغيل، وآخر وقت تسجيل دخول، ومعلومات الجهاز، ومعرفات الإشعارات لتحسين جودة الخدمة وتجربة المستخدم. لا يجمع التطبيق نشاط التصفح خارج التطبيق، ولا يصل إلى الصور أو جهات الاتصال بدون إذن، ولا يجمع بيانات شخصية حساسة إلا إذا كانت مطلوبة للميزات المعتمدة. قسم استخدام المعلومات. يستخدم Human Touch المعلومات لتحسين وظائف التطبيق، وإدارة التذكيرات، وتوفير دعم الطوارئ والمتطوعين، وتحسين أدوات التواصل، وإرسال الإشعارات، وتعزيز الأمان. قسم خدمات الطرف الثالث. قد يستخدم التطبيق خدمات مثل Google Play Services و Firebase Authentication and Database ومزودي الإشعارات. قسم مشاركة البيانات والإفصاح. قد تتم مشاركة المعلومات فقط للامتثال القانوني، أو حماية المستخدم، أو دعم الخلفية الآمن، أو حالات الطوارئ عند تفعيل المساعدة الطارئة. قسم حقوق إلغاء الاشتراك. يمكن للمستخدمين تعطيل الإشعارات، أو إلغاء الأذونات مثل الموقع أو الميكروفون، أو إلغاء تثبيت التطبيق، أو طلب حذف الحساب والبيانات. قسم سياسة الاحتفاظ بالبيانات. قد تبقى بيانات التذكيرات وجهات اتصال الطوارئ وإعدادات الإشعارات مخزنة أثناء نشاط الحساب. قسم خصوصية الأطفال. التطبيق غير مخصص للأطفال دون 13 سنة بدون إشراف الوالدين. قسم إجراءات الأمان. يحمي Human Touch بيانات المستخدم من خلال التشفير وضوابط الوصول المحدودة والمراقبة الأمنية المنتظمة. قسم تحديثات سياسة الخصوصية. قد يتم إشعار المستخدمين بالتحديثات المهمة عبر التطبيق أو البريد الإلكتروني. قسم الموافقة. باستخدام Human Touch، يوافق المستخدمون على جمع ومعالجة المعلومات الموضحة في سياسة الخصوصية. قسم التواصل. للأسئلة المتعلقة بالخصوصية، تواصل عبر info@humantouchapp.site. مزود الخدمة: Human Touch Team.',
      );

  Future<void> _speakOnlyForPatient(String text) async {
    if (_userRole != 'patient') return;
    if (!isAccessibilityVoiceEnabled) return;

    await VoiceAccessibilityService.instance.speak(text);
  }

  Future<void> _startVoiceAccessibilityAssistant() async {
    if (!mounted) return;

    if (_userRole != 'patient') {
      await VoiceAccessibilityService.instance.stopAll();
      return;
    }

    await VoiceAccessibilityService.instance.stopAll();

    setState(() {
      _isSpeaking = true;
    });

    await VoiceAccessibilityService.instance.readPageAndListen(
      context: context,
      pageText: _settingsReaderText,
      routes: {
        'dashboard': (context) => const DashboardPage(),
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

  Future<void> _showSimplePopup({
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
          textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
          child: AlertDialog(
            backgroundColor: _cardColor,
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
                    color: _textColor,
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
                  color: _subTextColor,
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
          textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
          child: AlertDialog(
            backgroundColor: _cardColor,
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
                    color: _textColor,
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
                  color: _subTextColor,
                  fontSize: 15,
                  height: 1.5,
                ),
              ),
            ),
            actionsAlignment: MainAxisAlignment.center,
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(cancelText, style: TextStyle(color: _subTextColor)),
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

  Future<void> _showDarkModePopup(bool enabled) async {
    await _showSimplePopup(
      title: tr('Dark Mode', 'الوضع الليلي'),
      message: enabled
          ? tr(
              'Dark mode has been enabled successfully.',
              'تم تفعيل الوضع الليلي بنجاح.',
            )
          : tr(
              'Dark mode has been disabled successfully.',
              'تم إيقاف الوضع الليلي بنجاح.',
            ),
      icon: enabled ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
      iconColor: const Color(0xFF87CEEB),
    );
  }

  Future<void> _showLanguageChangePopup(String language) async {
    await _showSimplePopup(
      title: tr('Language Changed', 'تم تغيير اللغة'),
      message: language == 'ar'
          ? tr(
              'The app language has been changed to Arabic.',
              'تم تغيير لغة التطبيق إلى العربية.',
            )
          : tr(
              'The app language has been changed to English.',
              'تم تغيير لغة التطبيق إلى الإنجليزية.',
            ),
      icon: Icons.g_translate_rounded,
      iconColor: const Color(0xFF87CEEB),
    );
  }

  Future<void> _showAccessibilityPopup() async {
    final selectedSize = _textScaleTitle(_textScale);

    await _showSimplePopup(
      title: tr('Accessibility Options', 'خيارات الوصول'),
      message: tr(
        'You can improve accessibility by changing text size to $selectedSize.',
        'يمكنك تحسين سهولة الاستخدام من خلال تغيير حجم الخط إلى $selectedSize.',
      ),
      icon: Icons.accessibility_new_rounded,
      iconColor: const Color(0xFF87CEEB),
    );
  }

  Future<void> _showAccessibilityVoicePopup(bool enabled) async {
    await _showSimplePopup(
      title: tr('Accessibility Voice', 'صوت الوصول'),
      message: enabled
          ? tr(
              'Accessibility voice has been enabled. The app can speak when voice features are used.',
              'تم تفعيل صوت الوصول. يمكن للتطبيق التحدث عند استخدام ميزات الصوت.',
            )
          : tr(
              'Accessibility voice has been disabled. Voice speaking features will not work.',
              'تم إيقاف صوت الوصول. ميزات التحدث الصوتي لن تعمل.',
            ),
      icon: Icons.record_voice_over_rounded,
      iconColor: const Color(0xFF87CEEB),
    );
  }

  Future<void> _showNotificationsPopup(bool enabled) async {
    await _showSimplePopup(
      title: tr('Notifications', 'الإشعارات'),
      message: enabled
          ? tr(
              'Notifications have been enabled. You will receive reminders and important alerts.',
              'تم تفعيل الإشعارات. ستصلك التذكيرات والتنبيهات المهمة.',
            )
          : tr(
              'Notifications have been disabled. You will not receive reminder alerts until you enable them again.',
              'تم إيقاف الإشعارات. لن تصلك تنبيهات التذكيرات حتى تقوم بتفعيلها مرة أخرى.',
            ),
      icon: enabled
          ? Icons.notifications_active_rounded
          : Icons.notifications_off_rounded,
      iconColor: const Color(0xFF87CEEB),
    );
  }

  Future<void> _showLocationSharingPopup(bool enabled) async {
    await _showSimplePopup(
      title: tr('Location Sharing', 'مشاركة الموقع'),
      message: enabled
          ? tr(
              'Location sharing has been enabled. The app can use your location for emergency and accessibility features.',
              'تم تفعيل مشاركة الموقع. يمكن للتطبيق استخدام موقعك لميزات الطوارئ وإمكانية الوصول.',
            )
          : tr(
              'Location sharing has been disabled. Location-based features may not work until you enable it again.',
              'تم إيقاف مشاركة الموقع. قد لا تعمل الميزات المعتمدة على الموقع حتى تقوم بتفعيلها مرة أخرى.',
            ),
      icon: enabled ? Icons.location_on_rounded : Icons.location_off_rounded,
      iconColor: const Color(0xFF87CEEB),
    );
  }

  Future<void> _confirmLogout() async {
    final confirm = await _showConfirmPopup(
      title: tr('Log Out', 'تسجيل الخروج'),
      message: tr(
        'Are you sure you want to log out?',
        'هل أنت متأكد أنك تريد تسجيل الخروج؟',
      ),
      icon: Icons.logout_rounded,
      iconColor: Colors.redAccent,
      confirmText: tr('Log Out', 'تسجيل الخروج'),
      cancelText: tr('Cancel', 'إلغاء'),
    );

    if (confirm) {
      await _logout();
    }
  }

  void _showInfoCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    showDialog(
      context: context,
      builder: (context) {
        return Directionality(
          textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
          child: Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.all(20),
            child: Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.78,
              ),
              decoration: BoxDecoration(
                color: _cardColor,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(20, 18, 12, 18),
                    decoration: const BoxDecoration(
                      color: Color(0xFF87CEEB),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(24),
                        topRight: Radius.circular(24),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(icon, color: Colors.white, size: 28),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            title,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: child,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showAboutHumanTouch() {
    _speakOnlyForPatient(_aboutReaderText);

    _showInfoCard(
      title: tr('About Human Touch', 'عن Human Touch'),
      icon: Icons.supervisor_account,
      child: Text(
        tr(
          'Human Touch is a smart and user-friendly mobile application designed to support people with disabilities in their daily lives. The app helps users manage reminders, communicate more easily, access emergency support, and connect with volunteers and companions. Human Touch aims to improve independence, safety, and accessibility through simple and helpful digital solutions.',
          'Human Touch هو تطبيق ذكي وسهل الاستخدام مصمم لدعم الأشخاص ذوي الإعاقة في حياتهم اليومية. يساعد التطبيق المستخدمين على إدارة التذكيرات، والتواصل بسهولة أكبر، والوصول إلى دعم الطوارئ، والتواصل مع المتطوعين والمرافقين. يهدف Human Touch إلى تحسين الاستقلالية والسلامة وإمكانية الوصول من خلال حلول رقمية بسيطة ومفيدة.',
        ),
        style: TextStyle(
          color: _textColor,
          fontSize: 14,
          height: 1.55,
        ),
      ),
    );
  }

  void _showContactUs() {
    _speakOnlyForPatient(_contactReaderText);

    _showInfoCard(
      title: tr('Contact Us', 'تواصل معنا'),
      icon: Icons.phone_paused_rounded,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment:
            isArabic ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Text(
            tr(
              'We are here to support you.',
              'نحن هنا لدعمك.',
            ),
            style: TextStyle(
              color: _textColor,
              fontSize: 14,
              height: 1.55,
            ),
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: _openEmail,
            child: const Text(
              'mailto:$humanTouchEmail',
              style: TextStyle(
                color: Color(0xFF87CEEB),
                fontSize: 15,
                fontWeight: FontWeight.bold,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            tr(
              'Service Provider: Human Touch Team',
              'مزود الخدمة: فريق Human Touch',
            ),
            style: TextStyle(
              color: _textColor,
              fontSize: 14,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }

  void _showPrivacyPolicy() {
    _speakOnlyForPatient(_privacyReaderText);

    _showInfoCard(
      title: tr('Privacy Policy', 'سياسة الخصوصية'),
      icon: Icons.privacy_tip_outlined,
      child: Text(
        r'''Privacy Policy
Effective Date: May 11, 2026

This Privacy Policy applies to the Human Touch app (hereafter referred to as the “Application”), developed and provided as a free service by the Human Touch Team (hereafter referred to as the “Service Provider”). The Application is provided “AS IS”, and this Privacy Policy explains how user data is collected, used, and protected.

1. Information Collection and Use

1.1 User-Provided Information

The Application may collect certain personally identifiable information (e.g., name, email address, phone number) when:

Users create an account or sign in.
Users contact the Service Provider for support or inquiries.
Users use specific features such as volunteer assistance, emergency contacts, or reminders.

This information is securely stored and used only as outlined in this Privacy Policy.

1.2 Automatically Collected Information

The Application may automatically collect certain data to improve user experience and service quality. This may include:

Operation Logs: Basic records of feature usage for analytics and performance improvements.
Last Login Time: The date and time of the user’s most recent login.
Device Information: Device type, operating system version, and app version.
Push Notification Identifiers: Device identifiers used to send reminders, alerts, and updates.

🚫 What the Application Does NOT Collect Automatically:

No tracking of browsing activity outside the app.
No access to photos, files, or contacts without user permission.
No collection of sensitive personal data unless required for specific features and approved by the user.

2. Use of Information

The Service Provider uses collected information solely for the following purposes:

To provide and improve Application functionality.
To manage reminders for medications, meals, appointments, and tasks.
To enable emergency support features and volunteer assistance.
To improve communication tools such as voice and sign support.
To analyze engagement and enhance user experience.
To send important notifications, reminders, or updates.
To prevent fraudulent activity and ensure security.

3. Third-Party Services

The Application may integrate third-party services which may collect limited data as part of their functionality. These may include:

Google Play Services
Firebase Authentication / Database
OneSignal or similar Push Notification Services

These providers have their own Privacy Policies, which users are encouraged to review.

🚨 Important: The Service Provider does not sell, rent, or share user data with advertisers or third-party marketing platforms.

4. Data Sharing and Disclosure

The Service Provider may disclose collected information only in the following circumstances:

Legal Compliance: If required by law or government request.
User Protection: If necessary to protect user safety or investigate fraud/security issues.
Trusted Service Providers: For secure backend support under strict confidentiality agreements.
Emergency Situations: If the user activates emergency assistance features requiring contact with selected companions or responders.

🚫 No user data is shared for advertising purposes.

5. Opt-Out Rights

Users may opt-out of certain data collection by:

Disabling notifications in device settings.
Disabling optional permissions such as location or microphone access.
Uninstalling the Application.
Requesting account or data deletion by contacting the Service Provider.

6. Data Retention Policy

The Service Provider retains user data only as long as necessary to provide services.

Reminder and account data are retained while the account remains active.
Emergency contacts remain stored until edited or deleted by the user.
Notification identifiers remain while notifications are enabled.

📌 Users may request deletion of their personal data at any time.

7. Children’s Privacy

The Application is not intended for children under the age of 13 without parental supervision.

The Service Provider does not knowingly collect personal data from children under 13. If discovered, such data will be deleted promptly.

8. Security Measures

The Service Provider takes reasonable precautions to protect user data, including:

Encryption and secure storage of sensitive information.
Restricted access controls.
Regular security monitoring and updates.

📌 However, no online method is 100% secure, and users should take care when sharing personal information.

9. Privacy Policy Updates

This Privacy Policy may be updated periodically to reflect:

Changes in Application features.
Security improvements.
Compliance with new laws or regulations.

📌 Users will be notified of significant updates through the app or email.

Continued use of the Application after updates means acceptance of the revised policy.

10. Your Consent

By using the Application, you consent to the collection and processing of your information as described in this Privacy Policy.

11. Contact Us

For privacy-related questions or concerns, you may contact:

📧 Email: mailto:info@humantouchapp.site

🏢 Service Provider: Human Touch Team''',
        style: TextStyle(
          color: _textColor,
          fontSize: 14,
          height: 1.55,
        ),
      ),
    );
  }

  Widget _bottomItem(IconData icon, String label, int index) {
    return Expanded(
      child: GestureDetector(
        onTap: () => _goToPage(index),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 25),
            const SizedBox(height: 3),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
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
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF87CEEB),
          borderRadius: BorderRadius.circular(28),
          boxShadow: _shadow(),
        ),
        child: Row(
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
    return Stack(
      alignment: Alignment.topCenter,
      children: [
        Container(
          width: double.infinity,
          height: isSmallScreen ? 115 : 130,
          color: const Color(0xFF87CEEB),
        ),
        Padding(
          padding: EdgeInsets.only(top: isSmallScreen ? 88 : 100),
          child: Container(
            width: double.infinity,
            height: 41,
            decoration: BoxDecoration(
              color: _backgroundColor,
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

  Widget _profileImageWidget() {
    if (_profileImageBase64.isNotEmpty) {
      try {
        return Image.memory(
          base64Decode(_profileImageBase64),
          fit: BoxFit.cover,
        );
      } catch (_) {
        return Icon(
          Icons.person,
          size: isSmallScreen ? 34 : 40,
          color: Colors.white,
        );
      }
    }

    return Icon(
      Icons.person,
      size: isSmallScreen ? 34 : 40,
      color: Colors.white,
    );
  }

  Widget _buildProfileCard() {
    final screenWidth = MediaQuery.of(context).size.width;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(color: _profileCardColor),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        child: Wrap(
          spacing: 14,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Container(
              width: isSmallScreen ? 60 : 70,
              height: isSmallScreen ? 60 : 70,
              decoration: BoxDecoration(
                color: const Color(0xFF87CEEB),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: _profileImageWidget(),
              ),
            ),
            SizedBox(
              width: screenWidth - (isSmallScreen ? 120 : 140),
              child: Column(
                crossAxisAlignment: isArabic
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  Text(
                    _name.isEmpty ? tr('No Name', 'لا يوجد اسم') : _name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: isArabic ? TextAlign.right : TextAlign.left,
                    style: TextStyle(
                      color: _textColor,
                      fontSize: isSmallScreen ? 20 : 24,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _email.isEmpty
                        ? tr('No Email', 'لا يوجد بريد إلكتروني')
                        : _email,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: isArabic ? TextAlign.right : TextAlign.left,
                    style: const TextStyle(
                      color: Color(0xFF87CEEB),
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

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: EdgeInsets.fromLTRB(isArabic ? 0 : 15, 10, isArabic ? 15 : 0, 0),
      child: Align(
        alignment: isArabic ? Alignment.centerRight : Alignment.centerLeft,
        child: Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: _textColor,
          ),
        ),
      ),
    );
  }

  Widget _buildCard({required List<Widget> children}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: _cardColor,
          boxShadow: const [
            BoxShadow(
              blurRadius: 5,
              color: Color(0x3416202A),
              offset: Offset(0, 2),
            ),
          ],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(children: children),
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(
      thickness: 1,
      indent: 15,
      endIndent: 15,
      color: _dividerColor,
    );
  }

  Widget _buildSwitchRow({
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
    IconData? icon,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 4),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, color: _subTextColor, size: 22),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Text(
              title,
              textAlign: isArabic ? TextAlign.right : TextAlign.left,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: _textColor, fontSize: 14),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: const Color(0xFF87CEEB),
          ),
        ],
      ),
    );
  }

  Widget _buildSimpleRow({
    required IconData icon,
    required String title,
    String? trailingText,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
        child: Row(
          children: [
            Icon(icon, color: _subTextColor, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                textAlign: isArabic ? TextAlign.right : TextAlign.left,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: _textColor, fontSize: 14),
              ),
            ),
            if (trailingText != null)
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 120),
                child: Align(
                  alignment:
                      isArabic ? Alignment.centerLeft : Alignment.centerRight,
                  child: Text(
                    trailingText,
                    textAlign: isArabic ? TextAlign.left : TextAlign.right,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: _subTextColor, fontSize: 14),
                  ),
                ),
              ),
            if (onTap != null) ...[
              const SizedBox(width: 8),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: _subTextColor,
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _textScaleTitle(double value) {
    if (value == 1.0) return tr('Small', 'صغير');
    if (value == 1.4) return tr('Large', 'كبير');
    return tr('Medium', 'متوسط');
  }

  Widget _buildTextSizeRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 10, 24, 10),
      child: Column(
        crossAxisAlignment:
            isArabic ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.format_size_rounded, color: _subTextColor, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  tr('Text Size', 'حجم الخط'),
                  textAlign: isArabic ? TextAlign.right : TextAlign.left,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: _textColor, fontSize: 14),
                ),
              ),
              Text(
                _textScaleTitle(_textScale),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: _subTextColor, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: _fieldColor,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                _textSizeOption(tr('Small', 'صغير'), 1.0),
                _textSizeOption(tr('Medium', 'متوسط'), 1.2),
                _textSizeOption(tr('Large', 'كبير'), 1.4),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _textSizeOption(String title, double value) {
    final bool selected = _textScale == value;

    return Expanded(
      child: GestureDetector(
        onTap: () async {
          setState(() => _textScale = value);

          await AppSettingsStore.instance.setTextScale(value);

          await _updateSetting('textScale', value);

          if (!mounted) return;

          await _showAccessibilityPopup();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF87CEEB) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: selected ? Colors.white : _textColor,
                fontSize: 13,
                fontWeight: selected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompanionPhoneRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 10, 24, 10),
      child: Column(
        crossAxisAlignment:
            isArabic ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Text(
            tr('Companion Phone Number', 'رقم هاتف المرافق'),
            textAlign: isArabic ? TextAlign.right : TextAlign.left,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: _textColor,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              SizedBox(
                width: isSmallScreen
                    ? double.infinity
                    : MediaQuery.of(context).size.width - 150,
                child: Container(
                  height: 52,
                  decoration: BoxDecoration(
                    color: _fieldColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: TextField(
                    controller: _companionPhoneController,
                    keyboardType: TextInputType.phone,
                    textAlign: isArabic ? TextAlign.right : TextAlign.left,
                    style: TextStyle(color: _textColor),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: tr(
                        'Enter companion phone number',
                        'أدخل رقم هاتف المرافق',
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: isSmallScreen ? double.infinity : 80,
                height: 52,
                child: ElevatedButton(
                  onPressed: () async {
                    final phone = _companionPhoneController.text.trim();

                    await _updateSetting('companionPhone', phone);

                    setState(() {
                      _isPatientLinkedToCompanion = phone.isNotEmpty;
                    });

                    if (!mounted) return;

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          tr(
                            'Companion phone saved successfully',
                            'تم حفظ رقم المرافق بنجاح',
                          ),
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF87CEEB),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    tr('Save', 'حفظ'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLogoutButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 20, 0, 20),
      child: Center(
        child: ElevatedButton(
          onPressed: _confirmLogout,
          style: ElevatedButton.styleFrom(
            backgroundColor: _cardColor,
            elevation: 1,
            foregroundColor: _textColor,
            minimumSize: const Size(120, 44),
          ),
          child: Text(
            tr('Log Out', 'تسجيل الخروج'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF4F4F4),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF87CEEB)),
        ),
      );
    }

    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaleFactor: AppSettingsStore.instance.textScale,
      ),
      child: Directionality(
        textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
        child: GestureDetector(
          onTap: () {
            FocusScope.of(context).unfocus();
          },
          child: Scaffold(
            resizeToAvoidBottomInset: true,
            backgroundColor: _backgroundColor,
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
                          padding: const EdgeInsets.only(bottom: 120),
                          child: Column(
                            children: [
                              _buildProfileCard(),
                              _buildCard(
                                children: [
                                  _buildSectionTitle(
                                    tr('Account Settings', 'إعدادات الحساب'),
                                  ),
                                  _buildDivider(),
                                  _buildSwitchRow(
                                    title: tr(
                                      'Switch to Dark Mode',
                                      'تفعيل الوضع الداكن',
                                    ),
                                    value: _darkMode,
                                    onChanged: (value) async {
                                      setState(() => _darkMode = value);

                                      await AppSettingsStore.instance
                                          .setDarkMode(value);

                                      await _updateSetting('darkMode', value);

                                      if (!mounted) return;

                                      await _showDarkModePopup(value);
                                    },
                                  ),
                                  _buildDivider(),
                                  _buildSwitchRow(
                                    title: tr('Notifications', 'الإشعارات'),
                                    value: _notifications,
                                    onChanged: (value) async {
                                      setState(() => _notifications = value);

                                      await _updateSetting(
                                          'notifications', value);

                                      if (!mounted) return;

                                      await _showNotificationsPopup(value);
                                    },
                                  ),
                                  _buildDivider(),
                                  _buildSwitchRow(
                                    title: tr(
                                      'Accessibility Voice',
                                      'صوت الوصول',
                                    ),
                                    value: _accessibilityVoice,
                                    onChanged: (value) async {
                                      setState(
                                          () => _accessibilityVoice = value);

                                      await AppSettingsStore.instance
                                          .setAccessibilityVoice(value);

                                      await _updateSetting(
                                        'accessibilityVoice',
                                        value,
                                      );

                                      if (!mounted) return;

                                      await _showAccessibilityVoicePopup(value);

                                      if (value && _userRole == 'patient') {
                                        await _startVoiceAccessibilityAssistant();
                                      } else {
                                        await VoiceAccessibilityService.instance
                                            .stopAll();
                                      }
                                    },
                                    icon: Icons.record_voice_over_rounded,
                                  ),
                                  _buildDivider(),
                                  _buildSwitchRow(
                                    title:
                                        tr('Location Sharing', 'مشاركة الموقع'),
                                    value: _locationSharing,
                                    onChanged: (value) async {
                                      setState(() => _locationSharing = value);

                                      await _updateSetting(
                                        'locationSharing',
                                        value,
                                      );

                                      if (!mounted) return;

                                      await _showLocationSharingPopup(value);
                                    },
                                  ),
                                  _buildDivider(),
                                  _buildSimpleRow(
                                    icon: Icons.g_translate_sharp,
                                    title: tr('Language', 'اللغة'),
                                    trailingText: _language == 'ar'
                                        ? tr('Arabic', 'العربية')
                                        : tr('English', 'الإنجليزية'),
                                    onTap: () async {
                                      final newLang =
                                          _language == 'ar' ? 'en' : 'ar';

                                      setState(() => _language = newLang);

                                      await AppSettingsStore.instance
                                          .changeLanguage(
                                        newLang,
                                      );

                                      await _updateSetting('language', newLang);

                                      if (!mounted) return;

                                      await _showLanguageChangePopup(newLang);
                                    },
                                  ),
                                  _buildDivider(),
                                  _buildTextSizeRow(),
                                  _buildDivider(),
                                  _buildSimpleRow(
                                    icon: Icons.accessibility_new_rounded,
                                    title: tr(
                                      'Accessibility Options',
                                      'خيارات الوصول',
                                    ),
                                    onTap: _showAccessibilityPopup,
                                  ),
                                  if (_userRole == 'patient' &&
                                      _isPatientLinkedToCompanion) ...[
                                    _buildDivider(),
                                    _buildCompanionPhoneRow(),
                                    _buildDivider(),
                                    _buildSwitchRow(
                                      title: tr(
                                        'Call Companion in Emergency',
                                        'الاتصال بالمرافق في الطوارئ',
                                      ),
                                      value: _callCompanion,
                                      onChanged: (value) async {
                                        setState(() => _callCompanion = value);
                                        await _updateSetting(
                                          'callCompanion',
                                          value,
                                        );
                                      },
                                      icon: Icons.phone_rounded,
                                    ),
                                    _buildDivider(),
                                    _buildSwitchRow(
                                      title: tr(
                                        'Send SMS to Companion',
                                        'إرسال رسالة SMS للمرافق',
                                      ),
                                      value: _sendSmsToCompanion,
                                      onChanged: (value) async {
                                        setState(
                                          () => _sendSmsToCompanion = value,
                                        );
                                        await _updateSetting(
                                          'sendSmsToCompanion',
                                          value,
                                        );
                                      },
                                      icon: Icons.sms_outlined,
                                    ),
                                    _buildDivider(),
                                    _buildSwitchRow(
                                      title: tr(
                                        'Alert Nearby Volunteers',
                                        'تنبيه المتطوعين القريبين',
                                      ),
                                      value: _alertNearbyVolunteers,
                                      onChanged: (value) async {
                                        setState(
                                          () => _alertNearbyVolunteers = value,
                                        );
                                        await _updateSetting(
                                          'alertNearbyVolunteers',
                                          value,
                                        );
                                      },
                                      icon: Icons.location_on_outlined,
                                    ),
                                  ],
                                ],
                              ),
                              _buildCard(
                                children: [
                                  _buildSectionTitle(
                                    tr('Human Touch', 'Human Touch'),
                                  ),
                                  _buildDivider(),
                                  _buildSimpleRow(
                                    icon: Icons.supervisor_account,
                                    title: tr(
                                      'About Human Touch',
                                      'عن Human Touch',
                                    ),
                                    onTap: _showAboutHumanTouch,
                                  ),
                                  _buildDivider(),
                                  _buildSimpleRow(
                                    icon: Icons.phone_paused_rounded,
                                    title: tr('Contact Us', 'تواصل معنا'),
                                    onTap: _showContactUs,
                                  ),
                                  _buildDivider(),
                                  _buildSimpleRow(
                                    icon: Icons.privacy_tip_outlined,
                                    title:
                                        tr('Privacy Policy', 'سياسة الخصوصية'),
                                    onTap: _showPrivacyPolicy,
                                  ),
                                ],
                              ),
                              _buildLogoutButton(),
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
      ),
    );
  }
}
