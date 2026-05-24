import 'dart:convert';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'app_settings_store.dart';

class ForgetPasswordPage extends StatefulWidget {
  const ForgetPasswordPage({super.key});

  @override
  State<ForgetPasswordPage> createState() => _ForgetPasswordPageState();
}

class _ForgetPasswordPageState extends State<ForgetPasswordPage> {
  final GlobalKey<FormState> _emailFormKey = GlobalKey<FormState>();

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _isLoading = false;
  bool _codeSent = false;
  bool _codeVerified = false;
  bool _passwordChanged = false;

  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;

  String _verificationCode = '';

  bool get isArabic => AppSettingsStore.instance.isArabic;
  bool get isDarkMode => AppSettingsStore.instance.isDarkMode;

  bool get isSmallScreen {
    return MediaQuery.of(context).size.width < 380;
  }

  Color get backgroundColor =>
      isDarkMode ? const Color(0xFF808080) : Colors.white;

  Color get fieldColor =>
      isDarkMode ? const Color(0xFF9E9E9E) : const Color(0xFFF4F4F4);

  Color get textColor => isDarkMode ? Colors.white : Colors.black;

  Color get subTextColor => isDarkMode ? Colors.white70 : Colors.black87;

  String tr(String en, String ar) => isArabic ? ar : en;

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
    _emailController.dispose();
    _codeController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _goToLogin() {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  String _generateVerificationCode() {
    return (100000 + Random().nextInt(900000)).toString();
  }

  String _generateStrongPassword() {
    const String lowercase = 'abcdefghijklmnopqrstuvwxyz';
    const String uppercase = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    const String numbers = '0123456789';
    const String symbols = '@#\$!';
    const String all = lowercase + uppercase + numbers + symbols;

    final Random random = Random.secure();

    final List<String> chars = [
      lowercase[random.nextInt(lowercase.length)],
      uppercase[random.nextInt(uppercase.length)],
      numbers[random.nextInt(numbers.length)],
      symbols[random.nextInt(symbols.length)],
    ];

    for (int i = 0; i < 8; i++) {
      chars.add(all[random.nextInt(all.length)]);
    }

    chars.shuffle(random);
    return chars.join();
  }

  void _fillGeneratedPassword() {
    final String password = _generateStrongPassword();

    setState(() {
      _newPasswordController.text = password;
      _confirmPasswordController.text = password;
      _obscureNewPassword = false;
      _obscureConfirmPassword = false;
    });
  }

  Future<void> _sendOtpEmail({
    required String email,
    required String passcode,
  }) async {
    final response = await http.post(
      Uri.parse('https://api.emailjs.com/api/v1.0/email/send'),
      headers: {
        'origin': 'http://localhost',
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

  Future<void> _showMessage({
    required String title,
    required String message,
    required IconData icon,
    required Color color,
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
              borderRadius: BorderRadius.circular(22),
            ),
            title: Column(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: color.withOpacity(0.15),
                  child: Icon(icon, color: color, size: 32),
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: isSmallScreen ? 18 : 20,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: isSmallScreen ? 13 : 15,
                  color: textColor,
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

  Future<void> _sendVerificationCode() async {
    FocusScope.of(context).unfocus();

    if (!_emailFormKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final String email = _emailController.text.trim();

      _verificationCode = _generateVerificationCode();

      await _sendOtpEmail(
        email: email,
        passcode: _verificationCode,
      );

      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _codeSent = true;
        _codeVerified = false;
        _passwordChanged = false;
      });

      await _showMessage(
        title: tr('Verification Code Sent', 'تم إرسال كود التحقق'),
        message: tr(
          'A 6-digit verification code has been sent to your email.',
          'تم إرسال كود تحقق مكون من 6 أرقام إلى بريدك الإلكتروني.',
        ),
        icon: Icons.mark_email_unread_outlined,
        color: const Color(0xFF87CEEB),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      await _showMessage(
        title: tr('Error', 'خطأ'),
        message: e.toString(),
        icon: Icons.error_outline_rounded,
        color: Colors.red,
      );
    }
  }

  Future<void> _verifyCodeAndContinue() async {
    FocusScope.of(context).unfocus();

    final String enteredCode = _codeController.text.trim();

    if (enteredCode.isEmpty || enteredCode.length != 6) {
      await _showMessage(
        title: tr('Invalid Code', 'كود غير صحيح'),
        message: tr(
          'Please enter the 6-digit code.',
          'يرجى إدخال كود التحقق المكون من 6 أرقام.',
        ),
        icon: Icons.pin_outlined,
        color: Colors.orange,
      );
      return;
    }

    if (enteredCode != _verificationCode) {
      await _showMessage(
        title: tr('Invalid Code', 'كود غير صحيح'),
        message: tr(
          'Invalid verification code.',
          'كود التحقق غير صحيح.',
        ),
        icon: Icons.error_outline_rounded,
        color: Colors.red,
      );
      return;
    }

    setState(() {
      _codeVerified = true;
    });
  }

  bool _isStrongPassword(String password) {
    final bool hasLowercase = RegExp(r'[a-z]').hasMatch(password);
    final bool hasUppercase = RegExp(r'[A-Z]').hasMatch(password);
    final bool hasNumber = RegExp(r'[0-9]').hasMatch(password);
    final bool hasSymbol = RegExp(r'[@#$!]').hasMatch(password);
    final bool hasMinLength = password.length >= 8;

    return hasLowercase &&
        hasUppercase &&
        hasNumber &&
        hasSymbol &&
        hasMinLength;
  }

  Future<void> _changePassword() async {
    FocusScope.of(context).unfocus();

    final String newPassword = _newPasswordController.text.trim();
    final String confirmPassword = _confirmPasswordController.text.trim();

    if (newPassword.isEmpty || confirmPassword.isEmpty) {
      await _showMessage(
        title: tr('Required Field', 'حقل مطلوب'),
        message: tr(
          'Please enter and confirm your new password.',
          'يرجى إدخال كلمة المرور الجديدة وتأكيدها.',
        ),
        icon: Icons.lock_outline_rounded,
        color: Colors.orange,
      );
      return;
    }

    if (!_isStrongPassword(newPassword)) {
      await _showMessage(
        title: tr('Weak Password', 'كلمة المرور ضعيفة'),
        message: tr(
          'Password must contain uppercase, lowercase, number, symbol (@#\$!), and at least 8 characters.',
          'يجب أن تحتوي كلمة المرور على حرف كبير وصغير ورقم ورمز (@#\$!) و8 أحرف على الأقل.',
        ),
        icon: Icons.lock_outline_rounded,
        color: Colors.red,
      );
      return;
    }

    if (newPassword != confirmPassword) {
      await _showMessage(
        title: tr('Passwords Do Not Match', 'كلمتا المرور غير متطابقتين'),
        message: tr(
          'New password and confirm password must be the same.',
          'يجب أن تكون كلمة المرور الجديدة وتأكيدها متطابقين.',
        ),
        icon: Icons.lock_reset_outlined,
        color: Colors.red,
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final HttpsCallable callable = FirebaseFunctions.instanceFor(
        region: 'us-central1',
      ).httpsCallable('changePasswordByEmail');

      await callable.call({
        'email': _emailController.text.trim(),
        'newPassword': newPassword,
      });

      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _passwordChanged = true;
      });
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      await _showMessage(
        title: tr('Password Change Failed', 'فشل تغيير كلمة المرور'),
        message: e.message ?? e.code,
        icon: Icons.error_outline_rounded,
        color: Colors.red,
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      await _showMessage(
        title: tr('Password Change Failed', 'فشل تغيير كلمة المرور'),
        message: e.toString(),
        icon: Icons.error_outline_rounded,
        color: Colors.red,
      );
    }
  }

  InputDecoration _inputDecoration({
    required String label,
    IconData? prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      isDense: true,
      labelText: label,
      labelStyle: TextStyle(
        fontSize: isSmallScreen ? 15 : 18,
        color: subTextColor,
        fontWeight: FontWeight.normal,
      ),
      prefixIcon:
          prefixIcon != null ? Icon(prefixIcon, color: subTextColor) : null,
      suffixIcon: suffixIcon,
      border: InputBorder.none,
      enabledBorder: InputBorder.none,
      focusedBorder: InputBorder.none,
      errorBorder: InputBorder.none,
      focusedErrorBorder: InputBorder.none,
      contentPadding: EdgeInsets.symmetric(
        vertical: isSmallScreen ? 13 : 16,
      ),
    );
  }

  Widget _buildFieldContainer({
    required Widget child,
    double? height,
  }) {
    return Container(
      width: double.infinity,
      height: height ?? (isSmallScreen ? 52 : 56),
      decoration: BoxDecoration(
        color: fieldColor,
        borderRadius: BorderRadius.circular(4),
        border: isDarkMode ? Border.all(color: Colors.white12, width: 1) : null,
      ),
      padding: EdgeInsets.fromLTRB(
        isSmallScreen ? 10 : 12,
        5,
        isSmallScreen ? 10 : 12,
        0,
      ),
      child: child,
    );
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
                color: Colors.black.withOpacity(isDarkMode ? 0.35 : 0.15),
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

  Widget _logo() {
    return Center(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.asset(
          'assets/logo.png',
          width: isSmallScreen ? 150 : 200,
          height: isSmallScreen ? 150 : 200,
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  Widget _mainButton({
    required String text,
    required VoidCallback? onPressed,
    bool rounded = false,
  }) {
    return SizedBox(
      width: double.infinity,
      height: isSmallScreen ? 46 : 49,
      child: ElevatedButton(
        onPressed: _isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF87CEEB),
          disabledBackgroundColor: Colors.grey.shade400,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(rounded ? 100 : 4),
          ),
        ),
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
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isSmallScreen ? 14 : 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }

  Widget _buildEmailForm() {
    return Form(
      key: _emailFormKey,
      child: Column(
        children: [
          _logo(),
          Text(
            tr('Change Password', 'تغيير كلمة المرور'),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: isSmallScreen ? 25 : 30,
              fontWeight: FontWeight.w300,
              color: textColor,
            ),
          ),
          SizedBox(height: isSmallScreen ? 8 : 10),
          Text(
            tr(
              'Enter your email and we will send you a verification code.',
              'أدخل بريدك الإلكتروني وسنرسل لك كود تحقق.',
            ),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: isSmallScreen ? 14 : 16,
              color: subTextColor,
            ),
          ),
          SizedBox(height: isSmallScreen ? 22 : 30),
          _buildFieldContainer(
            child: TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              textAlign: isArabic ? TextAlign.right : TextAlign.left,
              decoration: _inputDecoration(
                label: tr('Enter your email', 'أدخل بريدك الإلكتروني'),
                prefixIcon: Icons.mail_outline_rounded,
              ),
              style: TextStyle(
                fontSize: isSmallScreen ? 14 : 16,
                color: textColor,
              ),
              validator: (value) {
                final String text = (value ?? '').trim();

                if (text.isEmpty) {
                  return tr(
                    'Please enter your email',
                    'يرجى إدخال بريدك الإلكتروني',
                  );
                }

                if (!text.contains('@') || !text.contains('.')) {
                  return tr(
                    'Please enter a valid email',
                    'يرجى إدخال بريد إلكتروني صحيح',
                  );
                }

                return null;
              },
            ),
          ),
          SizedBox(height: isSmallScreen ? 22 : 30),
          _mainButton(
            text: tr('Continue', 'متابعة'),
            onPressed: _sendVerificationCode,
            rounded: true,
          ),
        ],
      ),
    );
  }

  Widget _buildCodeForm() {
    return Column(
      children: [
        _logo(),
        Text(
          tr('Enter Verification Code', 'أدخل كود التحقق'),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: isSmallScreen ? 24 : 28,
            fontWeight: FontWeight.w300,
            color: textColor,
          ),
        ),
        SizedBox(height: isSmallScreen ? 8 : 10),
        Text(
          tr(
            'We have sent the verification code to your email.',
            'تم إرسال كود التحقق إلى بريدك الإلكتروني.',
          ),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: isSmallScreen ? 13 : 15,
            color: subTextColor,
          ),
        ),
        SizedBox(height: isSmallScreen ? 22 : 30),
        _buildFieldContainer(
          child: TextFormField(
            controller: _codeController,
            keyboardType: TextInputType.number,
            maxLength: 6,
            textAlign: TextAlign.center,
            decoration: _inputDecoration(
              label: tr('Verification Code', 'كود التحقق'),
              prefixIcon: Icons.verified_user_outlined,
            ).copyWith(counterText: ''),
            style: TextStyle(
              fontSize: isSmallScreen ? 18 : 20,
              color: textColor,
              fontWeight: FontWeight.bold,
              letterSpacing: 4,
            ),
          ),
        ),
        SizedBox(height: isSmallScreen ? 22 : 30),
        _mainButton(
          text: tr('Continue', 'متابعة'),
          onPressed: _verifyCodeAndContinue,
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: _isLoading ? null : _sendVerificationCode,
          child: Text(
            tr('Resend Code', 'إعادة إرسال الكود'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: const Color(0xFF025590),
              fontSize: isSmallScreen ? 13 : 14,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNewPasswordForm() {
    return Column(
      children: [
        _logo(),
        Text(
          tr('Create New Password', 'إنشاء كلمة مرور جديدة'),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: isSmallScreen ? 24 : 28,
            fontWeight: FontWeight.w300,
            color: textColor,
          ),
        ),
        SizedBox(height: isSmallScreen ? 8 : 10),
        Text(
          tr(
            'Enter your new password and confirm it.',
            'أدخل كلمة المرور الجديدة وقم بتأكيدها.',
          ),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: isSmallScreen ? 13 : 15,
            color: subTextColor,
          ),
        ),
        SizedBox(height: isSmallScreen ? 12 : 16),
        Align(
          alignment: isArabic ? Alignment.centerLeft : Alignment.centerRight,
          child: TextButton.icon(
            onPressed: _isLoading ? null : _fillGeneratedPassword,
            icon: const Icon(Icons.auto_awesome, size: 18),
            label: Text(
              tr('Generate strong password', 'إنشاء كلمة مرور قوية'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        SizedBox(height: isSmallScreen ? 8 : 10),
        _buildFieldContainer(
          child: TextFormField(
            controller: _newPasswordController,
            obscureText: _obscureNewPassword,
            textAlign: isArabic ? TextAlign.right : TextAlign.left,
            decoration: _inputDecoration(
              label: tr('New Password', 'كلمة المرور الجديدة'),
              prefixIcon: Icons.lock_outline_rounded,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureNewPassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: subTextColor,
                ),
                onPressed: () {
                  setState(() {
                    _obscureNewPassword = !_obscureNewPassword;
                  });
                },
              ),
            ),
            style: TextStyle(
              fontSize: isSmallScreen ? 14 : 16,
              color: textColor,
            ),
          ),
        ),
        const SizedBox(height: 12),
        _buildFieldContainer(
          child: TextFormField(
            controller: _confirmPasswordController,
            obscureText: _obscureConfirmPassword,
            textAlign: isArabic ? TextAlign.right : TextAlign.left,
            decoration: _inputDecoration(
              label: tr('Confirm Password', 'تأكيد كلمة المرور'),
              prefixIcon: Icons.lock_reset_outlined,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureConfirmPassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: subTextColor,
                ),
                onPressed: () {
                  setState(() {
                    _obscureConfirmPassword = !_obscureConfirmPassword;
                  });
                },
              ),
            ),
            style: TextStyle(
              fontSize: isSmallScreen ? 14 : 16,
              color: textColor,
            ),
          ),
        ),
        SizedBox(height: isSmallScreen ? 22 : 30),
        _mainButton(
          text: tr('Save Password', 'حفظ كلمة المرور'),
          onPressed: _changePassword,
        ),
      ],
    );
  }

  Widget _buildSuccessMessage() {
    return Column(
      children: [
        SizedBox(height: isSmallScreen ? 60 : 110),
        Icon(
          Icons.check_circle_outline_rounded,
          color: const Color(0xFF46DE2D),
          size: isSmallScreen ? 100 : 140,
        ),
        SizedBox(height: isSmallScreen ? 16 : 20),
        Text(
          tr('Password Changed', 'تم تغيير كلمة المرور'),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: isSmallScreen ? 22 : 26,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
        SizedBox(height: isSmallScreen ? 16 : 20),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: isSmallScreen ? 8 : 20),
          child: Text(
            tr(
              'Your password has been changed successfully. You can now log in with your new password.',
              'تم تغيير كلمة المرور بنجاح. يمكنك الآن تسجيل الدخول بكلمة المرور الجديدة.',
            ),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: isSmallScreen ? 14 : 16,
              fontWeight: FontWeight.w500,
              color: subTextColor,
            ),
          ),
        ),
        SizedBox(height: isSmallScreen ? 22 : 30),
        SizedBox(
          width: double.infinity,
          height: isSmallScreen ? 52 : 56,
          child: ElevatedButton(
            onPressed: _goToLogin,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF87CEEB),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            child: Text(
              tr('Back to Login', 'الرجوع إلى تسجيل الدخول'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white,
                fontSize: isSmallScreen ? 14 : 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _currentBody() {
    if (_passwordChanged) return _buildSuccessMessage();
    if (_codeVerified) return _buildNewPasswordForm();
    if (_codeSent) return _buildCodeForm();
    return _buildEmailForm();
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
                      Column(
                        children: [
                          if (!_passwordChanged)
                            Align(
                              alignment: isArabic
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                              child: Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(20, 0, 20, 0),
                                child: IconButton(
                                  onPressed: _goToLogin,
                                  style: ButtonStyle(
                                    overlayColor:
                                        WidgetStateProperty.resolveWith<Color?>(
                                      (states) {
                                        if (states.contains(
                                          WidgetState.pressed,
                                        )) {
                                          return Colors.grey.withOpacity(0.30);
                                        }
                                        return null;
                                      },
                                    ),
                                  ),
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
                              child: _currentBody(),
                            ),
                          ),
                        ],
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
