import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'VolunteerHelpCall.dart';
import 'call_engine_service.dart';
import 'app_settings_store.dart';

class IncomingCallPage extends StatefulWidget {
  final String callId;
  final String callerId;
  final String callerName;
  final String volunteerId;
  final String? photoUrl;

  const IncomingCallPage({
    super.key,
    required this.callId,
    required this.callerId,
    required this.callerName,
    required this.volunteerId,
    this.photoUrl,
  });

  @override
  State<IncomingCallPage> createState() => _IncomingCallPageState();
}

class _IncomingCallPageState extends State<IncomingCallPage> {
  bool _handled = false;

  bool get isArabic => AppSettingsStore.instance.isArabic;

  Color get backgroundColor => Theme.of(context).scaffoldBackgroundColor;

  Color get textColor =>
      Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;

  Color get subTextColor => Colors.black54;

  String tr(String en, String ar) {
    return isArabic ? ar : en;
  }

  bool get isSmallScreen {
    final width = MediaQuery.maybeOf(context)?.size.width ?? 400;
    return width < 380;
  }

  @override
  void initState() {
    super.initState();

    AppSettingsStore.instance.addListener(_languageListener);

    CallEngineService.instance.listenToCall(widget.callId);
    CallEngineService.instance.updateStatus('ringing');

    _listenToCallChanges();
    _autoMissed();
  }

  @override
  void dispose() {
    AppSettingsStore.instance.removeListener(_languageListener);
    super.dispose();
  }

  void _languageListener() {
    if (mounted) {
      setState(() {});
    }
  }

  void _listenToCallChanges() {
    CallEngineService.instance.listenToCall(widget.callId);

    CallEngineService.instance.statusStream.listen((status) {
      if (!mounted || _handled) return;

      if (status == 'ended' ||
          status == 'missed' ||
          status == 'rejected' ||
          status == 'failed') {
        _handled = true;
        Navigator.pop(context);
      }
    });
  }

  void _accept(BuildContext context) async {
    if (_handled) return;

    _handled = true;

    await CallEngineService.instance.acceptCall(widget.callId);

    if (!mounted) return;

    Navigator.pop(context);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VolunteerHelpCallPage(
          callId: widget.callId,
          volunteerId:
              widget.callerId.isNotEmpty ? widget.callerId : widget.volunteerId,
          volunteerName: widget.callerName,
          isIncoming: true,
        ),
      ),
    );
  }

  void _reject(BuildContext context) async {
    if (_handled) return;

    _handled = true;

    await CallEngineService.instance.rejectCall(widget.callId);

    if (!mounted) return;

    Navigator.pop(context);
  }

  void _autoMissed() async {
    await Future.delayed(const Duration(seconds: 25));

    if (!_handled) {
      _handled = true;

      await CallEngineService.instance.markMissed(widget.callId);

      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  Widget _buildCallButton({
    required String heroTag,
    required Color color,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: isSmallScreen ? 68 : 76,
      height: isSmallScreen ? 68 : 76,
      child: FloatingActionButton(
        heroTag: heroTag,
        backgroundColor: color,
        elevation: 4,
        onPressed: onTap,
        child: Icon(
          icon,
          size: isSmallScreen ? 28 : 32,
          color: Colors.white,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasPhoto = widget.photoUrl != null && widget.photoUrl!.isNotEmpty;

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
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        physics: const NeverScrollableScrollPhysics(),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: constraints.maxHeight,
                          ),
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: isSmallScreen ? 20 : 28,
                            ),
                            child: Column(
                              children: [
                                const Spacer(),
                                Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.25),
                                        blurRadius: 18,
                                        offset: const Offset(0, 6),
                                      ),
                                    ],
                                  ),
                                  child: CircleAvatar(
                                    radius: isSmallScreen ? 50 : 60,
                                    backgroundColor: Colors.white,
                                    backgroundImage: hasPhoto
                                        ? NetworkImage(widget.photoUrl!)
                                        : null,
                                    child: !hasPhoto
                                        ? Icon(
                                            Icons.person,
                                            size: isSmallScreen ? 50 : 60,
                                            color: Colors.grey,
                                          )
                                        : null,
                                  ),
                                ),
                                SizedBox(height: isSmallScreen ? 18 : 20),
                                Text(
                                  widget.callerName,
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: textColor,
                                    fontSize: isSmallScreen ? 22 : 26,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: isSmallScreen ? 8 : 10),
                                Text(
                                  tr(
                                    "Incoming Call...",
                                    "مكالمة واردة...",
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: subTextColor,
                                    fontSize: isSmallScreen ? 14 : 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const Spacer(),
                                Wrap(
                                  alignment: WrapAlignment.center,
                                  spacing: isSmallScreen ? 40 : 55,
                                  runSpacing: 20,
                                  children: [
                                    _buildCallButton(
                                      heroTag: "reject",
                                      color: Colors.red,
                                      icon: Icons.call_end,
                                      onTap: () => _reject(context),
                                    ),
                                    _buildCallButton(
                                      heroTag: "accept",
                                      color: Colors.green,
                                      icon: Icons.call,
                                      onTap: () => _accept(context),
                                    ),
                                  ],
                                ),
                                SizedBox(height: isSmallScreen ? 35 : 50),
                              ],
                            ),
                          ),
                        ),
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
