import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'Dashboard_page.dart';
import 'Profile_page.dart';
import 'Settings_page.dart';
import 'HealthSupportChat_page.dart';
import 'app_settings_store.dart';

class HealthAssessmentPage extends StatefulWidget {
  const HealthAssessmentPage({super.key});

  @override
  State<HealthAssessmentPage> createState() => _HealthAssessmentPageState();
}

class _HealthAssessmentPageState extends State<HealthAssessmentPage> {
  int _currentQuestionIndex = 0;
  double _moodValue = 2;
  bool _isSaving = false;

  final Map<int, dynamic> _answers = {};

  bool get isArabic => AppSettingsStore.instance.isArabic;

  Color get backgroundColor => Theme.of(context).scaffoldBackgroundColor;

  Color get cardColor => Theme.of(context).cardColor;

  Color get textColor =>
      Theme.of(context).textTheme.bodyLarge?.color ?? const Color(0xFF0F1113);

  Color get subTextColor => const Color(0xFF57636C);

  Color get borderColor => Theme.of(context).dividerColor;

  String tr(String en, String ar) => isArabic ? ar : en;

  bool get isSmallScreen {
    final width = MediaQuery.maybeOf(context)?.size.width ?? 400;
    return width < 380;
  }

  final List<AssessmentQuestion> _questions = const [
    AssessmentQuestion(
      title: 'How is your mood?',
      titleAr: 'كيف حال مزاجك؟',
      subtitle: 'On a scale of 1 - 3 how are you feeling today?',
      subtitleAr: 'من 1 إلى 3، كيف تشعر اليوم؟',
      type: QuestionType.slider,
      options: ['Low', 'Medium', 'High'],
    ),
    AssessmentQuestion(
      title: 'How was your day?',
      titleAr: 'كيف كان يومك؟',
      subtitle: 'Did you experience anything out of the ordinary?',
      subtitleAr: 'هل حدث معك شيء غير معتاد اليوم؟',
      type: QuestionType.singleChoice,
      options: [
        'Incredible 😇',
        'Great 😃',
        'Good 🙂',
        'Okay 😕',
        'Really Bad 😞',
      ],
    ),
    AssessmentQuestion(
      title: 'How is your energy level right now?',
      titleAr: 'كيف مستوى طاقتك الآن؟',
      subtitle: 'Did you notice anything affecting your energy today?',
      subtitleAr: 'هل لاحظت شيئاً أثر على طاقتك اليوم؟',
      type: QuestionType.singleChoice,
      options: ['High ⚡', 'Medium 🙂', 'Low 😴', 'Exhausted 🛌'],
    ),
    AssessmentQuestion(
      title: 'How are you feeling physically?',
      titleAr: 'كيف تشعر جسدياً؟',
      subtitle: 'Did you experience any unusual physical symptoms?',
      subtitleAr: 'هل شعرت بأي أعراض جسدية غير معتادة؟',
      type: QuestionType.singleChoice,
      options: ['Excellent 💪', 'Good 🙂', 'Okay 😐', 'Not well 🤕'],
    ),
    AssessmentQuestion(
      title: 'Did you sleep well last night?',
      titleAr: 'هل نمت جيداً الليلة الماضية؟',
      subtitle:
          'Did anything disturb your sleep or make it different than usual?',
      subtitleAr: 'هل أزعجك شيء أثناء النوم أو جعله مختلفاً عن المعتاد؟',
      type: QuestionType.singleChoice,
      options: ['Excellent 🌙', 'Good 🙂', 'Okay 😐', 'Poor 😴'],
    ),
    AssessmentQuestion(
      title: 'Do you need any help or support today?',
      titleAr: 'هل تحتاج إلى مساعدة أو دعم اليوم؟',
      subtitle: 'Is there anything specific you need help with today?',
      subtitleAr: 'هل يوجد شيء محدد تحتاج المساعدة فيه اليوم؟',
      type: QuestionType.singleChoice,
      options: ['Yes ✅', 'Maybe 🤔', 'No ❌'],
    ),
  ];

  AssessmentQuestion get _currentQuestion => _questions[_currentQuestionIndex];

  double get _progress => (_currentQuestionIndex + 1) / _questions.length;

  @override
  void initState() {
    super.initState();
    AppSettingsStore.instance.addListener(_onLanguageChanged);
  }

  void _onLanguageChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    AppSettingsStore.instance.removeListener(_onLanguageChanged);
    super.dispose();
  }

  void _saveCurrentAnswer() {
    if (_currentQuestion.type == QuestionType.slider) {
      _answers[_currentQuestionIndex] = _moodValue;
    }
  }

  String _moodTextFromValue(double value) {
    if (value <= 1) return 'Low';
    if (value <= 2) return 'Medium';
    return 'High';
  }

  String _moodTextDisplay(double value) {
    if (value <= 1) return tr('Low', 'منخفض');
    if (value <= 2) return tr('Medium', 'متوسط');
    return tr('High', 'مرتفع');
  }

  String _moodEmojiFromValue(double value) {
    if (value <= 1) return '😞';
    if (value <= 2) return '🙂';
    return '😃';
  }

  String _optionText(String option) {
    switch (option) {
      case 'Low':
        return tr('Low', 'منخفض');
      case 'Medium':
        return tr('Medium', 'متوسط');
      case 'High':
        return tr('High', 'مرتفع');
      case 'Incredible 😇':
        return tr('Incredible 😇', 'ممتاز جداً 😇');
      case 'Great 😃':
        return tr('Great 😃', 'رائع 😃');
      case 'Good 🙂':
        return tr('Good 🙂', 'جيد 🙂');
      case 'Okay 😕':
        return tr('Okay 😕', 'عادي 😕');
      case 'Really Bad 😞':
        return tr('Really Bad 😞', 'سيئ جداً 😞');
      case 'High ⚡':
        return tr('High ⚡', 'مرتفع ⚡');
      case 'Medium 🙂':
        return tr('Medium 🙂', 'متوسط 🙂');
      case 'Low 😴':
        return tr('Low 😴', 'منخفض 😴');
      case 'Exhausted 🛌':
        return tr('Exhausted 🛌', 'مرهق 🛌');
      case 'Excellent 💪':
        return tr('Excellent 💪', 'ممتاز 💪');
      case 'Excellent 🌙':
        return tr('Excellent 🌙', 'ممتاز 🌙');
      case 'Okay 😐':
        return tr('Okay 😐', 'عادي 😐');
      case 'Not well 🤕':
        return tr('Not well 🤕', 'لست بخير 🤕');
      case 'Poor 😴':
        return tr('Poor 😴', 'سيئ 😴');
      case 'Yes ✅':
        return tr('Yes ✅', 'نعم ✅');
      case 'Maybe 🤔':
        return tr('Maybe 🤔', 'ربما 🤔');
      case 'No ❌':
        return tr('No ❌', 'لا ❌');
      default:
        return option;
    }
  }

  bool _calculateNeedsHelp() {
    final dynamic q6 = _answers[5];

    return q6 == 'Yes ✅' ||
        q6 == 'Maybe 🤔' ||
        (_moodValue <= 1.5) ||
        _answers[1] == 'Really Bad 😞' ||
        _answers[2] == 'Exhausted 🛌' ||
        _answers[3] == 'Not well 🤕' ||
        _answers[4] == 'Poor 😴';
  }

  Future<void> _saveAssessmentToFirebase(bool needsHelp) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('Please login first', 'يرجى تسجيل الدخول أولاً')),
        ),
      );
      return;
    }

    final String result = needsHelp
        ? 'The patient may need support today.'
        : 'The patient seems okay today.';

    await FirebaseFirestore.instance.collection('health_ai_reports').add({
      'userId': user.uid,
      'moodValue': _moodValue,
      'mood': _moodTextFromValue(_moodValue),
      'moodEmoji': _moodEmojiFromValue(_moodValue),
      'dayStatus': _answers[1] ?? '',
      'energy': _answers[2] ?? '',
      'physical': _answers[3] ?? '',
      'sleep': _answers[4] ?? '',
      'supportNeeded': _answers[5] ?? '',
      'needsHelp': needsHelp,
      'result': result,
      'answers': {
        'mood': _moodTextFromValue(_moodValue),
        'dayStatus': _answers[1] ?? '',
        'energy': _answers[2] ?? '',
        'physical': _answers[3] ?? '',
        'sleep': _answers[4] ?? '',
        'supportNeeded': _answers[5] ?? '',
      },
      'createdAt': FieldValue.serverTimestamp(),
    });

    await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
      'lastAssessmentResult': result,
      'lastAssessmentNeedsHelp': needsHelp,
      'lastAssessmentMood': _moodTextFromValue(_moodValue),
      'lastAssessmentMoodEmoji': _moodEmojiFromValue(_moodValue),
      'lastAssessmentTime': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _goNext() async {
    if (_currentQuestion.type == QuestionType.slider) {
      _saveCurrentAnswer();
    }

    if (_currentQuestionIndex < _questions.length - 1) {
      setState(() {
        _currentQuestionIndex++;
      });
    } else {
      await _showFinalResult();
    }
  }

  void _selectOption(String value) {
    setState(() {
      _answers[_currentQuestionIndex] = value;
    });
  }

  bool get _canContinue {
    if (_currentQuestion.type == QuestionType.slider) {
      return true;
    }
    return _answers[_currentQuestionIndex] != null;
  }

  Future<void> _showFinalResult() async {
    final bool needsHelp = _calculateNeedsHelp();

    setState(() {
      _isSaving = true;
    });

    try {
      await _saveAssessmentToFirebase(needsHelp);

      if (!mounted) return;

      setState(() {
        _isSaving = false;
      });

      showDialog(
        context: context,
        builder: (context) {
          return Directionality(
            textDirection:
                isArabic ? ui.TextDirection.rtl : ui.TextDirection.ltr,
            child: AlertDialog(
              backgroundColor: cardColor,
              title: Text(
                tr('Assessment Result', 'نتيجة التقييم'),
                style: TextStyle(color: textColor),
              ),
              content: SingleChildScrollView(
                child: Text(
                  needsHelp
                      ? tr(
                          'The patient may need support today.',
                          'قد يحتاج المريض إلى دعم اليوم.',
                        )
                      : tr(
                          'The patient seems okay today.',
                          'يبدو أن المريض بخير اليوم.',
                        ),
                  style: TextStyle(color: subTextColor),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);

                    if (needsHelp) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const HealthSupportChatPage(),
                        ),
                      );
                    } else {
                      Navigator.pop(context);
                    }
                  },
                  child: Text(
                    needsHelp
                        ? tr('Open Help', 'فتح المساعدة')
                        : tr('Done', 'تم'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          );
        },
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr('Error saving assessment: $e', 'حدث خطأ أثناء حفظ التقييم: $e'),
          ),
        ),
      );
    }
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
            height: 41.1,
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

  Widget _buildQuestionContent() {
    if (_currentQuestion.type == QuestionType.slider) {
      final String moodText = _moodTextDisplay(_moodValue);
      final String emoji = _moodEmojiFromValue(_moodValue);

      return Column(
        children: [
          SizedBox(height: isSmallScreen ? 20 : 30),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Text('😞', style: TextStyle(fontSize: isSmallScreen ? 34 : 42)),
              Text('🙂', style: TextStyle(fontSize: isSmallScreen ? 34 : 42)),
              Text('😃', style: TextStyle(fontSize: isSmallScreen ? 34 : 42)),
            ],
          ),
          SizedBox(height: isSmallScreen ? 18 : 24),
          Slider(
            activeColor: const Color(0xFF87CEEB),
            inactiveColor: borderColor,
            min: 1,
            max: 3,
            divisions: 2,
            value: _moodValue,
            onChanged: (value) {
              setState(() {
                _moodValue = value;
              });
            },
          ),
          const SizedBox(height: 8),
          Text(
            '$emoji  $moodText',
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: isSmallScreen ? 18 : 20,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ],
      );
    }

    final selectedValue = _answers[_currentQuestionIndex];

    return Column(
      children: _currentQuestion.options.map((option) {
        final bool isSelected = selectedValue == option;

        return Padding(
          padding: EdgeInsets.only(bottom: isSmallScreen ? 10 : 14),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => _selectOption(option),
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                horizontal: isSmallScreen ? 12 : 16,
                vertical: isSmallScreen ? 13 : 16,
              ),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF87CEEB).withOpacity(0.20)
                    : cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected ? const Color(0xFF87CEEB) : borderColor,
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _optionText(option),
                      textAlign: isArabic ? TextAlign.right : TextAlign.left,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: isSmallScreen ? 14 : 16,
                        color: subTextColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    isSelected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                    color: const Color(0xFF87CEEB),
                    size: isSmallScreen ? 22 : 24,
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _bottomNavItem({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: IconButton(
        onPressed: onTap,
        icon: Icon(
          icon,
          color: textColor,
          size: isSmallScreen
              ? 34
              : icon == Icons.settings_outlined
                  ? 45
                  : 50,
        ),
        splashColor: Colors.grey.withOpacity(0.20),
        highlightColor: Colors.grey.withOpacity(0.12),
      ),
    );
  }

  Widget _buildBottomNavigation() {
    return SafeArea(
      top: false,
      child: Container(
        width: double.infinity,
        height: isSmallScreen ? 56 : 60,
        decoration: BoxDecoration(color: cardColor),
        child: Row(
          children: [
            _bottomNavItem(
              icon: Icons.home_outlined,
              onTap: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const DashboardPage(),
                  ),
                );
              },
            ),
            _bottomNavItem(
              icon: Icons.person_outlined,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ProfilePage(),
                  ),
                );
              },
            ),
            _bottomNavItem(
              icon: Icons.settings_outlined,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SettingsPage(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionsRow(int questionNumber) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool small = constraints.maxWidth < 340;

        if (small) {
          return Column(
            children: [
              _actionButton(
                text: tr('Need help?', 'تحتاج مساعدة؟'),
                onPressed: _isSaving
                    ? null
                    : () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const HealthSupportChatPage(),
                          ),
                        );
                      },
              ),
              const SizedBox(height: 12),
              _actionButton(
                text: questionNumber == 6
                    ? tr('Finish', 'إنهاء')
                    : tr('Next Question', 'السؤال التالي'),
                onPressed: _canContinue && !_isSaving ? _goNext : null,
                showLoading: _isSaving,
              ),
            ],
          );
        }

        return Row(
          children: [
            Expanded(
              child: _actionButton(
                text: tr('Need help?', 'تحتاج مساعدة؟'),
                onPressed: _isSaving
                    ? null
                    : () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const HealthSupportChatPage(),
                          ),
                        );
                      },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _actionButton(
                text: questionNumber == 6
                    ? tr('Finish', 'إنهاء')
                    : tr('Next Question', 'السؤال التالي'),
                onPressed: _canContinue && !_isSaving ? _goNext : null,
                showLoading: _isSaving,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _actionButton({
    required String text,
    required VoidCallback? onPressed,
    bool showLoading = false,
  }) {
    return SizedBox(
      width: double.infinity,
      height: isSmallScreen ? 48 : 50,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF87CEEB),
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey.shade300,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(40),
          ),
        ),
        child: showLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Text(
                text,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: isSmallScreen ? 14 : 16),
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final int questionNumber = _currentQuestionIndex + 1;

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
                  child: Column(
                    children: [
                      _buildHeader(),
                      Expanded(
                        child: SingleChildScrollView(
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                          padding: EdgeInsets.fromLTRB(
                            isSmallScreen ? 14 : 16,
                            12,
                            isSmallScreen ? 14 : 16,
                            24,
                          ),
                          child: Column(
                            crossAxisAlignment: isArabic
                                ? CrossAxisAlignment.end
                                : CrossAxisAlignment.start,
                            children: [
                              Text(
                                tr(
                                  'Question $questionNumber/6',
                                  'السؤال $questionNumber/6',
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: subTextColor,
                                  fontSize: isSmallScreen ? 13 : 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 12),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(24),
                                child: LinearProgressIndicator(
                                  value: _progress,
                                  minHeight: isSmallScreen ? 10 : 12,
                                  backgroundColor: borderColor,
                                  valueColor: const AlwaysStoppedAnimation(
                                    Color(0xFF87CEEB),
                                  ),
                                ),
                              ),
                              SizedBox(height: isSmallScreen ? 42 : 80),
                              Center(
                                child: Text(
                                  isArabic
                                      ? _currentQuestion.titleAr
                                      : _currentQuestion.title,
                                  textAlign: TextAlign.center,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: isSmallScreen ? 22 : 28,
                                    fontWeight: FontWeight.w600,
                                    color: textColor,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Center(
                                child: Text(
                                  isArabic
                                      ? _currentQuestion.subtitleAr
                                      : _currentQuestion.subtitle,
                                  textAlign: TextAlign.center,
                                  maxLines: 4,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: isSmallScreen ? 14 : 15,
                                    color: subTextColor,
                                    fontWeight: FontWeight.w500,
                                    height: 1.35,
                                  ),
                                ),
                              ),
                              SizedBox(height: isSmallScreen ? 22 : 30),
                              _buildQuestionContent(),
                              SizedBox(height: isSmallScreen ? 30 : 50),
                              _buildActionsRow(questionNumber),
                            ],
                          ),
                        ),
                      ),
                      _buildBottomNavigation(),
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

enum QuestionType { slider, singleChoice }

class AssessmentQuestion {
  final String title;
  final String titleAr;
  final String subtitle;
  final String subtitleAr;
  final QuestionType type;
  final List<String> options;

  const AssessmentQuestion({
    required this.title,
    required this.titleAr,
    required this.subtitle,
    required this.subtitleAr,
    required this.type,
    required this.options,
  });
}
