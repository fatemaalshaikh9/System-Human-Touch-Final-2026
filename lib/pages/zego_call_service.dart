import 'package:zego_uikit_prebuilt_call/zego_uikit_prebuilt_call.dart';
import 'package:zego_uikit_signaling_plugin/zego_uikit_signaling_plugin.dart';

import 'zego_config.dart';

class ZegoCallService {
  static final instance = ZegoCallService._();
  ZegoCallService._();

  bool _init = false;
  String? userID;

  String? get currentUserID => userID;

  Future<void> init({
    required String userID,
    required String userName,
  }) async {
    if (_init && this.userID == userID) return;

    if (_init && this.userID != userID) {
      await uninit();
    }

    this.userID = userID;

    await ZegoUIKitPrebuiltCallInvitationService().init(
      appID: ZegoConfig.appID,
      appSign: ZegoConfig.appSign,
      userID: userID,
      userName: userName,
      plugins: [
        ZegoUIKitSignalingPlugin(),
      ],
      requireConfig: (data) {
        final config = ZegoUIKitPrebuiltCallConfig.oneOnOneVideoCall();

        config.turnOnCameraWhenJoining = true;
        config.turnOnMicrophoneWhenJoining = true;
        config.useSpeakerWhenJoining = true;

        return config;
      },
    );

    _init = true;
  }

  Future<void> uninit() async {
    await ZegoUIKitPrebuiltCallInvitationService().uninit();
    _init = false;
    userID = null;
  }
}
