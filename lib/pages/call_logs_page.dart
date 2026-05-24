import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'app_settings_store.dart';

class CallLogsPage extends StatelessWidget {
  final String userId;

  const CallLogsPage({
    super.key,
    required this.userId,
  });

  bool get isArabic => AppSettingsStore.instance.isArabic;

  String tr(String en, String ar) => isArabic ? ar : en;

  bool isSmallScreen(BuildContext context) {
    final width = MediaQuery.maybeOf(context)?.size.width ?? 400;
    return width < 380;
  }

  String _formatStatus(String status) {
    switch (status) {
      case 'accepted':
        return tr('Answered', 'تم الرد');
      case 'rejected':
        return tr('Rejected', 'مرفوضة');
      case 'missed':
        return tr('Missed', 'فائتة');
      case 'failed':
        return tr('Failed', 'فشلت');
      case 'calling':
        return tr('Calling', 'جاري الاتصال');
      case 'ringing':
        return tr('Ringing', 'يرن');
      case 'ended':
        return tr('Ended', 'انتهت');
      default:
        return status;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'accepted':
        return Icons.call;
      case 'missed':
        return Icons.call_missed;
      case 'rejected':
      case 'failed':
      case 'ended':
        return Icons.call_end;
      default:
        return Icons.call;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'accepted':
        return Colors.green;
      case 'missed':
        return Colors.orange;
      case 'rejected':
      case 'failed':
        return Colors.red;
      case 'ended':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  String _formatTime(Timestamp? time) {
    if (time == null) return '';

    final dt = time.toDate();
    final minute = dt.minute.toString().padLeft(2, '0');

    return '${dt.day}/${dt.month} - ${dt.hour}:$minute';
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

  Widget _buildCallCard({
    required BuildContext context,
    required Map<String, dynamic> data,
    required Color cardColor,
    required Color textColor,
    required Color subTextColor,
  }) {
    final bool small = isSmallScreen(context);

    final bool isOutgoing = data['callerId'] == userId;

    final String otherPartyName = (isOutgoing
            ? data['receiverName'] ?? data['receiverId']
            : data['callerName'] ?? data['callerId'])
        .toString();

    final String status = (data['status'] ?? 'unknown').toString();
    final String time = _formatTime(data['updatedAt']);

    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: small ? 10 : 14,
        vertical: 6,
      ),
      padding: EdgeInsets.all(small ? 12 : 14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(18),
        boxShadow: _shadow(),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: small ? 22 : 25,
            backgroundColor: _statusColor(status).withOpacity(0.15),
            child: Icon(
              _statusIcon(status),
              color: _statusColor(status),
              size: small ? 21 : 24,
            ),
          ),
          SizedBox(width: small ? 10 : 12),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  isArabic ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Text(
                  otherPartyName,
                  textAlign: isArabic ? TextAlign.right : TextAlign.left,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: textColor,
                    fontSize: small ? 15 : 16,
                  ),
                ),
                const SizedBox(height: 5),
                Wrap(
                  spacing: 8,
                  runSpacing: 5,
                  alignment: isArabic ? WrapAlignment.end : WrapAlignment.start,
                  children: [
                    _buildInfoChip(
                      text: _formatStatus(status),
                      color: _statusColor(status),
                      small: small,
                    ),
                    _buildInfoChip(
                      text: isOutgoing
                          ? tr('Outgoing Call', 'مكالمة صادرة')
                          : tr('Incoming Call', 'مكالمة واردة'),
                      color: subTextColor,
                      small: small,
                    ),
                  ],
                ),
                if (time.isNotEmpty) ...[
                  const SizedBox(height: 7),
                  Text(
                    time,
                    textAlign: isArabic ? TextAlign.right : TextAlign.left,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: small ? 11 : 12,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip({
    required String text,
    required Color color,
    required bool small,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: small ? 8 : 10,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: small ? 11 : 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color backgroundColor = Theme.of(context).scaffoldBackgroundColor;

    final Color cardColor = Theme.of(context).cardColor;

    final Color textColor =
        Theme.of(context).textTheme.bodyLarge?.color ?? const Color(0xFF14181B);

    const Color subTextColor = Color(0xFF57636C);

    final bool small = isSmallScreen(context);

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
              appBar: AppBar(
                title: Text(
                  tr('Call History', 'سجل المكالمات'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: small ? 18 : 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                backgroundColor: const Color(0xFF87CEEB),
                foregroundColor: Colors.white,
                elevation: 0,
              ),
              body: SafeArea(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('call_logs')
                      .where(
                        Filter.or(
                          Filter('callerId', isEqualTo: userId),
                          Filter('receiverId', isEqualTo: userId),
                        ),
                      )
                      .orderBy('updatedAt', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            tr(
                              'Index required. Create Firestore index from console.',
                              'تحتاج إنشاء Index في Firestore من لوحة التحكم.',
                            ),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: textColor,
                              fontSize: small ? 14 : 16,
                              height: 1.4,
                            ),
                          ),
                        ),
                      );
                    }

                    if (!snapshot.hasData) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF87CEEB),
                        ),
                      );
                    }

                    final docs = snapshot.data!.docs;

                    if (docs.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            tr('No calls yet', 'لا توجد مكالمات بعد'),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: textColor,
                              fontSize: small ? 15 : 16,
                            ),
                          ),
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.only(top: 10, bottom: 24),
                      itemCount: docs.length,
                      itemBuilder: (context, i) {
                        final data = docs[i].data() as Map<String, dynamic>;

                        return _buildCallCard(
                          context: context,
                          data: data,
                          cardColor: cardColor,
                          textColor: textColor,
                          subTextColor: subTextColor,
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
