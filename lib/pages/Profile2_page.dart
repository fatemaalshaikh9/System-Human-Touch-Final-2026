import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'Dashboard_page.dart';
import 'Login_page.dart';
import 'Profile_page.dart';
import 'Settings_page.dart';
import 'voice_accessibility_service.dart';
import 'package:humantouch/pages/app_settings_store.dart';

class Profile2Page extends StatefulWidget {
  const Profile2Page({super.key});

  @override
  State<Profile2Page> createState() => _Profile2PageState();
}

class _Profile2PageState extends State<Profile2Page> {
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _manualPatientCodeController;
  late TextEditingController _patientDisabilityController;
  late TextEditingController _volunteerSpecialtyController;
  late TextEditingController _volunteerSkillController;
  late TextEditingController _volunteerBioController;
  late TextEditingController _volunteerWorkController;

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  bool _isScanning = false;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isLinkingPatient = false;
  bool _isSpeaking = false;

  String _userRole = 'patient';
  String _profileImageBase64 = '';
  String _patientLinkCode = '';
  String _linkedPatientCode = '';
  String _linkedCompanionUid = '';
  String _linkedCompanionName = '';
  String _linkedCompanionPhone = '';
  String _linkedCompanionEmail = '';
  String _selectedVolunteerType = 'Medical';

  final List<String> _volunteerTypes = [
    'Medical',
    'Shopping',
    'Transportation',
    'Other',
  ];

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
      Theme.of(context).textTheme.bodyLarge?.color ?? const Color(0xFF14181B);
  Color get subTextColor => const Color(0xFF57636C);
  Color get borderColor => Theme.of(context).dividerColor;

  String tr(String en, String ar) => isArabic ? ar : en;

  bool get isSmallScreen {
    final width = MediaQuery.maybeOf(context)?.size.width ?? 400;
    return width < 380;
  }

  bool get _isVolunteerProfileRequired => _userRole == 'volunteer';

  bool get _isVolunteerProfileComplete {
    if (!_isVolunteerProfileRequired) return true;
    return _volunteerSpecialtyController.text.trim().isNotEmpty &&
        _volunteerSkillController.text.trim().isNotEmpty &&
        _volunteerBioController.text.trim().isNotEmpty &&
        _volunteerWorkController.text.trim().isNotEmpty &&
        _selectedVolunteerType.trim().isNotEmpty;
  }

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _phoneController = TextEditingController();
    _emailController = TextEditingController();
    _manualPatientCodeController = TextEditingController();
    _patientDisabilityController = TextEditingController();
    _volunteerSpecialtyController = TextEditingController();
    _volunteerSkillController = TextEditingController();
    _volunteerBioController = TextEditingController();
    _volunteerWorkController = TextEditingController();
    AppSettingsStore.instance.addListener(_onLanguageChanged);
    _loadProfileFromFirebase();
  }

  void _onLanguageChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    AppSettingsStore.instance.removeListener(_onLanguageChanged);
    VoiceAccessibilityService.instance.stopAll();
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _manualPatientCodeController.dispose();
    _patientDisabilityController.dispose();
    _volunteerSpecialtyController.dispose();
    _volunteerSkillController.dispose();
    _volunteerBioController.dispose();
    _volunteerWorkController.dispose();
    super.dispose();
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

  InputDecoration _profileInputDecoration({
    required String label,
    String? hintText,
    IconData? prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hintText,
      labelStyle: TextStyle(color: subTextColor),
      hintStyle: TextStyle(color: subTextColor),
      prefixIcon:
          prefixIcon != null ? Icon(prefixIcon, color: subTextColor) : null,
      suffixIcon: suffixIcon,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF87CEEB), width: 1.5),
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: borderColor),
      ),
    );
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
            backgroundColor: cardColor,
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
          textDirection: isArabic ? ui.TextDirection.rtl : ui.TextDirection.ltr,
          child: AlertDialog(
            backgroundColor: cardColor,
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
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(cancelText, style: TextStyle(color: subTextColor)),
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

  Future<void> _showSaveProfileChangesPopup() async {
    await _showInfoPopup(
      title: tr('Profile Saved', 'تم حفظ الملف'),
      message: tr(
        'Your profile changes have been saved successfully.',
        'تم حفظ تغييرات الملف الشخصي بنجاح.',
      ),
      icon: Icons.check_circle_rounded,
      iconColor: Colors.green,
    );
  }

  Future<void> _showImageUploadSuccessPopup() async {
    await _showInfoPopup(
      title: tr('Image Uploaded', 'تم رفع الصورة'),
      message: tr(
        'Your profile image has been uploaded successfully. Press Save Changes to keep it.',
        'تم رفع صورة الملف الشخصي بنجاح. اضغط حفظ التغييرات لتثبيتها.',
      ),
      icon: Icons.image_rounded,
      iconColor: const Color(0xFF87CEEB),
    );
  }

  Future<void> _showPasswordChangedPopup() async {
    await _showInfoPopup(
      title: tr('Password Changed', 'تم تغيير كلمة المرور'),
      message: tr(
        'Your password has been changed successfully. You can use the new password next time you log in.',
        'تم تغيير كلمة المرور بنجاح. يمكنك استخدام كلمة المرور الجديدة عند تسجيل الدخول مرة أخرى.',
      ),
      icon: Icons.check_circle_rounded,
      iconColor: Colors.green,
    );
  }

  String _requiredVolunteerMessage() {
    return tr(
      'Please complete all volunteer information first. These details are required and will be shown to patients when they book or request your help.',
      'يرجى إكمال جميع معلومات المتطوع أولاً. هذه البيانات إجبارية وستظهر للمريض عند الحجز أو طلب المساعدة.',
    );
  }

  Future<void> _showVolunteerRequiredPopup() async {
    await _showInfoPopup(
      title: tr('Complete Volunteer Information', 'أكملي معلومات المتطوع'),
      message: _requiredVolunteerMessage(),
      icon: Icons.volunteer_activism_rounded,
      iconColor: const Color(0xFF87CEEB),
    );
  }

  bool _validateVolunteerInfoBeforeSave() {
    if (!_isVolunteerProfileRequired || _isVolunteerProfileComplete)
      return true;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_requiredVolunteerMessage())),
    );
    _showVolunteerRequiredPopup();
    return false;
  }

  String _generatePatientCode() {
    final random = Random();
    final randomNumber = 100000 + random.nextInt(900000);
    return 'HT-$randomNumber';
  }

  String volunteerTypeText(String type) {
    switch (type) {
      case 'Medical':
        return tr('Medical', 'طبي');
      case 'Shopping':
        return tr('Shopping', 'تسوق');
      case 'Transportation':
        return tr('Transportation', 'مواصلات');
      case 'Other':
        return tr('Other', 'أخرى');
      default:
        return type;
    }
  }

  Future<void> _loadProfileFromFirebase() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() => _isLoading = false);
        return;
      }

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final data = doc.data() ?? {};

      if (!mounted) return;
      setState(() {
        _nameController.text =
            (data['name'] ?? data['fullName'] ?? data['username'] ?? '')
                .toString();
        _phoneController.text =
            (data['phone'] ?? data['phoneNumber'] ?? '').toString();
        _emailController.text = (data['email'] ?? user.email ?? '').toString();
        _userRole = (data['role'] ?? 'patient').toString();
        _profileImageBase64 =
            (data['profileImageBase64'] ?? data['image'] ?? '').toString();
        _patientLinkCode = (data['patientLinkCode'] ?? '').toString();
        _linkedPatientCode = (data['linkedPatientCode'] ?? '').toString();
        _linkedCompanionUid = (data['companionUid'] ?? '').toString();
        _linkedCompanionName = (data['companionName'] ?? '').toString();
        _linkedCompanionPhone =
            (data['companionPhone'] ?? data['emergencyContactPhone'] ?? '')
                .toString();
        _linkedCompanionEmail = (data['companionEmail'] ?? '').toString();
        _patientDisabilityController.text = (data['disabilityType'] ??
                data['disability'] ??
                data['typeOfDisability'] ??
                data['patientDisability'] ??
                '')
            .toString();
        _manualPatientCodeController.text = _linkedPatientCode;
        _volunteerSpecialtyController.text =
            (data['volunteerSpecialty'] ?? '').toString();
        _volunteerSkillController.text =
            (data['volunteerSkill'] ?? '').toString();
        _volunteerBioController.text = (data['volunteerBio'] ?? '').toString();
        _volunteerWorkController.text =
            (data['volunteerWork'] ?? '').toString();
        _selectedVolunteerType =
            (data['volunteerType'] ?? 'Medical').toString();
        if (!_volunteerTypes.contains(_selectedVolunteerType)) {
          _selectedVolunteerType = 'Medical';
        }
        _isLoading = false;
      });

      if (_userRole == 'patient') {
        await _refreshPatientCode();
        if (mounted && isAccessibilityVoiceEnabled) {
          await _startVoiceAccessibilityAssistant();
        }
      }

      if (_userRole == 'volunteer' && !_isVolunteerProfileComplete) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _showVolunteerRequiredPopup();
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(tr(
                'Error loading profile: $e', 'حدث خطأ أثناء تحميل الملف: $e'))),
      );
    }
  }

  Future<void> _refreshPatientCode({bool forceNew = false}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (!forceNew && _patientLinkCode.trim().isNotEmpty) return;

    if (user == null) {
      if (mounted && (forceNew || _patientLinkCode.trim().isEmpty)) {
        setState(() => _patientLinkCode = _generatePatientCode());
      }
      return;
    }

    try {
      final userRef =
          FirebaseFirestore.instance.collection('users').doc(user.uid);
      final currentDoc = await userRef.get();
      final currentCode =
          (currentDoc.data()?['patientLinkCode'] ?? '').toString();
      if (!forceNew && currentCode.trim().isNotEmpty) {
        if (mounted) setState(() => _patientLinkCode = currentCode);
        return;
      }

      final newCode = _generatePatientCode();
      if (mounted) setState(() => _patientLinkCode = newCode);
      await userRef.set({
        'patientLinkCode': newCode,
        'patientLinkCodeUpdatedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)).timeout(const Duration(seconds: 5));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(tr(
                'Code generated locally, but Firebase did not save it.',
                'تم توليد الكود محلياً، لكن لم يتم حفظه في Firebase.'))),
      );
    }
  }

  Future<void> _linkPatientByCode(String code) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(tr('Please login first', 'يرجى تسجيل الدخول أولاً'))),
      );
      return;
    }

    final cleanCode = code.trim().toUpperCase();
    if (cleanCode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text(tr('Please enter patient code', 'يرجى إدخال كود المريض'))),
      );
      return;
    }

    setState(() => _isLinkingPatient = true);
    try {
      final patientQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('patientLinkCode', isEqualTo: cleanCode)
          .where('role', isEqualTo: 'patient')
          .limit(1)
          .get();

      if (patientQuery.docs.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(tr('Invalid patient code', 'كود المريض غير صحيح'))),
        );
        return;
      }

      final companionDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final companionData = companionDoc.data() ?? {};
      final patientDoc = patientQuery.docs.first;
      final patientData = patientDoc.data();

      final companionName = (companionData['name'] ??
              companionData['fullName'] ??
              companionData['username'] ??
              user.displayName ??
              'Companion')
          .toString();
      final companionPhone =
          (companionData['phone'] ?? companionData['phoneNumber'] ?? '')
              .toString();
      final companionEmail =
          (companionData['email'] ?? user.email ?? '').toString();
      final patientName = (patientData['name'] ??
              patientData['fullName'] ??
              patientData['username'] ??
              'Patient')
          .toString();
      final patientDisability = (patientData['disabilityType'] ??
              patientData['disability'] ??
              patientData['typeOfDisability'] ??
              patientData['patientDisability'] ??
              '')
          .toString();

      setState(() {
        _linkedPatientCode = cleanCode;
        _manualPatientCodeController.text = cleanCode;
      });

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'linkedPatientCode': cleanCode,
        'patientUid': patientDoc.id,
        'linkedPatientName': patientName,
        'linkedPatientDisability': patientDisability,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await FirebaseFirestore.instance
          .collection('users')
          .doc(patientDoc.id)
          .set({
        'companionUid': user.uid,
        'companionName': companionName,
        'companionPhone': companionPhone,
        'companionEmail': companionEmail,
        'emergencyContactName': companionName,
        'emergencyContactPhone': companionPhone,
        'emergencyContactEmail': companionEmail,
        'emergencyContactSource': 'linked_companion',
        'linkedCompanionUpdatedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(tr('Patient linked successfully: $cleanCode',
                'تم ربط المريض بنجاح: $cleanCode'))),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(tr(
                'Error linking patient: $e', 'حدث خطأ أثناء ربط المريض: $e'))),
      );
    } finally {
      if (mounted) setState(() => _isLinkingPatient = false);
    }
  }

  Future<void> _showChangePasswordDialog() async {
    await VoiceAccessibilityService.instance.stopAll();

    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool obscureCurrent = true;
    bool obscureNew = true;
    bool obscureConfirm = true;
    bool isChanging = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Directionality(
              textDirection:
                  isArabic ? ui.TextDirection.rtl : ui.TextDirection.ltr,
              child: AlertDialog(
                backgroundColor: cardColor,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24)),
                title: Column(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor:
                          const Color(0xFF87CEEB).withOpacity(0.15),
                      child: const Icon(Icons.lock_reset_rounded,
                          color: Color(0xFF87CEEB), size: 32),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      tr('Change Password', 'تغيير كلمة المرور'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: textColor,
                          fontSize: 20,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _passwordDialogField(
                        controller: currentPasswordController,
                        label: tr('Current Password', 'كلمة المرور الحالية'),
                        obscure: obscureCurrent,
                        onToggle: () => setDialogState(
                            () => obscureCurrent = !obscureCurrent),
                      ),
                      const SizedBox(height: 12),
                      _passwordDialogField(
                        controller: newPasswordController,
                        label: tr('New Password', 'كلمة المرور الجديدة'),
                        obscure: obscureNew,
                        onToggle: () =>
                            setDialogState(() => obscureNew = !obscureNew),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: isArabic
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Text(
                          tr(
                            'Must be at least 8 characters and include uppercase, lowercase, number, and symbol.',
                            'يجب أن تكون 8 أحرف على الأقل وتحتوي على حرف كبير وصغير ورقم ورمز.',
                          ),
                          textAlign:
                              isArabic ? TextAlign.right : TextAlign.left,
                          style: TextStyle(
                              color: subTextColor, fontSize: 12, height: 1.4),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _passwordDialogField(
                        controller: confirmPasswordController,
                        label: tr('Confirm New Password',
                            'تأكيد كلمة المرور الجديدة'),
                        obscure: obscureConfirm,
                        onToggle: () => setDialogState(
                            () => obscureConfirm = !obscureConfirm),
                      ),
                    ],
                  ),
                ),
                actionsAlignment: MainAxisAlignment.center,
                actions: [
                  TextButton(
                    onPressed:
                        isChanging ? null : () => Navigator.pop(dialogContext),
                    child: Text(tr('Cancel', 'إلغاء'),
                        style: TextStyle(color: subTextColor)),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF87CEEB),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: isChanging
                        ? null
                        : () async {
                            final currentPassword =
                                currentPasswordController.text.trim();
                            final newPassword =
                                newPasswordController.text.trim();
                            final confirmPassword =
                                confirmPasswordController.text.trim();
                            final validationMessage = _validateNewPassword(
                              currentPassword: currentPassword,
                              newPassword: newPassword,
                              confirmPassword: confirmPassword,
                            );
                            if (validationMessage != null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(validationMessage)));
                              return;
                            }

                            setDialogState(() => isChanging = true);
                            final errorMessage =
                                await _changePasswordInFirebase(
                              currentPassword: currentPassword,
                              newPassword: newPassword,
                            );
                            if (!mounted) return;
                            setDialogState(() => isChanging = false);

                            if (errorMessage != null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(errorMessage)));
                              return;
                            }

                            Navigator.of(dialogContext).pop();
                            await _goToLoginAfterPasswordChange();
                          },
                    child: isChanging
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : Text(tr('Change', 'تغيير')),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    currentPasswordController.dispose();
    newPasswordController.dispose();
    confirmPasswordController.dispose();
  }

  Widget _passwordDialogField({
    required TextEditingController controller,
    required String label,
    required bool obscure,
    required VoidCallback onToggle,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      textAlign: isArabic ? TextAlign.right : TextAlign.left,
      style: TextStyle(color: textColor),
      decoration: _profileInputDecoration(
        label: label,
        prefixIcon: Icons.lock_outline,
        suffixIcon: IconButton(
          onPressed: onToggle,
          icon: Icon(
              obscure
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              color: subTextColor),
        ),
      ),
    );
  }

  String? _validateNewPassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) {
    if (currentPassword.isEmpty) {
      return tr('Please enter your current password.',
          'يرجى إدخال كلمة المرور الحالية.');
    }
    if (newPassword.isEmpty) {
      return tr(
          'Please enter a new password.', 'يرجى إدخال كلمة المرور الجديدة.');
    }
    if (newPassword.length < 8 ||
        !RegExp(r'[a-z]').hasMatch(newPassword) ||
        !RegExp(r'[A-Z]').hasMatch(newPassword) ||
        !RegExp(r'[0-9]').hasMatch(newPassword) ||
        !RegExp(r'[!@#\$%^&*(),.?":{}|<>_+\-=\[\];/`~]')
            .hasMatch(newPassword)) {
      return tr(
        'Password must be at least 8 characters and include uppercase, lowercase, number, and symbol.',
        'كلمة المرور يجب أن تكون 8 أحرف على الأقل وتحتوي على حرف كبير وصغير ورقم ورمز.',
      );
    }
    if (newPassword != confirmPassword) {
      return tr('New password and confirmation do not match.',
          'كلمة المرور الجديدة وتأكيدها غير متطابقين.');
    }
    if (currentPassword == newPassword) {
      return tr('New password must be different from the current password.',
          'كلمة المرور الجديدة يجب أن تختلف عن كلمة المرور الحالية.');
    }
    return null;
  }

  Future<String?> _changePasswordInFirebase({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || user.email == null || user.email!.trim().isEmpty) {
        return tr('Please log in again before changing your password.',
            'يرجى تسجيل الدخول مرة أخرى قبل تغيير كلمة المرور.');
      }

      final credential = EmailAuthProvider.credential(
        email: user.email!.trim(),
        password: currentPassword,
      );

      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(newPassword);
      await _updateSavedPasswordIfNeeded(newPassword);
      return null;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password' ||
          e.code == 'invalid-credential' ||
          e.code == 'user-mismatch') {
        return tr(
            'Current password is incorrect.', 'كلمة المرور الحالية غير صحيحة.');
      }
      if (e.code == 'weak-password') {
        return tr(
            'The new password is too weak.', 'كلمة المرور الجديدة ضعيفة.');
      }
      if (e.code == 'requires-recent-login') {
        return tr(
            'Please log out and log in again before changing your password.',
            'يرجى تسجيل الخروج ثم الدخول مرة أخرى قبل تغيير كلمة المرور.');
      }
      if (e.code == 'network-request-failed') {
        return tr('Please check your internet connection and try again.',
            'يرجى التحقق من اتصال الإنترنت والمحاولة مرة أخرى.');
      }
      return e.message ??
          tr('Could not change password. Please try again.',
              'تعذر تغيير كلمة المرور. يرجى المحاولة مرة أخرى.');
    } catch (_) {
      return tr('Could not change password. Please try again.',
          'تعذر تغيير كلمة المرور. يرجى المحاولة مرة أخرى.');
    }
  }

  Future<void> _goToLoginAfterPasswordChange() async {
    await VoiceAccessibilityService.instance.stopAll();
    await FirebaseAuth.instance.signOut();

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()),
      (route) => false,
    );
  }

  Future<void> _updateSavedPasswordIfNeeded(String newPassword) async {
    final prefs = await SharedPreferences.getInstance();
    final rememberMe = prefs.getBool('remember_me') ?? false;
    if (!rememberMe) return;
    await _secureStorage.write(key: 'saved_password', value: newPassword);
  }

  Future<void> _pickProfileImage(ImageSource source) async {
    await VoiceAccessibilityService.instance.stopAll();
    final picker = ImagePicker();
    final pickedImage =
        await picker.pickImage(source: source, imageQuality: 60);
    if (pickedImage == null) return;
    final Uint8List imageBytes = await pickedImage.readAsBytes();
    setState(() => _profileImageBase64 = base64Encode(imageBytes));
    await _showImageUploadSuccessPopup();
  }

  Future<void> _saveProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(tr('Please login first', 'يرجى تسجيل الدخول أولاً'))),
      );
      return;
    }
    if (!_validateVolunteerInfoBeforeSave()) return;

    setState(() => _isSaving = true);
    try {
      final updatedData = <String, dynamic>{
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'email': _emailController.text.trim(),
        'profileImageBase64': _profileImageBase64,
        'role': _userRole,
        'patientLinkCode': _patientLinkCode,
        'linkedPatientCode': _linkedPatientCode,
        'disabilityType': _patientDisabilityController.text.trim(),
        'patientDisability': _patientDisabilityController.text.trim(),
        'companionUid': _linkedCompanionUid,
        'companionName': _linkedCompanionName,
        'companionPhone': _linkedCompanionPhone,
        'companionEmail': _linkedCompanionEmail,
        'emergencyContactName': _linkedCompanionName,
        'emergencyContactPhone': _linkedCompanionPhone,
        'emergencyContactEmail': _linkedCompanionEmail,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (_userRole == 'volunteer') {
        updatedData.addAll({
          'volunteerSpecialty': _volunteerSpecialtyController.text.trim(),
          'volunteerSkill': _volunteerSkillController.text.trim(),
          'volunteerBio': _volunteerBioController.text.trim(),
          'volunteerWork': _volunteerWorkController.text.trim(),
          'volunteerType': _selectedVolunteerType,
          'isVolunteerProfileComplete': true,
          'volunteerProfileCompletedAt': FieldValue.serverTimestamp(),
          'availableForBooking': true,
          'isOnline': true,
        });
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set(updatedData, SetOptions(merge: true));

      if (_emailController.text.trim().isNotEmpty &&
          _emailController.text.trim() != user.email) {
        await user.verifyBeforeUpdateEmail(_emailController.text.trim());
      }

      if (!mounted) return;
      await _showSaveProfileChangesPopup();
    } on FirebaseAuthException catch (e) {
      var message = e.message ?? tr('Authentication error', 'خطأ في المصادقة');
      if (e.code == 'requires-recent-login') {
        message = tr('Please log out and log in again before changing email.',
            'يرجى تسجيل الخروج ثم الدخول مرة أخرى قبل تغيير البريد الإلكتروني.');
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                tr('Error saving profile: $e', 'حدث خطأ أثناء حفظ الملف: $e'))),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _confirmDeleteAccount() async {
    await VoiceAccessibilityService.instance.stopAll();
    final confirm = await _showConfirmPopup(
      title: tr('Delete Account', 'حذف الحساب'),
      message: tr(
        'Are you sure you want to delete your account? This action cannot be undone.',
        'هل أنت متأكد أنك تريد حذف حسابك؟ لا يمكن التراجع عن هذا الإجراء.',
      ),
      icon: Icons.delete_forever_rounded,
      iconColor: Colors.red,
      confirmText: tr('Delete', 'حذف'),
      cancelText: tr('Cancel', 'إلغاء'),
    );
    if (confirm) await _deleteAccount();
  }

  Future<void> _deleteAccount() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .delete();
      await user.delete();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
        (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      var message =
          e.message ?? tr('Could not delete account', 'تعذر حذف الحساب');
      if (e.code == 'requires-recent-login') {
        message = tr('Please log out and log in again before deleting account.',
            'يرجى تسجيل الخروج ثم الدخول مرة أخرى قبل حذف الحساب.');
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _logout() async {
    await VoiceAccessibilityService.instance.stopAll();
    final confirm = await _showConfirmPopup(
      title: tr('Log Out', 'تسجيل الخروج'),
      message: tr('Are you sure you want to log out?',
          'هل أنت متأكد أنك تريد تسجيل الخروج؟'),
      icon: Icons.logout_rounded,
      iconColor: Colors.orange,
      confirmText: tr('Log Out', 'تسجيل الخروج'),
      cancelText: tr('Cancel', 'إلغاء'),
    );
    if (!confirm) return;
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()),
      (route) => false,
    );
  }

  Future<void> _openScanner() async {
    await VoiceAccessibilityService.instance.stopAll();
    setState(() => _isScanning = true);
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _ScanPatientQrPage(
          onScanned: (code) async => _linkPatientByCode(code),
        ),
      ),
    );
    if (!mounted) return;
    setState(() => _isScanning = false);
  }

  void _goToPage(int index) {
    VoiceAccessibilityService.instance.stopAll();
    if (_isVolunteerProfileRequired &&
        !_isVolunteerProfileComplete &&
        index != 1) {
      _showVolunteerRequiredPopup();
      return;
    }
    if (index == 0) {
      if (_userRole == 'companion') {
        Navigator.pushReplacementNamed(context, '/companionDashboard');
      } else {
        Navigator.pushReplacementNamed(context, '/dashboard');
      }
    } else if (index == 1) {
      Navigator.pushReplacementNamed(context, '/profile');
    } else if (index == 2) {
      Navigator.pushReplacementNamed(context, '/settings');
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
                  fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
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
              color: backgroundColor,
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
        return Image.memory(base64Decode(_profileImageBase64),
            fit: BoxFit.cover);
      } catch (_) {}
    }
    return Icon(Icons.person,
        size: isSmallScreen ? 34 : 40, color: Colors.white);
  }

  Widget _buildTopProfileInfo() {
    return Container(
      width: double.infinity,
      color: backgroundColor,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
        child: Wrap(
          spacing: 16,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            InkWell(
              onTap: () => _pickProfileImage(ImageSource.gallery),
              child: Stack(
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
                        child: _profileImageWidget()),
                  ),
                  PositionedDirectional(
                    bottom: 0,
                    end: 0,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: borderColor),
                      ),
                      child: const Icon(Icons.camera_alt,
                          size: 16, color: Color(0xFF87CEEB)),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: MediaQuery.of(context).size.width -
                  (isSmallScreen ? 130 : 145),
              child: Column(
                crossAxisAlignment: isArabic
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  Text(
                    _nameController.text.isEmpty
                        ? tr('No Name', 'لا يوجد اسم')
                        : _nameController.text,
                    textAlign: isArabic ? TextAlign.right : TextAlign.left,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: textColor,
                        fontSize: isSmallScreen ? 20 : 24,
                        fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _emailController.text.isEmpty
                        ? tr('No Email', 'لا يوجد بريد إلكتروني')
                        : _emailController.text,
                    textAlign: isArabic ? TextAlign.right : TextAlign.left,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style:
                        const TextStyle(color: Color(0xFF87CEEB), fontSize: 14),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitleCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
          boxShadow: _shadow(),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(15, 12, 15, 12),
          child: Align(
            alignment: isArabic ? Alignment.centerRight : Alignment.centerLeft,
            child: Text(
              tr('Edit Profile', 'تعديل الملف الشخصي'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w600, color: textColor),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required IconData icon,
    required String label,
    required TextEditingController controller,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
          boxShadow: _shadow(),
        ),
        child: TextField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          textInputAction:
              maxLines == 1 ? TextInputAction.next : TextInputAction.newline,
          textAlign: isArabic ? TextAlign.right : TextAlign.left,
          onChanged: (_) => setState(() {}),
          style: TextStyle(color: textColor),
          cursorColor: textColor,
          decoration: InputDecoration(
            icon: Icon(icon, color: subTextColor),
            border: InputBorder.none,
            labelText: label,
            labelStyle: TextStyle(color: subTextColor),
          ),
        ),
      ),
    );
  }

  Widget _buildUploadImageButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          SizedBox(
            width: isSmallScreen
                ? double.infinity
                : (MediaQuery.of(context).size.width - 50) / 2,
            child: ElevatedButton.icon(
              onPressed: () => _pickProfileImage(ImageSource.gallery),
              icon: const Icon(Icons.photo_library),
              label: Text(tr('Gallery', 'المعرض'),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF87CEEB),
                foregroundColor: Colors.white,
                elevation: 1,
                minimumSize: const Size(0, 48),
              ),
            ),
          ),
          SizedBox(
            width: isSmallScreen
                ? double.infinity
                : (MediaQuery.of(context).size.width - 50) / 2,
            child: ElevatedButton.icon(
              onPressed: () => _pickProfileImage(ImageSource.camera),
              icon: const Icon(Icons.camera_alt),
              label: Text(tr('Camera', 'الكاميرا'),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF87CEEB),
                foregroundColor: Colors.white,
                elevation: 1,
                minimumSize: const Size(0, 48),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String text,
    required VoidCallback onPressed,
    IconData? icon,
    Color? backgroundColor,
    Color? foregroundColor,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: SizedBox(
        width: double.infinity,
        height: isSmallScreen ? 48 : 44,
        child: ElevatedButton.icon(
          onPressed: onPressed,
          icon: icon != null ? Icon(icon) : const SizedBox.shrink(),
          label: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis),
          style: ElevatedButton.styleFrom(
            backgroundColor: backgroundColor ?? cardColor,
            foregroundColor: foregroundColor ?? textColor,
            elevation: 1,
            minimumSize: const Size(0, 44),
          ),
        ),
      ),
    );
  }

  Widget _buildVolunteerInfoSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
          boxShadow: _shadow(),
        ),
        child: Column(
          crossAxisAlignment:
              isArabic ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    tr('Volunteer Information', 'معلومات المتطوع'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: textColor),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _isVolunteerProfileComplete
                        ? Colors.green.withOpacity(0.12)
                        : Colors.orange.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Text(
                    _isVolunteerProfileComplete
                        ? tr('Complete', 'مكتمل')
                        : tr('Required', 'إجباري'),
                    style: TextStyle(
                      color: _isVolunteerProfileComplete
                          ? Colors.green
                          : Colors.orange,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _volunteerTextField(
                _volunteerSpecialtyController,
                tr('Specialty *', 'التخصص *'),
                tr('Example: Nursing, First Aid, Physical Therapy',
                    'مثال: تمريض، إسعافات أولية، علاج طبيعي'),
                Icons.work_outline),
            const SizedBox(height: 12),
            _volunteerTextField(
                _volunteerSkillController,
                tr('Skill *', 'المهارة *'),
                tr('Example: Communication, Driving, Patient Care',
                    'مثال: التواصل، القيادة، رعاية المرضى'),
                Icons.star_outline),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _selectedVolunteerType,
              isExpanded: true,
              dropdownColor: cardColor,
              style: TextStyle(color: textColor),
              decoration: _profileInputDecoration(
                  label: tr('Volunteer Type *', 'نوع التطوع *'),
                  prefixIcon: Icons.volunteer_activism_outlined),
              items: _volunteerTypes.map((type) {
                return DropdownMenuItem(
                  value: type,
                  child: Text(volunteerTypeText(type),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                );
              }).toList(),
              onChanged: (value) {
                if (value == null) return;
                setState(() => _selectedVolunteerType = value);
              },
            ),
            const SizedBox(height: 12),
            _volunteerTextField(
                _volunteerBioController,
                tr('About Me *', 'نبذة عني *'),
                tr('Write a short bio about yourself',
                    'اكتب نبذة قصيرة عن نفسك'),
                Icons.info_outline,
                maxLines: 3),
            const SizedBox(height: 12),
            _volunteerTextField(
                _volunteerWorkController,
                tr('What do you volunteer in? *', 'في ماذا تتطوع؟ *'),
                tr('Example: Helping patients with shopping or transport',
                    'مثال: مساعدة المرضى في التسوق أو المواصلات'),
                Icons.favorite_outline,
                maxLines: 3),
          ],
        ),
      ),
    );
  }

  Widget _volunteerTextField(TextEditingController controller, String label,
      String hint, IconData icon,
      {int maxLines = 1}) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      textAlign: isArabic ? TextAlign.right : TextAlign.left,
      textInputAction:
          maxLines == 1 ? TextInputAction.next : TextInputAction.newline,
      onChanged: (_) => setState(() {}),
      style: TextStyle(color: textColor),
      cursorColor: textColor,
      decoration: _profileInputDecoration(
          label: label, hintText: hint, prefixIcon: icon),
    );
  }

  Widget _buildPatientMedicalInfoSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
          boxShadow: _shadow(),
        ),
        child: Column(
          crossAxisAlignment:
              isArabic ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(tr('Patient Information', 'معلومات المريض'),
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: textColor)),
            const SizedBox(height: 12),
            TextField(
              controller: _patientDisabilityController,
              textAlign: isArabic ? TextAlign.right : TextAlign.left,
              textInputAction: TextInputAction.next,
              onChanged: (_) => setState(() {}),
              style: TextStyle(color: textColor),
              cursorColor: textColor,
              decoration: _profileInputDecoration(
                label: tr('Type of Disability', 'نوع الإعاقة'),
                hintText: tr('Example: Visual, Hearing, Physical, Cognitive',
                    'مثال: بصرية، سمعية، حركية، ذهنية'),
                prefixIcon: Icons.accessible_forward_rounded,
              ),
            ),
            if (_linkedCompanionPhone.isNotEmpty ||
                _linkedCompanionName.isNotEmpty) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF87CEEB).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF87CEEB)),
                ),
                child: Column(
                  crossAxisAlignment: isArabic
                      ? CrossAxisAlignment.end
                      : CrossAxisAlignment.start,
                  children: [
                    Text(
                        tr('Linked Companion / Emergency Contact',
                            'المرافق المرتبط / جهة الطوارئ'),
                        style: TextStyle(
                            color: textColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 14)),
                    const SizedBox(height: 8),
                    if (_linkedCompanionName.isNotEmpty)
                      Text('${tr('Name', 'الاسم')}: $_linkedCompanionName',
                          style: TextStyle(color: textColor, fontSize: 13)),
                    if (_linkedCompanionPhone.isNotEmpty)
                      Text('${tr('Phone', 'الهاتف')}: $_linkedCompanionPhone',
                          style: TextStyle(color: textColor, fontSize: 13)),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPatientQrSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
          boxShadow: _shadow(),
        ),
        child: Column(
          children: [
            Align(
              alignment:
                  isArabic ? Alignment.centerRight : Alignment.centerLeft,
              child: Text(tr('Patient QR Code', 'رمز QR للمريض'),
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: textColor)),
            ),
            const SizedBox(height: 14),
            if (_patientLinkCode.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12)),
                child: QrImageView(
                    data: _patientLinkCode,
                    version: QrVersions.auto,
                    size: isSmallScreen ? 160 : 200),
              )
            else
              const CircularProgressIndicator(color: Color(0xFF87CEEB)),
            const SizedBox(height: 12),
            SelectableText(
              _patientLinkCode.isEmpty
                  ? tr('Code is loading...', 'الكود قيد التحميل...')
                  : _patientLinkCode,
              style: TextStyle(
                  fontSize: isSmallScreen ? 18 : 20,
                  color: textColor,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              tr('Your companion can scan or manually enter this code.',
                  'يمكن للمرافق مسح الرمز أو كتابة الكود يدويًا.'),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: subTextColor),
            ),
            const SizedBox(height: 14),
            ElevatedButton.icon(
              onPressed: () => _refreshPatientCode(forceNew: true),
              icon: const Icon(Icons.refresh),
              label: Text(tr('Generate New Code', 'توليد كود جديد')),
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF87CEEB),
                  foregroundColor: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompanionScanSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
          boxShadow: _shadow(),
        ),
        child: Column(
          children: [
            Align(
              alignment:
                  isArabic ? Alignment.centerRight : Alignment.centerLeft,
              child: Text(tr('Patient Linking', 'ربط المريض'),
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: textColor)),
            ),
            const SizedBox(height: 14),
            _buildActionButton(
              text: _isScanning
                  ? tr('Opening Camera...', 'جاري فتح الكاميرا...')
                  : tr('Scan Patient QR', 'مسح رمز QR للمريض'),
              icon: Icons.qr_code_scanner,
              onPressed: _isScanning ? () {} : _openScanner,
              backgroundColor: const Color(0xFF87CEEB),
              foregroundColor: Colors.white,
            ),
            const SizedBox(height: 16),
            Text(
                tr('Or enter patient code manually',
                    'أو أدخل كود المريض يدويًا'),
                style: TextStyle(fontSize: 14, color: subTextColor)),
            const SizedBox(height: 12),
            TextField(
              controller: _manualPatientCodeController,
              textAlign: isArabic ? TextAlign.right : TextAlign.left,
              textCapitalization: TextCapitalization.characters,
              textInputAction: TextInputAction.done,
              style: TextStyle(color: textColor),
              cursorColor: textColor,
              decoration: _profileInputDecoration(
                  label: tr('Enter Patient Code', 'أدخل كود المريض'),
                  hintText: 'HT-123456',
                  prefixIcon: Icons.password),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton.icon(
                onPressed: _isLinkingPatient
                    ? null
                    : () =>
                        _linkPatientByCode(_manualPatientCodeController.text),
                icon: const Icon(Icons.link),
                label: Text(_isLinkingPatient
                    ? tr('Linking...', 'جاري الربط...')
                    : tr('Link Patient', 'ربط المريض')),
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF87CEEB),
                    foregroundColor: Colors.white),
              ),
            ),
            if (_linkedPatientCode.isNotEmpty) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).inputDecorationTheme.fillColor ??
                      const Color(0xFFF4F4F4),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: borderColor),
                ),
                child: Text(
                    '${tr('Linked Patient Code', 'رمز المريض المرتبط')}: $_linkedPatientCode',
                    style: TextStyle(fontSize: 14, color: textColor)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _startVoiceAccessibilityAssistant() async {
    if (!mounted) return;
    if (_userRole != 'patient') {
      await VoiceAccessibilityService.instance.stopAll();
      return;
    }
    await VoiceAccessibilityService.instance.stopAll();
    setState(() => _isSpeaking = true);
    await VoiceAccessibilityService.instance.readPageAndListen(
      context: context,
      pageText: tr(
        'Edit Profile screen. You can update your profile photo using gallery or camera, edit your name, phone number, and email, change password, view patient information and QR code, generate a new code, save changes, delete account, or log out.',
        'صفحة تعديل الملف الشخصي. يمكنك تحديث صورة الملف الشخصي من المعرض أو الكاميرا، وتعديل الاسم ورقم الهاتف والبريد الإلكتروني، وتغيير كلمة المرور، وعرض معلومات المريض ورمز QR، وتوليد كود جديد، وحفظ التغييرات، أو حذف الحساب، أو تسجيل الخروج.',
      ),
      routes: {
        'dashboard': (context) => const DashboardPage(),
        'profile': (context) => const ProfilePage(),
        'settings': (context) => const SettingsPage(),
      },
    );
    if (!mounted) return;
    setState(() => _isSpeaking = false);
  }

  Future<void> _stopSpeaking() async {
    await VoiceAccessibilityService.instance.stopAll();
    if (!mounted) return;
    setState(() => _isSpeaking = false);
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
              size: 40,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: backgroundColor,
        body: const Center(
            child: CircularProgressIndicator(color: Color(0xFF87CEEB))),
      );
    }

    return Directionality(
      textDirection: isArabic ? ui.TextDirection.rtl : ui.TextDirection.ltr,
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Scaffold(
          resizeToAvoidBottomInset: true,
          backgroundColor: backgroundColor,
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
                            _buildTopProfileInfo(),
                            _buildSectionTitleCard(),
                            _buildUploadImageButton(),
                            _buildField(
                                icon: Icons.person_outlined,
                                label: tr('Name', 'الاسم'),
                                controller: _nameController),
                            _buildField(
                                icon: Icons.phone_in_talk,
                                label: tr('Phone Number', 'رقم الهاتف'),
                                controller: _phoneController,
                                keyboardType: TextInputType.phone),
                            _buildField(
                                icon: Icons.mail_outline_rounded,
                                label: tr('Email', 'البريد الإلكتروني'),
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress),
                            _buildActionButton(
                              text: tr('Change Password', 'تغيير كلمة المرور'),
                              icon: Icons.lock_reset,
                              onPressed: _showChangePasswordDialog,
                            ),
                            if (_userRole == 'volunteer')
                              _buildVolunteerInfoSection(),
                            if (_userRole == 'patient')
                              _buildPatientMedicalInfoSection(),
                            if (_userRole == 'patient')
                              _buildPatientQrSection(),
                            if (_userRole == 'companion')
                              _buildCompanionScanSection(),
                            _buildActionButton(
                              text: _isSaving
                                  ? tr('Saving...', 'جاري الحفظ...')
                                  : (_isVolunteerProfileRequired &&
                                          !_isVolunteerProfileComplete)
                                      ? tr('Complete Required Info',
                                          'إكمال البيانات الإجبارية')
                                      : tr('Save Changes', 'حفظ التغييرات'),
                              icon: Icons.save_outlined,
                              onPressed: _isSaving ? () {} : _saveProfile,
                              backgroundColor: const Color(0xFF87CEEB),
                              foregroundColor: Colors.white,
                            ),
                            _buildActionButton(
                              text: tr('Delete Account', 'حذف الحساب'),
                              icon: Icons.delete_outlined,
                              onPressed: _confirmDeleteAccount,
                            ),
                            _buildActionButton(
                                text: tr('Log Out', 'تسجيل الخروج'),
                                onPressed: _logout),
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
    );
  }
}

class _ScanPatientQrPage extends StatelessWidget {
  final void Function(String code) onScanned;

  const _ScanPatientQrPage({required this.onScanned});

  bool get isArabic => AppSettingsStore.instance.isArabic;
  Color backgroundColor(BuildContext context) =>
      Theme.of(context).scaffoldBackgroundColor;
  String tr(String en, String ar) => isArabic ? ar : en;

  @override
  Widget build(BuildContext context) {
    bool scanned = false;
    return Directionality(
      textDirection: isArabic ? ui.TextDirection.rtl : ui.TextDirection.ltr,
      child: Scaffold(
        backgroundColor: backgroundColor(context),
        appBar: AppBar(
          title: Text(tr('Scan Patient QR', 'مسح رمز QR للمريض'),
              overflow: TextOverflow.ellipsis),
          backgroundColor: const Color(0xFF87CEEB),
          foregroundColor: Colors.white,
        ),
        body: MobileScanner(
          onDetect: (capture) {
            if (scanned) return;
            final barcodes = capture.barcodes;
            for (final barcode in barcodes) {
              final code = barcode.rawValue;
              if (code != null && code.isNotEmpty) {
                scanned = true;
                onScanned(code);
                Navigator.pop(context);
                break;
              }
            }
          },
        ),
      ),
    );
  }
}

class ScanPatientQrPage extends StatelessWidget {
  final void Function(String code) onScanned;

  const ScanPatientQrPage({super.key, required this.onScanned});

  bool get isArabic => AppSettingsStore.instance.isArabic;
  Color backgroundColor(BuildContext context) =>
      Theme.of(context).scaffoldBackgroundColor;
  String tr(String en, String ar) => isArabic ? ar : en;

  @override
  Widget build(BuildContext context) {
    bool scanned = false;
    return Directionality(
      textDirection: isArabic ? ui.TextDirection.rtl : ui.TextDirection.ltr,
      child: Scaffold(
        backgroundColor: backgroundColor(context),
        appBar: AppBar(
          title: Text(tr('Scan Patient QR', 'مسح رمز QR للمريض'),
              overflow: TextOverflow.ellipsis),
          backgroundColor: const Color(0xFF87CEEB),
          foregroundColor: Colors.white,
        ),
        body: MobileScanner(
          onDetect: (capture) {
            if (scanned) return;
            final barcodes = capture.barcodes;
            for (final barcode in barcodes) {
              final code = barcode.rawValue;
              if (code != null && code.isNotEmpty) {
                scanned = true;
                onScanned(code);
                Navigator.pop(context);
                break;
              }
            }
          },
        ),
      ),
    );
  }
}
