import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import '../incoming_call_page.dart';

class FCMService {
  static FirebaseMessaging messaging = FirebaseMessaging.instance;
  static GlobalKey<NavigatorState>? navKey;

  static bool _isNavigating = false;

  static Future<void> init(GlobalKey<NavigatorState> key) async {
    navKey = key;

    await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    final initialMessage = await messaging.getInitialMessage();
    if (initialMessage != null) {
      _handle(initialMessage.data);
    }

    FirebaseMessaging.onMessage.listen((msg) {
      _handleForeground(msg);
    });

    FirebaseMessaging.onMessageOpenedApp.listen((msg) {
      _handle(msg.data);
    });
  }

  static void _handleForeground(RemoteMessage msg) {
    final data = msg.data;

    if (data['type'] == 'call') {
      _handle(data);
    }
  }

  static void _handle(Map data) {
    if (_isNavigating) return;

    final type = data['type'];
    if (type != 'call') return;

    final callId = data['callId']?.toString() ?? '';
    if (callId.isEmpty) return;

    _isNavigating = true;

    navKey?.currentState
        ?.push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => IncomingCallPage(
          callId: callId,
          callerId: data['callerId']?.toString() ?? '',
          callerName: data['callerName']?.toString() ?? 'Someone',
          volunteerId: data['volunteerId']?.toString() ?? '',
          photoUrl: data['photoUrl']?.toString() ?? '',
        ),
      ),
    )
        .then((_) {
      _isNavigating = false;
    });
  }

  static Map<String, dynamic> payload({
    required String callId,
    required String callerId,
    required String callerName,
    required String volunteerId,
    String? photoUrl,
  }) {
    return {
      'type': 'call',
      'callId': callId,
      'callerId': callerId,
      'callerName': callerName,
      'volunteerId': volunteerId,
      'photoUrl': photoUrl ?? '',
    };
  }
}
