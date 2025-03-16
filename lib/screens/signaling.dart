// ignore_for_file: avoid_print, unnecessary_null_comparison, non_constant_identifier_names, unused_field, unused_local_variable, avoid_function_literals_in_foreach_calls, prefer_interpolation_to_compose_strings, unused_element, constant_identifier_names

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:path_provider/path_provider.dart';

import '../utils/LogUtil.dart';
import 'random_string.dart';

enum SignalingState {
  ConnectionOpen,
  ConnectionClosed,
  ConnectionError,
}

enum RecordState {
  Redording,
  RecordClosed,
}

enum CallState {
  CallStateNew,
  CallStateRinging,
  CallStateInvite,
  CallStateConnected,
  CallStateBye,
}

enum OnlineState {
  OnLine,
  OffLine,
  Sleep,
  Error,
}

class Session {
  Session({required this.sid, required this.pid});
  String pid;
  String sid;
  bool audio = false;
  bool video = false;
  bool datachannel = false;
  bool datachannel_opened = false;
  bool onlydatachnannel = false;
  final bool _offered = false;
  RecordState redordstate = RecordState.RecordClosed;
  RTCPeerConnection? pc;
  RTCDataChannel? dc;
  final List<MediaStream> _remoteStreams = <MediaStream>[];
  List<RTCIceCandidate> remoteCandidates = [];
}

class Signaling {
  Signaling(
      this._selfId, this._peerId, this._onlydatachnannel, this._localvideo);

  final JsonEncoder _encoder = const JsonEncoder();
  final JsonDecoder _decoder = const JsonDecoder();
  final String _selfId;
  final String _peerId;
  String _Mode = "";
  String _Source = "";
  String _User = "";
  String _Password = "";
  final bool _offered = false;
  String _SessionId = randomNumeric(32);
  final bool _onlydatachnannel;
  bool _localvideo = true;
  bool _localaudio = true;
  bool _video = true;
  bool _audio = true;
  bool _datachannel = true;
  final int _start_time_ = currentTimeMillis();
  final MediaRecorder _mediarecoder = MediaRecorder();
  final Map<String, Session> _sessions = {};
  MediaStream? _localStream;
  MediaStreamTrack? _remotevideotrack;

  List<RTCIceCandidate> remoteCandidates = [];

  Function(SignalingState state)? onSignalingStateChange;
  Function(Session session, CallState state)? onCallStateChange;
  Function(MediaStream stream)? onLocalStream;
  Function(Session session, MediaStream stream)? onAddRemoteStream;
  Function(Session session, MediaStream stream)? onRemoveRemoteStream;
  Function(Session session, String message)? onRecvSignalingMessage;
  Function(Session session, RTCDataChannel dc, RTCDataChannelMessage data)?
      onDataChannelMessage;
  Function(Session session, RTCDataChannel dc)? onDataChannel;
  Function(Session session, RTCDataChannelState state)? onDataChannelState;
  Function(Session session, RecordState state)? onRedordState;
  Function(String eventName, dynamic data)? onSendSignalMessge;
  Function(String sessionId, String peerId, OnlineState state)? onSessionCreate;
  Function(Session session, RTCPeerConnectionState state)?
      onSessionRTCConnectState;

  String get sdpSemantics =>
      WebRTC.platformIsWindows ? 'plan-b' : 'unified-plan';

  Map<String, dynamic> _iceServers = {
    'iceServers': [
      {'url': 'stun:webrtc.qq-kan.com:3478'},
    ]
  };

  final Map<String, dynamic> _config = {
    'mandatory': {},
    'optional': [
      {'DtlsSrtpKeyAgreement': true},
      {'googCpuOveruseDetection': false},
      {'googSuspendBelowMinBitrate': true},
    ]
  };

  final Map<String, dynamic> _dcConstraints = {
    'mandatory': {
      'OfferToReceiveAudio': true,
      'OfferToReceiveVideo': true,
    },
    'optional': [],
  };

  bool _isWeb() {
    return kIsWeb == true;
  }

  close() async {
    await _cleanSessions();
  }

  void switchCamera() {
    if (_localStream != null) {
      Helper.switchCamera(_localStream!.getVideoTracks()[0]);
    }
  }

  /*
    使能麦克风 本地声音使能
  */
  void muteMic(bool enabled) {
    if (_localStream != null) {
      _localStream!.getAudioTracks().forEach((track) {
        track.enabled = enabled;
      });
    } else {}
  }

  /*
    使能喇叭  对方声音使能播放
  */
  void muteAllSpeek(bool enabled) {
    _sessions.forEach((key, sess) async {
      for (int i = 0; i < sess._remoteStreams.length; i++) {
        MediaStream item = sess._remoteStreams[i];
        if (item != null) {
          item.getAudioTracks().forEach((track) {
            track.enabled = enabled;
          });
        }
      }
    });
  }

  void muteSpeekSession(String sessionId, bool enabled) {
    var sess = _sessions[sessionId];
    if (sess != null) {
      for (int i = 0; i < sess._remoteStreams.length; i++) {
        MediaStream item = sess._remoteStreams[i];
        if (item != null) {
          item.getAudioTracks().forEach((track) {
            track.enabled = enabled;
          });
        }
      }
    }
  }
  /*
     函数 ： 发起呼叫
     注：  生成一个会话并创建 RTCPeerConnection 并发起Offer
     参数：
     sessionId： 会话ID 用于表示这次会话
     peerId：    设备端ID
     audio：     是否需要音频
     video：     是否需要视频
     localaudio：     是否开始本地音频
     localvideo：     是否开始本地视频
     datachennel：    是否启用datachennel
     mode：       会话模式，用于表示是实时流，远程回放，下载等等，
     source：     会话源，用于表示会话的数据源，例如 实时流的时候。用于表示主通道跟其他通道数据
     user：       用户名，用于设备端校验
     password     用户密码，用于设备端校验
  */

  void invite(
      String sessionId,
      String peerId,
      bool audio,
      bool video,
      bool localaudio,
      bool localvideo,
      bool datachennel,
      String mode,
      String source,
      String user,
      String password) async {
    _SessionId = sessionId;
    _Mode = mode;
    _Source = source;
    _User = user;
    _Password = password;
    _video = video;
    _audio = audio;
    _datachannel = datachennel;
    _localvideo = localvideo;
    _localaudio = localaudio;

    Session session = await _createSession(null,
        peerId: peerId,
        sessionId: sessionId,
        audio: audio,
        video: video,
        dataChannel: datachennel);
    _sessions[sessionId] = session;
    if (datachennel) {
      _createDataChannel(session);
    }
    _createOffer(session, mode, source);
    onCallStateChange?.call(session, CallState.CallStateNew);
  }

  /*
     函数 ： 发起呼叫
     注：  发送一个_call 信令，让设备端发起呼叫
     参数：
     sessionId： 会话ID 用于表示这次会话
     peerId：    设备端ID
     audio：     是否需要音频
     video：     是否需要视频
     localaudio：     是否开始本地音频
     localvideo：     是否开始本地视频
     datachennel：    是否启用datachennel
     mode：       会话模式，用于表示是实时流，远程回放，下载等等，
     source：     会话源，用于表示会话的数据源，例如 实时流的时候。用于表示主通道跟其他通道数据
     user：       用户名，用于设备端校验
     password     用户密码，用于设备端校验
  */
  void startcall(
      String sessionId,
      String peerId,
      bool audio,
      bool video,
      bool localaudio,
      bool localvideo,
      bool datachennel,
      String mode,
      String source,
      String user,
      String password) {
    var delay = currentTimeMillis() - _start_time_;
    print(
        '<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<  send call use time  :$delay');
    _Mode = mode;
    _Source = source;
    _localvideo = localvideo;
    _localaudio = localaudio;
    _video = video;
    _audio = audio;
    _datachannel = datachennel;
    var datachanneldir = 'true';
    var audiodir = 'sendrecv';
    var videodir = 'sendrecv';
    if (video == true && localvideo == false) {
      videodir = 'recvonly';
    } else if (video == true && localvideo == true) {
      videodir = 'sendrecv';
    } else {
      videodir = 'false';
    }
    if (datachennel == true) {
      datachanneldir = 'true';
    } else {
      datachanneldir = 'false';
    }
    if (audio == true && localaudio == true) {
      audiodir = 'sendrecv';
    } else if (audio == true && localaudio == false) {
      audiodir = 'recvonly';
    } else {
      audiodir = 'false';
    }

    _send('__call', {
      "sessionId": sessionId,
      'sessionType': "flutter",
      'messageId': randomNumeric(32),
      'from': _selfId,
      'to': peerId,
      "mode": mode,
      "source": source,
      "datachannel": datachanneldir,
      "audio": audiodir,
      "video": videodir,
      "user": user,
      "pwd": password,
      "iceservers": _encoder.convert(_iceServers)
    });
  }

  /*
    使用信令通道给设备发送信息
  */
  void postmessage(String sessionId, String message) async {
    var sess = _sessions[sessionId];
    if (sess != null) {
      _send('__post_message', {
        "sessionId": sess.sid,
        'sessionType': "flutter",
        'messageId': randomNumeric(32),
        'from': _selfId,
        'to': sess.pid,
        "message": message
      });
    }
  }

  /*
    发送 __disconnected 信令给设备。让设备断开链接
  */
  void bye(String sessionId) {
    var sess = _sessions[sessionId];
    if (sess != null) {
      _send('__disconnected', {
        "sessionId": sess.sid,
        'sessionType': "flutter",
        'messageId': randomNumeric(32),
        'from': _selfId,
        'to': sess.pid
      });

      _closeSession(sess);
    }
  }

  int compare(String str1, String str2) {
    var res = Comparable.compare(str1, str2);
    return res;
  }

  void onMessage(message) async {
    print('onMessage recv $message');
    Map<String, dynamic> mapData = _decoder.convert(message);
    var data = mapData['data'];
    var eventName = mapData['eventName'];
    switch (eventName) {
      case '_create':
        {
          var sessionId = data['sessionId'];
          var peerId = data['from'];
          if (compare(sessionId, _SessionId) == 0) {
            var iceServers = data['iceServers'];
            if (iceServers != null) {
              if (iceServers is String) {
                print('onMessage iceServers $iceServers');
                _iceServers = _decoder.convert(iceServers);
              } else {
                var subiceServers = iceServers['iceServers'];
                if (subiceServers == null) {
                  _iceServers = subiceServers;
                } else {
                  _iceServers = iceServers;
                }
              }
            }
            var state = data['state'];
            if (state != null) {
              if (compare(state, "online") == 0) {
                onSessionCreate?.call(sessionId, peerId, OnlineState.OnLine);
              } else if (compare(state, "sleep") == 0) {
                onSessionCreate?.call(sessionId, peerId, OnlineState.Sleep);
              } else {
                onSessionCreate?.call(sessionId, peerId, OnlineState.OffLine);
              }
            } else {
              // print('_create sessionId = $sessionId   _SessionId = $_SessionId');
              onSessionCreate?.call(sessionId, peerId, OnlineState.Error);
            }
          } else {
            //print('_create sessionId ----------=$sessionId   _SessionId =$_SessionId');
            onSessionCreate?.call(sessionId, peerId, OnlineState.Error);
          }
        }
        break;
      case '_call':
        {
          var sessionId = data['sessionId'];
          if (sessionId == null) {
            return;
          }
          var peerId = data['from'];
          if (peerId == null) {
            return;
          }
          var iceServers = data['iceservers'];
          if (iceServers != null) {
            print('_call iceServers ----------=$iceServers');
            _iceServers = _decoder.convert(iceServers);
          }
          var datachannel = data['datachannel'];
          var audiodir = data['audio'];
          var videodir = data['video'];
          var user = data['user'];
          var pwd = data['pwd'];
          var usedatachannel = false;
          var useaudio = false;
          var usevideo = false;
          if (datachannel == null) {
          } else {
            if (compare(datachannel, "true") == 0) {
              usedatachannel = true;
            }
          }
          if (audiodir == null) {
          } else {
            if (compare(audiodir, "sendrecv") == 0) {
              useaudio = true;
              _localaudio = true;
            } else if (compare(audiodir, "sendonly") == 0) {
              useaudio = true;
              _localaudio = true;
            } else if (compare(audiodir, "recvonly") == 0) {
              useaudio = true;
              _localaudio = false;
            } else if (compare(audiodir, "true") == 0) {
              useaudio = true;
              _localaudio = true;
            }
          }

          if (videodir == null) {
          } else {
            if (compare(videodir, "sendrecv") == 0) {
              usevideo = true;
              _localvideo = true;
            } else if (compare(videodir, "sendonly") == 0) {
              usevideo = true;
              _localvideo = true;
            } else if (compare(videodir, "recvonly") == 0) {
              usevideo = false;
              _localvideo = false;
            } else if (compare(videodir, "true") == 0) {
              usevideo = true;
              _localvideo = true;
            }
          }
          invite(sessionId, peerId, useaudio, usevideo, _localaudio,
              _localvideo, usedatachannel, _Mode, _Source, _User, _Password);
        }
        break;
      case '_offer':
        {
          var delay = currentTimeMillis() - _start_time_;
          print(
              '<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<  recv offer use time  :$delay');
          var iceServers = data['iceservers'];
          //  print('<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<  recv offer iceServers  :$iceServers');
          if (iceServers != null && iceServers.toString().isNotEmpty) {
            _iceServers = _decoder.convert(iceServers);
          }
          var peerId = data['from'];
          var sdp = data['sdp'];
          LogUtil.v("_offer $sdp");
          var datachannel = data['datachannel'];
          var audiodir = data['audio'];
          var videodir = data['video'];
          var user = data['user'];
          var pwd = data['pwd'];
          var usedatachannel = true;
          var useaudio = true;
          var usevideo = false;
          if (datachannel == null) {
          } else {
            if (compare(datachannel, "true") == 0) {
              usedatachannel = true;
            }
          }
          if (audiodir == null) {
          } else {
            if (compare(audiodir, "sendrecv") == 0) {
              useaudio = true;
              _localaudio = true;
            } else if (compare(audiodir, "sendonly") == 0) {
              useaudio = true;
              _localaudio = false;
            } else if (compare(audiodir, "recvonly") == 0) {
              useaudio = true;
              _localaudio = true;
            } else if (compare(audiodir, "true") == 0) {
              useaudio = true;
              _localaudio = true;
            }
          }
          if (videodir == null) {
          } else {
            if (compare(videodir, "sendrecv") == 0) {
              usevideo = true;
              _localvideo = true;
            } else if (compare(videodir, "sendonly") == 0) {
              usevideo = true;
              _localvideo = false;
            } else if (compare(videodir, "recvonly") == 0) {
              usevideo = true;
              _localvideo = true;
            } else if (compare(videodir, "true") == 0) {
              usevideo = true;
              _localvideo = true;
            }
          }
          var sessionId = data['sessionId'];
          var session = _sessions[sessionId];
          var newSession = await _createSession(session,
              peerId: peerId,
              sessionId: sessionId,
              audio: useaudio,
              video: usevideo,
              dataChannel: usedatachannel);
          _sessions[sessionId] = newSession;
          if (newSession != null && usedatachannel == true) {
            _createDataChannel(newSession);
          }

          await newSession.pc
              ?.setRemoteDescription(RTCSessionDescription(sdp, "offer"));
          await _createAnswer(newSession);
          if (newSession.remoteCandidates.isNotEmpty) {
            newSession.remoteCandidates.forEach((candidate) async {
              await newSession.pc?.addCandidate(candidate);
            });
            newSession.remoteCandidates.clear();
          }
          if (remoteCandidates.isNotEmpty) {
            remoteCandidates.forEach((candidate) async {
              var candi = candidate.candidate;
              print(
                  '<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<  recv offer addCandidate --- $candi');
              await newSession.pc?.addCandidate(candidate);
            });
            remoteCandidates.clear();
          }

          onCallStateChange?.call(newSession, CallState.CallStateNew);
        }
        break;
      case '_answer':
        {
          var type = data['type'];
          var sdp = data['sdp'];
          LogUtil.v("_answer $sdp");
          var sessionId = data['sessionId'];
          if (compare(sessionId, _SessionId) == 0) {
            var session = _sessions[sessionId];
            session?.pc?.setRemoteDescription(RTCSessionDescription(sdp, type));
          }
        }
        break;
      case '_ice_candidate':
        {
          var peerId = data['from'];
          var candidateMap = data['candidate'];
          var candidateobject = _decoder.convert(candidateMap);
          var scandidate = candidateobject['candidate'];
          var nsdpMLineIndex = candidateobject['sdpMLineIndex'];
          var ssdpMid = candidateobject['sdpMid'];
          var sessionId = data['sessionId'];
          if (compare(sessionId, _SessionId) == 0) {
            print(
                'recv candidate-<<<-----------sdpMLineIndex :$nsdpMLineIndex sdpMid: $ssdpMid candidate: $scandidate');
            var session = _sessions[sessionId];
            RTCIceCandidate candidate =
                RTCIceCandidate(scandidate, ssdpMid, nsdpMLineIndex);

            if (session != null) {
              if (session.pc != null) {
                print('addCandidate-----------candidate: $scandidate');
                await session.pc?.addCandidate(candidate);
              } else {
                print('addCandidate-----------add tmp: $scandidate');
                session.remoteCandidates.add(candidate);
              }
            } else {
              remoteCandidates.add(candidate);

              print(
                  'addCandidate--------sessionId--$sessionId -add candidate------------: $scandidate');
              //_sessions[sessionId] = Session(pid: peerId, sid: sessionId)..remoteCandidates.add(candidate);
            }
          }
        }
        break;
      case '_disconnected':
        {
          var sessionId = data['sessionId'];
          if (compare(sessionId, _SessionId) == 0) {
            print('_disconnected: ' + sessionId);
            var session = _sessions.remove(sessionId);
            if (session != null) {
              onCallStateChange?.call(session, CallState.CallStateBye);
              _closeSession(session);
            }
          }
        }
        break;
      case '_session_failed':
        {
          var sessionId = data['sessionId'];
          if (compare(sessionId, _SessionId) == 0) {
            print('_session_failed: ' + sessionId);
            var session = _sessions.remove(sessionId);
            if (session != null) {
              onCallStateChange?.call(session, CallState.CallStateBye);
              _closeSession(session);
            }
          }
        }
        break;
      case '_post_message':
        {
          var sessionId = data['sessionId'];
          if (compare(sessionId, _SessionId) == 0) {
            var session = _sessions[sessionId];
            var message = data['message'];
            if (session != null) {
              onRecvSignalingMessage?.call(session, message);
            }
          }
        }
        break;
      case '_connectinfo':
        print('onMessage recv $message');
        break;
      case '_ping':
        {
          print('keepalive response!');
        }
        break;
      default:
        break;
    }
  }

  Future<void> connect() async {
    _send('__connectto', {
      'sessionId': _SessionId,
      'sessionType': "flutter",
      'messageId': randomNumeric(32),
      'from': _selfId,
      'to': _peerId
    });
  }

  Future<MediaStream> createLocalStream(
      bool audio, bool video, bool datachennel) async {
    print(
        'createLocalStream: audio = $audio  video= $video datachennel = $datachennel');
    Map<String, dynamic> mediaConstraints = {};
    if (audio == false && video == false && datachennel == true) {
      mediaConstraints = {'audio': false, 'video': false};
    } else if (audio == true &&
        video == true &&
        (_localaudio == true || _localvideo == true) &&
        datachennel == true) {
      mediaConstraints = {
        'audio': _localaudio,
        'video': _localvideo
            ? {
                'mandatory': {
                  'minWidth':
                      '1280', // Provide your own width, height and frame rate here
                  'minHeight': '720',
                  'minFrameRate': '30',
                },
                'facingMode': 'user',
                'optional': [],
              }
            : false
      };
    } else if (audio == true &&
        video == true &&
        (_localaudio == true || _localvideo == true) &&
        datachennel == false) {
      mediaConstraints = {'audio': _localaudio, 'video': _localvideo};
    } else if (audio == true &&
        video == false &&
        (_localaudio == true || _localvideo == true) &&
        datachennel == true) {
      mediaConstraints = {
        'audio': _localaudio,
        'video': _localvideo
            ? {
                'mandatory': {
                  'minWidth':
                      '1280', // Provide your own width, height and frame rate here
                  'minHeight': '720',
                  'minFrameRate': '30',
                },
                'facingMode': 'user',
                'optional': [],
              }
            : false
      };
    } else {
      mediaConstraints = {'audio': _localaudio, 'video': _localvideo};
    }

    MediaStream stream =
        await navigator.mediaDevices.getUserMedia(mediaConstraints);
    if (stream != null) {
      onLocalStream?.call(stream);
    }

    return stream;
  }

  Future<Session> _createSession(Session? session,
      {required String peerId,
      required String sessionId,
      required bool audio,
      required bool video,
      required bool dataChannel}) async {
    var newSession = session ?? Session(sid: sessionId, pid: peerId);
    newSession.audio = audio;
    newSession.video = video;
    newSession.datachannel = dataChannel;
    newSession.redordstate = RecordState.RecordClosed;
    if (_onlydatachnannel == false &&
        (_localaudio == true || _localvideo == true)) {
      _localStream = await createLocalStream(audio, video, dataChannel);
    }
    //print(_iceServers);
    //  ...{'tcpCandidatePolicy':'disabled'},
    //  ...{'disableIpv6':true},
    RTCPeerConnection pc = await createPeerConnection({
      ..._iceServers,
      ...{'tcpCandidatePolicy': 'disabled'},
      ...{'disableIpv6': true},
      ...{'sdpSemantics': sdpSemantics}
    }, _config);
    if (_onlydatachnannel == false) {
      switch (sdpSemantics) {
        case 'plan-b':
          pc.onAddStream = (MediaStream stream) {
            onAddRemoteStream?.call(newSession, stream);
            print('_add remote streams ');
            newSession._remoteStreams.add(stream);
          };
          if (_localStream != null) {
            await pc.addStream(_localStream!);
          }

          break;
        case 'unified-plan':
          // Unified-Plan
          pc.onTrack = (event) {
            onAddRemoteStream?.call(newSession, event.streams[0]);
            newSession._remoteStreams.add(event.streams[0]);
          };
          if (_localStream != null) {
            _localStream!.getTracks().forEach((track) {
              pc.addTrack(track, _localStream!);
            });
          }
          break;
      }

      // Unified-Plan: Simuclast
      /*
      await pc.addTransceiver(
        track: _localStream.getAudioTracks()[0],
        init: RTCRtpTransceiverInit(
            direction: TransceiverDirection.SendOnly, streams: [_localStream]),
      );

      await pc.addTransceiver(
        track: _localStream.getVideoTracks()[0],
        init: RTCRtpTransceiverInit(
            direction: TransceiverDirection.SendOnly,
            streams: [
              _localStream
            ],
            sendEncodings: [
              RTCRtpEncoding(rid: 'f', active: true),
              RTCRtpEncoding(
                rid: 'h',
                active: true,
                scaleResolutionDownBy: 2.0,
                maxBitrate: 150000,
              ),
              RTCRtpEncoding(
                rid: 'q',
                active: true,
                scaleResolutionDownBy: 4.0,
                maxBitrate: 100000,
              ),
            ]),
      );*/
      /*
        var sender = pc.getSenders().find(s => s.track.kind == "video");
        var parameters = sender.getParameters();
        if(!parameters)
          parameters = {};
        parameters.encodings = [
          { rid: "h", active: true, maxBitrate: 900000 },
          { rid: "m", active: true, maxBitrate: 300000, scaleResolutionDownBy: 2 },
          { rid: "l", active: true, maxBitrate: 100000, scaleResolutionDownBy: 4 }
        ];
        sender.setParameters(parameters);
      */
    } else {}

    pc.onIceCandidate = (candidate) async {
      if (candidate == null) {
        print('onIceCandidate: complete!');
        return;
      }
      var szcandidate = candidate.candidate;
      var sdpMLineIndex = candidate.sdpMLineIndex;
      var sdpMid = candidate.sdpMid;
      print(
          'send candidate -------------->> sdpMLineIndex: $sdpMLineIndex sdpMid: $sdpMid candidate: $szcandidate');

      // This delay is needed to allow enough time to try an ICE candidate
      // before skipping to the next one. 1 second is just an heuristic value
      // and should be thoroughly tested in your own environment.
      await Future.delayed(
          const Duration(milliseconds: 10),
          () => _send('__ice_candidate', {
                'sessionId': newSession.sid,
                'sessionType': "flutter",
                'messageId': randomNumeric(32),
                'from': _selfId,
                'to': newSession.pid,
                "candidate": _encoder.convert({
                  'candidate': candidate.candidate,
                  'sdpMid': candidate.sdpMid,
                  'sdpMLineIndex': candidate.sdpMLineIndex
                })
              }));
    };

    pc.onSignalingState = (state) {
      print('onSignalingState: $state');
    };
    pc.onConnectionState = (state) {
      print('onConnectionState: $state');
      onSessionRTCConnectState?.call(newSession, state);
    };
    pc.onIceGatheringState = (state) {
      print('onIceGatheringState: $state');
    };
    pc.onIceConnectionState = (state) {
      print('onIceConnectionState: $state');
    };
    pc.onAddStream = (stream) {
      stream.getVideoTracks().forEach((videoTrack) {
        _remotevideotrack ??= videoTrack;
      });
    };
    pc.onRemoveStream = (stream) {
      onRemoveRemoteStream?.call(newSession, stream);
      newSession._remoteStreams.removeWhere((it) {
        return (it.id == stream.id);
      });
      stream.getVideoTracks().forEach((videoTrack) {
        if (_remotevideotrack == videoTrack) {
          _remotevideotrack = null;
        }
      });
    };
    pc.onAddTrack = (stream, track) {
      if (track.kind == "video") {
        _remotevideotrack = track;
      }
    };
    pc.onRemoveTrack = (stream, track) {
      if (track.kind == "video") {
        if (_remotevideotrack == track) {
          _remotevideotrack = null;
        }
      }
    };
    pc.onDataChannel = (channel) {
      _addDataChannel(newSession, channel);
    };
    newSession.pc = pc;
    return newSession;
  }

  void _addDataChannel(Session session, RTCDataChannel channel) {
    channel.onDataChannelState = (e) {
      if (e == RTCDataChannelState.RTCDataChannelOpen) {
        session.datachannel_opened = true;
      } else if (e == RTCDataChannelState.RTCDataChannelClosing) {
        session.datachannel_opened = false;
      } else if (e == RTCDataChannelState.RTCDataChannelClosed) {
        session.datachannel_opened = false;
      } else if (e == RTCDataChannelState.RTCDataChannelConnecting) {
        session.datachannel_opened = false;
      }
      onDataChannelState?.call(session, e);
    };
    channel.onMessage = (RTCDataChannelMessage data) {
      onDataChannelMessage?.call(session, channel, data);
    };
    session.dc = channel;
    onDataChannel?.call(session, channel);
  }

  Future<void> _createDataChannel(Session session,
      {label = 'fileTransfer'}) async {
    RTCDataChannelInit dataChannelDict = RTCDataChannelInit()
      ..maxRetransmits = 30;
    RTCDataChannel channel =
        await session.pc!.createDataChannel(label, dataChannelDict);
    _addDataChannel(session, channel);
  }

  Future<void> _createOffer(Session session, String mode, String source) async {
    try {
      Map<String, dynamic> dcConstraints = {
        'mandatory': {
          'OfferToReceiveAudio': session.audio,
          'OfferToReceiveVideo': session.video,
        },
        'optional': [],
      };

      RTCSessionDescription s =
          await session.pc!.createOffer(_onlydatachnannel ? {} : dcConstraints);
      await session.pc!.setLocalDescription(s);
      LogUtil.v("_createOffer ${s.sdp}");

      var datachanneldir = 'true';
      var audiodir = 'sendrecv';
      var videodir = 'sendrecv';
      if (_video == true && _localvideo == false) {
        videodir = 'recvonly';
      } else if (_video == true && _localvideo == true) {
        videodir = 'sendrecv';
      } else {
        videodir = 'false';
      }
      if (_datachannel == true) {
        datachanneldir = 'true';
      } else {
        datachanneldir = 'false';
      }
      if (_audio == true && _localaudio == true) {
        audiodir = 'sendrecv';
      } else if (_audio == true && _localaudio == false) {
        audiodir = 'recvonly';
      } else {
        audiodir = 'false';
      }
      _send('__offer', {
        'sessionId': session.sid,
        'sessionType': "flutter",
        'messageId': randomNumeric(32),
        'from': _selfId,
        'to': session.pid,
        "type": s.type,
        "sdp": s.sdp,
        "mode": mode,
        "source": source,
        "datachannel": datachanneldir,
        "audio": audiodir,
        "video": videodir,
        "user": _User,
        "pwd": _Password,
        "iceservers": _encoder.convert(_iceServers)
      });
    } catch (e) {
      print(e.toString());
    }
  }

  Future<void> _createAnswer(Session session) async {
    try {
      Map<String, dynamic> dcConstraints = {};

      RTCSessionDescription s = await session.pc!
          .createAnswer(_onlydatachnannel ? {} : dcConstraints);
      await session.pc!.setLocalDescription(s);
      var delay = currentTimeMillis() - _start_time_;
      print(
          '>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> send answer  use time  :$delay');
      LogUtil.v("_createAnswer ${s.sdp}");
      _send('__answer', {
        "type": s.type,
        "sdp": s.sdp,
        'sessionId': session.sid,
        'sessionType': "flutter",
        'messageId': randomNumeric(32),
        'from': _selfId,
        'to': session.pid
      });
    } catch (e) {
      print(e.toString());
    }
  }

  _send(event, data) {
    onSendSignalMessge?.call(event, data);
  }

  Future<void> _cleanSessions() async {
    _sessions.forEach((key, sess) async {
      if (sess.redordstate == RecordState.Redording) {
        await _mediarecoder.stop();
        sess.redordstate = RecordState.RecordClosed;
      }
    });
    if (_localStream != null) {
      _localStream!.getTracks().forEach((element) async {
        await element.stop();
      });
      await _localStream!.dispose();
      _localStream = null;
    }
    _sessions.forEach((key, sess) async {
      await sess.dc?.close();
      await sess.pc?.close();
    });

    _sessions.clear();
  }

  void _closeSessionByPeerId(String peerId) {
    Session? session;
    _sessions.removeWhere((String key, Session sess) {
      var ids = key.split('-');
      session = sess;
      return peerId == ids[0] || peerId == ids[1];
    });
    if (session != null) {
      _closeSession(session!);
      onCallStateChange?.call(session!, CallState.CallStateBye);
    }
  }

  Future<void> _closeSession(Session session) async {
    if (session.redordstate == RecordState.Redording) {
      await _mediarecoder.stop();
      session.redordstate = RecordState.RecordClosed;
    }
    _localStream?.getTracks().forEach((element) async {
      await element.stop();
    });
    await _localStream?.dispose();
    _localStream = null;
    await session.dc?.close();
    await session.pc?.close();
  }

  /*
    开始录像
  */
  Future<void> startRecord(String sessionId) async {
    print('startRecord ------------------------');
    var sess = _sessions[sessionId];
    if (sess != null) {
      if (sess.redordstate == RecordState.RecordClosed) {
        try {
          var peerconnectid = sess.pc!.getPeerConnectionId();
          Directory? appDocDir;
          if (Platform.isIOS) {
            appDocDir = await getApplicationDocumentsDirectory();
          } else if (Platform.isAndroid) {
            appDocDir = await getExternalStorageDirectory();
          } else {
            return;
          }
          String appDocPath = appDocDir!.path;
          print('startRecord appDocPath : $appDocPath');
          List<RTCRtpReceiver> receivers = await sess.pc!.getReceivers();
          bool startrecorded = false;
          for (var receive in receivers) {
            print(
                'startRecord track ------------------------: ${receive.track}');
            if (receive.track!.kind == "video") {
              if (_remotevideotrack != null) {
                if (_remotevideotrack!.id == receive.track!.id) {
                  if (startrecorded == false) {
                    startrecorded = true;
                    if (_isWeb()) {
                    } else {
                      RecorderAudioChannel audiochannel =
                          RecorderAudioChannel.OUTPUT;
                      _mediarecoder.start('$appDocPath/test.mp4', peerconnectid,
                          videoTrack: receive.track,
                          audioChannel: audiochannel);
                      sess.redordstate = RecordState.Redording;
                      onRedordState?.call(sess, RecordState.Redording);
                    }
                  }
                }
              }
            }
          }
        } catch (err) {
          print(err);
        }
      } else {
        print('startRecord  is recording');
      }
    } else {
      print('startRecord  is no session $sessionId');
    }
  }

  /*
    停止录像
  */
  Future<void> stopRecord(String sessionId) async {
    print('stopRecord  -------------------------------------------');
    var sess = _sessions[sessionId];
    if (sess != null) {
      if (sess.redordstate == RecordState.Redording) {
        print('stopRecord  ');
        await _mediarecoder.stop();
        sess.redordstate = RecordState.RecordClosed;
        onRedordState?.call(sess, RecordState.RecordClosed);
        print('stopRecord  end');
      }
    }
  }

  /*
    截取一张图片并保存
  */
  Future<void> captureFrame(String sessionId) async {
    var sess = _sessions[sessionId];
    if (sess != null) {
      try {
        Directory? appDocDir;
        if (Platform.isIOS) {
          appDocDir = await getApplicationDocumentsDirectory();
        } else if (Platform.isAndroid) {
          appDocDir = await getExternalStorageDirectory();
        } else {
          return;
        }
        String appDocPath = appDocDir!.path;
        print('captureFrame appPath: $appDocPath');
        String captureFilepath =
            "$appDocPath/${sess.sid}${randomNumeric(32)}.jpg";

        List<RTCRtpReceiver> receivers = await sess.pc!.getReceivers();

        for (int i = 0; i < receivers.length; i++) {
          RTCRtpReceiver receive = receivers[i];
          if (receive.track!.kind!.isNotEmpty) {
            if (receive.track!.kind!.compareTo("video") == 0) {
              if (_remotevideotrack != null) {
                if (_remotevideotrack!.id == receive.track!.id) {
                  print('captureFrame track : ${receive.track!.kind}');
                  await receive.track!.captureFrame(captureFilepath);
                }
              }
            }
          }
        }
      } catch (err) {
        print(err);
      }
    }
  }

  Future<void> writeToFile(ByteData data, String path) {
    final buffer = data.buffer;
    return File(path).writeAsBytes(
        buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
  }

  /*
    发送 使用 datachennel 发送 文本数据
  */
  Future<void> dataChannelSendTextMsg(String sessionId, String msg) async {
    var sess = _sessions[sessionId];
    if (sess != null) {
      if (sess.datachannel_opened == true) {
        await sess.dc?.send(RTCDataChannelMessage(msg));
      }
    }
  }

  /*
    发送 使用 datachennel 发送 原始
  */
  Future<void> dataChannelSendRawMsg(String sessionId, Uint8List data) async {
    var sess = _sessions[sessionId];
    if (sess != null) {
      if (sess.datachannel_opened == true) {
        await sess.dc?.send(RTCDataChannelMessage.fromBinary(data));
      }
    }
  }
}
