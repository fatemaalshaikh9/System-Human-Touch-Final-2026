import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'Login_page.dart';
import 'SignUpPatient_page.dart';
import 'SignUpCompanion_page.dart';
import 'SignUpVolunteer_page.dart';
import 'app_settings_store.dart';
import 'voice_accessibility_service.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  bool _isSpeaking = false;

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

  Color get textColor =>
      Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;

  String tr(String en, String ar) => isArabic ? ar : en;

  bool get isSmallScreen {
    final width = MediaQuery.maybeOf(context)?.size.width ?? 400;
    return width < 380;
  }

  String get _signUpVoiceText => tr(
        'Human Touch sign up screen. Please choose whether you want to create an account as a patient, companion, or volunteer.',
        'شاشة إنشاء حساب في Human Touch. يرجى اختيار إذا كنت تريد إنشاء حساب كمريض، أو مرافق، أو متطوع.',
      );

  @override
  void initState() {
    super.initState();
    AppSettingsStore.instance.addListener(_onLanguageChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (isAccessibilityVoiceEnabled) {
        _startVoiceAccessibility();
      }
    });
  }

  Future<void> _startVoiceAccessibility() async {
    if (!mounted) return;

    await VoiceAccessibilityService.instance.stopAll();

    if (!mounted) return;

    setState(() {
      _isSpeaking = true;
    });

    await VoiceAccessibilityService.instance.readPageAndListen(
      context: context,
      pageText: _signUpVoiceText,
      routes: {
        'patient': (context) => const SignUpPatientPage(),
        'companion': (context) => const SignUpCompanionPage(),
        'volunteer': (context) => const SignUpVolunteerPage(),
        'login': (context) => const LoginPage(),
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
      await _startVoiceAccessibility();
    }
  }

  void _onLanguageChanged() {
    if (!mounted) return;

    setState(() {});

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (isAccessibilityVoiceEnabled) {
        _startVoiceAccessibility();
      }
    });
  }

  void _toggleLanguage() {
    AppSettingsStore.instance.toggleLanguage();
    setState(() {});

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (isAccessibilityVoiceEnabled) {
        _startVoiceAccessibility();
      }
    });
  }

  @override
  void dispose() {
    AppSettingsStore.instance.removeListener(_onLanguageChanged);
    VoiceAccessibilityService.instance.stopAll();
    super.dispose();
  }

  ButtonStyle _mainButtonStyle() {
    return ButtonStyle(
      backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
        if (states.contains(WidgetState.pressed)) {
          return Colors.grey;
        }
        return const Color(0xFF87CEEB);
      }),
      overlayColor: WidgetStateProperty.resolveWith<Color?>((states) {
        if (states.contains(WidgetState.pressed)) {
          return Colors.grey.withOpacity(0.25);
        }
        return null;
      }),
      elevation: WidgetStateProperty.all(0),
      shape: WidgetStateProperty.all(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
    );
  }

  ButtonStyle _linkButtonStyle() {
    return ButtonStyle(
      padding: WidgetStateProperty.all(EdgeInsets.zero),
      minimumSize: WidgetStateProperty.all(Size.zero),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      overlayColor: WidgetStateProperty.resolveWith<Color?>((states) {
        if (states.contains(WidgetState.pressed)) {
          return Colors.grey.withOpacity(0.30);
        }
        return null;
      }),
      foregroundColor: WidgetStateProperty.resolveWith<Color>((states) {
        if (states.contains(WidgetState.pressed)) {
          return Colors.grey.shade700;
        }
        return const Color(0xFF025590);
      }),
    );
  }

  Widget _buildRoleButton({
    required String text,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: onPressed,
        style: _mainButtonStyle(),
        child: Text(
          text,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _languageButton() {
    return Positioned(
      top: 10,
      right: isArabic ? null : 16,
      left: isArabic ? 16 : null,
      child: Semantics(
        button: true,
        label: tr('Change language', 'تغيير اللغة'),
        child: GestureDetector(
          onTap: _toggleLanguage,
          child: Container(
            width: isSmallScreen ? 46 : 52,
            height: isSmallScreen ? 46 : 52,
            decoration: BoxDecoration(
              color: const Color(0xFF87CEEB),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: Text(
                isArabic ? 'EN' : 'AR',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isSmallScreen ? 13 : 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      ),
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
            width: isSmallScreen ? 68 : 76,
            height: isSmallScreen ? 68 : 76,
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

  Widget _buildLoginRow() {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 10,
      runSpacing: 6,
      children: [
        Text(
          tr('Have an account?', 'لديك حساب؟'),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        TextButton(
          style: _linkButtonStyle(),
          onPressed: () async {
            await _stopSpeaking();

            if (!mounted) return;

            Navigator.pushNamed(context, '/login');
          },
          child: Text(
            tr('Login', 'تسجيل الدخول'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14),
          ),
        ),
      ],
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
              onTap: () {
                FocusScope.of(context).unfocus();
              },
              child: Scaffold(
                resizeToAvoidBottomInset: true,
                backgroundColor: backgroundColor,
                body: SafeArea(
                  child: Stack(
                    children: [
                      LayoutBuilder(
                        builder: (context, constraints) {
                          return SingleChildScrollView(
                            keyboardDismissBehavior:
                                ScrollViewKeyboardDismissBehavior.onDrag,
                            padding: EdgeInsets.fromLTRB(
                              isSmallScreen ? 20 : 26,
                              0,
                              isSmallScreen ? 20 : 26,
                              70,
                            ),
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                minHeight: constraints.maxHeight,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  SizedBox(height: isSmallScreen ? 8 : 10),
                                  Center(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.asset(
                                        'assets/logo.png',
                                        width: isSmallScreen ? 150 : 200,
                                        height: isSmallScreen ? 150 : 200,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Center(
                                    child: Text(
                                      tr('Sign Up', 'إنشاء حساب'),
                                      textAlign: TextAlign.center,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: isSmallScreen ? 32 : 40,
                                        fontWeight: FontWeight.w300,
                                        color: textColor,
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: isSmallScreen ? 18 : 20),
                                  _buildRoleButton(
                                    text: tr('Patient', 'مريض'),
                                    onPressed: () async {
                                      await _stopSpeaking();

                                      if (!mounted) return;

                                      Navigator.pushNamed(
                                        context,
                                        '/signupPatient',
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 20),
                                  _buildRoleButton(
                                    text: tr('Companion', 'مرافق'),
                                    onPressed: () async {
                                      await _stopSpeaking();

                                      if (!mounted) return;

                                      Navigator.pushNamed(
                                        context,
                                        '/signupCompanion',
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 20),
                                  _buildRoleButton(
                                    text: tr('Volunteer', 'متطوع'),
                                    onPressed: () async {
                                      await _stopSpeaking();

                                      if (!mounted) return;

                                      Navigator.pushNamed(
                                        context,
                                        '/signupVolunteer',
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 18),
                                  _buildLoginRow(),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                      _languageButton(),
                      _voiceControlButton(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
