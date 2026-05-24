import 'dart:async';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:zego_uikit_prebuilt_call/zego_uikit_prebuilt_call.dart';

import 'call_engine_service.dart';
import 'zego_config.dart';

import 'package:humantouch/pages/app_settings_store.dart';

class VolunteerHelpCallPage extends StatefulWidget {
  final String volunteerId;
  final String volunteerName;
  final String? callId;
  final bool isIncoming;
  final bool isVideoCall;

  const VolunteerHelpCallPage({
    super.key,
    required this.volunteerId,
    required this.volunteerName,
    this.callId,
    this.isIncoming = false,
    this.isVideoCall = false,
  });

  @override
  State<VolunteerHelpCallPage> createState() => _VolunteerHelpCallPageState();
}

class _VolunteerHelpCallPageState extends State<VolunteerHelpCallPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Timer? _timeoutTimer;
  Timer? _ringingTimer;

  bool _isCreatingCall = false;
  bool _isOpeningCall = false;

  bool get isArabic => AppSettingsStore.instance.isArabic;

  Color get backgroundColor => Theme.of(context).scaffoldBackgroundColor;

  Color get textColor =>
      Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;

  Color get subTextColor => Theme.of(context).brightness == Brightness.dark
      ? Colors.white70
      : Colors.black54;

  String tr(String en, String ar) => isArabic ? ar : en;

  bool get isSmallScreen {
    final width = MediaQuery.maybeOf(context)?.size.width ?? 400;
    return width < 380;
  }

  String get _currentStatus => CallEngineService.instance.callStatus;

  String get _callType => widget.isVideoCall ? 'video' : 'voice';

  Future<void> _syncCallTypeToFirestore(String callId, bool isVideoCall) async {
    if (callId.trim().isEmpty) return;

    try {
      await FirebaseFirestore.instance
          .collection('call_logs')
          .doc(callId.trim())
          .set({
        'callType': isVideoCall ? 'video' : 'voice',
        'type': isVideoCall ? 'video' : 'voice',
        'isVideoCall': isVideoCall,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Failed to sync call type: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    AppSettingsStore.instance.addListener(_onLanguageChanged);

    final incomingCallId = widget.callId?.trim() ?? '';
    if (incomingCallId.isNotEmpty) {
      CallEngineService.instance.listenToCall(incomingCallId);
    }
  }

  void _onLanguageChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    AppSettingsStore.instance.removeListener(_onLanguageChanged);
    _timeoutTimer?.cancel();
    _ringingTimer?.cancel();
    super.dispose();
  }

  Future<String?> _createCallIfNeeded() async {
    final active = CallEngineService.instance.activeCallId;
    if (active != null && active.trim().isNotEmpty) return active.trim();

    final existing = widget.callId?.trim() ?? '';
    if (existing.isNotEmpty) {
      CallEngineService.instance.listenToCall(existing);
      return existing;
    }

    if (_isCreatingCall) return CallEngineService.instance.activeCallId;

    _isCreatingCall = true;
    try {
      final callId = await CallEngineService.instance.createCall(
        receiverId: widget.volunteerId,
        receiverName: widget.volunteerName,
        isVideoCall: widget.isVideoCall,
      );
      return callId;
    } finally {
      _isCreatingCall = false;
    }
  }

  void _startRingingTimer() {
    _ringingTimer?.cancel();
    _ringingTimer = Timer(const Duration(seconds: 2), () async {
      if (!mounted) return;
      if (CallEngineService.instance.callStatus == 'calling') {
        await CallEngineService.instance.updateStatus('ringing');
      }
    });
  }

  void _startTimeoutWatcher() {
    _timeoutTimer?.cancel();
    _timeoutTimer = Timer(const Duration(seconds: 45), () async {
      if (!mounted) return;
      final status = CallEngineService.instance.callStatus;
      if (status == 'calling' || status == 'ringing') {
        await CallEngineService.instance.updateStatus('missed');
      }
    });
  }

  Future<void> _startOutgoingCall({required bool isVideoCall}) async {
    if (_isOpeningCall) return;

    final user = _auth.currentUser;
    if (user == null) {
      _showSnack(tr('Login required', 'تسجيل الدخول مطلوب'));
      return;
    }

    setState(() => _isOpeningCall = true);

    try {
      final callId = await _createCallIfNeeded();
      if (callId == null || callId.trim().isEmpty) {
        _showSnack(tr('Could not create call.', 'لم يتم إنشاء المكالمة.'));
        return;
      }

      await _syncCallTypeToFirestore(callId.trim(), isVideoCall);
      await CallEngineService.instance.updateStatus('calling');
      _startRingingTimer();
      _startTimeoutWatcher();

      if (!mounted) return;
      await _openCallRoom(callId: callId.trim(), isVideoCall: isVideoCall);
    } catch (e) {
      _showSnack('${tr('Call failed:', 'فشل الاتصال:')} $e');
    } finally {
      if (mounted) setState(() => _isOpeningCall = false);
    }
  }

  Future<void> _acceptIncomingCall({required bool isVideoCall}) async {
    if (_isOpeningCall) return;

    final callId = CallEngineService.instance.activeCallId ?? widget.callId;
    if (callId == null || callId.trim().isEmpty) {
      _showSnack(tr('No call found.', 'لا توجد مكالمة.'));
      return;
    }

    setState(() => _isOpeningCall = true);

    try {
      await _syncCallTypeToFirestore(callId.trim(), isVideoCall);
      await CallEngineService.instance.acceptCall(callId.trim());
      if (!mounted) return;
      await _openCallRoom(callId: callId.trim(), isVideoCall: isVideoCall);
    } catch (e) {
      _showSnack('${tr('Could not accept call:', 'لم يتم قبول المكالمة:')} $e');
    } finally {
      if (mounted) setState(() => _isOpeningCall = false);
    }
  }

  Future<void> _rejectIncomingCall() async {
    final callId = CallEngineService.instance.activeCallId ?? widget.callId;
    if (callId != null && callId.trim().isNotEmpty) {
      await CallEngineService.instance.rejectCall(callId.trim());
    }
    if (!mounted) return;
    if (Navigator.canPop(context)) Navigator.pop(context);
  }

  Future<void> _endCall() async {
    await CallEngineService.instance.endCall();
    if (!mounted) return;
    setState(() => _isOpeningCall = false);
  }

  Future<void> _openCallRoom({
    required String callId,
    required bool isVideoCall,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final userName = await CallEngineService.instance.getCurrentUserName();

    if (!mounted) return;

    final config = isVideoCall
        ? ZegoUIKitPrebuiltCallConfig.oneOnOneVideoCall()
        : ZegoUIKitPrebuiltCallConfig.oneOnOneVoiceCall();

    config.turnOnCameraWhenJoining = isVideoCall;
    config.turnOnMicrophoneWhenJoining = true;
    config.useSpeakerWhenJoining = true;

    await Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => ZegoUIKitPrebuiltCall(
          appID: ZegoConfig.appID,
          appSign: ZegoConfig.appSign,
          userID: user.uid,
          userName: userName,
          callID: callId,
          config: config,
        ),
      ),
    );

    await _endCall();
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String _statusText(String status) {
    switch (status) {
      case 'calling':
        return tr('Calling...', 'جاري الاتصال...');
      case 'ringing':
        return tr('Ringing...', 'يرن...');
      case 'accepted':
        return tr('Connected', 'متصل');
      case 'rejected':
        return tr('Rejected', 'مرفوض');
      case 'missed':
        return tr('Missed Call', 'مكالمة فائتة');
      case 'ended':
        return tr('Call Ended', 'انتهت المكالمة');
      case 'failed':
        return tr('Failed', 'فشل');
      default:
        return widget.isIncoming
            ? (widget.isVideoCall
                ? tr('Incoming video call', 'مكالمة فيديو واردة')
                : tr('Incoming voice call', 'مكالمة صوتية واردة'))
            : tr('Choose call type', 'اختاري نوع المكالمة');
    }
  }

  bool _showLoading(String status) {
    return status == 'calling' || status == 'ringing' || _isOpeningCall;
  }

  Widget _buildBackButton(String status) {
    return Row(
      children: [
        IconButton(
          onPressed: () async {
            if (status == 'calling' ||
                status == 'ringing' ||
                status == 'accepted') {
              await _endCall();
            }

            if (!mounted) return;
            if (Navigator.canPop(context)) Navigator.pop(context);
          },
          icon: Icon(
            isArabic ? Icons.arrow_forward : Icons.arrow_back,
            color: textColor,
            size: isSmallScreen ? 24 : 28,
          ),
        ),
        const Spacer(),
      ],
    );
  }

  Widget _buildProfileHeader(String status) {
    final firstLetter = widget.volunteerName.trim().isNotEmpty
        ? widget.volunteerName.trim()[0].toUpperCase()
        : 'V';

    return Column(
      children: [
        CircleAvatar(
          radius: isSmallScreen ? 40 : 45,
          backgroundColor: Colors.white,
          child: Text(
            firstLetter,
            style: TextStyle(
              fontSize: isSmallScreen ? 30 : 35,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF025590),
            ),
          ),
        ),
        SizedBox(height: isSmallScreen ? 16 : 20),
        Text(
          widget.volunteerName,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: textColor,
            fontSize: isSmallScreen ? 20 : 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: isSmallScreen ? 8 : 10),
        Text(
          _statusText(status),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: subTextColor,
            fontSize: isSmallScreen ? 14 : 16,
          ),
        ),
      ],
    );
  }

  Widget _buildOutgoingOptions(String status) {
    final bool disabled = _isOpeningCall ||
        status == 'calling' ||
        status == 'ringing' ||
        status == 'accepted';

    return Column(
      children: [
        Text(
          tr(
            'Start a direct call',
            'ابدئي مكالمة مباشرة',
          ),
          textAlign: TextAlign.center,
          style: TextStyle(
            color: subTextColor,
            fontSize: isSmallScreen ? 14 : 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: isSmallScreen ? 16 : 20),
        LayoutBuilder(
          builder: (context, constraints) {
            final bool stack = constraints.maxWidth < 700;
            final cards = [
              Expanded(
                child: _callCard(
                  title: tr('Voice Call', 'مكالمة صوتية'),
                  subtitle: tr('Tap anywhere on this card to start',
                      'اضغطي على الكرت للاتصال'),
                  icon: Icons.call_rounded,
                  color: const Color(0xFF29C765),
                  enabled: !disabled,
                  onTap: () => _startOutgoingCall(isVideoCall: false),
                ),
              ),
              Expanded(
                child: _callCard(
                  title: tr('Video Call', 'مكالمة فيديو'),
                  subtitle: tr('Tap anywhere on this card to start',
                      'اضغطي على الكرت للاتصال'),
                  icon: Icons.videocam_rounded,
                  color: const Color(0xFF29C765),
                  enabled: !disabled,
                  onTap: () => _startOutgoingCall(isVideoCall: true),
                ),
              ),
            ];

            if (stack) {
              return Column(
                children: [
                  SizedBox(width: double.infinity, child: cards[0].child),
                  const SizedBox(height: 14),
                  SizedBox(width: double.infinity, child: cards[1].child),
                ],
              );
            }

            return Row(
              children: [
                cards[0],
                const SizedBox(width: 16),
                cards[1],
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildIncomingActions(String status) {
    final bool canAnswer = !_isOpeningCall &&
        status != 'accepted' &&
        status != 'rejected' &&
        status != 'ended' &&
        status != 'missed';

    return Column(
      children: [
        Text(
          tr('Answer or reject the call', 'قبلي أو ارفضي المكالمة'),
          textAlign: TextAlign.center,
          style: TextStyle(
            color: subTextColor,
            fontSize: isSmallScreen ? 14 : 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: isSmallScreen ? 16 : 20),
        Row(
          children: [
            Expanded(
              child: _actionButton(
                text: tr('Reject', 'رفض'),
                icon: Icons.call_end_rounded,
                color: Colors.redAccent,
                onPressed: canAnswer ? _rejectIncomingCall : null,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _actionButton(
                text: widget.isVideoCall
                    ? tr('Accept Video', 'قبول فيديو')
                    : tr('Accept Voice', 'قبول صوت'),
                icon: widget.isVideoCall
                    ? Icons.videocam_rounded
                    : Icons.call_rounded,
                color: const Color(0xFF29C765),
                onPressed: canAnswer
                    ? () => _acceptIncomingCall(isVideoCall: widget.isVideoCall)
                    : null,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _callCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: enabled ? onTap : null,
        child: Container(
          constraints: const BoxConstraints(minHeight: 178),
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: const Color(0xFF87CEEB).withOpacity(0.65),
              width: 1.4,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: const Color(0xFF025590),
                size: isSmallScreen ? 30 : 34,
              ),
              const SizedBox(height: 10),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: textColor,
                  fontSize: isSmallScreen ? 15 : 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: subTextColor,
                  fontSize: isSmallScreen ? 11 : 12,
                ),
              ),
              const SizedBox(height: 14),
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: enabled ? color : color.withOpacity(0.35),
                ),
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: 30,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _actionButton({
    required String text,
    required IconData icon,
    required Color color,
    required VoidCallback? onPressed,
  }) {
    return SizedBox(
      height: isSmallScreen ? 48 : 52,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          disabledBackgroundColor: color.withOpacity(0.35),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  Widget _buildEndCallButton(String status) {
    if (status != 'calling' && status != 'ringing' && status != 'accepted') {
      return const SizedBox.shrink();
    }

    return SizedBox(
      width: double.infinity,
      height: isSmallScreen ? 46 : 50,
      child: ElevatedButton.icon(
        onPressed: _endCall,
        icon: const Icon(Icons.call_end_rounded),
        label: Text(
          tr('End Call', 'إنهاء المكالمة'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.redAccent,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginRequired() {
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
            child: Scaffold(
              resizeToAvoidBottomInset: true,
              backgroundColor: backgroundColor,
              body: SafeArea(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      tr('Login required', 'تسجيل الدخول مطلوب'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: textColor,
                        fontSize: isSmallScreen ? 16 : 18,
                      ),
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

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;

    if (user == null) {
      return _buildLoginRequired();
    }

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
              onTap: () => FocusScope.of(context).unfocus(),
              child: Scaffold(
                resizeToAvoidBottomInset: true,
                backgroundColor: backgroundColor,
                body: SafeArea(
                  child: StreamBuilder<String>(
                    stream: CallEngineService.instance.statusStream,
                    initialData: CallEngineService.instance.callStatus,
                    builder: (context, snapshot) {
                      final status = snapshot.data ?? _currentStatus;

                      return LayoutBuilder(
                        builder: (context, constraints) {
                          return SingleChildScrollView(
                            keyboardDismissBehavior:
                                ScrollViewKeyboardDismissBehavior.onDrag,
                            padding: EdgeInsets.symmetric(
                              horizontal: isSmallScreen ? 18 : 20,
                              vertical: isSmallScreen ? 10 : 20,
                            ),
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                minHeight: constraints.maxHeight -
                                    (isSmallScreen ? 20 : 40),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _buildBackButton(status),
                                  SizedBox(height: isSmallScreen ? 18 : 25),
                                  _buildProfileHeader(status),
                                  SizedBox(height: isSmallScreen ? 34 : 55),
                                  if (_showLoading(status)) ...[
                                    Center(
                                      child: CircularProgressIndicator(
                                        color: textColor,
                                      ),
                                    ),
                                    SizedBox(height: isSmallScreen ? 20 : 24),
                                  ],
                                  if (widget.isIncoming)
                                    _buildIncomingActions(status)
                                  else
                                    _buildOutgoingOptions(status),
                                  SizedBox(height: isSmallScreen ? 20 : 25),
                                  _buildEndCallButton(status),
                                  SizedBox(height: isSmallScreen ? 30 : 40),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
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
