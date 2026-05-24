import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'ForgetPassword_page.dart';
import 'SignUp_page.dart';
import 'app_settings_store.dart';
import 'voice_accessibility_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  final FocusNode _emailFocusNode = FocusNode();
  final FocusNode _passwordFocusNode = FocusNode();

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  bool _obscurePassword = true;
  bool _rememberMe = true;
  bool _isLoading = false;
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

  Color get fieldColor =>
      Theme.of(context).inputDecorationTheme.fillColor ?? Colors.white;

  Color get textColor =>
      Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;

  Color get subTextColor =>
      Theme.of(context).textTheme.bodyMedium?.color ?? Colors.black87;

  Color get iconColor => Colors.grey;

  Color get borderColor => Theme.of(context).dividerColor;

  String tr(String en, String ar) => isArabic ? ar : en;

  bool get isSmallScreen {
    final width = MediaQuery.maybeOf(context)?.size.width ?? 400;
    return width < 380;
  }

  @override
  void initState() {
    super.initState();
    AppSettingsStore.instance.addListener(_onLanguageChanged);
    _loadSavedLoginData();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (mounted && isAccessibilityVoiceEnabled) {
        await _startVoiceAccessibilityAssistant();
      }
    });
  }

  void _onLanguageChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _toggleLanguage() async {
    await VoiceAccessibilityService.instance.stopAll();

    AppSettingsStore.instance.toggleLanguage();
    setState(() {});

    if (isAccessibilityVoiceEnabled) {
      await _startVoiceAccessibilityAssistant();
    }
  }

  @override
  void dispose() {
    AppSettingsStore.instance.removeListener(_onLanguageChanged);
    VoiceAccessibilityService.instance.stopAll();
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadSavedLoginData() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    final bool savedRememberMe = prefs.getBool('remember_me') ?? false;
    final String savedEmail = prefs.getString('saved_email') ?? '';
    final String savedPassword =
        await _secureStorage.read(key: 'saved_password') ?? '';

    if (!mounted) return;

    setState(() {
      _rememberMe = savedRememberMe;
      if (_rememberMe) {
        _emailController.text = savedEmail;
        _passwordController.text = savedPassword;
      }
    });
  }

  Future<void> _saveLoginData() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    if (_rememberMe) {
      await prefs.setBool('remember_me', true);
      await prefs.setString('saved_email', _emailController.text.trim());

      await _secureStorage.write(
        key: 'saved_password',
        value: _passwordController.text,
      );
    } else {
      await prefs.setBool('remember_me', false);
      await prefs.remove('saved_email');
      await _secureStorage.delete(key: 'saved_password');
    }
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
            backgroundColor: fieldColor,
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

  Future<void> _showWrongPasswordPopup(String message) async {
    await _showInfoPopup(
      title: tr('Login Failed', 'فشل تسجيل الدخول'),
      message: message,
      icon: Icons.lock_outline_rounded,
      iconColor: Colors.red,
    );
  }

  Future<void> _showLoginSuccessPopup() async {
    await _showInfoPopup(
      title: tr('Login Success', 'تم تسجيل الدخول'),
      message: tr(
        'Welcome back to Human Touch.',
        'مرحباً بعودتك إلى Human Touch.',
      ),
      icon: Icons.check_circle_outline_rounded,
      iconColor: Colors.green,
    );
  }

  Future<void> _showInternetErrorPopup() async {
    await _showInfoPopup(
      title: tr('Internet Error', 'خطأ في الاتصال'),
      message: tr(
        'Please check your internet connection and try again.',
        'يرجى التحقق من اتصال الإنترنت والمحاولة مرة أخرى.',
      ),
      icon: Icons.wifi_off_rounded,
      iconColor: Colors.orange,
    );
  }

  Future<void> _showAccountSecurityPopup(String message) async {
    await _showInfoPopup(
      title: tr('Account Security', 'أمان الحساب'),
      message: message,
      icon: Icons.security_rounded,
      iconColor: Colors.orange,
    );
  }

  Future<void> _showEmailNotVerifiedPopup() async {
    await _showInfoPopup(
      title: tr('Email Not Verified', 'البريد غير مؤكد'),
      message: tr(
        'Please verify your account using the 6-digit code sent to your email.',
        'يرجى تأكيد حسابك باستخدام كود التحقق المكون من 6 أرقام المرسل إلى بريدك.',
      ),
      icon: Icons.mark_email_unread_outlined,
      iconColor: Colors.orange,
    );
  }

  Future<void> _handleForgotPassword() async {
    await VoiceAccessibilityService.instance.stopAll();

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ForgetPasswordPage(),
      ),
    );
  }

  Future<void> _handleLogin() async {
    await VoiceAccessibilityService.instance.stopAll();

    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final UserCredential userCredential =
          await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final User? user = userCredential.user;

      if (user == null) {
        throw Exception(
          tr(
            'User not found. Please try again.',
            'لم يتم العثور على المستخدم. يرجى المحاولة مرة أخرى.',
          ),
        );
      }

      final DocumentSnapshot<Map<String, dynamic>> userDoc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();

      if (!userDoc.exists) {
        throw Exception(
          tr(
            'User role not found in Firestore.',
            'لم يتم العثور على دور المستخدم في قاعدة البيانات.',
          ),
        );
      }

      final Map<String, dynamic>? data = userDoc.data();

      final String role = (data?['role'] ?? '').toString();
      final bool emailVerified = data?['emailVerified'] == true;

      if (!emailVerified) {
        await FirebaseAuth.instance.signOut();

        if (!mounted) return;

        setState(() {
          _isLoading = false;
        });

        await _showEmailNotVerifiedPopup();
        return;
      }

      await _saveLoginData();

      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      await _showLoginSuccessPopup();

      if (!mounted) return;

      await VoiceAccessibilityService.instance.stopAll();

      if (role == 'patient') {
        Navigator.pushReplacementNamed(context, '/dashboard');
      } else if (role == 'companion') {
        Navigator.pushReplacementNamed(context, '/companionDashboard');
      } else if (role == 'volunteer') {
        Navigator.pushReplacementNamed(context, '/volunteerDashboard');
      } else {
        await _showAccountSecurityPopup(
          tr('Unknown user role.', 'دور المستخدم غير معروف.'),
        );
      }
    } on FirebaseAuthException catch (e) {
      String message = tr(
        'Email or password is incorrect.',
        'البريد الإلكتروني أو كلمة المرور غير صحيحة.',
      );

      bool isInternetError = false;
      bool isSecurityError = false;

      if (e.code == 'invalid-email') {
        message = tr(
          'Please enter a valid email.',
          'يرجى إدخال بريد إلكتروني صحيح.',
        );
      } else if (e.code == 'user-not-found') {
        message = tr(
          'No account found with this email.',
          'لا يوجد حساب بهذا البريد الإلكتروني.',
        );
      } else if (e.code == 'wrong-password') {
        message = tr('Incorrect password.', 'كلمة المرور غير صحيحة.');
      } else if (e.code == 'invalid-credential') {
        message = tr(
          'Email or password is incorrect.',
          'البريد الإلكتروني أو كلمة المرور غير صحيحة.',
        );
      } else if (e.code == 'user-disabled') {
        isSecurityError = true;
        message = tr(
          'This account has been disabled for security reasons.',
          'تم تعطيل هذا الحساب لأسباب أمنية.',
        );
      } else if (e.code == 'too-many-requests') {
        isSecurityError = true;
        message = tr(
          'Too many login attempts. Please try again later.',
          'تمت محاولات تسجيل دخول كثيرة. يرجى المحاولة لاحقاً.',
        );
      } else if (e.code == 'network-request-failed') {
        isInternetError = true;
      } else if (e.message != null && e.message!.trim().isNotEmpty) {
        message = e.message!;
      }

      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      if (isInternetError) {
        await _showInternetErrorPopup();
      } else if (isSecurityError) {
        await _showAccountSecurityPopup(message);
      } else {
        await _showWrongPasswordPopup(message);
      }
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      await _showInternetErrorPopup();
    }
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

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      floatingLabelBehavior: FloatingLabelBehavior.auto,
      labelStyle: TextStyle(
        fontSize: isSmallScreen ? 14 : 16,
        color: subTextColor,
        fontWeight: FontWeight.normal,
      ),
      floatingLabelStyle: const TextStyle(
        fontSize: 14,
        color: Color(0xFF025590),
        fontWeight: FontWeight.normal,
      ),
      filled: true,
      fillColor: fieldColor,
      prefixIcon: Icon(icon, color: iconColor),
      suffixIcon: suffixIcon,
      contentPadding: EdgeInsets.symmetric(
        horizontal: 14,
        vertical: isSmallScreen ? 14 : 18,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: BorderSide(color: borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: BorderSide(color: borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: const BorderSide(color: Color(0xFF025590), width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: const BorderSide(color: Colors.red),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: const BorderSide(color: Colors.red, width: 2),
      ),
    );
  }

  Widget _buildFieldContainer({required Widget child}) {
    return SizedBox(
      width: double.infinity,
      child: child,
    );
  }

  Widget _languageButton() {
    return Positioned(
      top: 10,
      right: isArabic ? null : 16,
      left: isArabic ? 16 : null,
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
    );
  }

  Widget _buildRememberAndForgotRow() {
    return Row(
      children: [
        Checkbox(
          value: _rememberMe,
          onChanged: (value) {
            setState(() {
              _rememberMe = value ?? false;
            });
          },
          activeColor: const Color(0xFF87CEEB),
          checkColor: Colors.white,
          side: const BorderSide(
            width: 1.5,
            color: Colors.grey,
          ),
        ),
        Text(
          tr('Remember me', 'تذكرني'),
          style: TextStyle(
            fontSize: 14,
            color: textColor,
          ),
        ),
        const Spacer(),
        SizedBox(
          width: 170,
          child: Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              style: _linkButtonStyle(),
              onPressed: _handleForgotPassword,
              child: Text(
                tr('Forgot Password?', 'نسيت كلمة المرور؟'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSignUpRow() {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 6,
      runSpacing: 6,
      children: [
        Text(
          tr('Don\'t have an account?', 'ليس لديك حساب؟'),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: textColor,
          ),
        ),
        TextButton(
          style: _linkButtonStyle(),
          onPressed: () async {
            await VoiceAccessibilityService.instance.stopAll();

            if (!mounted) return;

            Navigator.pushNamed(context, '/signup');
          },
          child: Text(
            tr('Sign Up', 'إنشاء حساب'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14),
          ),
        ),
      ],
    );
  }

  String get _loginReaderText => tr(
        'Login screen. Enter your email and password to sign in. Email. Password. Remember me. Forgot password. Login. Sign up. Change language.',
        'صفحة تسجيل الدخول. أدخل البريد الإلكتروني وكلمة المرور لتسجيل الدخول. البريد الإلكتروني. كلمة المرور. تذكرني. نسيت كلمة المرور. تسجيل الدخول. إنشاء حساب. تغيير اللغة.',
      );

  Future<void> _startVoiceAccessibilityAssistant() async {
    if (!mounted) return;

    await VoiceAccessibilityService.instance.stopAll();

    setState(() {
      _isSpeaking = true;
    });

    await VoiceAccessibilityService.instance.readPageAndListen(
      context: context,
      pageText: _loginReaderText,
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
                  ? const Color(0xFF87CEEB)
                  : const Color(0xFFFF5A5F),
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.18),
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
            textScaler: TextScaler.linear(AppSettingsStore.instance.textScale),
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
                              32,
                            ),
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                minHeight: constraints.maxHeight,
                              ),
                              child: Form(
                                key: _formKey,
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
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
                                        tr('Login', 'تسجيل الدخول'),
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
                                    SizedBox(height: isSmallScreen ? 14 : 16),
                                    _buildFieldContainer(
                                      child: TextFormField(
                                        controller: _emailController,
                                        focusNode: _emailFocusNode,
                                        keyboardType:
                                            TextInputType.emailAddress,
                                        textInputAction: TextInputAction.next,
                                        textAlign: isArabic
                                            ? TextAlign.right
                                            : TextAlign.left,
                                        decoration: _inputDecoration(
                                          label:
                                              tr('Email', 'البريد الإلكتروني'),
                                          icon: Icons.account_circle_outlined,
                                        ),
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: textColor,
                                        ),
                                        cursorColor: textColor,
                                        validator: (value) {
                                          final text = value?.trim() ?? '';
                                          if (text.isEmpty) {
                                            return tr(
                                              'Please enter your email',
                                              'يرجى إدخال البريد الإلكتروني',
                                            );
                                          }
                                          if (!text.contains('@') ||
                                              !text.contains('.')) {
                                            return tr(
                                              'Please enter a valid email',
                                              'يرجى إدخال بريد إلكتروني صحيح',
                                            );
                                          }
                                          return null;
                                        },
                                        onFieldSubmitted: (_) {
                                          FocusScope.of(context).requestFocus(
                                            _passwordFocusNode,
                                          );
                                        },
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    _buildFieldContainer(
                                      child: TextFormField(
                                        controller: _passwordController,
                                        focusNode: _passwordFocusNode,
                                        obscureText: _obscurePassword,
                                        textInputAction: TextInputAction.done,
                                        textAlign: isArabic
                                            ? TextAlign.right
                                            : TextAlign.left,
                                        decoration: _inputDecoration(
                                          label: tr('Password', 'كلمة المرور'),
                                          icon: Icons.lock_outlined,
                                          suffixIcon: InkWell(
                                            onTap: () {
                                              setState(() {
                                                _obscurePassword =
                                                    !_obscurePassword;
                                              });
                                            },
                                            child: Icon(
                                              _obscurePassword
                                                  ? Icons
                                                      .visibility_off_outlined
                                                  : Icons.visibility_outlined,
                                              color: iconColor,
                                              size: 25,
                                            ),
                                          ),
                                        ),
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: textColor,
                                        ),
                                        cursorColor: textColor,
                                        validator: (value) {
                                          final text = value ?? '';
                                          if (text.isEmpty) {
                                            return tr(
                                              'Please enter your password',
                                              'يرجى إدخال كلمة المرور',
                                            );
                                          }
                                          return null;
                                        },
                                        onFieldSubmitted: (_) => _handleLogin(),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    _buildRememberAndForgotRow(),
                                    SizedBox(height: isSmallScreen ? 22 : 30),
                                    SizedBox(
                                      width: double.infinity,
                                      height: 56,
                                      child: ElevatedButton(
                                        onPressed:
                                            _isLoading ? null : _handleLogin,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              const Color(0xFF87CEEB),
                                          disabledBackgroundColor:
                                              Colors.grey.shade400,
                                          elevation: 0,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(4),
                                          ),
                                        ),
                                        child: _isLoading
                                            ? const SizedBox(
                                                width: 22,
                                                height: 22,
                                                child:
                                                    CircularProgressIndicator(
                                                  strokeWidth: 2.2,
                                                  color: Colors.white,
                                                ),
                                              )
                                            : Text(
                                                tr('Login', 'تسجيل الدخول'),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                      ),
                                    ),
                                    SizedBox(height: isSmallScreen ? 34 : 50),
                                    _buildSignUpRow(),
                                  ],
                                ),
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
