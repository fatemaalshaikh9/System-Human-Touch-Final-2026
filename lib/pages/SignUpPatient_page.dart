import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'location_picker_page.dart';
import 'Dashboard_page.dart';
import 'Login_page.dart';
import 'SignUp_page.dart';
import 'app_settings_store.dart';

class SignUpPatientPage extends StatefulWidget {
  const SignUpPatientPage({super.key});

  @override
  State<SignUpPatientPage> createState() => _SignUpPatientPageState();
}

class _SignUpPatientPageState extends State<SignUpPatientPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _multipleDisabilitiesController =
      TextEditingController();

  final FocusNode _nameFocusNode = FocusNode();
  final FocusNode _emailFocusNode = FocusNode();
  final FocusNode _phoneFocusNode = FocusNode();
  final FocusNode _passwordFocusNode = FocusNode();
  final FocusNode _confirmPasswordFocusNode = FocusNode();
  final FocusNode _ageFocusNode = FocusNode();
  final FocusNode _multipleDisabilitiesFocusNode = FocusNode();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  bool _isVoiceEnabled = false;
  bool _isSpeaking = false;

  late final FlutterTts _flutterTts;

  static const String _accessibilityVoiceKey = 'accessibility_voice_enabled';

  String _passwordText = '';
  String _verificationCode = '';

  bool get isArabic => AppSettingsStore.instance.isArabic;

  bool get isSmallScreen {
    return MediaQuery.of(context).size.width < 380;
  }

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

  String get _patientSignUpScreenReaderText => tr(
        'Welcome to the Human Touch patient sign up screen. Please enter your name, email, phone number, password, confirm password, and age. Then select your disability type, gender, and location. You can also generate a strong password. Press the sign up button to create your account or use the login option if you already have an account.',
        'مرحباً بك في شاشة تسجيل المريض في تطبيق Human Touch. يرجى إدخال الاسم، البريد الإلكتروني، رقم الهاتف، كلمة المرور، تأكيد كلمة المرور، والعمر. بعد ذلك اختَر نوع الإعاقة، الجنس، والموقع. يمكنك أيضاً إنشاء كلمة مرور قوية. اضغط على زر تسجيل المريض لإنشاء الحساب، أو استخدم خيار تسجيل الدخول إذا كان لديك حساب مسبقاً.',
      );

  Future<void> _setupAccessibilityVoice() async {
    _flutterTts = FlutterTts();

    await _flutterTts.setLanguage(isArabic ? 'ar-SA' : 'en-US');
    await _flutterTts.setSpeechRate(0.45);
    await _flutterTts.setPitch(1.0);
    await _flutterTts.awaitSpeakCompletion(false);

    _flutterTts.setStartHandler(() {
      if (mounted) {
        setState(() {
          _isSpeaking = true;
        });
      }
    });

    _flutterTts.setCompletionHandler(() {
      if (mounted) {
        setState(() {
          _isSpeaking = false;
        });
      }
    });

    _flutterTts.setCancelHandler(() {
      if (mounted) {
        setState(() {
          _isSpeaking = false;
        });
      }
    });
  }

  Future<bool?> _readVoiceFromAppSettingsStore() async {
    try {
      final dynamic settings = AppSettingsStore.instance;

      try {
        final value = settings.isAccessibilityVoiceEnabled;
        if (value is bool) return value;
      } catch (_) {}

      try {
        final value = settings.accessibilityVoiceEnabled;
        if (value is bool) return value;
      } catch (_) {}

      try {
        final value = settings.isVoiceEnabled;
        if (value is bool) return value;
      } catch (_) {}

      try {
        final value = settings.voiceEnabled;
        if (value is bool) return value;
      } catch (_) {}
    } catch (_) {}

    return null;
  }

  Future<void> _saveVoiceToAppSettingsStore(bool enabled) async {
    try {
      final dynamic settings = AppSettingsStore.instance;

      try {
        settings.setAccessibilityVoiceEnabled(enabled);
        return;
      } catch (_) {}

      try {
        settings.updateAccessibilityVoice(enabled);
        return;
      } catch (_) {}

      try {
        settings.setVoiceEnabled(enabled);
        return;
      } catch (_) {}

      try {
        settings.updateVoiceEnabled(enabled);
        return;
      } catch (_) {}
    } catch (_) {}
  }

  Future<void> _loadAccessibilityVoiceSetting() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    final bool enabled = (await _readVoiceFromAppSettingsStore()) ??
        prefs.getBool(_accessibilityVoiceKey) ??
        false;

    if (!mounted) return;

    setState(() {
      _isVoiceEnabled = enabled;
    });

    if (enabled) {
      await _speakPatientSignUpScreen();
    }
  }

  Future<void> _setAccessibilityVoiceEnabled(bool enabled) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    await prefs.setBool(_accessibilityVoiceKey, enabled);
    await _saveVoiceToAppSettingsStore(enabled);

    if (!mounted) return;

    setState(() {
      _isVoiceEnabled = enabled;
    });

    if (!enabled) {
      await _stopAccessibilityVoice();
    }
  }

  Future<void> _speakPatientSignUpScreen() async {
    if (!_isVoiceEnabled || !mounted) return;

    await _flutterTts.stop();
    await _flutterTts.setLanguage(isArabic ? 'ar-SA' : 'en-US');
    await _flutterTts.speak(_patientSignUpScreenReaderText);
  }

  Future<void> _stopAccessibilityVoice() async {
    await _flutterTts.stop();

    if (mounted) {
      setState(() {
        _isSpeaking = false;
      });
    }
  }

  Future<void> _toggleAccessibilityVoiceButton() async {
    if (_isVoiceEnabled && _isSpeaking) {
      await _stopAccessibilityVoice();
      return;
    }

    if (!_isVoiceEnabled) {
      await _setAccessibilityVoiceEnabled(true);
    }

    await _speakPatientSignUpScreen();
  }

  bool get _hasLowercase => RegExp(r'[a-z]').hasMatch(_passwordText);
  bool get _hasUppercase => RegExp(r'[A-Z]').hasMatch(_passwordText);
  bool get _hasNumber => RegExp(r'[0-9]').hasMatch(_passwordText);
  bool get _hasSymbol => RegExp(r'[@#$!]').hasMatch(_passwordText);
  bool get _hasMinLength => _passwordText.length >= 8;

  String? _selectedDisability;
  String? _selectedGender;

  double? _selectedLatitude;
  double? _selectedLongitude;

  final List<String> _disabilityOptions = const [
    'Physical Disability',
    'Hearing Disability',
    'Visual Disability',
    'Intellectual Disability',
    'Multiple Disabilities',
  ];

  String generateVerificationCode() {
    return (100000 + Random().nextInt(900000)).toString();
  }

  Future<void> _sendOtpEmail({
    required String email,
    required String passcode,
  }) async {
    print('OTP SEND START: $email / $passcode');

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

    print('EMAILJS STATUS: ${response.statusCode}');
    print('EMAILJS BODY: ${response.body}');

    if (response.statusCode != 200) {
      throw Exception('EmailJS failed: ${response.body}');
    }

    print('OTP SEND DONE');
  }

  @override
  void initState() {
    super.initState();
    AppSettingsStore.instance.addListener(_onLanguageChanged);
    _setupAccessibilityVoice();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAccessibilityVoiceSetting();
    });
  }

  void _onLanguageChanged() {
    if (mounted) setState(() {});
    _flutterTts.setLanguage(isArabic ? 'ar-SA' : 'en-US');
  }

  void _toggleLanguage() {
    AppSettingsStore.instance.toggleLanguage();
    setState(() {});
  }

  String _disabilityText(String value) {
    switch (value) {
      case 'Physical Disability':
        return tr('Physical Disability', 'إعاقة حركية');
      case 'Hearing Disability':
        return tr('Hearing Disability', 'إعاقة سمعية');
      case 'Visual Disability':
        return tr('Visual Disability', 'إعاقة بصرية');
      case 'Intellectual Disability':
        return tr('Intellectual Disability', 'إعاقة ذهنية');
      case 'Multiple Disabilities':
        return tr('Multiple Disabilities', 'إعاقات متعددة');
      default:
        return value;
    }
  }

  @override
  void dispose() {
    AppSettingsStore.instance.removeListener(_onLanguageChanged);

    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _ageController.dispose();
    _locationController.dispose();
    _multipleDisabilitiesController.dispose();

    _nameFocusNode.dispose();
    _emailFocusNode.dispose();
    _phoneFocusNode.dispose();
    _passwordFocusNode.dispose();
    _confirmPasswordFocusNode.dispose();
    _ageFocusNode.dispose();
    _multipleDisabilitiesFocusNode.dispose();

    _flutterTts.stop();

    super.dispose();
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
                  child: Icon(
                    icon,
                    color: color,
                    size: 32,
                  ),
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
                onPressed: () {
                  Navigator.pop(context);
                },
                child: Text(tr('OK', 'حسنًا')),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showOtpDialog({
    required User user,
  }) async {
    final TextEditingController codeController = TextEditingController();

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return Directionality(
          textDirection: isArabic ? ui.TextDirection.rtl : ui.TextDirection.ltr,
          child: AlertDialog(
            backgroundColor: fieldColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),
            title: Text(
              tr('Enter Verification Code', 'أدخل كود التحقق'),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: textColor,
                fontSize: isSmallScreen ? 18 : 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: TextField(
              controller: codeController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: textColor,
                fontSize: isSmallScreen ? 20 : 22,
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

                    await _showMessage(
                      title: tr(
                        'Account Created',
                        'تم إنشاء الحساب',
                      ),
                      message: tr(
                        'Your patient account has been created successfully.',
                        'تم إنشاء حساب المريض بنجاح.',
                      ),
                      icon: Icons.check_circle_outline_rounded,
                      color: Colors.green,
                    );

                    if (!mounted) return;

                    Navigator.pushReplacementNamed(context, '/dashboard');
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
      ),
      floatingLabelStyle: const TextStyle(
        fontSize: 14,
        color: Color(0xFF025590),
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

  Widget _buildFieldContainer({
    required Widget child,
    double? height,
  }) {
    return SizedBox(
      width: double.infinity,
      height: height ?? (isSmallScreen ? 58 : 64),
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

      await _showMessage(
        title: tr('Location Selected', 'تم اختيار الموقع'),
        message: tr(
          'Your location has been selected successfully.',
          'تم اختيار موقعك بنجاح.',
        ),
        icon: Icons.location_on_rounded,
        color: Colors.green,
      );
    }
  }

  Future<void> _handleSignUp() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;

    if (_selectedDisability == null || _selectedDisability!.isEmpty) {
      await _showMessage(
        title: tr('Required Field', 'حقل مطلوب'),
        message: tr(
          'Please select type of disability',
          'يرجى اختيار نوع الإعاقة',
        ),
        icon: Icons.accessibility_new_rounded,
        color: Colors.orange,
      );
      return;
    }

    if (_selectedDisability == 'Multiple Disabilities' &&
        _multipleDisabilitiesController.text.trim().isEmpty) {
      await _showMessage(
        title: tr('Required Field', 'حقل مطلوب'),
        message: tr(
          'Please enter the disabilities',
          'يرجى إدخال الإعاقات',
        ),
        icon: Icons.warning_amber_rounded,
        color: Colors.orange,
      );
      return;
    }

    if (_selectedGender == null || _selectedGender!.isEmpty) {
      await _showMessage(
        title: tr('Required Field', 'حقل مطلوب'),
        message: tr(
          'Please select gender',
          'يرجى اختيار الجنس',
        ),
        icon: Icons.person_outline,
        color: Colors.orange,
      );
      return;
    }

    if (_locationController.text.trim().isEmpty ||
        _selectedLatitude == null ||
        _selectedLongitude == null) {
      await _showMessage(
        title: tr('Location Permission', 'الموقع مطلوب'),
        message: tr(
          'Please select your location before creating the account.',
          'يرجى اختيار موقعك قبل إنشاء الحساب.',
        ),
        icon: Icons.location_on_outlined,
        color: Colors.orange,
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final String email = _emailController.text.trim();

      final UserCredential userCredential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: _passwordController.text.trim(),
      );

      final User? user = userCredential.user;

      if (user == null) {
        throw Exception('User is null');
      }

      _verificationCode = generateVerificationCode();

      print('OTP CODE: $_verificationCode');

      await _sendOtpEmail(
        email: email,
        passcode: _verificationCode,
      );

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'name': _nameController.text.trim(),
        'email': email,
        'phone': _phoneController.text.trim(),
        'age': int.tryParse(_ageController.text.trim()) ?? 0,
        'disabilityType': _selectedDisability,
        'multipleDisabilities': _selectedDisability == 'Multiple Disabilities'
            ? _multipleDisabilitiesController.text.trim()
            : '',
        'gender': _selectedGender,
        'location': _locationController.text.trim(),
        'latitude': _selectedLatitude,
        'longitude': _selectedLongitude,
        'role': 'patient',
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

      await _showMessage(
        title: tr(
          'Verification Code Sent',
          'تم إرسال كود التحقق',
        ),
        message: tr(
          'A 6-digit verification code has been sent to your email. Please enter it to verify your account.',
          'تم إرسال كود تحقق مكون من 6 أرقام إلى بريدك الإلكتروني. يرجى إدخاله لتأكيد الحساب.',
        ),
        icon: Icons.mark_email_unread_outlined,
        color: const Color(0xFF87CEEB),
      );

      if (!mounted) return;

      await _showOtpDialog(user: user);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      if (e.code == 'email-already-in-use') {
        await _showMessage(
          title: tr(
            'Email Already Used',
            'البريد مستخدم مسبقاً',
          ),
          message: tr(
            'This email is already registered. Please use another email.',
            'هذا البريد الإلكتروني مستخدم مسبقاً. يرجى استخدام بريد آخر.',
          ),
          icon: Icons.email_outlined,
          color: Colors.orange,
        );
      } else if (e.code == 'weak-password') {
        await _showMessage(
          title: tr(
            'Weak Password',
            'كلمة المرور ضعيفة',
          ),
          message: tr(
            'Password must contain uppercase, lowercase, number, symbol, and at least 8 characters.',
            'يجب أن تحتوي كلمة المرور على حرف كبير وصغير ورقم ورمز و8 أحرف على الأقل.',
          ),
          icon: Icons.lock_outline_rounded,
          color: Colors.red,
        );
      } else if (e.code == 'invalid-email') {
        await _showMessage(
          title: tr(
            'Account Security',
            'أمان الحساب',
          ),
          message: tr(
            'Please enter a valid email.',
            'يرجى إدخال بريد إلكتروني صحيح.',
          ),
          icon: Icons.security_rounded,
          color: Colors.deepOrange,
        );
      } else if (e.code == 'operation-not-allowed') {
        await _showMessage(
          title: tr(
            'Account Security',
            'أمان الحساب',
          ),
          message: tr(
            'Email/Password sign-in is not enabled in Firebase.',
            'تسجيل الدخول بالبريد وكلمة المرور غير مفعل في Firebase.',
          ),
          icon: Icons.security_rounded,
          color: Colors.deepOrange,
        );
      } else if (e.code == 'network-request-failed') {
        await _showMessage(
          title: tr(
            'Connection Error',
            'خطأ في الاتصال',
          ),
          message: tr(
            'Please check your internet connection and try again.',
            'يرجى التحقق من اتصال الإنترنت والمحاولة مرة أخرى.',
          ),
          icon: Icons.wifi_off_rounded,
          color: Colors.orange,
        );
      } else {
        await _showMessage(
          title: tr(
            'Account Security',
            'أمان الحساب',
          ),
          message: 'Auth error: ${e.code}',
          icon: Icons.security_rounded,
          color: Colors.deepOrange,
        );
      }
    } on FirebaseException catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      await _showMessage(
        title: tr(
          'Firebase Error',
          'خطأ في Firebase',
        ),
        message: 'Firebase error: ${e.code}',
        icon: Icons.error_outline_rounded,
        color: Colors.red,
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      await _showMessage(
        title: tr(
          'Error',
          'خطأ',
        ),
        message: e.toString(),
        icon: Icons.error_outline_rounded,
        color: Colors.red,
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

  Widget _accessibilityVoiceButton() {
    return Positioned(
      bottom: 18,
      left: isArabic ? null : 18,
      right: isArabic ? 18 : null,
      child: SafeArea(
        child: Semantics(
          button: true,
          label: _isSpeaking
              ? tr(
                  'Stop accessibility voice',
                  'إيقاف صوت إمكانية الوصول',
                )
              : tr(
                  'Read this page',
                  'قراءة هذه الصفحة',
                ),
          child: GestureDetector(
            onTap: _toggleAccessibilityVoiceButton,
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool showMultipleDisabilitiesField =
        _selectedDisability == 'Multiple Disabilities';

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
                      Align(
                        alignment: isArabic
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Column(
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
                                        context, '/signup');
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
                                child: Form(
                                  key: _formKey,
                                  child: Column(
                                    children: [
                                      SizedBox(
                                        height: isSmallScreen ? 14 : 20,
                                      ),
                                      Center(
                                        child: Text(
                                          tr(
                                            'Patient Sign Up',
                                            'تسجيل المريض',
                                          ),
                                          textAlign: TextAlign.center,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: isSmallScreen ? 30 : 40,
                                            fontWeight: FontWeight.w300,
                                            color: textColor,
                                          ),
                                        ),
                                      ),
                                      SizedBox(
                                        height: isSmallScreen ? 8 : 10,
                                      ),
                                      _buildFieldContainer(
                                        child: TextFormField(
                                          controller: _nameController,
                                          focusNode: _nameFocusNode,
                                          textInputAction: TextInputAction.next,
                                          textAlign: isArabic
                                              ? TextAlign.right
                                              : TextAlign.left,
                                          decoration: _inputDecoration(
                                            label: tr('Name', 'الاسم'),
                                          ),
                                          style: TextStyle(
                                            color: textColor,
                                            fontSize: isSmallScreen ? 14 : 16,
                                          ),
                                          validator: (value) {
                                            if ((value ?? '').trim().isEmpty) {
                                              return tr(
                                                'Please enter your name',
                                                'يرجى إدخال الاسم',
                                              );
                                            }
                                            return null;
                                          },
                                          onFieldSubmitted: (_) {
                                            FocusScope.of(context)
                                                .requestFocus(_emailFocusNode);
                                          },
                                        ),
                                      ),
                                      SizedBox(
                                        height: isSmallScreen ? 6 : 8,
                                      ),
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
                                            label: tr(
                                              'Email',
                                              'البريد الإلكتروني',
                                            ),
                                          ),
                                          style: TextStyle(
                                            color: textColor,
                                            fontSize: isSmallScreen ? 14 : 16,
                                          ),
                                          validator: (value) {
                                            final text = (value ?? '').trim();

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
                                                .requestFocus(_phoneFocusNode);
                                          },
                                        ),
                                      ),
                                      SizedBox(
                                        height: isSmallScreen ? 6 : 8,
                                      ),
                                      _buildFieldContainer(
                                        child: TextFormField(
                                          controller: _phoneController,
                                          focusNode: _phoneFocusNode,
                                          keyboardType: TextInputType.phone,
                                          textInputAction: TextInputAction.next,
                                          textAlign: isArabic
                                              ? TextAlign.right
                                              : TextAlign.left,
                                          decoration: _inputDecoration(
                                            label: tr(
                                              'Phone Number',
                                              'رقم الهاتف',
                                            ),
                                          ),
                                          style: TextStyle(
                                            color: textColor,
                                            fontSize: isSmallScreen ? 14 : 16,
                                          ),
                                          validator: (value) {
                                            final text = (value ?? '').trim();

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
                                            FocusScope.of(context).requestFocus(
                                              _passwordFocusNode,
                                            );
                                          },
                                        ),
                                      ),
                                      SizedBox(
                                        height: isSmallScreen ? 6 : 8,
                                      ),
                                      Align(
                                        alignment: isArabic
                                            ? Alignment.centerLeft
                                            : Alignment.centerRight,
                                        child: TextButton.icon(
                                          style: _linkButtonStyle(),
                                          onPressed: _generateStrongPassword,
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
                                            style:
                                                const TextStyle(fontSize: 13),
                                          ),
                                        ),
                                      ),
                                      SizedBox(
                                        height: isSmallScreen ? 4 : 6,
                                      ),
                                      _buildFieldContainer(
                                        child: TextFormField(
                                          controller: _passwordController,
                                          focusNode: _passwordFocusNode,
                                          obscureText: _obscurePassword,
                                          textInputAction: TextInputAction.next,
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
                                                    : Icons.visibility_outlined,
                                                color: Colors.grey,
                                                size: 25,
                                              ),
                                            ),
                                          ),
                                          style: TextStyle(
                                            color: textColor,
                                            fontSize: isSmallScreen ? 14 : 16,
                                          ),
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
                                            FocusScope.of(context).requestFocus(
                                              _confirmPasswordFocusNode,
                                            );
                                          },
                                        ),
                                      ),
                                      SizedBox(
                                        height: isSmallScreen ? 4 : 6,
                                      ),
                                      if (_passwordText.isNotEmpty)
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
                                      SizedBox(
                                        height: isSmallScreen ? 6 : 8,
                                      ),
                                      _buildFieldContainer(
                                        child: TextFormField(
                                          controller:
                                              _confirmPasswordController,
                                          focusNode: _confirmPasswordFocusNode,
                                          obscureText: _obscureConfirmPassword,
                                          textInputAction: TextInputAction.next,
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
                                                    : Icons.visibility_outlined,
                                                color: Colors.grey,
                                                size: 25,
                                              ),
                                            ),
                                          ),
                                          style: TextStyle(
                                            color: textColor,
                                            fontSize: isSmallScreen ? 14 : 16,
                                          ),
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
                                                .requestFocus(_ageFocusNode);
                                          },
                                        ),
                                      ),
                                      SizedBox(
                                        height: isSmallScreen ? 6 : 8,
                                      ),
                                      _buildFieldContainer(
                                        child: TextFormField(
                                          controller: _ageController,
                                          focusNode: _ageFocusNode,
                                          keyboardType: TextInputType.number,
                                          textInputAction: TextInputAction.done,
                                          textAlign: isArabic
                                              ? TextAlign.right
                                              : TextAlign.left,
                                          decoration: _inputDecoration(
                                            label: tr('Age', 'العمر'),
                                          ),
                                          style: TextStyle(
                                            color: textColor,
                                            fontSize: isSmallScreen ? 14 : 16,
                                          ),
                                          validator: (value) {
                                            final text = (value ?? '').trim();

                                            if (text.isEmpty) {
                                              return tr(
                                                'Please enter age',
                                                'يرجى إدخال العمر',
                                              );
                                            }

                                            final int? age = int.tryParse(text);

                                            if (age == null) {
                                              return tr(
                                                'Please enter a valid age',
                                                'يرجى إدخال عمر صحيح',
                                              );
                                            }

                                            if (age <= 0) {
                                              return tr(
                                                'Age must be greater than 0',
                                                'يجب أن يكون العمر أكبر من صفر',
                                              );
                                            }

                                            return null;
                                          },
                                        ),
                                      ),
                                      SizedBox(
                                        height: isSmallScreen ? 6 : 8,
                                      ),
                                      _buildFieldContainer(
                                        child: DropdownButtonFormField<String>(
                                          value: _selectedDisability,
                                          isExpanded: true,
                                          decoration: _inputDecoration(
                                            label: tr(
                                              'Type of Disability',
                                              'نوع الإعاقة',
                                            ),
                                          ),
                                          items: _disabilityOptions
                                              .map(
                                                (option) =>
                                                    DropdownMenuItem<String>(
                                                  value: option,
                                                  child: Text(
                                                    _disabilityText(option),
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              )
                                              .toList(),
                                          onChanged: (value) {
                                            setState(() {
                                              _selectedDisability = value;
                                              if (_selectedDisability !=
                                                  'Multiple Disabilities') {
                                                _multipleDisabilitiesController
                                                    .clear();
                                              }
                                            });
                                          },
                                          icon: const Icon(
                                            Icons.keyboard_arrow_down_rounded,
                                          ),
                                        ),
                                      ),
                                      if (showMultipleDisabilitiesField) ...[
                                        SizedBox(
                                          height: isSmallScreen ? 6 : 8,
                                        ),
                                        _buildFieldContainer(
                                          height: isSmallScreen ? 72 : 78,
                                          child: TextFormField(
                                            controller:
                                                _multipleDisabilitiesController,
                                            focusNode:
                                                _multipleDisabilitiesFocusNode,
                                            maxLines: 2,
                                            textAlign: isArabic
                                                ? TextAlign.right
                                                : TextAlign.left,
                                            decoration: _inputDecoration(
                                              label: tr(
                                                'Write the disabilities',
                                                'اكتب الإعاقات',
                                              ),
                                            ),
                                            style: TextStyle(
                                              color: textColor,
                                              fontSize: isSmallScreen ? 14 : 16,
                                            ),
                                            validator: (value) {
                                              if (showMultipleDisabilitiesField &&
                                                  (value ?? '')
                                                      .trim()
                                                      .isEmpty) {
                                                return tr(
                                                  'Please enter the disabilities',
                                                  'يرجى إدخال الإعاقات',
                                                );
                                              }

                                              return null;
                                            },
                                          ),
                                        ),
                                      ],
                                      SizedBox(
                                        height: isSmallScreen ? 6 : 8,
                                      ),
                                      _buildFieldContainer(
                                        child: DropdownButtonFormField<String>(
                                          value: _selectedGender,
                                          isExpanded: true,
                                          decoration: _inputDecoration(
                                            label: tr('Gender', 'الجنس'),
                                          ),
                                          items: [
                                            DropdownMenuItem(
                                              value: 'Female',
                                              child: Text(
                                                tr('Female', 'أنثى'),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            DropdownMenuItem(
                                              value: 'Male',
                                              child: Text(
                                                tr('Male', 'ذكر'),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                          onChanged: (value) {
                                            setState(() {
                                              _selectedGender = value;
                                            });
                                          },
                                          icon: const Icon(
                                            Icons.keyboard_arrow_down_rounded,
                                          ),
                                        ),
                                      ),
                                      SizedBox(
                                        height: isSmallScreen ? 6 : 8,
                                      ),
                                      SizedBox(
                                        width: double.infinity,
                                        height: isSmallScreen ? 52 : 56,
                                        child: ElevatedButton(
                                          onPressed: _selectLocation,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: buttonFieldColor,
                                            foregroundColor: textColor,
                                            elevation: 0,
                                            alignment: isArabic
                                                ? Alignment.centerRight
                                                : Alignment.centerLeft,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              const Icon(Icons.place, size: 18),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  _locationController
                                                          .text.isEmpty
                                                      ? tr(
                                                          'Select Location',
                                                          'اختيار الموقع',
                                                        )
                                                      : _locationController
                                                          .text,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  maxLines: 1,
                                                  textAlign: isArabic
                                                      ? TextAlign.right
                                                      : TextAlign.left,
                                                  style: TextStyle(
                                                    fontSize:
                                                        isSmallScreen ? 14 : 16,
                                                    color: textColor,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      SizedBox(
                                        height: isSmallScreen ? 6 : 8,
                                      ),
                                      SizedBox(
                                        width: double.infinity,
                                        height: isSmallScreen ? 52 : 56,
                                        child: ElevatedButton(
                                          onPressed:
                                              _isLoading ? null : _handleSignUp,
                                          style: _mainButtonStyle(),
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
                                                  tr(
                                                    'Patient Sign Up',
                                                    'تسجيل المريض',
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize:
                                                        isSmallScreen ? 14 : 16,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      Wrap(
                                        alignment: WrapAlignment.center,
                                        spacing: 8,
                                        runSpacing: 4,
                                        children: [
                                          Text(
                                            tr(
                                              'Have an account?',
                                              'لديك حساب؟',
                                            ),
                                            style: TextStyle(
                                              fontSize: isSmallScreen ? 13 : 14,
                                              fontWeight: FontWeight.bold,
                                              color: textColor,
                                            ),
                                          ),
                                          TextButton(
                                            style: _linkButtonStyle(),
                                            onPressed: () {
                                              Navigator.pushNamed(
                                                  context, '/login');
                                            },
                                            child: Text(
                                              tr('Login', 'تسجيل الدخول'),
                                              style: TextStyle(
                                                fontSize:
                                                    isSmallScreen ? 13 : 14,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      _languageButton(),
                      _accessibilityVoiceButton(),
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
