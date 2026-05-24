import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'Profile_page.dart';
import 'Settings_page.dart';
import 'VolunteerHelpCall.dart';

import 'package:humantouch/pages/app_settings_store.dart';

class VolunteerDashboardPage extends StatefulWidget {
  const VolunteerDashboardPage({super.key});

  @override
  State<VolunteerDashboardPage> createState() => _VolunteerDashboardPageState();
}

class _VolunteerDashboardPageState extends State<VolunteerDashboardPage> {
  final TextEditingController _tipTitleController = TextEditingController();
  final TextEditingController _tipDescController = TextEditingController();

  bool _isSendingTip = false;

  String _selectedTipCategory = 'Health';
  String _volunteerName = 'Volunteer';

  final List<String> _tipCategories = [
    'Health',
    'Food',
    'Medicine',
    'Exercise',
    'Mental Health',
    'Others',
  ];

  bool get isArabic => AppSettingsStore.instance.isArabic;

  Color get backgroundColor => Theme.of(context).scaffoldBackgroundColor;

  Color get cardColor => Theme.of(context).cardColor;

  Color get fieldColor =>
      Theme.of(context).inputDecorationTheme.fillColor ?? Colors.white;

  Color get textColor =>
      Theme.of(context).textTheme.bodyLarge?.color ?? const Color(0xFF1A1A1A);

  Color get subTextColor => const Color(0xFF666666);

  String tr(String en, String ar) => isArabic ? ar : en;

  String categoryText(String category) {
    switch (category) {
      case 'Health':
        return tr('Health', 'الصحة');
      case 'Food':
        return tr('Food', 'الغذاء');
      case 'Medicine':
        return tr('Medicine', 'الدواء');
      case 'Exercise':
        return tr('Exercise', 'الرياضة');
      case 'Mental Health':
        return tr('Mental Health', 'الصحة النفسية');
      case 'Others':
        return tr('Others', 'أخرى');
      default:
        return category;
    }
  }

  @override
  void initState() {
    super.initState();

    AppSettingsStore.instance.addListener(_onLanguageChanged);
    _loadVolunteerName();
  }

  void _onLanguageChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    AppSettingsStore.instance.removeListener(_onLanguageChanged);
    _tipTitleController.dispose();
    _tipDescController.dispose();
    super.dispose();
  }

  Future<void> _loadVolunteerName() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (!mounted) return;

    final data = doc.data() ?? {};

    setState(() {
      _volunteerName = (data['name'] ??
              data['fullName'] ??
              data['username'] ??
              user.displayName ??
              'Volunteer')
          .toString();
    });
  }

  Widget _buildHeader() {
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
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(40)),
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Row(
            children: [
              const SizedBox(width: 48),
              Expanded(
                child: Text(
                  tr('Volunteer', 'المتطوع'),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
              ),
              const SizedBox(width: 48),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 0, 22, 12),
          child: Align(
            alignment: isArabic ? Alignment.centerRight : Alignment.centerLeft,
            child: Text(
              tr('Welcome, $_volunteerName', 'مرحباً، $_volunteerName'),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: isArabic ? TextAlign.right : TextAlign.left,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _updateRequestStatus(String requestId, String status) async {
    await FirebaseFirestore.instance
        .collection('volunteer_requests')
        .doc(requestId)
        .update({'status': status, 'updatedAt': FieldValue.serverTimestamp()});

    await FirebaseFirestore.instance.collection('notifications').add({
      'title': status == 'accepted' ? 'Request Accepted' : 'Request Rejected',
      'message': status == 'accepted'
          ? 'Volunteer accepted the patient request.'
          : 'Volunteer rejected the patient request.',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _sendTipToPatient() async {
    final user = FirebaseAuth.instance.currentUser;

    final title = _tipTitleController.text.trim();
    final details = _tipDescController.text.trim();

    if (title.isEmpty || details.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr(
              'Please write the tip title and details',
              'يرجى كتابة عنوان النصيحة والتفاصيل',
            ),
          ),
        ),
      );
      return;
    }

    setState(() {
      _isSendingTip = true;
    });

    try {
      final tipData = <String, dynamic>{
        'volunteerId': user?.uid ?? '',
        'volunteerName': _volunteerName,
        'personName': _volunteerName,
        'personType': 'Volunteer',
        'title': title,
        'shortTip': details,
        'fullTip': details,
        'description': details,
        'category': _selectedTipCategory,
        'emoji': _getEmojiForCategory(_selectedTipCategory),
        'color': _getColorForCategory(_selectedTipCategory).value,
        'targetRole': 'patient',
        'visibleToPatient': true,
        'createdByRole': 'volunteer',
        'createdAt': FieldValue.serverTimestamp(),
        'createdAtMs': DateTime.now().millisecondsSinceEpoch,
      };

      await FirebaseFirestore.instance.collection('healthTips').add(tipData);

      _tipTitleController.clear();
      _tipDescController.clear();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr(
              'Tip sent to patient successfully',
              'تم إرسال النصيحة للمريض بنجاح',
            ),
          ),
        ),
      );
    } catch (e) {
      debugPrint('Failed to send health tip: $e');
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr(
              'Failed to send tip. Please check Firestore rules.',
              'فشل إرسال النصيحة. تأكدي من صلاحيات Firestore.',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSendingTip = false;
        });
      }
    }
  }

  String _getEmojiForCategory(String category) {
    switch (category) {
      case 'Health':
        return '💙';
      case 'Food':
        return '🥗';
      case 'Medicine':
        return '💊';
      case 'Exercise':
        return '🏃';
      case 'Mental Health':
        return '🧠';
      case 'Others':
        return '✨';
      default:
        return '💡';
    }
  }

  Color _getColorForCategory(String category) {
    switch (category) {
      case 'Health':
        return const Color(0xFFC5E7F5);
      case 'Food':
        return const Color(0xFFFFC6FF);
      case 'Medicine':
        return const Color(0xFFCAFFBF);
      case 'Exercise':
        return const Color(0xFF9BF6FF);
      case 'Mental Health':
        return const Color(0xFFFFADAD);
      case 'Others':
        return const Color(0xFFFDFFB6);
      default:
        return const Color(0xFFC5E7F5);
    }
  }

  String _safeString(dynamic value, String fallback) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  String _buildVolunteerChatId(String patientId, String volunteerId) {
    final ids = [patientId.trim(), volunteerId.trim()]..sort();
    return '${ids[0]}_${ids[1]}';
  }

  Future<void> _openFullChatWithPatient(Map<String, dynamic> data) async {
    final volunteerUser = FirebaseAuth.instance.currentUser;

    if (volunteerUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(tr('Please login first', 'يرجى تسجيل الدخول أولاً'))),
      );
      return;
    }

    final String patientId = _safeString(
      data['patientId'] ?? data['userId'] ?? data['senderId'],
      '',
    );

    final String patientName = _safeString(
      data['patientName'] ?? data['name'] ?? data['senderName'],
      tr('Patient', 'المريض'),
    );

    if (patientId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr(
              'Cannot open chat because patient ID is missing.',
              'لا يمكن فتح المحادثة لأن رقم المريض غير موجود.',
            ),
          ),
        ),
      );
      return;
    }

    final chatId = _buildVolunteerChatId(patientId, volunteerUser.uid);

    await FirebaseFirestore.instance
        .collection('volunteer_chats')
        .doc(chatId)
        .set({
      'chatId': chatId,
      'patientId': patientId,
      'patientName': patientName,
      'volunteerId': volunteerUser.uid,
      'volunteerName': _volunteerName,
      'participants': [patientId, volunteerUser.uid],
      'participantIds': [patientId, volunteerUser.uid],
      'updatedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
      'requestId': data['requestId'] ?? '',
    }, SetOptions(merge: true));

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VolunteerPatientChatPage(
          patientId: patientId,
          patientName: patientName,
          volunteerName: _volunteerName,
        ),
      ),
    );
  }

  Stream<QuerySnapshot> _requestsStream(String status) {
    return FirebaseFirestore.instance
        .collection('volunteer_requests')
        .where('status', isEqualTo: status)
        .snapshots();
  }

  Stream<QuerySnapshot> _volunteerChatsStream() {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Stream<QuerySnapshot>.empty();
    }

    // No orderBy to avoid Firestore index errors.
    // We sort by updatedAt locally below.
    return FirebaseFirestore.instance
        .collection('volunteer_chats')
        .where('volunteerId', isEqualTo: user.uid)
        .snapshots();
  }

  void _goToPage(int index) {
    if (index == 0) {
      return;
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
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
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

  Widget _buildBottomBar() {
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

  Widget _buildSectionCards() {
    final sections = [
      {
        'title': tr('Requests', 'الطلبات'),
        'subtitle': tr('Pending support requests', 'طلبات المساعدة المعلقة'),
        'icon': Icons.assignment_rounded,
        'color': const Color(0xFFFFF3CD),
      },
      {
        'title': tr('Accepted', 'المقبولة'),
        'subtitle': tr('Accepted patient requests', 'طلبات المرضى المقبولة'),
        'icon': Icons.check_circle_rounded,
        'color': const Color(0xFFE6F7E9),
      },
      {
        'title': tr('Calls', 'المكالمات'),
        'subtitle':
            tr('Incoming voice/video calls', 'مكالمات صوت وفيديو واردة'),
        'icon': Icons.call_rounded,
        'color': const Color(0xFFE3F6FF),
      },
      {
        'title': tr('Chats', 'المحادثات'),
        'subtitle': tr('Patient conversations', 'محادثات المرضى'),
        'icon': Icons.chat_bubble_rounded,
        'color': const Color(0xFFF0E8FF),
      },
      {
        'title': tr('Tips', 'النصائح'),
        'subtitle': tr('Send health tips', 'إرسال نصائح صحية'),
        'icon': Icons.lightbulb_rounded,
        'color': const Color(0xFFFFF0F5),
      },
      {
        'title': tr('Notifications', 'الإشعارات'),
        'subtitle': tr('Recent app updates', 'آخر تحديثات التطبيق'),
        'icon': Icons.notifications_rounded,
        'color': const Color(0xFFEAF8FD),
      },
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 760;

          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: sections.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: isWide ? 3 : 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: isWide ? 2.25 : 1.50,
            ),
            itemBuilder: (context, index) {
              final item = sections[index];

              return InkWell(
                borderRadius: BorderRadius.circular(24),
                onTap: () => _openDashboardSection(index),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Colors.black.withOpacity(0.06),
                      width: 1,
                    ),
                    boxShadow: _shadow(),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        radius: 27,
                        backgroundColor: item['color'] as Color,
                        child: Icon(
                          item['icon'] as IconData,
                          color: const Color(0xFF2196F3),
                          size: 28,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        item['title'].toString(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item['subtitle'].toString(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: subTextColor,
                          fontSize: 11.5,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _openDashboardSection(int index) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _VolunteerDashboardSectionPage(
          title: _sectionTitle(index),
          icon: _sectionIcon(index),
          isArabic: isArabic,
          backgroundColor: backgroundColor,
          textColor: textColor,
          bottomNavigationBar: _buildBottomBar(),
          child: _buildSectionContent(index),
        ),
      ),
    );
  }

  String _sectionTitle(int index) {
    switch (index) {
      case 0:
        return tr('Requests', 'الطلبات');
      case 1:
        return tr('Accepted Requests', 'الطلبات المقبولة');
      case 2:
        return tr('Incoming Calls', 'المكالمات الواردة');
      case 3:
        return tr('Chats', 'المحادثات');
      case 4:
        return tr('Health Tips', 'النصائح الصحية');
      case 5:
        return tr('Notifications', 'الإشعارات');
      default:
        return tr('Requests', 'الطلبات');
    }
  }

  IconData _sectionIcon(int index) {
    switch (index) {
      case 0:
        return Icons.assignment_rounded;
      case 1:
        return Icons.check_circle_rounded;
      case 2:
        return Icons.call_rounded;
      case 3:
        return Icons.chat_bubble_rounded;
      case 4:
        return Icons.lightbulb_rounded;
      case 5:
        return Icons.notifications_rounded;
      default:
        return Icons.assignment_rounded;
    }
  }

  Widget _buildSectionContent(int index) {
    switch (index) {
      case 0:
        return _buildRequestsTab();
      case 1:
        return _buildAcceptedTab();
      case 2:
        return _buildIncomingCallsTab();
      case 3:
        return _buildChatsTab();
      case 4:
        return _buildTipsTab();
      case 5:
        return _buildNotificationsTab();
      default:
        return _buildRequestsTab();
    }
  }

  Stream<QuerySnapshot> _incomingCallsStream() {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Stream<QuerySnapshot>.empty();
    }

    return FirebaseFirestore.instance
        .collection('call_logs')
        .where('receiverId', isEqualTo: user.uid)
        .where('status', whereIn: ['calling', 'ringing']).snapshots();
  }

  Future<void> _rejectIncomingCall(String callId) async {
    await FirebaseFirestore.instance
        .collection('call_logs')
        .doc(callId)
        .update({
      'status': 'rejected',
      'rejectedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  bool _isVideoCallData(Map<String, dynamic> data) {
    final type = (data['callType'] ?? data['type'] ?? '')
        .toString()
        .toLowerCase()
        .trim();
    return data['isVideoCall'] == true || type == 'video';
  }

  void _openIncomingCallPage({
    required String callId,
    required Map<String, dynamic> data,
  }) {
    final String callerId =
        (data['callerId'] ?? data['senderId'] ?? data['patientId'] ?? '')
            .toString()
            .trim();

    final String callerName = (data['callerName'] ??
            data['senderName'] ??
            data['patientName'] ??
            tr('Patient', 'المريض'))
        .toString();

    final bool isVideoCall = _isVideoCallData(data);

    if (callerId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr(
              'Cannot open call because patient ID is missing.',
              'لا يمكن فتح المكالمة لأن رقم المريض غير موجود.',
            ),
          ),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VolunteerHelpCallPage(
          volunteerId: callerId,
          volunteerName: callerName,
          callId: callId,
          isIncoming: true,
          isVideoCall: isVideoCall,
        ),
      ),
    );
  }

  Widget _buildIncomingCallsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _incomingCallsStream(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _emptyText(
            tr(
              'Something went wrong while loading calls. Please check Firestore rules.',
              'حدث خطأ أثناء تحميل المكالمات. تأكدي من صلاحيات Firestore.',
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF87CEEB)),
          );
        }

        final docs = snapshot.data!.docs;

        if (docs.isEmpty) {
          return _emptyText(
            tr('No incoming calls now', 'لا توجد مكالمات واردة الآن'),
          );
        }

        return ListView.builder(
          padding: _responsivePadding(context),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final callId = docs[index].id;
            return _incomingCallCard(callId: callId, data: data);
          },
        );
      },
    );
  }

  Widget _incomingCallCard({
    required String callId,
    required Map<String, dynamic> data,
  }) {
    final String patientName = (data['callerName'] ??
            data['senderName'] ??
            data['patientName'] ??
            tr('Patient', 'المريض'))
        .toString();

    final String status = (data['status'] ?? 'calling').toString();
    final bool isVideoCall = _isVideoCallData(data);

    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: () => _openIncomingCallPage(callId: callId, data: data),
      child: Container(
        margin: const EdgeInsets.only(bottom: 15),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(24),
          boxShadow: _shadow(),
          border: Border.all(
            color: const Color(0xFF87CEEB).withOpacity(0.7),
            width: 1.2,
          ),
        ),
        child: Column(
          crossAxisAlignment:
              isArabic ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 25,
                  backgroundColor: const Color(0xFFE3F6FF),
                  child: Icon(
                    isVideoCall ? Icons.videocam_rounded : Icons.call_rounded,
                    color: const Color(0xFF2196F3),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: isArabic
                        ? CrossAxisAlignment.end
                        : CrossAxisAlignment.start,
                    children: [
                      Text(
                        patientName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isVideoCall
                            ? tr('Incoming video call', 'مكالمة فيديو واردة')
                            : tr('Incoming voice call', 'مكالمة صوتية واردة'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: subTextColor),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3CD),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    status == 'ringing'
                        ? tr('Ringing', 'يرن')
                        : tr('Calling', 'يتصل'),
                    style: const TextStyle(
                      color: Color(0xFF8A6D00),
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () =>
                        _openIncomingCallPage(callId: callId, data: data),
                    icon: const Icon(Icons.call, color: Colors.white),
                    label: Text(
                      tr('Answer', 'رد'),
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      minimumSize: const Size(0, 46),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _rejectIncomingCall(callId),
                    icon: const Icon(Icons.call_end, color: Colors.white),
                    label: Text(
                      tr('Reject', 'رفض'),
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      minimumSize: const Size(0, 46),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _volunteerChatsStream(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _emptyText(
            tr(
              'Something went wrong while loading chats. Please check Firestore rules.',
              'حدث خطأ أثناء تحميل المحادثات. تأكدي من صلاحيات Firestore.',
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF87CEEB)),
          );
        }

        final docs = snapshot.data!.docs.toList();

        docs.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;

          final aTime = aData['updatedAt'];
          final bTime = bData['updatedAt'];

          final aMs = aTime is Timestamp ? aTime.millisecondsSinceEpoch : 0;
          final bMs = bTime is Timestamp ? bTime.millisecondsSinceEpoch : 0;

          return bMs.compareTo(aMs);
        });

        if (docs.isEmpty) {
          return _emptyText(
            tr(
              'No patient chats yet. When a patient sends a message, it will appear here.',
              'لا توجد محادثات مع المرضى بعد. عندما يرسل مريض رسالة ستظهر هنا.',
            ),
          );
        }

        return ListView.builder(
          padding: _responsivePadding(context),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            return _chatCard(data);
          },
        );
      },
    );
  }

  Widget _chatCard(Map<String, dynamic> data) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final patientId = _safeString(data['patientId'], '');
    final patientName =
        _safeString(data['patientName'], tr('Patient', 'المريض'));
    final patientPhoto = _safeString(data['patientPhoto'], '');
    final lastMessage = _safeString(
      data['lastMessage'],
      tr('No messages yet', 'لا توجد رسائل بعد'),
    );
    final lastType = _safeString(data['lastMessageType'], 'text');
    final lastMessageAt = data['lastMessageAt'] ?? data['updatedAt'];
    final unreadMap =
        data['unreadCount'] is Map ? data['unreadCount'] as Map : {};
    final unread = currentUser == null
        ? 0
        : int.tryParse((unreadMap[currentUser.uid] ?? 0).toString()) ?? 0;

    return StreamBuilder<DocumentSnapshot>(
      stream: patientId.isEmpty
          ? const Stream<DocumentSnapshot>.empty()
          : FirebaseFirestore.instance
              .collection('users')
              .doc(patientId)
              .snapshots(),
      builder: (context, patientSnapshot) {
        final patientData =
            patientSnapshot.data?.data() as Map<String, dynamic>?;
        final liveName = _safeString(
          patientData?['name'] ??
              patientData?['fullName'] ??
              patientData?['username'],
          patientName,
        );
        final livePhoto = _safeString(
          patientData?['profileImageBase64'] ??
              patientData?['photoBase64'] ??
              patientData?['imageBase64'] ??
              patientData?['photoUrl'] ??
              patientPhoto,
          patientPhoto,
        );
        final isOnline = _boolFromDynamic(
          patientData?['isActive'] ??
              patientData?['active'] ??
              patientData?['online'] ??
              patientData?['isOnline'] ??
              patientData?['patientActive'],
        );

        return InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () {
            if (patientId.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    tr(
                      'Cannot open chat because patient ID is missing.',
                      'لا يمكن فتح المحادثة لأن رقم المريض غير موجود.',
                    ),
                  ),
                ),
              );
              return;
            }

            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => VolunteerPatientChatPage(
                  patientId: patientId,
                  patientName: liveName,
                  volunteerName: _volunteerName,
                ),
              ),
            );
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(24),
              boxShadow: _shadow(),
            ),
            child: Row(
              children: [
                _chatAvatar(livePhoto, isOnline),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: isArabic
                        ? CrossAxisAlignment.end
                        : CrossAxisAlignment.start,
                    children: [
                      Text(
                        liveName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: isArabic ? TextAlign.right : TextAlign.left,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          if (lastType == 'voice') ...[
                            const Icon(Icons.mic, size: 16, color: Colors.grey),
                            const SizedBox(width: 4),
                          ] else if (lastType == 'image') ...[
                            const Icon(Icons.image,
                                size: 16, color: Colors.grey),
                            const SizedBox(width: 4),
                          ],
                          Expanded(
                            child: Text(
                              lastType == 'voice'
                                  ? tr('Voice message', 'رسالة صوتية')
                                  : lastType == 'image'
                                      ? tr('Photo message', 'رسالة صورة')
                                      : lastMessage,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign:
                                  isArabic ? TextAlign.right : TextAlign.left,
                              style: TextStyle(color: subTextColor),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _formatSmallTime(lastMessageAt),
                      style: TextStyle(color: subTextColor, fontSize: 12),
                    ),
                    if (unread > 0) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: const BoxDecoration(
                          color: Color(0xFF87CEEB),
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          unread > 9 ? '9+' : '$unread',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _chatAvatar(String imageValue, bool isOnline) {
    Widget imageChild;

    if (imageValue.isNotEmpty && imageValue.startsWith('http')) {
      imageChild = ClipOval(
        child: Image.network(
          imageValue,
          width: 54,
          height: 54,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const Icon(
            Icons.person,
            color: Color(0xFF2196F3),
          ),
        ),
      );
    } else if (imageValue.isNotEmpty) {
      try {
        imageChild = ClipOval(
          child: Image.memory(
            base64Decode(imageValue),
            width: 54,
            height: 54,
            fit: BoxFit.cover,
          ),
        );
      } catch (_) {
        imageChild = const Icon(Icons.person, color: Color(0xFF2196F3));
      }
    } else {
      imageChild = const Icon(Icons.person, color: Color(0xFF2196F3));
    }

    return Stack(
      children: [
        CircleAvatar(
          radius: 28,
          backgroundColor: const Color(0xFFE3F6FF),
          child: imageChild,
        ),
        PositionedDirectional(
          end: 1,
          bottom: 2,
          child: Container(
            width: 13,
            height: 13,
            decoration: BoxDecoration(
              color: isOnline ? Colors.green : Colors.red,
              shape: BoxShape.circle,
              border: Border.all(color: cardColor, width: 2),
            ),
          ),
        ),
      ],
    );
  }

  bool _boolFromDynamic(dynamic value) {
    if (value is bool) return value;

    final text = value.toString().trim().toLowerCase();

    return text == 'true' ||
        text == 'active' ||
        text == 'online' ||
        text == '1' ||
        text == 'yes';
  }

  String _formatSmallTime(dynamic value) {
    DateTime? date;

    if (value is Timestamp) {
      date = value.toDate();
    } else if (value is DateTime) {
      date = value;
    }

    if (date == null) return '';

    final now = DateTime.now();

    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
      final minute = date.minute.toString().padLeft(2, '0');
      final period = date.hour >= 12 ? 'PM' : 'AM';
      return '$hour:$minute $period';
    }

    return '${date.day}/${date.month}';
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
            child: Scaffold(
              backgroundColor: backgroundColor,
              body: SafeArea(
                child: Column(
                  children: [
                    _buildHeader(),
                    Expanded(
                      child: SingleChildScrollView(
                        child: _buildSectionCards(),
                      ),
                    ),
                  ],
                ),
              ),
              bottomNavigationBar: _buildBottomBar(),
            ),
          ),
        );
      },
    );
  }

  EdgeInsets _responsivePadding(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width >= 900) {
      return const EdgeInsets.symmetric(horizontal: 24, vertical: 18);
    }
    return const EdgeInsets.all(16);
  }

  Widget _buildRequestsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _requestsStream('pending'),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _emptyText(
            tr(
              'Something went wrong. Please check Firestore rules or fields.',
              'حدث خطأ. تأكدي من صلاحيات Firestore والحقول.',
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF87CEEB)),
          );
        }

        final docs = snapshot.data!.docs;

        if (docs.isEmpty) {
          return _emptyText(tr('No pending requests', 'لا توجد طلبات معلقة'));
        }

        return ListView.builder(
          padding: _responsivePadding(context),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            data['requestId'] = docs[index].id;

            return _requestCard(
              requestId: docs[index].id,
              data: data,
              showActions: true,
            );
          },
        );
      },
    );
  }

  Widget _buildAcceptedTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _requestsStream('accepted'),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _emptyText(
            tr(
              'Something went wrong. Please check Firestore rules or fields.',
              'حدث خطأ. تأكدي من صلاحيات Firestore والحقول.',
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF87CEEB)),
          );
        }

        final docs = snapshot.data!.docs;

        if (docs.isEmpty) {
          return _emptyText(tr('No accepted requests', 'لا توجد طلبات مقبولة'));
        }

        return ListView.builder(
          padding: _responsivePadding(context),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            data['requestId'] = docs[index].id;

            return _requestCard(
              requestId: docs[index].id,
              data: data,
              showActions: false,
            );
          },
        );
      },
    );
  }

  Widget _requestCard({
    required String requestId,
    required Map<String, dynamic> data,
    required bool showActions,
  }) {
    final patientName = data['patientName'] ?? tr('Patient', 'المريض');
    final needTitle = data['needTitle'] ?? tr('Need help', 'يحتاج مساعدة');
    final needDescription = data['needDescription'] ??
        tr(
          'Patient needs volunteer support',
          'المريض يحتاج إلى دعم من متطوع',
        );
    final location =
        data['location'] ?? tr('Unknown location', 'موقع غير معروف');
    final date = data['date'] ?? '';
    final time = data['time'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: _shadow(),
      ),
      child: Column(
        crossAxisAlignment:
            isArabic ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const CircleAvatar(
                radius: 24,
                backgroundColor: Color(0xFFE3F6FF),
                child: Icon(Icons.person, color: Color(0xFF2196F3)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  patientName.toString(),
                  textAlign: isArabic ? TextAlign.right : TextAlign.left,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.access_time,
                    size: 18,
                    color: Colors.grey,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    time.toString(),
                    style: TextStyle(color: textColor),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            needTitle.toString(),
            textAlign: isArabic ? TextAlign.right : TextAlign.left,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            needDescription.toString(),
            textAlign: isArabic ? TextAlign.right : TextAlign.left,
            style: TextStyle(color: subTextColor),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 14,
            runSpacing: 8,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.calendar_month,
                      size: 18, color: Colors.grey),
                  const SizedBox(width: 6),
                  Text(date.toString(), style: TextStyle(color: textColor)),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.location_on, size: 18, color: Colors.grey),
                  const SizedBox(width: 6),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 220),
                    child: Text(
                      location.toString(),
                      textAlign: isArabic ? TextAlign.right : TextAlign.left,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                      style: TextStyle(color: textColor),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 15),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _openFullChatWithPatient(data),
              icon: const Icon(Icons.chat_bubble_outline),
              label: Text(
                tr('Chat with Patient', 'الدردشة مع المريض'),
                overflow: TextOverflow.ellipsis,
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF2196F3),
                side: const BorderSide(color: Color(0xFF2196F3)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
          if (showActions) ...[
            const SizedBox(height: 10),
            LayoutBuilder(
              builder: (context, constraints) {
                final small = constraints.maxWidth < 340;

                if (small) {
                  return Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: _actionButton(
                          text: tr('Accept', 'قبول'),
                          color: Colors.green,
                          onTap: () =>
                              _updateRequestStatus(requestId, 'accepted'),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: _actionButton(
                          text: tr('Reject', 'رفض'),
                          color: Colors.redAccent,
                          onTap: () =>
                              _updateRequestStatus(requestId, 'rejected'),
                        ),
                      ),
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(
                      child: _actionButton(
                        text: tr('Accept', 'قبول'),
                        color: Colors.green,
                        onTap: () =>
                            _updateRequestStatus(requestId, 'accepted'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _actionButton(
                        text: tr('Reject', 'رفض'),
                        color: Colors.redAccent,
                        onTap: () =>
                            _updateRequestStatus(requestId, 'rejected'),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _actionButton({
    required String text,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        minimumSize: const Size(0, 44),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      child: Text(
        text,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: Colors.white),
      ),
    );
  }

  Widget _buildTipsTab() {
    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: _responsivePadding(context),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(24),
          boxShadow: _shadow(),
        ),
        child: Column(
          crossAxisAlignment:
              isArabic ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              tr('Send Health Tip to Patient', 'إرسال نصيحة صحية للمريض'),
              textAlign: isArabic ? TextAlign.right : TextAlign.left,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _tipTitleController,
              textAlign: isArabic ? TextAlign.right : TextAlign.left,
              style: TextStyle(color: textColor),
              decoration: _inputDecoration(tr('Tip title', 'عنوان النصيحة')),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _tipDescController,
              textAlign: isArabic ? TextAlign.right : TextAlign.left,
              maxLines: 4,
              style: TextStyle(color: textColor),
              decoration: _inputDecoration(
                tr('Tip description', 'تفاصيل النصيحة'),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _selectedTipCategory,
              isExpanded: true,
              items: _tipCategories.map((item) {
                return DropdownMenuItem(
                  value: item,
                  child: Text(
                    categoryText(item),
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  _selectedTipCategory = value;
                });
              },
              decoration: _inputDecoration(tr('Category', 'التصنيف')),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _isSendingTip ? null : _sendTipToPatient,
                icon: _isSendingTip
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send, color: Colors.white),
                label: Text(
                  _isSendingTip
                      ? tr('Sending...', 'جاري الإرسال...')
                      : tr(
                          'Send to Patient Health Page',
                          'إرسال إلى صفحة صحة المريض',
                        ),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF87CEEB),
                  disabledBackgroundColor: Colors.grey,
                  minimumSize: const Size(0, 52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('notifications')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _emptyText(
            tr(
              'Something went wrong. Please check Firestore rules or fields.',
              'حدث خطأ. تأكدي من صلاحيات Firestore والحقول.',
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF87CEEB)),
          );
        }

        final docs = snapshot.data!.docs;

        if (docs.isEmpty) {
          return _emptyText(tr('No notifications yet', 'لا توجد إشعارات بعد'));
        }

        return ListView.builder(
          padding: _responsivePadding(context),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(22),
                boxShadow: _shadow(),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const CircleAvatar(
                    backgroundColor: Color(0xFFE3F6FF),
                    child: Icon(Icons.notifications, color: Color(0xFF2196F3)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: isArabic
                          ? CrossAxisAlignment.end
                          : CrossAxisAlignment.start,
                      children: [
                        Text(
                          data['title'] ?? tr('Notification', 'إشعار'),
                          textAlign:
                              isArabic ? TextAlign.right : TextAlign.left,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          data['message'] ?? '',
                          textAlign:
                              isArabic ? TextAlign.right : TextAlign.left,
                          style: TextStyle(color: textColor),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: fieldColor,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
    );
  }

  Widget _emptyText(String text) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(color: subTextColor, fontSize: 16),
        ),
      ),
    );
  }
}

class _VolunteerDashboardSectionPage extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool isArabic;
  final Color backgroundColor;
  final Color textColor;
  final Widget child;
  final Widget bottomNavigationBar;

  const _VolunteerDashboardSectionPage({
    required this.title,
    required this.icon,
    required this.isArabic,
    required this.backgroundColor,
    required this.textColor,
    required this.child,
    required this.bottomNavigationBar,
  });

  Widget _buildHeader(BuildContext context) {
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
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(40)),
              ),
            ),
          ],
        ),
        Container(
          width: double.infinity,
          color: backgroundColor,
          padding: const EdgeInsets.fromLTRB(12, 0, 20, 14),
          child: Row(
            children: [
              IconButton(
                onPressed: () => Navigator.maybePop(context),
                icon: Icon(
                  isArabic ? Icons.arrow_forward : Icons.arrow_back,
                  size: 28,
                  color: textColor,
                ),
              ),
              const SizedBox(width: 4),
              CircleAvatar(
                radius: 23,
                backgroundColor: const Color(0xFFE3F6FF),
                child: Icon(icon, color: const Color(0xFF2196F3)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: isArabic ? TextAlign.right : TextAlign.left,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: isArabic ? ui.TextDirection.rtl : ui.TextDirection.ltr,
      child: Scaffold(
        backgroundColor: backgroundColor,
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(context),
              Expanded(child: child),
            ],
          ),
        ),
        bottomNavigationBar: bottomNavigationBar,
      ),
    );
  }
}

class VolunteerPatientChatPage extends StatefulWidget {
  final String patientId;
  final String patientName;
  final String volunteerName;

  const VolunteerPatientChatPage({
    super.key,
    required this.patientId,
    required this.patientName,
    required this.volunteerName,
  });

  @override
  State<VolunteerPatientChatPage> createState() =>
      _VolunteerPatientChatPageState();
}

class _VolunteerPatientChatPageState extends State<VolunteerPatientChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool _isSending = false;

  bool get isArabic => AppSettingsStore.instance.isArabic;

  Color get backgroundColor => Theme.of(context).scaffoldBackgroundColor;

  Color get cardColor => Theme.of(context).cardColor;

  Color get textColor =>
      Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black87;

  Color get subTextColor => Colors.grey;

  String tr(String en, String ar) => isArabic ? ar : en;

  String get _currentUserId => FirebaseAuth.instance.currentUser?.uid ?? '';

  String get _chatId {
    final ids = [widget.patientId.trim(), _currentUserId.trim()]..sort();
    return '${ids[0]}_${ids[1]}';
  }

  @override
  void initState() {
    super.initState();
    AppSettingsStore.instance.addListener(_onLanguageChanged);
    _ensureChatExists();
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

  Future<void> _ensureChatExists() async {
    if (_currentUserId.isEmpty || widget.patientId.isEmpty) return;

    final chatRef =
        FirebaseFirestore.instance.collection('volunteer_chats').doc(_chatId);

    await chatRef.set({
      'chatId': _chatId,
      'patientId': widget.patientId,
      'patientName': widget.patientName,
      'volunteerId': _currentUserId,
      'volunteerName': widget.volunteerName,
      'participants': [widget.patientId, _currentUserId],
      'participantIds': [widget.patientId, _currentUserId],
      'updatedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();

    if (text.isEmpty ||
        _isSending ||
        _currentUserId.isEmpty ||
        widget.patientId.isEmpty) {
      return;
    }

    setState(() => _isSending = true);

    try {
      final chatRef =
          FirebaseFirestore.instance.collection('volunteer_chats').doc(_chatId);

      await _ensureChatExists();

      final messageRef = chatRef.collection('messages').doc();

      await messageRef.set({
        'messageId': messageRef.id,
        'text': text,
        'message': text,
        'senderId': _currentUserId,
        'senderName': widget.volunteerName,
        'senderRole': 'volunteer',
        'receiverId': widget.patientId,
        'receiverName': widget.patientName,
        'receiverRole': 'patient',
        'patientId': widget.patientId,
        'volunteerId': _currentUserId,
        'createdAt': FieldValue.serverTimestamp(),
        'isRead': false,
        'isSeen': false,
        'type': 'text',
      });

      await chatRef.set({
        'lastMessage': text,
        'lastMessageType': 'text',
        'lastSenderId': _currentUserId,
        'lastSenderName': widget.volunteerName,
        'lastSenderRole': 'volunteer',
        'lastMessageAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'unreadCount.${widget.patientId}': FieldValue.increment(1),
      }, SetOptions(merge: true));

      await FirebaseFirestore.instance.collection('notifications').add({
        'userId': widget.patientId,
        'receiverId': widget.patientId,
        'senderId': _currentUserId,
        'senderName': widget.volunteerName,
        'senderRole': 'volunteer',
        'type': 'volunteer_chat_message',
        'title': 'New message from volunteer',
        'message': text,
        'chatId': _chatId,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      _messageController.clear();
      _scrollToBottom();
    } catch (e) {
      debugPrint('Error sending volunteer message: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr(
              'Could not send message. Check Firestore rules.',
              'تعذر إرسال الرسالة. تأكدي من صلاحيات Firestore.',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _markMessagesAsSeen() async {
    if (_currentUserId.isEmpty) return;

    final chatRef =
        FirebaseFirestore.instance.collection('volunteer_chats').doc(_chatId);

    final query = await chatRef
        .collection('messages')
        .where('receiverId', isEqualTo: _currentUserId)
        .where('isSeen', isEqualTo: false)
        .get();

    final batch = FirebaseFirestore.instance.batch();

    for (final doc in query.docs) {
      batch.update(doc.reference, {
        'isSeen': true,
        'isRead': true,
        'seenAt': FieldValue.serverTimestamp(),
      });
    }

    batch.set(
      chatRef,
      {
        'unreadCount.$_currentUserId': 0,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    await batch.commit();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 180), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 120,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> _patientDocStream() {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(widget.patientId)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _messagesStream() {
    if (_currentUserId.isEmpty || widget.patientId.isEmpty) {
      return const Stream.empty();
    }

    return FirebaseFirestore.instance
        .collection('volunteer_chats')
        .doc(_chatId)
        .collection('messages')
        .orderBy('createdAt', descending: false)
        .snapshots();
  }

  bool _boolFromDynamic(dynamic value) {
    if (value is bool) return value;

    final text = value.toString().trim().toLowerCase();

    return text == 'true' ||
        text == 'active' ||
        text == 'online' ||
        text == '1' ||
        text == 'yes';
  }

  String _safeString(dynamic value, String fallback) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  String _imageFromData(Map<String, dynamic> data) {
    return (data['profileImageBase64'] ??
            data['profileImage'] ??
            data['imageBase64'] ??
            data['photoBase64'] ??
            data['photoUrl'] ??
            data['profileImageUrl'] ??
            '')
        .toString()
        .trim();
  }

  Widget _profileAvatar(String imageValue, bool isOnline) {
    Widget imageChild;

    if (imageValue.isNotEmpty && imageValue.startsWith('http')) {
      imageChild = ClipOval(
        child: Image.network(
          imageValue,
          width: 58,
          height: 58,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const Icon(
            Icons.person_rounded,
            color: Color(0xFF2D9CDB),
            size: 32,
          ),
        ),
      );
    } else if (imageValue.isNotEmpty) {
      try {
        imageChild = ClipOval(
          child: Image.memory(
            base64Decode(imageValue),
            width: 58,
            height: 58,
            fit: BoxFit.cover,
          ),
        );
      } catch (_) {
        imageChild = const Icon(
          Icons.person_rounded,
          color: Color(0xFF2D9CDB),
          size: 32,
        );
      }
    } else {
      imageChild = const Icon(
        Icons.person_rounded,
        color: Color(0xFF2D9CDB),
        size: 32,
      );
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        CircleAvatar(
          radius: 29,
          backgroundColor: const Color(0xFFEAF8FD),
          child: imageChild,
        ),
        Positioned(
          right: 1,
          bottom: 2,
          child: Container(
            width: 13,
            height: 13,
            decoration: BoxDecoration(
              color: isOnline ? Colors.green : Colors.red,
              shape: BoxShape.circle,
              border: Border.all(color: backgroundColor, width: 2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _chatHeader(Map<String, dynamic> patientData) {
    final displayName = _safeString(
      patientData['name'] ?? patientData['fullName'] ?? patientData['username'],
      widget.patientName,
    );

    final isOnline = _boolFromDynamic(
      patientData['isActive'] ??
          patientData['active'] ??
          patientData['online'] ??
          patientData['isOnline'] ??
          patientData['patientActive'],
    );

    final imageValue = _imageFromData(patientData);

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
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(40)),
              ),
            ),
          ],
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          color: backgroundColor,
          child: Row(
            children: [
              IconButton(
                onPressed: () => Navigator.maybePop(context),
                icon: Icon(
                  isArabic ? Icons.arrow_forward : Icons.arrow_back,
                  size: 28,
                  color: textColor,
                ),
              ),
              const SizedBox(width: 8),
              _profileAvatar(imageValue, isOnline),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: isArabic
                      ? CrossAxisAlignment.end
                      : CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: isArabic ? TextAlign.right : TextAlign.left,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isOnline
                          ? tr('Online', 'متصل')
                          : tr('Offline', 'غير متصل'),
                      style: TextStyle(
                        color: isOnline ? Colors.green : Colors.red,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
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

  String _formatTime(dynamic value) {
    try {
      if (value is Timestamp) {
        final date = value.toDate();
        final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
        final minute = date.minute.toString().padLeft(2, '0');
        final period = date.hour >= 12 ? 'PM' : 'AM';
        return '$hour:$minute $period';
      }
    } catch (_) {}

    return '';
  }

  Widget _messageBubble(Map<String, dynamic> data) {
    final isMe = data['senderId'] == _currentUserId;
    final message = (data['text'] ?? data['message'] ?? '').toString();
    final time = _formatTime(data['createdAt']);

    return Align(
      alignment: isMe
          ? (isArabic ? Alignment.centerLeft : Alignment.centerRight)
          : (isArabic ? Alignment.centerRight : Alignment.centerLeft),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 430),
        margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 18),
        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 14),
        decoration: BoxDecoration(
          color: isMe ? const Color(0xFF87CEEB) : const Color(0xFFEAF8FD),
          borderRadius: BorderRadius.circular(18),
          border: isMe ? null : Border.all(color: Colors.black12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              message,
              textAlign: isArabic ? TextAlign.right : TextAlign.left,
              style: TextStyle(
                color: isMe ? Colors.white : textColor,
                fontSize: 15,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              time,
              style: TextStyle(
                color: isMe ? Colors.white70 : subTextColor,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _messagesList(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    if (docs.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _markMessagesAsSeen();

        if (_scrollController.hasClients) {
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        }
      });
    }

    if (docs.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Text(
            tr(
              'No messages yet. Start chatting with the patient.',
              'لا توجد رسائل بعد. ابدأ المحادثة مع المريض.',
            ),
            textAlign: TextAlign.center,
            style: TextStyle(color: subTextColor, fontSize: 15),
          ),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.only(bottom: 12, top: 8),
      itemCount: docs.length,
      itemBuilder: (context, index) {
        return _messageBubble(docs[index].data());
      },
    );
  }

  Widget _inputBar() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
        child: Row(
          children: [
            Expanded(
              child: Container(
                constraints: const BoxConstraints(minHeight: 50),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE6E6E6)),
                  color: cardColor,
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 12),
                    const Icon(
                      Icons.emoji_emotions_outlined,
                      color: Colors.grey,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _messageController,
                        textInputAction: TextInputAction.send,
                        textAlign: isArabic ? TextAlign.right : TextAlign.left,
                        onFieldSubmitted: (_) => _sendMessage(),
                        decoration: InputDecoration(
                          hintText: tr('Type a message', 'اكتب رسالة'),
                          border: InputBorder.none,
                          isDense: true,
                        ),
                        style: TextStyle(fontSize: 14, color: textColor),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            InkWell(
              onTap: _isSending ? null : _sendMessage,
              borderRadius: BorderRadius.circular(30),
              child: Container(
                width: 50,
                height: 50,
                decoration: const BoxDecoration(
                  color: Color(0xFF87CEEB),
                  shape: BoxShape.circle,
                ),
                child: _isSending
                    ? const Padding(
                        padding: EdgeInsets.all(14),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(
                        Icons.send_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _loginRequired() {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: Center(
        child: Text(
          tr('Please login first', 'يرجى تسجيل الدخول أولاً'),
          style: TextStyle(color: textColor),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUserId.isEmpty) {
      return _loginRequired();
    }

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
              stream: _patientDocStream(),
              builder: (context, patientSnapshot) {
                final patientData = patientSnapshot.data?.data() ?? {};

                return GestureDetector(
                  onTap: () => FocusScope.of(context).unfocus(),
                  child: Scaffold(
                    resizeToAvoidBottomInset: true,
                    backgroundColor: backgroundColor,
                    body: SafeArea(
                      child: Column(
                        children: [
                          _chatHeader(patientData),
                          Expanded(
                            child: StreamBuilder<
                                QuerySnapshot<Map<String, dynamic>>>(
                              stream: _messagesStream(),
                              builder: (context, messageSnapshot) {
                                if (messageSnapshot.connectionState ==
                                        ConnectionState.waiting &&
                                    !messageSnapshot.hasData) {
                                  return const Center(
                                    child: CircularProgressIndicator(
                                      color: Color(0xFF87CEEB),
                                    ),
                                  );
                                }

                                final docs = messageSnapshot.data?.docs ?? [];
                                return _messagesList(docs);
                              },
                            ),
                          ),
                          _inputBar(),
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
