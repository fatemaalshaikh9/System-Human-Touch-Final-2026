import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'app_settings_store.dart';

class CallEngineService {
  static final instance = CallEngineService._();

  CallEngineService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _activeCallSub;

  String? activeCallId;
  String callStatus = 'idle';

  final StreamController<String> _statusController =
      StreamController<String>.broadcast();

  Stream<String> get statusStream => _statusController.stream;

  DocumentReference<Map<String, dynamic>> callRef(String callId) {
    return _firestore.collection('call_logs').doc(callId);
  }

  Future<String> getCurrentUserName() async {
    final user = _auth.currentUser;

    if (user == null) {
      return AppSettingsStore.instance.isArabic ? 'مستخدم' : 'User';
    }

    final doc = await _firestore.collection('users').doc(user.uid).get();

    final data = doc.data() ?? {};

    return data['name'] ??
        data['fullName'] ??
        data['username'] ??
        (AppSettingsStore.instance.isArabic ? 'مستخدم' : 'User');
  }

  Future<String?> createCall({
    required String receiverId,
    required String receiverName,
    required bool isVideoCall,
  }) async {
    final user = _auth.currentUser;

    if (user == null) return null;

    final callerName = await getCurrentUserName();

    final doc = _firestore.collection('call_logs').doc();

    await doc.set({
      'receiverId': receiverId,
      'receiverName': receiverName,
      'status': 'calling',
      'callType': isVideoCall ? 'video' : 'voice',
      'type': isVideoCall ? 'video' : 'voice',
      'isVideoCall': isVideoCall,
      'createdAt': FieldValue.serverTimestamp(),
    });

    listenToCall(doc.id);

    return doc.id;
  }

  void listenToCall(String callId) {
    activeCallId = callId;

    _activeCallSub?.cancel();

    _activeCallSub = callRef(callId).snapshots().listen((doc) {
      if (!doc.exists) return;

      final data = doc.data() ?? {};

      final status = data['status']?.toString() ?? 'idle';

      callStatus = status;

      _statusController.add(status);
    });
  }

  Future<void> updateStatus(String status) async {
    if (activeCallId == null) return;

    await callRef(activeCallId!).set({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> acceptCall(String callId) async {
    activeCallId = callId;

    listenToCall(callId);

    await updateStatus('accepted');
  }

  Future<void> rejectCall(String callId) async {
    activeCallId = callId;

    listenToCall(callId);

    await updateStatus('rejected');

    stopListening();
  }

  Future<void> endCall() async {
    await updateStatus('ended');

    stopListening();
  }

  Future<void> markMissed(String callId) async {
    activeCallId = callId;

    listenToCall(callId);

    final doc = await callRef(callId).get();

    final status = doc.data()?['status']?.toString();

    if (status == 'calling' || status == 'ringing') {
      await updateStatus('missed');
    }

    stopListening();
  }

  void stopListening() {
    _activeCallSub?.cancel();

    _activeCallSub = null;

    activeCallId = null;

    callStatus = 'idle';

    _statusController.add('idle');
  }
}
