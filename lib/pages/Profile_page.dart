import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'Login_page.dart';
import 'Dashboard_page.dart';
import 'Settings_page.dart';
import 'voice_accessibility_service.dart';

import 'package:humantouch/pages/app_settings_store.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String _name = 'No Name';
  String _email = 'No Email';
  String _role = 'patient';
  String _profileImageBase64 = '';

  bool _isBusy = false;
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

  bool get isArabic => AppSettingsStore.instance.isArabic;

  Color get backgroundColor => Theme.of(context).scaffoldBackgroundColor;

  Color get cardColor => Theme.of(context).cardColor;

  Color get textColor =>
      Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;

  Color get subTextColor =>
      Theme.of(context).textTheme.bodyMedium?.color ?? Colors.black87;

  Color get borderColor => Theme.of(context).dividerColor;

  String tr(String en, String ar) => isArabic ? ar : en;

  @override
  void initState() {
    super.initState();
    _loadProfileFromFirebase();
    AppSettingsStore.instance.addListener(_onLanguageChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (mounted && isAccessibilityVoiceEnabled && _role == 'patient') {
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

  Future<void> _loadProfileFromFirebase() async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final data = doc.data();

      if (!mounted) return;

      setState(() {
        _name = (data?['name'] ??
                data?['fullName'] ??
                data?['username'] ??
                'No Name')
            .toString();

        _email = (data?['email'] ?? user.email ?? 'No Email').toString();

        _role = (data?['role'] ?? 'patient').toString();

        _profileImageBase64 =
            (data?['profileImageBase64'] ?? data?['image'] ?? '').toString();

        _isBusy = data?['isBusy'] ?? false;

        _isLoading = false;
      });

      if (isAccessibilityVoiceEnabled && _role == 'patient') {
        await _startVoiceAccessibilityAssistant();
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr('Error loading profile: $e', 'حدث خطأ أثناء تحميل الملف: $e'),
          ),
        ),
      );
    }
  }

  Future<void> _updateBusyStatus(bool value) async {
    final user = FirebaseAuth.instance.currentUser;

    setState(() {
      _isBusy = value;
    });

    if (user == null) return;

    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      'isBusy': value,
      'isAvailable': !value,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
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
      return;
    } else if (index == 2) {
      Navigator.pushReplacementNamed(context, '/settings');
    }
  }

  String _translatedRole() {
    if (_role == 'patient') {
      return tr('Patient Account', 'حساب مريض');
    } else if (_role == 'companion') {
      return tr('Companion Account', 'حساب مرافق');
    } else if (_role == 'volunteer') {
      return tr('Volunteer Account', 'حساب متطوع');
    } else {
      return tr('User Account', 'حساب مستخدم');
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

  Widget _buildHeader(bool isSmallScreen) {
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
        Positioned(
          top: 45,
          child: Text(
            tr('Profile', 'الملف الشخصي'),
            style: TextStyle(
              color: Colors.white,
              fontSize: isSmallScreen ? 22 : 28,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _profileImageWidget(bool isSmallScreen) {
    if (_profileImageBase64.isNotEmpty) {
      try {
        return Image.memory(
          base64Decode(_profileImageBase64),
          width: isSmallScreen ? 90 : 100,
          height: isSmallScreen ? 90 : 100,
          fit: BoxFit.cover,
        );
      } catch (_) {
        return _defaultProfileIcon(isSmallScreen);
      }
    }

    return _defaultProfileIcon(isSmallScreen);
  }

  Widget _defaultProfileIcon(bool isSmallScreen) {
    return Container(
      width: isSmallScreen ? 90 : 100,
      height: isSmallScreen ? 90 : 100,
      color: const Color(0xFF87CEEB),
      child: Icon(
        Icons.person,
        size: isSmallScreen ? 50 : 55,
        color: Colors.white,
      ),
    );
  }

  Widget _buildProfileTop(bool isSmallScreen) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Column(
        children: [
          Card(
            clipBehavior: Clip.antiAliasWithSaveLayer,
            color: const Color(0xFF87CEEB),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(50),
            ),
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(60),
                child: _profileImageWidget(isSmallScreen),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _name.isEmpty ? tr('No Name', 'لا يوجد اسم') : _name,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: textColor,
              fontSize: isSmallScreen ? 20 : 24,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _email.isEmpty ? tr('No Email', 'لا يوجد بريد إلكتروني') : _email,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: const Color(0xFF87CEEB),
              fontSize: isSmallScreen ? 14 : 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          Divider(
            height: 44,
            thickness: 1,
            indent: 24,
            endIndent: 24,
            color: borderColor,
          ),
        ],
      ),
    );
  }

  Widget _buildVolunteerStatusCard() {
    if (_role == 'patient') {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor, width: 2),
          ),
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(12, 0, 0, 0),
                child: Icon(
                  _isBusy ? Icons.cancel : Icons.check_circle,
                  color: _isBusy ? Colors.red : Colors.green,
                  size: 24,
                ),
              ),
              Expanded(
                child: SwitchListTile.adaptive(
                  value: !_isBusy,
                  onChanged: (value) {
                    _updateBusyStatus(!value);
                  },
                  title: Text(
                    _isBusy ? tr('None', 'غير نشط') : tr('Active', 'نشط'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 14,
                    ),
                  ),
                  activeColor: Colors.green,
                  inactiveThumbColor: Colors.red,
                  contentPadding: const EdgeInsetsDirectional.fromSTEB(
                    12,
                    0,
                    4,
                    0,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_role == 'volunteer') {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor, width: 2),
          ),
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(12, 0, 0, 0),
                child: Icon(
                  _isBusy ? Icons.do_not_disturb_on : Icons.check_circle,
                  color: _isBusy ? Colors.orange : Colors.green,
                  size: 24,
                ),
              ),
              Expanded(
                child: SwitchListTile.adaptive(
                  value: _isBusy,
                  onChanged: _updateBusyStatus,
                  title: Text(
                    _isBusy ? tr('Busy', 'مشغول') : tr('Available', 'متاح'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 14,
                    ),
                  ),
                  activeColor: Colors.orange,
                  contentPadding: const EdgeInsetsDirectional.fromSTEB(
                    12,
                    0,
                    4,
                    0,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor, width: 2),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
            child: Row(
              children: [
                Icon(icon, color: textColor, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    textAlign: isArabic ? TextAlign.right : TextAlign.left,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoleInfoCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: 2),
        ),
        child: Row(
          children: [
            Icon(
              Icons.badge_outlined,
              color: textColor,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _translatedRole(),
                textAlign: isArabic ? TextAlign.right : TextAlign.left,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: textColor,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoutButton() {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: ElevatedButton(
        onPressed: _logout,
        style: ElevatedButton.styleFrom(
          backgroundColor: cardColor,
          foregroundColor: textColor,
          elevation: 0,
          minimumSize: const Size(170, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(38),
            side: BorderSide(color: borderColor),
          ),
        ),
        child: Text(
          tr('Log Out', 'تسجيل الخروج'),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Future<void> _startVoiceAccessibilityAssistant() async {
    if (!mounted) return;

    if (_role != 'patient') {
      await VoiceAccessibilityService.instance.stopAll();
      return;
    }

    await VoiceAccessibilityService.instance.stopAll();

    setState(() {
      _isSpeaking = true;
    });

    await VoiceAccessibilityService.instance.readPageAndListen(
      context: context,
      pageText: tr(
        'Profile screen. Your account type is patient account. Choose what you want: edit profile, account settings, or log out.',
        'صفحة الملف الشخصي. نوع حسابك هو حساب مريض. اختر ما تريد: تعديل الملف الشخصي، إعدادات الحساب، أو تسجيل الخروج.',
      ),
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
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 380;

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
                body: Stack(
                  children: [
                    SafeArea(
                      child: Column(
                        children: [
                          _buildHeader(isSmallScreen),
                          Expanded(
                            child: _isLoading
                                ? const Center(
                                    child: CircularProgressIndicator(
                                      color: Color(0xFF87CEEB),
                                    ),
                                  )
                                : SingleChildScrollView(
                                    padding: const EdgeInsets.only(bottom: 110),
                                    child: Column(
                                      children: [
                                        _buildProfileTop(isSmallScreen),
                                        _buildVolunteerStatusCard(),
                                        _buildActionCard(
                                          icon: Icons.account_circle_outlined,
                                          title:
                                              tr('Edit Profile', 'تعديل الملف'),
                                          onTap: () async {
                                            await VoiceAccessibilityService
                                                .instance
                                                .stopAll();

                                            await Navigator.pushNamed(
                                              context,
                                              '/profile2',
                                            );

                                            await _loadProfileFromFirebase();
                                          },
                                        ),
                                        _buildActionCard(
                                          icon: Icons.settings_outlined,
                                          title: tr(
                                            'Account Settings',
                                            'إعدادات الحساب',
                                          ),
                                          onTap: () {
                                            VoiceAccessibilityService.instance
                                                .stopAll();

                                            Navigator.pushNamed(
                                              context,
                                              '/settings',
                                            );
                                          },
                                        ),
                                        _buildRoleInfoCard(),
                                        _buildLogoutButton(),
                                        const SizedBox(height: 20),
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
      },
    );
  }
}
