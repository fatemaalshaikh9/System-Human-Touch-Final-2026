import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'Login_page.dart';
import 'SignUp_page.dart';
import 'app_settings_store.dart';
import 'voice_accessibility_service.dart';

class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  bool _isSpeaking = false;

  bool get isArabic => AppSettingsStore.instance.isArabic;
  bool get isDarkMode => AppSettingsStore.instance.isDarkMode;

  Color get backgroundColor => Theme.of(context).scaffoldBackgroundColor;

  Color get textColor =>
      Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;

  Color get buttonColor => const Color(0xFF87CEEB);

  String tr(String en, String ar) {
    return isArabic ? ar : en;
  }

  bool get isSmallScreen {
    final width = MediaQuery.maybeOf(context)?.size.width ?? 400;
    return width < 380;
  }

  String get _welcomeVoiceText => tr(
        'Human Touch welcome screen. You can create a new account or log in to continue using the application. Language switch button is available at the top right.',
        'شاشة الترحيب في Human Touch. يمكنك إنشاء حساب جديد أو تسجيل الدخول للاستمرار في استخدام التطبيق. زر تغيير اللغة موجود في أعلى يمين الشاشة.',
      );

  @override
  void initState() {
    super.initState();
    AppSettingsStore.instance.addListener(_onLanguageChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startVoiceAccessibility();
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
      pageText: _welcomeVoiceText,
      routes: {
        'login': (context) => const LoginPage(),
        'signup': (context) => const SignUpPage(),
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
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    AppSettingsStore.instance.removeListener(_onLanguageChanged);
    VoiceAccessibilityService.instance.stopAll();
    super.dispose();
  }

  void _toggleLanguage() {
    AppSettingsStore.instance.toggleLanguage();
    setState(() {});

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startVoiceAccessibility();
    });
  }

  Widget _languageButton() {
    return Positioned(
      top: 15,
      right: isArabic ? null : 15,
      left: isArabic ? 15 : null,
      child: Semantics(
        button: true,
        label: tr('Change language', 'تغيير اللغة'),
        child: GestureDetector(
          onTap: _toggleLanguage,
          child: Container(
            width: isSmallScreen ? 46 : 55,
            height: isSmallScreen ? 46 : 55,
            decoration: BoxDecoration(
              color: const Color(0xFF87CEEB),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDarkMode ? 0.35 : 0.12),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: Text(
                isArabic ? 'EN' : 'AR',
                style: TextStyle(
                  fontSize: isSmallScreen ? 13 : 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
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

  Widget _mainButton({
    required String text,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: isSmallScreen ? 48 : 50,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: buttonColor,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: isSmallScreen ? 18 : 22,
            fontWeight: FontWeight.w500,
            color: isDarkMode ? Colors.black : Colors.white,
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
                              32,
                            ),
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                minHeight: constraints.maxHeight,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  SizedBox(height: isSmallScreen ? 30 : 45),
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
                                  SizedBox(height: isSmallScreen ? 18 : 25),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                    ),
                                    child: Text(
                                      tr(
                                        'Welcome to Human Touch',
                                        'مرحبًا بك في Human Touch "اللمسة الإنسانية"',
                                      ),
                                      textAlign: TextAlign.center,
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: isSmallScreen ? 24 : 30,
                                        fontWeight: FontWeight.bold,
                                        color: textColor,
                                        letterSpacing: 1,
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: isSmallScreen ? 45 : 75),
                                  _mainButton(
                                    text: tr('Create Account', 'إنشاء حساب'),
                                    onPressed: () async {
                                      await _stopSpeaking();
                                      if (!mounted) return;

                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              const SignUpPage(),
                                        ),
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 20),
                                  _mainButton(
                                    text: tr('Login', 'تسجيل الدخول'),
                                    onPressed: () async {
                                      await _stopSpeaking();
                                      if (!mounted) return;

                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              const LoginPage(),
                                        ),
                                      );
                                    },
                                  ),
                                  SizedBox(height: isSmallScreen ? 30 : 45),
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
