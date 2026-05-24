import 'dart:convert';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

import 'location_picker_page.dart';
import 'CompanionDashboard_page.dart';
import 'Login_page.dart';
import 'SignUp_page.dart';
import 'app_settings_store.dart';

class SignUpCompanionPage extends StatefulWidget {
  const SignUpCompanionPage({super.key});

  @override
  State<SignUpCompanionPage> createState() => _SignUpCompanionPageState();
}

class _SignUpCompanionPageState extends State<SignUpCompanionPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final TextEditingController _relationshipController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();

  final FocusNode _nameFocusNode = FocusNode();
  final FocusNode _emailFocusNode = FocusNode();
  final FocusNode _phoneFocusNode = FocusNode();
  final FocusNode _passwordFocusNode = FocusNode();
  final FocusNode _confirmPasswordFocusNode = FocusNode();
  final FocusNode _relationshipFocusNode = FocusNode();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;

  String _passwordText = '';
  String _verificationCode = '';

  double? _selectedLatitude;
  double? _selectedLongitude;

  bool get isArabic => AppSettingsStore.instance.isArabic;

  Color get backgroundColor => Theme.of(context).scaffoldBackgroundColor;

  Color get fieldColor =>
      Theme.of(context).inputDecorationTheme.fillColor ?? Colors.white;

  Color get buttonFieldColor =>
      Theme.of(context).inputDecorationTheme.fillColor ?? Colors.white;

  Color get textColor =>
      Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;

  Color get labelColor =>
      Theme.of(context).textTheme.bodyMedium?.color ?? Colors.black87;

  String tr(String en, String ar) => isArabic ? ar : en;

  bool get isSmallScreen {
    final width = MediaQuery.maybeOf(context)?.size.width ?? 400;
    return width < 380;
  }

  bool get _hasLowercase => RegExp(r'[a-z]').hasMatch(_passwordText);
  bool get _hasUppercase => RegExp(r'[A-Z]').hasMatch(_passwordText);
  bool get _hasNumber => RegExp(r'[0-9]').hasMatch(_passwordText);
  bool get _hasSymbol => RegExp(r'[@#$!]').hasMatch(_passwordText);
  bool get _hasMinLength => _passwordText.length >= 8;

  String generateVerificationCode() {
    return (100000 + Random().nextInt(900000)).toString();
  }

  Future<void> _sendOtpEmail({
    required String email,
    required String passcode,
  }) async {
    final response = await http.post(
      Uri.parse('https://api.emailjs.com/api/v1.0/email/send'),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'service_id': 'service_7urahca',
        'template_id': 'template_18bz7gs',
        'user_id': 'ZKCFmT-CnJTGjjkbW',
        'template_params': {
          'to_email': email,
          'passcode': passcode,
          'time': '15 minutes',
        },
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('EmailJS failed: ${response.body}');
    }
  }

  @override
  void initState() {
    super.initState();
    AppSettingsStore.instance.addListener(_onLanguageChanged);
  }

  void _onLanguageChanged() {
    if (mounted) setState(() {});
  }

  void _toggleLanguage() {
    AppSettingsStore.instance.toggleLanguage();
    setState(() {});
  }

  @override
  void dispose() {
    AppSettingsStore.instance.removeListener(_onLanguageChanged);

    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _relationshipController.dispose();
    _locationController.dispose();

    _nameFocusNode.dispose();
    _emailFocusNode.dispose();
    _phoneFocusNode.dispose();
    _passwordFocusNode.dispose();
    _confirmPasswordFocusNode.dispose();
    _relationshipFocusNode.dispose();

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
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: textColor,
                    fontSize: isSmallScreen ? 18 : 20,
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
                  color: textColor,
                  fontSize: isSmallScreen ? 14 : 15,
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

  Future<void> _showEmailAlreadyUsedPopup() async {
    await _showInfoPopup(
      title: tr('Email Already Used', 'البريد مستخدم مسبقاً'),
      message: tr(
        'This email is already registered. Please use another email or login instead.',
        'هذا البريد الإلكتروني مسجل مسبقاً. يرجى استخدام بريد آخر أو تسجيل الدخول.',
      ),
      icon: Icons.email_outlined,
      iconColor: Colors.orange,
    );
  }

  Future<void> _showWeakPasswordPopup() async {
    await _showInfoPopup(
      title: tr('Weak Password', 'كلمة المرور ضعيفة'),
      message: tr(
        'Password must contain at least 8 characters, uppercase letter, lowercase letter, number, and symbol.',
        'يجب أن تحتوي كلمة المرور على 8 أحرف على الأقل، وحرف كبير، وحرف صغير، ورقم، ورمز.',
      ),
      icon: Icons.lock_outline_rounded,
      iconColor: Colors.red,
    );
  }

  Future<void> _showAccountCreatedSuccessfullyPopup() async {
    await _showInfoPopup(
      title: tr('Account Created', 'تم إنشاء الحساب'),
      message: tr(
        'Your companion account has been created successfully.',
        'تم إنشاء حساب المرافق بنجاح.',
      ),
      icon: Icons.check_circle_outline_rounded,
      iconColor: Colors.green,
    );
  }

  Future<void> _showVerifyEmailPopup() async {
    await _showInfoPopup(
      title: tr('Verify Email', 'تأكيد البريد الإلكتروني'),
      message: tr(
        'A verification email has been sent. Please verify your email before logging in.',
        'تم إرسال رسالة تأكيد إلى بريدك الإلكتروني. يرجى تأكيد البريد قبل تسجيل الدخول.',
      ),
      icon: Icons.mark_email_unread_outlined,
      iconColor: const Color(0xFF87CEEB),
    );
  }

  Future<void> _showLocationPermissionPopup() async {
    await _showInfoPopup(
      title: tr('Location Required', 'الموقع مطلوب'),
      message: tr(
        'Please select your location before creating the account.',
        'يرجى اختيار موقعك قبل إنشاء الحساب.',
      ),
      icon: Icons.location_on_outlined,
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

  void _generateStrongPassword() {
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789@#\$!';
    final random = Random();

    String password = '';
    password += 'a';
    password += 'A';
    password += '1';
    password += '@';

    for (int i = 0; i < 6; i++) {
      password += chars[random.nextInt(chars.length)];
    }

    final shuffled = password.split('')..shuffle();

    setState(() {
      _passwordText = shuffled.join();
      _passwordController.text = _passwordText;
      _confirmPasswordController.text = _passwordText;
    });
  }

  Widget _passwordRequirement(String text, bool isValid) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(
            isValid ? Icons.check_circle : Icons.cancel,
            size: 16,
            color: isValid ? Colors.green : Colors.red,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              textAlign: isArabic ? TextAlign.right : TextAlign.left,
              style: TextStyle(
                fontSize: 12,
                color: isValid ? Colors.green : Colors.red,
              ),
            ),
          ),
        ],
      ),
    );
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

  InputDecoration _inputDecoration({
    required String label,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      floatingLabelBehavior: FloatingLabelBehavior.auto,
      labelStyle: TextStyle(
        fontSize: isSmallScreen ? 14 : 16,
        color: labelColor,
        fontWeight: FontWeight.normal,
      ),
      floatingLabelStyle: const TextStyle(
        fontSize: 14,
        color: Color(0xFF025590),
        fontWeight: FontWeight.normal,
      ),
      filled: true,
      fillColor: fieldColor,
      contentPadding: EdgeInsets.symmetric(
        horizontal: 14,
        vertical: isSmallScreen ? 14 : 18,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: const BorderSide(color: Color(0xFFBDBDBD)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: const BorderSide(color: Color(0xFFBDBDBD)),
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
      suffixIcon: suffixIcon,
    );
  }

  Widget _buildFieldContainer({required Widget child, double? height}) {
    return SizedBox(
      width: double.infinity,
      height: height,
      child: child,
    );
  }

  Future<void> _selectLocation() async {
    final result = await Navigator.pushNamed(
      context,
      '/locationPicker',
    );

    if (result != null && result is Map<String, dynamic>) {
      final latValue = result['latitude'];
      final lngValue = result['longitude'];

      setState(() {
        _locationController.text = result['address'] ?? '';
        _selectedLatitude = latValue is num ? latValue.toDouble() : null;
        _selectedLongitude = lngValue is num ? lngValue.toDouble() : null;
      });

      await _showInfoPopup(
        title: tr('Location Selected', 'تم اختيار الموقع'),
        message: tr(
          'Your location has been selected successfully.',
          'تم اختيار موقعك بنجاح.',
        ),
        icon: Icons.location_on_rounded,
        iconColor: Colors.green,
      );
    }
  }

  Future<void> _handleSignUp() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;

    if (_locationController.text.trim().isEmpty ||
        _selectedLatitude == null ||
        _selectedLongitude == null) {
      await _showLocationPermissionPopup();
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final UserCredential userCredential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final User? user = userCredential.user;

      if (user == null) {
        throw Exception('User is null');
      }

      _verificationCode = generateVerificationCode();

      await _sendOtpEmail(
        email: _emailController.text.trim(),
        passcode: _verificationCode,
      );

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'relationship': _relationshipController.text.trim(),
        'location': _locationController.text.trim(),
        'latitude': _selectedLatitude,
        'longitude': _selectedLongitude,
        'role': 'companion',
        'emailVerified': false,
        'verificationCode': _verificationCode,
        'verificationCodeCreatedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      await _showInfoPopup(
        title: tr('Verification Code Sent', 'تم إرسال كود التحقق'),
        message: tr(
          'A 6-digit verification code has been sent to your email. Please enter it to verify your account.',
          'تم إرسال كود تحقق مكون من 6 أرقام إلى بريدك الإلكتروني. يرجى إدخاله لتأكيد الحساب.',
        ),
        icon: Icons.mark_email_unread_outlined,
        iconColor: const Color(0xFF87CEEB),
      );

      if (!mounted) return;

      final TextEditingController codeController = TextEditingController();

      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return Directionality(
            textDirection:
                isArabic ? ui.TextDirection.rtl : ui.TextDirection.ltr,
            child: AlertDialog(
              backgroundColor: fieldColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
              title: Text(
                tr('Enter Verification Code', 'أدخل كود التحقق'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: TextField(
                controller: codeController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 4,
                ),
                decoration: InputDecoration(
                  hintText: tr('6-digit code', 'كود من 6 أرقام'),
                  counterText: '',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              actionsAlignment: MainAxisAlignment.center,
              actions: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF87CEEB),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    final enteredCode = codeController.text.trim();

                    if (enteredCode == _verificationCode) {
                      await FirebaseFirestore.instance
                          .collection('users')
                          .doc(user.uid)
                          .update({
                        'emailVerified': true,
                        'verificationCode': '',
                        'verifiedAt': FieldValue.serverTimestamp(),
                        'updatedAt': FieldValue.serverTimestamp(),
                      });

                      if (!mounted) return;

                      Navigator.pop(dialogContext);

                      await _showAccountCreatedSuccessfullyPopup();

                      if (!mounted) return;

                      Navigator.pushReplacementNamed(
                        context,
                        '/companionDashboard',
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            tr(
                              'Invalid verification code',
                              'كود التحقق غير صحيح',
                            ),
                          ),
                        ),
                      );
                    }
                  },
                  child: Text(tr('Verify', 'تحقق')),
                ),
              ],
            ),
          );
        },
      );

      codeController.dispose();
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      if (e.code == 'email-already-in-use') {
        await _showEmailAlreadyUsedPopup();
      } else if (e.code == 'weak-password') {
        await _showWeakPasswordPopup();
      } else if (e.code == 'invalid-email') {
        await _showAccountSecurityPopup(
          tr(
            'Please enter a valid email address.',
            'يرجى إدخال بريد إلكتروني صحيح.',
          ),
        );
      } else if (e.code == 'operation-not-allowed') {
        await _showAccountSecurityPopup(
          tr(
            'Email and password sign up is not enabled in Firebase.',
            'تسجيل البريد وكلمة المرور غير مفعل في Firebase.',
          ),
        );
      } else if (e.code == 'network-request-failed') {
        await _showAccountSecurityPopup(
          tr(
            'Please check your internet connection and try again.',
            'يرجى التحقق من اتصال الإنترنت والمحاولة مرة أخرى.',
          ),
        );
      } else {
        await _showAccountSecurityPopup(
          e.message ??
              tr(
                'Something went wrong while creating your account.',
                'حدث خطأ أثناء إنشاء الحساب.',
              ),
        );
      }
    } on FirebaseException catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      await _showAccountSecurityPopup(
        tr(
          'Firebase error: ${e.code}',
          'خطأ في Firebase: ${e.code}',
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      await _showAccountSecurityPopup(
        tr(
          'Something went wrong: $e',
          'حدث خطأ: $e',
        ),
      );
    }
  }

  Widget _languageButton() {
    return Positioned(
      top: 8,
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
          style: TextStyle(color: textColor),
        ),
        TextButton(
          style: _linkButtonStyle(),
          onPressed: () {
            Navigator.pushNamed(
              context,
              '/login',
            );
          },
          child: Text(
            tr('Login', 'تسجيل الدخول'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildLocationButton() {
    return SizedBox(
      width: double.infinity,
      height: isSmallScreen ? 52 : 56,
      child: ElevatedButton(
        onPressed: _selectLocation,
        style: ElevatedButton.styleFrom(
          backgroundColor: buttonFieldColor,
          foregroundColor: textColor,
          elevation: 0,
          alignment: isArabic ? Alignment.centerRight : Alignment.centerLeft,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.place),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _locationController.text.isEmpty
                    ? tr('Select Location', 'اختيار الموقع')
                    : _locationController.text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: isArabic ? TextAlign.right : TextAlign.left,
                style: TextStyle(color: textColor),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSignUpButton() {
    return SizedBox(
      width: double.infinity,
      height: isSmallScreen ? 52 : 56,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handleSignUp,
        style: _mainButtonStyle(),
        child: _isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: Colors.white,
                ),
              )
            : Text(
                tr(
                  'Companion Sign Up',
                  'تسجيل المرافق',
                ),
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
                          return Column(
                            children: [
                              Align(
                                alignment: isArabic
                                    ? Alignment.centerRight
                                    : Alignment.centerLeft,
                                child: Padding(
                                  padding:
                                      const EdgeInsets.fromLTRB(20, 0, 20, 0),
                                  child: IconButton(
                                    onPressed: () {
                                      Navigator.pushReplacementNamed(
                                        context,
                                        '/signup',
                                      );
                                    },
                                    icon: Icon(
                                      isArabic
                                          ? Icons.arrow_forward
                                          : Icons.arrow_back,
                                      size: isSmallScreen ? 26 : 30,
                                      color: textColor,
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: SingleChildScrollView(
                                  keyboardDismissBehavior:
                                      ScrollViewKeyboardDismissBehavior.onDrag,
                                  padding: EdgeInsets.fromLTRB(
                                    isSmallScreen ? 18 : 26,
                                    0,
                                    isSmallScreen ? 18 : 26,
                                    24,
                                  ),
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(
                                      minHeight: constraints.maxHeight - 60,
                                    ),
                                    child: Form(
                                      key: _formKey,
                                      child: Column(
                                        children: [
                                          SizedBox(
                                            height: isSmallScreen ? 20 : 40,
                                          ),
                                          Center(
                                            child: Text(
                                              tr(
                                                'Companion Sign Up',
                                                'تسجيل المرافق',
                                              ),
                                              textAlign: TextAlign.center,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize:
                                                    isSmallScreen ? 30 : 40,
                                                fontWeight: FontWeight.w300,
                                                color: textColor,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 20),
                                          _buildFieldContainer(
                                            child: TextFormField(
                                              controller: _nameController,
                                              focusNode: _nameFocusNode,
                                              textInputAction:
                                                  TextInputAction.next,
                                              textAlign: isArabic
                                                  ? TextAlign.right
                                                  : TextAlign.left,
                                              decoration: _inputDecoration(
                                                label: tr('Name', 'الاسم'),
                                              ),
                                              style:
                                                  TextStyle(color: textColor),
                                              validator: (value) {
                                                if ((value ?? '')
                                                    .trim()
                                                    .isEmpty) {
                                                  return tr(
                                                    'Please enter your name',
                                                    'يرجى إدخال الاسم',
                                                  );
                                                }
                                                return null;
                                              },
                                              onFieldSubmitted: (_) {
                                                FocusScope.of(context)
                                                    .requestFocus(
                                                  _emailFocusNode,
                                                );
                                              },
                                            ),
                                          ),
                                          const SizedBox(height: 10),
                                          _buildFieldContainer(
                                            child: TextFormField(
                                              controller: _emailController,
                                              focusNode: _emailFocusNode,
                                              keyboardType:
                                                  TextInputType.emailAddress,
                                              textInputAction:
                                                  TextInputAction.next,
                                              textAlign: isArabic
                                                  ? TextAlign.right
                                                  : TextAlign.left,
                                              decoration: _inputDecoration(
                                                label: tr(
                                                  'Email',
                                                  'البريد الإلكتروني',
                                                ),
                                              ),
                                              style:
                                                  TextStyle(color: textColor),
                                              validator: (value) {
                                                final text =
                                                    (value ?? '').trim();

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
                                                FocusScope.of(context)
                                                    .requestFocus(
                                                  _phoneFocusNode,
                                                );
                                              },
                                            ),
                                          ),
                                          const SizedBox(height: 10),
                                          _buildFieldContainer(
                                            child: TextFormField(
                                              controller: _phoneController,
                                              focusNode: _phoneFocusNode,
                                              keyboardType: TextInputType.phone,
                                              textInputAction:
                                                  TextInputAction.next,
                                              textAlign: isArabic
                                                  ? TextAlign.right
                                                  : TextAlign.left,
                                              decoration: _inputDecoration(
                                                label: tr(
                                                  'Phone Number',
                                                  'رقم الهاتف',
                                                ),
                                              ),
                                              style:
                                                  TextStyle(color: textColor),
                                              validator: (value) {
                                                final text =
                                                    (value ?? '').trim();

                                                if (text.isEmpty) {
                                                  return tr(
                                                    'Please enter your phone number',
                                                    'يرجى إدخال رقم الهاتف',
                                                  );
                                                }

                                                if (text.length != 8) {
                                                  return tr(
                                                    'Please enter a valid phone number',
                                                    'يرجى إدخال رقم هاتف صحيح',
                                                  );
                                                }

                                                return null;
                                              },
                                              onFieldSubmitted: (_) {
                                                FocusScope.of(context)
                                                    .requestFocus(
                                                  _passwordFocusNode,
                                                );
                                              },
                                            ),
                                          ),
                                          const SizedBox(height: 10),
                                          Align(
                                            alignment: isArabic
                                                ? Alignment.centerLeft
                                                : Alignment.centerRight,
                                            child: TextButton.icon(
                                              style: _linkButtonStyle(),
                                              onPressed:
                                                  _generateStrongPassword,
                                              icon: const Icon(
                                                Icons.auto_awesome,
                                                size: 18,
                                              ),
                                              label: Text(
                                                tr(
                                                  'Generate strong password',
                                                  'إنشاء كلمة مرور قوية',
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          _buildFieldContainer(
                                            child: TextFormField(
                                              controller: _passwordController,
                                              focusNode: _passwordFocusNode,
                                              obscureText: _obscurePassword,
                                              textInputAction:
                                                  TextInputAction.next,
                                              textAlign: isArabic
                                                  ? TextAlign.right
                                                  : TextAlign.left,
                                              decoration: _inputDecoration(
                                                label: tr(
                                                  'Password',
                                                  'كلمة المرور',
                                                ),
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
                                                        : Icons
                                                            .visibility_outlined,
                                                    color: Colors.grey,
                                                  ),
                                                ),
                                              ),
                                              style:
                                                  TextStyle(color: textColor),
                                              onChanged: (value) {
                                                setState(() {
                                                  _passwordText = value;
                                                });
                                              },
                                              validator: (value) {
                                                final text = value ?? '';

                                                if (text.isEmpty) {
                                                  return tr(
                                                    'Please enter password',
                                                    'يرجى إدخال كلمة المرور',
                                                  );
                                                }

                                                if (!RegExp(r'[a-z]')
                                                    .hasMatch(text)) {
                                                  return tr(
                                                    'Password must contain at least one lowercase letter',
                                                    'يجب أن تحتوي كلمة المرور على حرف صغير واحد على الأقل',
                                                  );
                                                }

                                                if (!RegExp(r'[A-Z]')
                                                    .hasMatch(text)) {
                                                  return tr(
                                                    'Password must contain at least one uppercase letter',
                                                    'يجب أن تحتوي كلمة المرور على حرف كبير واحد على الأقل',
                                                  );
                                                }

                                                if (!RegExp(r'[0-9]')
                                                    .hasMatch(text)) {
                                                  return tr(
                                                    'Password must contain at least one number',
                                                    'يجب أن تحتوي كلمة المرور على رقم واحد على الأقل',
                                                  );
                                                }

                                                if (!RegExp(r'[@#$!]')
                                                    .hasMatch(text)) {
                                                  return tr(
                                                    'Password must contain at least one symbol (@#\$!)',
                                                    'يجب أن تحتوي كلمة المرور على رمز واحد على الأقل (@#\$!)',
                                                  );
                                                }

                                                if (text.length < 8) {
                                                  return tr(
                                                    'Password must be at least 8 characters',
                                                    'يجب أن تكون كلمة المرور 8 أحرف على الأقل',
                                                  );
                                                }

                                                return null;
                                              },
                                              onFieldSubmitted: (_) {
                                                FocusScope.of(context)
                                                    .requestFocus(
                                                  _confirmPasswordFocusNode,
                                                );
                                              },
                                            ),
                                          ),
                                          if (_passwordText.isNotEmpty) ...[
                                            const SizedBox(height: 6),
                                            Column(
                                              crossAxisAlignment: isArabic
                                                  ? CrossAxisAlignment.end
                                                  : CrossAxisAlignment.start,
                                              children: [
                                                _passwordRequirement(
                                                  tr(
                                                    'At least one lowercase letter (a-z)',
                                                    'حرف صغير واحد على الأقل (a-z)',
                                                  ),
                                                  _hasLowercase,
                                                ),
                                                _passwordRequirement(
                                                  tr(
                                                    'At least one uppercase letter (A-Z)',
                                                    'حرف كبير واحد على الأقل (A-Z)',
                                                  ),
                                                  _hasUppercase,
                                                ),
                                                _passwordRequirement(
                                                  tr(
                                                    'At least one number (0-9)',
                                                    'رقم واحد على الأقل (0-9)',
                                                  ),
                                                  _hasNumber,
                                                ),
                                                _passwordRequirement(
                                                  tr(
                                                    'At least one symbol (@#\$!)',
                                                    'رمز واحد على الأقل (@#\$!)',
                                                  ),
                                                  _hasSymbol,
                                                ),
                                                _passwordRequirement(
                                                  tr(
                                                    'At least 8 characters',
                                                    '8 أحرف على الأقل',
                                                  ),
                                                  _hasMinLength,
                                                ),
                                              ],
                                            ),
                                          ],
                                          const SizedBox(height: 10),
                                          _buildFieldContainer(
                                            child: TextFormField(
                                              controller:
                                                  _confirmPasswordController,
                                              focusNode:
                                                  _confirmPasswordFocusNode,
                                              obscureText:
                                                  _obscureConfirmPassword,
                                              textInputAction:
                                                  TextInputAction.next,
                                              textAlign: isArabic
                                                  ? TextAlign.right
                                                  : TextAlign.left,
                                              decoration: _inputDecoration(
                                                label: tr(
                                                  'Confirm Password',
                                                  'تأكيد كلمة المرور',
                                                ),
                                                suffixIcon: InkWell(
                                                  onTap: () {
                                                    setState(() {
                                                      _obscureConfirmPassword =
                                                          !_obscureConfirmPassword;
                                                    });
                                                  },
                                                  child: Icon(
                                                    _obscureConfirmPassword
                                                        ? Icons
                                                            .visibility_off_outlined
                                                        : Icons
                                                            .visibility_outlined,
                                                    color: Colors.grey,
                                                  ),
                                                ),
                                              ),
                                              style:
                                                  TextStyle(color: textColor),
                                              validator: (value) {
                                                final text = value ?? '';

                                                if (text.isEmpty) {
                                                  return tr(
                                                    'Please confirm password',
                                                    'يرجى تأكيد كلمة المرور',
                                                  );
                                                }

                                                if (text !=
                                                    _passwordController.text) {
                                                  return tr(
                                                    'Passwords do not match',
                                                    'كلمتا المرور غير متطابقتين',
                                                  );
                                                }

                                                return null;
                                              },
                                              onFieldSubmitted: (_) {
                                                FocusScope.of(context)
                                                    .requestFocus(
                                                  _relationshipFocusNode,
                                                );
                                              },
                                            ),
                                          ),
                                          const SizedBox(height: 10),
                                          _buildFieldContainer(
                                            child: TextFormField(
                                              controller:
                                                  _relationshipController,
                                              focusNode: _relationshipFocusNode,
                                              textInputAction:
                                                  TextInputAction.done,
                                              textAlign: isArabic
                                                  ? TextAlign.right
                                                  : TextAlign.left,
                                              decoration: _inputDecoration(
                                                label: tr(
                                                  'Relationship with the patient',
                                                  'العلاقة مع المريض',
                                                ),
                                              ),
                                              style:
                                                  TextStyle(color: textColor),
                                              validator: (value) {
                                                if ((value ?? '')
                                                    .trim()
                                                    .isEmpty) {
                                                  return tr(
                                                    'Please enter relationship',
                                                    'يرجى إدخال العلاقة',
                                                  );
                                                }
                                                return null;
                                              },
                                            ),
                                          ),
                                          const SizedBox(height: 10),
                                          _buildLocationButton(),
                                          const SizedBox(height: 20),
                                          _buildSignUpButton(),
                                          const SizedBox(height: 10),
                                          _buildLoginRow(),
                                          const SizedBox(height: 18),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      _languageButton(),
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
