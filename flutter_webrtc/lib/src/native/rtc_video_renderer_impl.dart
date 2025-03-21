import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../interface/media_stream.dart';
import '../interface/rtc_video_renderer.dart';

import '../helper.dart';
import 'utils.dart';

class RTCVideoRenderer extends ValueNotifier<RTCVideoValue>
    implements VideoRenderer {
  RTCVideoRenderer() : super(RTCVideoValue.empty);
  int? _textureId;
  MediaStream? _srcObject;
  StreamSubscription<dynamic>? _eventSubscription;

  @override
  Future<void> initialize() async {
    final response = await WebRTC.invokeMethod('createVideoRenderer', {});
    _textureId = response['textureId'];
    _eventSubscription = EventChannel('FlutterWebRTC/Texture$textureId')
        .receiveBroadcastStream()
        .listen(eventListener, onError: errorListener);
  }

  @override
  int get videoWidth => value.width.toInt();

  @override
  int get videoHeight => value.height.toInt();

  @override
  int? get textureId => _textureId;

  @override
  MediaStream? get srcObject => _srcObject;

  @override
  Function? onResize;
  Function? onFirstFrameRendered;

  @override
  set srcObject(MediaStream? stream) {
    if (textureId == null) throw 'Call initialize before setting the stream';

    _srcObject = stream;
    WebRTC.invokeMethod('videoRendererSetSrcObject', <String, dynamic>{
      'textureId': textureId,
      'streamId': stream?.id ?? '',
      'ownerTag': stream?.ownerTag ?? ''
    }).then((_) {
      value = (stream == null)
          ? RTCVideoValue.empty
          : value.copyWith(renderVideo: renderVideo);
    });
  }

  @override
  Future<void> dispose() async {
    await _eventSubscription?.cancel();
    await WebRTC.invokeMethod(
      'videoRendererDispose',
      <String, dynamic>{'textureId': _textureId},
    );

    return super.dispose();
  }

  void eventListener(dynamic event) {
    final Map<dynamic, dynamic> map = event;
    switch (map['event']) {
      case 'didTextureChangeRotation':
        value = value.copyWith(
          rotation: map['rotation'],
          renderVideo: renderVideo,
          firstFrameArrival: firstFrameArrival,
        );
        onResize?.call();
        break;
      case 'didTextureChangeVideoSize':
        value = value.copyWith(
          width: 0.0 + map['width'],
          height: 0.0 + map['height'],
          renderVideo: renderVideo,
          firstFrameArrival: firstFrameArrival,
        );
        onResize?.call();
        break;
      case 'didFirstFrameRendered':
        if (kDebugMode) {
          // print("第一帧");
        }
        value = value.copyWith(firstFrameArrival: true);
        onFirstFrameRendered?.call();
        break;
    }
  }

  void errorListener(Object obj) {
    if (obj is Exception) {
      throw obj;
    }
  }

  @override
  bool get renderVideo => srcObject != null;

  bool get firstFrameArrival => value.firstFrameArrival;

  @override
  bool get muted => _srcObject?.getAudioTracks()[0].muted ?? true;

  @override
  set muted(bool mute) {
    if (_srcObject == null) {
      throw Exception('Can\'t be muted: The MediaStream is null');
    }
    if (_srcObject!.ownerTag != 'local') {
      throw Exception(
          'You\'re trying to mute a remote track, this is not supported');
    }
    if (_srcObject!.getAudioTracks().isEmpty) {
      throw Exception('Can\'t be muted: The MediaStreamTrack(audio) is empty');
    }

    Helper.setMicrophoneMute(mute, _srcObject!.getAudioTracks()[0]);
  }

  @override
  Future<bool> audioOutput(String deviceId) {
    // TODO(rhrtc): related to https://github.com/flutter-webrtc/flutter-webrtc/issues/395
    throw UnimplementedError('This is not implement yet');
  }
}
