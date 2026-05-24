import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'app_settings_store.dart';
import 'Emergency_page.dart';

class HealthSupportChatPage extends StatefulWidget {
  const HealthSupportChatPage({super.key});

  @override
  State<HealthSupportChatPage> createState() => _HealthSupportChatPageState();
}

class _HealthSupportChatPageState extends State<HealthSupportChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool get isArabic => AppSettingsStore.instance.isArabic;

  Color get backgroundColor => Theme.of(context).scaffoldBackgroundColor;

  Color get cardColor => Theme.of(context).cardColor;

  Color get fieldColor =>
      Theme.of(context).inputDecorationTheme.fillColor ?? Colors.white;

  Color get textColor =>
      Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black87;

  Color get subTextColor => Colors.grey;

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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showAiSuggestionPopup();
    });
  }

  void _onLanguageChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    AppSettingsStore.instance.removeListener(_onLanguageChanged);
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String _formatNow() {
    final now = DateTime.now();
    final int hour =
        now.hour > 12 ? now.hour - 12 : (now.hour == 0 ? 12 : now.hour);
    final String minute = now.minute.toString().padLeft(2, '0');
    final String suffix = now.hour >= 12 ? tr('PM', 'م') : tr('AM', 'ص');

    return '$hour:$minute $suffix';
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
                  color: subTextColor,
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
                  color: subTextColor,
                  fontSize: isSmallScreen ? 14 : 15,
                  height: 1.5,
                ),
              ),
            ),
            actionsAlignment: MainAxisAlignment.center,
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(
                  cancelText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: subTextColor),
                ),
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
                child: Text(
                  confirmText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
      },
    );

    return result ?? false;
  }

  Future<void> _showAiSuggestionPopup() async {
    await _showInfoPopup(
      title: tr('AI Suggestion', 'اقتراح الذكاء الاصطناعي'),
      message: tr(
        'This chat can help you express your feelings, ask for support, or explain your health condition clearly.',
        'هذه المحادثة تساعدك على التعبير عن شعورك، طلب الدعم، أو شرح حالتك الصحية بوضوح.',
      ),
      icon: Icons.smart_toy_rounded,
      iconColor: const Color(0xFF87CEEB),
    );
  }

  Future<void> _showStartVoiceAssistantPopup() async {
    await _showInfoPopup(
      title: tr('Start Voice Assistant', 'بدء المساعد الصوتي'),
      message: tr(
        'Voice assistant can be used to help you speak or explain your needs. This button is prepared for voice support.',
        'يمكن استخدام المساعد الصوتي لمساعدتك على التحدث أو شرح احتياجاتك. هذا الزر مخصص لدعم الصوت.',
      ),
      icon: Icons.mic_rounded,
      iconColor: const Color(0xFF87CEEB),
    );
  }

  Future<void> _showEmotionalSupportPopup() async {
    await _showInfoPopup(
      title: tr('Emotional Support', 'الدعم النفسي'),
      message: tr(
        'You are not alone. Take a deep breath. You can talk to your companion or continue chatting here for support.',
        'أنت لست وحدك. خذ نفساً عميقاً. يمكنك التحدث مع المرافق أو متابعة المحادثة هنا للحصول على الدعم.',
      ),
      icon: Icons.favorite_rounded,
      iconColor: Colors.pink,
    );
  }

  Future<void> _showAiEmergencyDetectionPopup() async {
    await _showInfoPopup(
      title: tr('AI Emergency Detection', 'اكتشاف حالة طارئة'),
      message: tr(
        'AI detected that your message may be urgent or dangerous.',
        'اكتشف الذكاء الاصطناعي أن رسالتك قد تكون عاجلة أو خطيرة.',
      ),
      icon: Icons.warning_amber_rounded,
      iconColor: Colors.red,
    );
  }

  Future<void> _showEmergencyRedirectPopup() async {
    final goEmergency = await _showConfirmPopup(
      title: tr('Emergency Redirect', 'الانتقال إلى الطوارئ'),
      message: tr(
        'Do you want to open the Emergency page now?',
        'هل تريد فتح صفحة الطوارئ الآن؟',
      ),
      icon: Icons.emergency_rounded,
      iconColor: Colors.red,
      confirmText: tr('Open Emergency', 'فتح الطوارئ'),
      cancelText: tr('Stay Here', 'البقاء هنا'),
    );

    if (goEmergency && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const EmergencyPage()),
      );
    }
  }

  bool _isEmergencyMessage(String message) {
    final text = message.toLowerCase();

    return text.contains('emergency') ||
        text.contains('urgent') ||
        text.contains('danger') ||
        text.contains('help me') ||
        text.contains('sos') ||
        text.contains('طوارئ') ||
        text.contains('خطر') ||
        text.contains('ساعدني') ||
        text.contains('نجدة');
  }

  bool _isEmotionalMessage(String message) {
    final text = message.toLowerCase();

    return text.contains('sad') ||
        text.contains('cry') ||
        text.contains('lonely') ||
        text.contains('depressed') ||
        text.contains('upset') ||
        text.contains('anxious') ||
        text.contains('stress') ||
        text.contains('worried') ||
        text.contains('scared') ||
        text.contains('حزين') ||
        text.contains('أبكي') ||
        text.contains('وحيد') ||
        text.contains('مكتئب') ||
        text.contains('متضايق') ||
        text.contains('قلق') ||
        text.contains('توتر') ||
        text.contains('خائف') ||
        text.contains('خايف');
  }

  String _generateSmartBotReply(String userMessage) {
    final message = userMessage.toLowerCase();

    if (_isEmergencyMessage(message)) {
      return tr(
        'This sounds urgent. Please press the Emergency SOS button or contact your companion immediately.',
        'يبدو أن الأمر طارئ. يرجى الضغط على زر الطوارئ SOS أو التواصل مع المرافق فوراً.',
      );
    }

    if (message.contains('pain') ||
        message.contains('hurt') ||
        message.contains('sick') ||
        message.contains('fever') ||
        message.contains('headache') ||
        message.contains('dizzy') ||
        message.contains('ألم') ||
        message.contains('تعبان') ||
        message.contains('مريض') ||
        message.contains('حمى') ||
        message.contains('صداع') ||
        message.contains('دوخة')) {
      return tr(
        'I am sorry you are not feeling well. Try to rest, drink water, and tell your companion if the pain continues.',
        'آسف لأنك لا تشعر بحالة جيدة. حاول أن ترتاح وتشرب الماء، وأخبر المرافق إذا استمر الألم.',
      );
    }

    if (_isEmotionalMessage(message)) {
      return tr(
        'I am sorry you feel this way. You are not alone. Try to talk to your companion or someone you trust.',
        'آسف لأنك تشعر بهذا الشعور. أنت لست وحدك. حاول التحدث مع المرافق أو شخص تثق به.',
      );
    }

    if (message.contains('tired') ||
        message.contains('sleep') ||
        message.contains('exhausted') ||
        message.contains('weak') ||
        message.contains('تعب') ||
        message.contains('نوم') ||
        message.contains('مرهق') ||
        message.contains('ضعيف')) {
      return tr(
        'It sounds like you need rest. Try to relax, drink water, and take a short break.',
        'يبدو أنك تحتاج إلى راحة. حاول أن تسترخي وتشرب الماء وتأخذ استراحة قصيرة.',
      );
    }

    if (message.contains('medicine') ||
        message.contains('medication') ||
        message.contains('pill') ||
        message.contains('dose') ||
        message.contains('دواء') ||
        message.contains('حبوب') ||
        message.contains('جرعة')) {
      return tr(
        'Please check your medication reminder. If you are unsure, ask your companion before taking anything.',
        'يرجى التحقق من تذكير الدواء. إذا لم تكن متأكداً، اسأل المرافق قبل أخذ أي شيء.',
      );
    }

    if (message.contains('food') ||
        message.contains('hungry') ||
        message.contains('eat') ||
        message.contains('meal') ||
        message.contains('طعام') ||
        message.contains('جوعان') ||
        message.contains('أكل') ||
        message.contains('وجبة')) {
      return tr(
        'Try to have a light healthy meal and drink enough water.',
        'حاول تناول وجبة صحية خفيفة واشرب كمية كافية من الماء.',
      );
    }

    return tr(
      'Thank you for sharing. I am here to support you. Tell me more about how you feel.',
      'شكراً لمشاركتك. أنا هنا لدعمك. أخبرني أكثر عن شعورك.',
    );
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();

    if (text.isEmpty) return;

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr('Please login first', 'يرجى تسجيل الدخول أولاً'),
          ),
        ),
      );
      return;
    }

    final bool emergencyDetected = _isEmergencyMessage(text);
    final bool emotionalDetected = _isEmotionalMessage(text);

    _messageController.clear();

    await FirebaseFirestore.instance.collection('health_support_chats').add({
      'userId': user.uid,
      'text': text,
      'isFromBot': false,
      'senderRole': 'patient',
      'time': _formatNow(),
      'createdAt': FieldValue.serverTimestamp(),
    });

    await Future.delayed(const Duration(milliseconds: 500));

    final botReply = _generateSmartBotReply(text);

    await FirebaseFirestore.instance.collection('health_support_chats').add({
      'userId': user.uid,
      'text': botReply,
      'isFromBot': true,
      'senderRole': 'bot',
      'time': _formatNow(),
      'createdAt': FieldValue.serverTimestamp(),
    });

    _scrollToBottom();

    if (emergencyDetected) {
      await _showAiEmergencyDetectionPopup();
      await _showEmergencyRedirectPopup();
    } else if (emotionalDetected) {
      await _showEmotionalSupportPopup();
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 150), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 100,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Widget _buildMessageBubble(ChatMessage message) {
    final alignment = message.isFromBot
        ? (isArabic ? CrossAxisAlignment.end : CrossAxisAlignment.start)
        : (isArabic ? CrossAxisAlignment.start : CrossAxisAlignment.end);

    final bubbleColor = message.isFromBot ? const Color(0xFF87CEEB) : cardColor;
    final bubbleTextColor = message.isFromBot ? Colors.white : textColor;

    final borderRadius = message.isFromBot
        ? const BorderRadius.only(
            topLeft: Radius.circular(12),
            topRight: Radius.circular(12),
            bottomRight: Radius.circular(12),
          )
        : const BorderRadius.only(
            topLeft: Radius.circular(12),
            topRight: Radius.circular(12),
            bottomLeft: Radius.circular(12),
          );

    return Column(
      crossAxisAlignment: alignment,
      children: [
        Container(
          constraints: BoxConstraints(
            maxWidth: isSmallScreen ? 220 : 260,
          ),
          padding: EdgeInsets.all(isSmallScreen ? 9 : 10),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: borderRadius,
            border: message.isFromBot ? null : Border.all(color: borderColor),
          ),
          child: Text(
            message.text,
            textAlign: isArabic ? TextAlign.right : TextAlign.left,
            style: TextStyle(
              color: bubbleTextColor,
              fontSize: isSmallScreen ? 13 : 14,
              height: 1.35,
            ),
          ),
        ),
        const SizedBox(height: 5),
        Text(
          message.time,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: subTextColor,
            fontSize: isSmallScreen ? 11 : 12,
          ),
        ),
      ],
    );
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _messagesStream() {
    final user = FirebaseAuth.instance.currentUser;

    return FirebaseFirestore.instance
        .collection('health_support_chats')
        .where('userId', isEqualTo: user?.uid ?? '')
        .orderBy('createdAt')
        .snapshots();
  }

  Widget _buildHeader() {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        isSmallScreen ? 4 : 8,
        0,
        isSmallScreen ? 4 : 8,
        0,
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(
              isArabic ? Icons.arrow_forward : Icons.arrow_back,
              color: textColor,
              size: isSmallScreen ? 24 : 26,
            ),
          ),
          Expanded(
            child: Text(
              tr('Help Chat', 'محادثة المساعدة'),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: isSmallScreen ? 18 : 20,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
          ),
          Container(
            width: isSmallScreen ? 40 : 44,
            height: isSmallScreen ? 40 : 44,
            decoration: const BoxDecoration(
              color: Color(0xFF87CEEB),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.person_outline,
              color: Colors.white,
              size: isSmallScreen ? 22 : 24,
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }

  Widget _buildMessagesList(List<ChatMessage> messages) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 12 : 20,
      ),
      child: ListView.separated(
        controller: _scrollController,
        padding: const EdgeInsets.only(bottom: 12),
        itemCount: messages.length + 1,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          if (index == 0) {
            return Center(
              child: Text(
                tr('Today', 'اليوم'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: subTextColor,
                  fontSize: isSmallScreen ? 12 : 13,
                ),
              ),
            );
          }

          final message = messages[index - 1];

          return _buildMessageBubble(message);
        },
      ),
    );
  }

  Widget _buildInputBar() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          isSmallScreen ? 6 : 8,
          0,
          isSmallScreen ? 6 : 8,
          14,
        ),
        child: Row(
          children: [
            Expanded(
              child: Container(
                constraints: const BoxConstraints(minHeight: 50),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: fieldColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: _showEmotionalSupportPopup,
                      child: Icon(
                        Icons.emoji_emotions_outlined,
                        color: subTextColor,
                        size: isSmallScreen ? 18 : 20,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        textAlign: isArabic ? TextAlign.right : TextAlign.left,
                        textInputAction: TextInputAction.send,
                        style: TextStyle(
                          color: textColor,
                          fontSize: isSmallScreen ? 13 : 14,
                        ),
                        decoration: InputDecoration(
                          hintText: tr(
                            'Type a message',
                            'اكتب رسالة',
                          ),
                          hintStyle: TextStyle(
                            color: subTextColor,
                            fontSize: isSmallScreen ? 13 : 14,
                          ),
                          border: InputBorder.none,
                        ),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                    GestureDetector(
                      onTap: _showStartVoiceAssistantPopup,
                      child: Icon(
                        Icons.mic_none_rounded,
                        color: subTextColor,
                        size: isSmallScreen ? 19 : 21,
                      ),
                    ),
                    if (!isSmallScreen) ...[
                      const SizedBox(width: 8),
                      Icon(
                        Icons.attach_file,
                        color: subTextColor,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.photo_camera_outlined,
                        color: subTextColor,
                        size: 20,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            SizedBox(width: isSmallScreen ? 6 : 10),
            GestureDetector(
              onTap: _sendMessage,
              child: Container(
                width: isSmallScreen ? 44 : 50,
                height: isSmallScreen ? 44 : 50,
                decoration: const BoxDecoration(
                  color: Color(0xFF87CEEB),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.send,
                  color: Colors.white,
                  size: isSmallScreen ? 20 : 24,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoginRequired() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          tr(
            'Please login to use chat',
            'يرجى تسجيل الدخول لاستخدام المحادثة',
          ),
          textAlign: TextAlign.center,
          style: TextStyle(
            color: subTextColor,
            fontSize: isSmallScreen ? 14 : 16,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

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
                      SizedBox(height: isSmallScreen ? 6 : 10),
                      _buildHeader(),
                      SizedBox(height: isSmallScreen ? 8 : 12),
                      Expanded(
                        child: user == null
                            ? _buildLoginRequired()
                            : StreamBuilder<
                                QuerySnapshot<Map<String, dynamic>>>(
                                stream: _messagesStream(),
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState ==
                                      ConnectionState.waiting) {
                                    return const Center(
                                      child: CircularProgressIndicator(
                                        color: Color(0xFF87CEEB),
                                      ),
                                    );
                                  }

                                  if (snapshot.hasError) {
                                    return Center(
                                      child: Padding(
                                        padding: const EdgeInsets.all(24),
                                        child: Text(
                                          tr(
                                            'Error loading messages',
                                            'حدث خطأ أثناء تحميل الرسائل',
                                          ),
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: subTextColor,
                                            fontSize: isSmallScreen ? 14 : 16,
                                          ),
                                        ),
                                      ),
                                    );
                                  }

                                  final docs = snapshot.data?.docs ?? [];

                                  final messages = docs.map((doc) {
                                    final data = doc.data();

                                    return ChatMessage(
                                      text: (data['text'] ?? '').toString(),
                                      isFromBot: data['isFromBot'] ?? false,
                                      time: (data['time'] ?? '').toString(),
                                    );
                                  }).toList();

                                  if (messages.isEmpty) {
                                    messages.add(
                                      ChatMessage(
                                        text: tr(
                                          'Hello! How can I assist you today?',
                                          'مرحباً! كيف يمكنني مساعدتك اليوم؟',
                                        ),
                                        isFromBot: true,
                                        time: _formatNow(),
                                      ),
                                    );
                                  }

                                  return _buildMessagesList(messages);
                                },
                              ),
                      ),
                      _buildInputBar(),
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

class ChatMessage {
  final String text;
  final bool isFromBot;
  final String time;

  ChatMessage({
    required this.text,
    required this.isFromBot,
    required this.time,
  });
}
