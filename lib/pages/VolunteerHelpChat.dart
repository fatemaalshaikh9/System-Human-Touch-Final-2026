import 'dart:io';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image_picker/image_picker.dart';

import 'package:humantouch/pages/app_settings_store.dart';

class VolunteerHelpChatPage extends StatefulWidget {
  final String volunteerId;
  final String volunteerName;

  const VolunteerHelpChatPage({
    super.key,
    required this.volunteerId,
    required this.volunteerName,
  });

  @override
  State<VolunteerHelpChatPage> createState() => _VolunteerHelpChatPageState();
}

class _VolunteerHelpChatPageState extends State<VolunteerHelpChatPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  final TextEditingController _messageController = TextEditingController();
  final FocusNode _messageFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();
  final ImagePicker _imagePicker = ImagePicker();

  static const String _chatCollection = 'volunteer_chats';

  bool _isRecording = false;
  bool _isSendingVoice = false;
  String? _playingUrl;

  bool get isArabic => AppSettingsStore.instance.isArabic;

  Color get backgroundColor => Theme.of(context).scaffoldBackgroundColor;

  Color get cardColor => Theme.of(context).cardColor;

  Color get myBubbleColor => Theme.of(context).cardColor;

  Color get textColor =>
      Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;

  Color get subTextColor => Colors.grey;

  String tr(String en, String ar) => isArabic ? ar : en;

  String get _currentUserId => _auth.currentUser?.uid ?? '';

  bool get isSmallScreen {
    final width = MediaQuery.maybeOf(context)?.size.width ?? 400;
    return width < 380;
  }

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
    _messageController.dispose();
    _messageFocusNode.dispose();
    _scrollController.dispose();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  String _buildChatId(String userA, String userB) {
    final ids = [userA, userB]..sort();
    return '${ids[0]}_${ids[1]}';
  }

  Future<Map<String, dynamic>> _currentUserData() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return {};

    try {
      final doc =
          await _firestore.collection('users').doc(currentUser.uid).get();
      return doc.data() ?? {};
    } catch (_) {
      return {};
    }
  }

  String _nameFromUserData(Map<String, dynamic> data, String fallback) {
    final name = (data['name'] ?? data['fullName'] ?? data['username'] ?? '')
        .toString()
        .trim();
    return name.isEmpty ? fallback : name;
  }

  String _photoFromUserData(Map<String, dynamic> data, {String fallback = ''}) {
    final value = (data['photoUrl'] ??
            data['profileImageUrl'] ??
            data['profileImageBase64'] ??
            data['profileImage'] ??
            data['imageBase64'] ??
            data['photoBase64'] ??
            fallback)
        .toString()
        .trim();
    return value;
  }

  bool _boolFromDynamic(dynamic value) {
    if (value is bool) return value;
    final text = value.toString().trim().toLowerCase();
    return text == 'true' ||
        text == 'active' ||
        text == 'online' ||
        text == 'available' ||
        text == '1' ||
        text == 'yes';
  }

  bool _isVolunteerOnline(Map<String, dynamic> volunteerData) {
    return _boolFromDynamic(
      volunteerData['isAvailable'] ??
          volunteerData['isOnline'] ??
          volunteerData['online'] ??
          volunteerData['active'] ??
          volunteerData['isActive'],
    );
  }

  Future<void> _ensureChatExists({
    required String chatId,
    required Map<String, dynamic> volunteerData,
  }) async {
    final chatRef = _firestore.collection(_chatCollection).doc(chatId);
    final currentUser = _auth.currentUser;

    if (currentUser == null ||
        _currentUserId.isEmpty ||
        widget.volunteerId.isEmpty) {
      return;
    }

    final patientData = await _currentUserData();
    final patientName = _nameFromUserData(
      patientData,
      currentUser.displayName ?? tr('Patient', 'المريض'),
    );
    final patientPhoto = _photoFromUserData(
      patientData,
      fallback: currentUser.photoURL ?? '',
    );
    final volunteerPhoto = _photoFromUserData(volunteerData);
    final participants = [_currentUserId, widget.volunteerId]..sort();

    await chatRef.set({
      'chatId': chatId,
      'participants': participants,
      'participantIds': participants,
      'patientId': _currentUserId,
      'volunteerId': widget.volunteerId,
      'patientName': patientName,
      'patientPhoto': patientPhoto,
      'volunteerName': widget.volunteerName,
      'volunteerPhoto': volunteerPhoto,
      'volunteerIsOnline': _isVolunteerOnline(volunteerData),
      'updatedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _sendMessage(Map<String, dynamic> volunteerData) async {
    final text = _messageController.text.trim();

    if (text.isEmpty) return;

    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    final chatId = _buildChatId(_currentUserId, widget.volunteerId);
    final chatRef = _firestore.collection(_chatCollection).doc(chatId);

    await _ensureChatExists(chatId: chatId, volunteerData: volunteerData);

    final messageRef = chatRef.collection('messages').doc();

    await messageRef.set({
      'messageId': messageRef.id,
      'text': text,
      'senderId': _currentUserId,
      'senderRole': 'patient',
      'receiverId': widget.volunteerId,
      'receiverRole': 'volunteer',
      'patientId': _currentUserId,
      'volunteerId': widget.volunteerId,
      'createdAt': FieldValue.serverTimestamp(),
      'isSeen': false,
      'isRead': false,
      'type': 'text',
    });

    await chatRef.update({
      'lastMessage': text,
      'lastMessageTime': FieldValue.serverTimestamp(),
      'lastMessageAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'lastSenderId': _currentUserId,
      'lastSenderRole': 'patient',
    });

    _messageController.clear();
    _scrollToBottom();
  }

  Future<void> _startRecording() async {
    final hasPermission = await _audioRecorder.hasPermission();

    if (!hasPermission) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr(
              'Microphone permission is required',
              'إذن الميكروفون مطلوب',
            ),
          ),
        ),
      );
      return;
    }

    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

    await _audioRecorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
        sampleRate: 44100,
      ),
      path: path,
    );

    setState(() {
      _isRecording = true;
    });
  }

  Future<void> _stopAndSendVoice(Map<String, dynamic> volunteerData) async {
    if (_isSendingVoice) return;

    setState(() {
      _isSendingVoice = true;
    });

    try {
      final path = await _audioRecorder.stop();

      setState(() {
        _isRecording = false;
      });

      if (path == null) {
        setState(() {
          _isSendingVoice = false;
        });
        return;
      }

      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      final chatId = _buildChatId(_currentUserId, widget.volunteerId);
      final chatRef = _firestore.collection(_chatCollection).doc(chatId);

      await _ensureChatExists(chatId: chatId, volunteerData: volunteerData);

      final file = File(path);
      final fileName = 'voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

      final storageRef = _storage
          .ref()
          .child('volunteer_chat_voice_messages')
          .child(chatId)
          .child(fileName);

      await storageRef.putFile(file);

      final audioUrl = await storageRef.getDownloadURL();

      final messageRef = chatRef.collection('messages').doc();

      await messageRef.set({
        'messageId': messageRef.id,
        'text': '',
        'audioUrl': audioUrl,
        'senderId': _currentUserId,
        'senderRole': 'patient',
        'receiverId': widget.volunteerId,
        'receiverRole': 'volunteer',
        'patientId': _currentUserId,
        'volunteerId': widget.volunteerId,
        'createdAt': FieldValue.serverTimestamp(),
        'isSeen': false,
        'isRead': false,
        'type': 'voice',
      });

      await chatRef.update({
        'lastMessage': 'Voice message',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessageAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'lastSenderId': _currentUserId,
        'lastSenderRole': 'patient',
      });

      _scrollToBottom();
    } catch (e) {
      setState(() {
        _isRecording = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr('Voice message failed: $e', 'فشل إرسال الرسالة الصوتية: $e'),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSendingVoice = false;
        });
      }
    }
  }

  Future<void> _playVoice(String audioUrl) async {
    try {
      if (_playingUrl == audioUrl) {
        await _audioPlayer.stop();
        setState(() {
          _playingUrl = null;
        });
        return;
      }

      await _audioPlayer.stop();

      setState(() {
        _playingUrl = audioUrl;
      });

      await _audioPlayer.play(UrlSource(audioUrl));

      _audioPlayer.onPlayerComplete.listen((event) {
        if (mounted) {
          setState(() {
            _playingUrl = null;
          });
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr('Could not play voice: $e', 'تعذر تشغيل الصوت: $e'),
          ),
        ),
      );
    }
  }

  Future<void> _pickAndSendImage(
    Map<String, dynamic> volunteerData,
    ImageSource source,
  ) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null || _currentUserId.isEmpty) return;

      final pickedFile = await _imagePicker.pickImage(
        source: source,
        imageQuality: 75,
        maxWidth: 1600,
      );

      if (pickedFile == null) return;

      final chatId = _buildChatId(_currentUserId, widget.volunteerId);
      final chatRef = _firestore.collection(_chatCollection).doc(chatId);

      await _ensureChatExists(chatId: chatId, volunteerData: volunteerData);

      final file = File(pickedFile.path);
      final fileName = 'image_${DateTime.now().millisecondsSinceEpoch}.jpg';

      final storageRef = _storage
          .ref()
          .child('volunteer_chat_images')
          .child(chatId)
          .child(fileName);

      await storageRef.putFile(file);
      final imageUrl = await storageRef.getDownloadURL();

      final messageRef = chatRef.collection('messages').doc();

      await messageRef.set({
        'messageId': messageRef.id,
        'text': '',
        'imageUrl': imageUrl,
        'senderId': _currentUserId,
        'senderRole': 'patient',
        'receiverId': widget.volunteerId,
        'receiverRole': 'volunteer',
        'patientId': _currentUserId,
        'volunteerId': widget.volunteerId,
        'createdAt': FieldValue.serverTimestamp(),
        'isSeen': false,
        'isRead': false,
        'type': 'image',
      });

      await chatRef.update({
        'lastMessage': 'Photo',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessageAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'lastSenderId': _currentUserId,
        'lastSenderRole': 'patient',
      });

      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr('Could not send photo: $e', 'تعذر إرسال الصورة: $e'),
          ),
        ),
      );
    }
  }

  void _showAttachmentSheet(Map<String, dynamic> volunteerData) {
    showModalBottomSheet(
      context: context,
      backgroundColor: cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading:
                      const Icon(Icons.photo_library, color: Color(0xFF87CEEB)),
                  title: Text(tr('Gallery', 'المعرض')),
                  onTap: () {
                    Navigator.pop(context);
                    _pickAndSendImage(volunteerData, ImageSource.gallery);
                  },
                ),
                ListTile(
                  leading:
                      const Icon(Icons.photo_camera, color: Color(0xFF87CEEB)),
                  title: Text(tr('Camera', 'الكاميرا')),
                  onTap: () {
                    Navigator.pop(context);
                    _pickAndSendImage(volunteerData, ImageSource.camera);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _markMessagesAsSeen(String chatId) async {
    final query = await _firestore
        .collection(_chatCollection)
        .doc(chatId)
        .collection('messages')
        .where('receiverId', isEqualTo: _currentUserId)
        .where('isSeen', isEqualTo: false)
        .get();

    for (final doc in query.docs) {
      await doc.reference.update({'isSeen': true, 'isRead': true});
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 120,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _formatTime(Timestamp? timestamp) {
    if (timestamp == null) return '';

    final date = timestamp.toDate();
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? tr('pm', 'م') : tr('am', 'ص');

    return '$hour:$minute $period';
  }

  String _formatHeaderDate(Timestamp? timestamp) {
    if (timestamp == null) return '';

    final date = timestamp.toDate();

    final weekDaysEn = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final weekDaysAr = [
      'الاثنين',
      'الثلاثاء',
      'الأربعاء',
      'الخميس',
      'الجمعة',
      'السبت',
      'الأحد',
    ];

    final dayName =
        isArabic ? weekDaysAr[date.weekday - 1] : weekDaysEn[date.weekday - 1];

    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? tr('PM', 'م') : tr('AM', 'ص');

    return '$dayName $hour:$minute $period';
  }

  Widget _buildTextBubble({
    required String text,
    required bool isMe,
    required String time,
  }) {
    return Align(
      alignment: isMe
          ? (isArabic ? Alignment.centerLeft : Alignment.centerRight)
          : (isArabic ? Alignment.centerRight : Alignment.centerLeft),
      child: Column(
        crossAxisAlignment: isMe
            ? (isArabic ? CrossAxisAlignment.start : CrossAxisAlignment.end)
            : (isArabic ? CrossAxisAlignment.end : CrossAxisAlignment.start),
        children: [
          Container(
            constraints: BoxConstraints(
              maxWidth: isSmallScreen ? 220 : 260,
            ),
            padding: EdgeInsets.all(isSmallScreen ? 10 : 12),
            decoration: BoxDecoration(
              color: isMe ? myBubbleColor : const Color(0xFF87CEEB),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(12),
                topRight: const Radius.circular(12),
                bottomLeft: Radius.circular(isMe ? 12 : 0),
                bottomRight: Radius.circular(isMe ? 0 : 12),
              ),
            ),
            child: Text(
              text,
              textAlign: isArabic ? TextAlign.right : TextAlign.left,
              style: TextStyle(
                fontSize: isSmallScreen ? 13 : 14,
                color: isMe ? textColor : Colors.white,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            time,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: isSmallScreen ? 11 : 12,
              color: subTextColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVoiceBubble({
    required String audioUrl,
    required bool isMe,
    required String time,
  }) {
    final bool isPlaying = _playingUrl == audioUrl;

    return Align(
      alignment: isMe
          ? (isArabic ? Alignment.centerLeft : Alignment.centerRight)
          : (isArabic ? Alignment.centerRight : Alignment.centerLeft),
      child: Column(
        crossAxisAlignment: isMe
            ? (isArabic ? CrossAxisAlignment.start : CrossAxisAlignment.end)
            : (isArabic ? CrossAxisAlignment.end : CrossAxisAlignment.start),
        children: [
          Container(
            constraints: BoxConstraints(
              maxWidth: isSmallScreen ? 220 : 260,
            ),
            padding: EdgeInsets.symmetric(
              horizontal: isSmallScreen ? 10 : 12,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              color: isMe ? myBubbleColor : const Color(0xFF87CEEB),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(12),
                topRight: const Radius.circular(12),
                bottomLeft: Radius.circular(isMe ? 12 : 0),
                bottomRight: Radius.circular(isMe ? 0 : 12),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: () => _playVoice(audioUrl),
                  borderRadius: BorderRadius.circular(30),
                  child: CircleAvatar(
                    radius: isSmallScreen ? 16 : 18,
                    backgroundColor: isMe
                        ? const Color(0xFF87CEEB)
                        : Colors.white.withOpacity(0.95),
                    child: Icon(
                      isPlaying ? Icons.pause : Icons.play_arrow,
                      color: isMe ? Colors.white : const Color(0xFF87CEEB),
                      size: isSmallScreen ? 20 : 22,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Icon(
                  Icons.graphic_eq_rounded,
                  color: isMe ? Colors.black54 : Colors.white,
                  size: isSmallScreen ? 19 : 22,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    tr('Voice', 'صوت'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isMe ? textColor : Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: isSmallScreen ? 13 : 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 5),
          Text(
            time,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: isSmallScreen ? 11 : 12,
              color: subTextColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageBubble({
    required String imageUrl,
    required bool isMe,
    required String time,
  }) {
    return Align(
      alignment: isMe
          ? (isArabic ? Alignment.centerLeft : Alignment.centerRight)
          : (isArabic ? Alignment.centerRight : Alignment.centerLeft),
      child: Column(
        crossAxisAlignment: isMe
            ? (isArabic ? CrossAxisAlignment.start : CrossAxisAlignment.end)
            : (isArabic ? CrossAxisAlignment.end : CrossAxisAlignment.start),
        children: [
          Container(
            constraints: BoxConstraints(
              maxWidth: isSmallScreen ? 220 : 270,
              maxHeight: 260,
            ),
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: isMe ? myBubbleColor : const Color(0xFF87CEEB),
              borderRadius: BorderRadius.circular(16),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  padding: const EdgeInsets.all(18),
                  color: Colors.black12,
                  child: Text(
                    tr('Photo unavailable', 'الصورة غير متوفرة'),
                    style: TextStyle(color: isMe ? textColor : Colors.white),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            time,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: isSmallScreen ? 11 : 12,
              color: subTextColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar(Map<String, dynamic> volunteerData) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          isSmallScreen ? 6 : 8,
          0,
          isSmallScreen ? 6 : 8,
          8,
        ),
        child: Row(
          children: [
            Expanded(
              child: Container(
                constraints: const BoxConstraints(minHeight: 50),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE6E6E6)),
                  color: cardColor,
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 10),
                    Icon(
                      Icons.emoji_emotions_outlined,
                      color: Colors.grey,
                      size: isSmallScreen ? 18 : 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _messageController,
                        focusNode: _messageFocusNode,
                        textInputAction: TextInputAction.send,
                        textAlign: isArabic ? TextAlign.right : TextAlign.left,
                        onFieldSubmitted: (_) => _sendMessage(volunteerData),
                        decoration: InputDecoration(
                          hintText: _isRecording
                              ? tr('Recording voice...', 'جاري تسجيل الصوت...')
                              : tr('Type a message', 'اكتب رسالة'),
                          border: InputBorder.none,
                          isDense: true,
                        ),
                        style: TextStyle(
                          fontSize: isSmallScreen ? 12 : 13,
                          color: textColor,
                        ),
                      ),
                    ),
                    if (!isSmallScreen) ...[
                      InkWell(
                        onTap: () => _showAttachmentSheet(volunteerData),
                        borderRadius: BorderRadius.circular(18),
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: FaIcon(
                            FontAwesomeIcons.paperclip,
                            color: Colors.grey,
                            size: 18,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: () => _pickAndSendImage(
                            volunteerData, ImageSource.camera),
                        borderRadius: BorderRadius.circular(18),
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(
                            Icons.photo_camera_outlined,
                            color: Colors.grey,
                            size: 20,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ] else ...[
                      InkWell(
                        onTap: () => _showAttachmentSheet(volunteerData),
                        borderRadius: BorderRadius.circular(18),
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(
                            Icons.attach_file_rounded,
                            color: Colors.grey,
                            size: 18,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ],
                ),
              ),
            ),
            SizedBox(width: isSmallScreen ? 6 : 10),
            _circleActionButton(
              color: _isRecording ? Colors.red : const Color(0xFF87CEEB),
              onTap: _isSendingVoice
                  ? null
                  : () {
                      if (_isRecording) {
                        _stopAndSendVoice(volunteerData);
                      } else {
                        _startRecording();
                      }
                    },
              child: _isSendingVoice
                  ? const Padding(
                      padding: EdgeInsets.all(13),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Icon(
                      _isRecording ? Icons.stop : Icons.mic,
                      color: Colors.white,
                      size: isSmallScreen ? 21 : 23,
                    ),
            ),
            SizedBox(width: isSmallScreen ? 6 : 8),
            _circleActionButton(
              color: const Color(0xFF87CEEB),
              onTap: () => _sendMessage(volunteerData),
              child: Icon(
                Icons.send_rounded,
                color: Colors.white,
                size: isSmallScreen ? 20 : 22,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _circleActionButton({
    required Color color,
    required Widget child,
    required VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30),
      child: Container(
        width: isSmallScreen ? 44 : 50,
        height: isSmallScreen ? 44 : 50,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
        child: child,
      ),
    );
  }

  Widget _buildHeader(Map<String, dynamic> volunteerData) {
    final String name = _nameFromUserData(volunteerData, widget.volunteerName);
    final String photoUrl = _photoFromUserData(volunteerData);
    final bool isAvailable = _isVolunteerOnline(volunteerData);

    ImageProvider? avatarImage;
    if (photoUrl.isNotEmpty && photoUrl.startsWith('http')) {
      avatarImage = NetworkImage(photoUrl);
    } else if (photoUrl.isNotEmpty) {
      try {
        avatarImage = MemoryImage(base64Decode(photoUrl));
      } catch (_) {
        avatarImage = null;
      }
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          alignment: Alignment.bottomCenter,
          children: [
            Container(
              height: 130,
              width: double.infinity,
              color: const Color(0xFF87CEEB),
            ),
            Container(
              height: 40,
              width: double.infinity,
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(40),
                ),
              ),
            ),
          ],
        ),
        Container(
          width: double.infinity,
          color: backgroundColor,
          padding: EdgeInsets.fromLTRB(
            isSmallScreen ? 8 : 16,
            0,
            isSmallScreen ? 8 : 16,
            12,
          ),
          child: Row(
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Icon(
                  isArabic ? Icons.arrow_forward : Icons.arrow_back,
                  color: textColor,
                  size: 28,
                ),
              ),
              const SizedBox(width: 8),
              Stack(
                clipBehavior: Clip.none,
                children: [
                  CircleAvatar(
                    radius: isSmallScreen ? 26 : 30,
                    backgroundColor: const Color(0xFFEAF8FD),
                    backgroundImage: avatarImage,
                    child: avatarImage == null
                        ? Icon(
                            Icons.person_rounded,
                            color: const Color(0xFF2D9CDB),
                            size: isSmallScreen ? 30 : 35,
                          )
                        : null,
                  ),
                  PositionedDirectional(
                    end: 2,
                    bottom: 3,
                    child: Container(
                      width: 13,
                      height: 13,
                      decoration: BoxDecoration(
                        color: isAvailable ? Colors.green : Colors.red,
                        shape: BoxShape.circle,
                        border: Border.all(color: backgroundColor, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: isArabic
                      ? CrossAxisAlignment.end
                      : CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: isArabic ? TextAlign.right : TextAlign.left,
                      style: TextStyle(
                        fontSize: isSmallScreen ? 20 : 24,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isAvailable
                          ? tr('Online', 'متصل')
                          : tr('Offline', 'غير متصل'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: isSmallScreen ? 12 : 14,
                        color: isAvailable ? Colors.green : Colors.red,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLoginRequired() {
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
            child: Scaffold(
              resizeToAvoidBottomInset: true,
              backgroundColor: backgroundColor,
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    tr('Please login first', 'يرجى تسجيل الدخول أولاً'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: textColor,
                      fontSize: isSmallScreen ? 15 : 16,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildVolunteerNotFound() {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: backgroundColor,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            tr(
              'Volunteer not found',
              'لم يتم العثور على المتطوع',
            ),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: textColor,
              fontSize: isSmallScreen ? 15 : 16,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: backgroundColor,
      body: const Center(
        child: CircularProgressIndicator(
          color: Color(0xFF87CEEB),
        ),
      ),
    );
  }

  Widget _buildMessagesList({
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> messages,
    required String chatId,
  }) {
    if (messages.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _markMessagesAsSeen(chatId);

        if (_scrollController.hasClients) {
          _scrollController.jumpTo(
            _scrollController.position.maxScrollExtent,
          );
        }
      });
    }

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
            final firstTimestamp = messages.isNotEmpty
                ? messages.first.data()['createdAt'] as Timestamp?
                : null;

            return Center(
              child: Text(
                firstTimestamp != null ? _formatHeaderDate(firstTimestamp) : '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: subTextColor,
                  fontSize: isSmallScreen ? 12 : 13,
                ),
              ),
            );
          }

          final message = messages[index - 1].data();
          final bool isMe = message['senderId'] == _currentUserId;

          final String type = (message['type'] ?? 'text').toString();

          if (type == 'image') {
            return _buildImageBubble(
              imageUrl: (message['imageUrl'] ?? '').toString(),
              isMe: isMe,
              time: _formatTime(
                message['createdAt'] as Timestamp?,
              ),
            );
          }

          if (type == 'voice') {
            return _buildVoiceBubble(
              audioUrl: (message['audioUrl'] ?? '').toString(),
              isMe: isMe,
              time: _formatTime(
                message['createdAt'] as Timestamp?,
              ),
            );
          }

          return _buildTextBubble(
            text: message['text'] ?? '',
            isMe: isMe,
            time: _formatTime(
              message['createdAt'] as Timestamp?,
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = _auth.currentUser;

    if (currentUser == null) {
      return _buildLoginRequired();
    }

    final volunteerRef = _firestore.collection('users').doc(widget.volunteerId);

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
            child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: volunteerRef.snapshots(),
              builder: (context, volunteerSnapshot) {
                if (volunteerSnapshot.connectionState ==
                    ConnectionState.waiting) {
                  return _buildLoading();
                }

                if (!volunteerSnapshot.hasData ||
                    !volunteerSnapshot.data!.exists) {
                  return _buildVolunteerNotFound();
                }

                final volunteerData = volunteerSnapshot.data!.data()!;
                final chatId = _buildChatId(_currentUserId, widget.volunteerId);
                final chatRef =
                    _firestore.collection(_chatCollection).doc(chatId);

                return GestureDetector(
                  onTap: () => FocusScope.of(context).unfocus(),
                  child: Scaffold(
                    resizeToAvoidBottomInset: true,
                    backgroundColor: backgroundColor,
                    body: SafeArea(
                      child: Column(
                        children: [
                          _buildHeader(volunteerData),
                          Expanded(
                            child: StreamBuilder<
                                QuerySnapshot<Map<String, dynamic>>>(
                              stream: chatRef
                                  .collection('messages')
                                  .orderBy('createdAt')
                                  .snapshots(),
                              builder: (context, messageSnapshot) {
                                if (messageSnapshot.connectionState ==
                                    ConnectionState.waiting) {
                                  return const Center(
                                    child: CircularProgressIndicator(
                                      color: Color(0xFF87CEEB),
                                    ),
                                  );
                                }

                                final messages =
                                    messageSnapshot.data?.docs ?? [];

                                return _buildMessagesList(
                                  messages: messages,
                                  chatId: chatId,
                                );
                              },
                            ),
                          ),
                          _buildInputBar(volunteerData),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}
