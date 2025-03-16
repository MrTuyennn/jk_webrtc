// ignore_for_file: unused_field, prefer_typing_uninitialized_variables, prefer_interpolation_to_compose_strings, avoid_print, deprecated_member_use

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:jk_webrtc/screens/event_bus_util.dart';
import 'package:jk_webrtc/screens/event_message.dart';
import 'package:jk_webrtc/screens/signaling.dart';
import 'package:jk_webrtc/utils/ProxyWebsocket.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LivePage extends StatefulWidget {
  // params
  static String tag = 'call_sample';
  final String peerId;
  final String selfId;
  final bool usedatachannel;
  // params
  const LivePage(
      {super.key,
      required this.peerId,
      required this.selfId,
      required this.usedatachannel});

  @override
  State<LivePage> createState() => _LivePageState();
}

class _LivePageState extends State<LivePage> {
  final String _serverurl = "https://webrtc.qq-kan.com/wswebclient/";
  ProxyWebsocket? _socket;
  final Map<String, String> _sessions = {};
  late SharedPreferences _prefs;

  var _sendMsgEvent;
  var _delSessionMsgEvent;
  var _newSessionMsgEvent;
  Signaling? _signaling;
  final List<dynamic> _peers = [];
  String? _selfId;
  String? _peerId;
  bool _dataChannelOpened = false;
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();

  final bool _isStartOffer = false;

  bool _showremotevideo = false;
  bool _usedatachannel = false;
  bool _remotevideo = true;
  bool _inCalling = false;
  bool _mute = false;
  bool _speek = false;
  bool _recording = false;

  bool _inited = false;

  final JsonEncoder _encoder = const JsonEncoder();
  final JsonDecoder _decoder = const JsonDecoder();

  RTCDataChannel? _dataChannel;
  Session? _session;
  Timer? _timer;
  var _recvMsgEvent;

  // init render socket
  @override
  initState() {
    super.initState();
    if (_inited == false) {
      _inited = true;
      _selfId = widget.selfId;
      _peerId = widget.peerId;
      _usedatachannel = widget.usedatachannel;
      _recvMsgEvent = eventBus.on<ReciveMsgEvent>((event) {
        _signaling?.onMessage(event.msg);
      });
      _sendMsgEvent = eventBus.on<SendMsgEvent>((event) {
        _send(event.event, event.data);
      });
      _delSessionMsgEvent = eventBus.on<DeleteSessionMsgEvent>((event) {
        var session = _sessions.remove(event.msg);
        if (session != null) {}
      });
      _newSessionMsgEvent = eventBus.on<NewSessionMsgEvent>((event) {
        _sessions[event.msg] = event.msg;
        //LogUtil.v('add session ${event.msg}');
      });
      run();
    }
  }

  Future<void> run() async {
    await websocketconnect();

    await initRenderers();
    _initWebrtc();
  }

  _send(event, data) {
    var request = {};
    request["eventName"] = event;
    request["data"] = data;
    _socket?.send(_encoder.convert(request));
  }

  Future<void> websocketconnect() async {
    var url = _serverurl + widget.selfId;

    _socket = ProxyWebsocket(url);

    print('websocketconnect::connect to $url');

    _socket?.onOpen = () {
      print('websocketconnect::onOpen');
    };

    _socket?.onMessage = (message) {
      // print('websocket recive message --> $message');
      Map<String, dynamic> mapData = _decoder.convert(message);
      var eventName = mapData['eventName'];
      var data = mapData['data'];
      // print('websocket onMessage recive $eventName');
      switch (eventName) {
        case '_ring':
          {
            //var peerId = data['from'];
            //var selfId = data['to'];
            //print('websocket onMessage recive peerId = $peerId');
            //print('websocket onMessage recive selfId = $selfId');
            //startcallcample(selfId,peerId,message,true);
          }
          break;
        case '_call':
          {
            var peerId = data['from'];
            var selfId = data['to'];
            print('websocket onMessage recive peerId = $peerId');
            print('websocket onMessage recive selfId = $selfId');
            eventBus.emit(ReciveMsgEvent(message));
          }
          break;
        case '_offer':
          {
            //var peerId = data['from'];
            //var selfId = data['to'];
            // print('websocket onMessage recive peerId = $peerId');
            // print('websocket onMessage recive selfId = $selfId');
            // startcallcample(selfId,peerId,message,true);
            eventBus.emit(ReciveMsgEvent(message));
          }
          break;
        default:
          eventBus.emit(ReciveMsgEvent(message));
          break;
      }
    };

    _socket?.onClose = (int code, String reason) {
      print('websocketconnect   Closed by server [$code => $reason]!');

      const timeout = Duration(seconds: 5);
      //print('currentTime='+DateTime.now().toString()); // 当前时间
      Timer(timeout, () {
        //callback function
        print('afterTimer=' +
            DateTime.now().toString() +
            " reconnect---------------------------------------"); // 5s之后
        websocketconnect();
      });
    };

    await _socket?.connect();
  }
  /*
   Lưu ý: Khởi tạo điều khiển hiển thị
  */

  initRenderers() async {
    print("run");
    await _remoteRenderer.initialize();
    _remoteRenderer.onFirstFrameRendered = () {
      print(
          '------------------------------video frame onFirstFrameRendered------------------------------');
      setState(() {
        _showremotevideo = true;
      });
    };
    _remoteRenderer.onResize = () {};
  }

  @override
  deactivate() {
    super.deactivate();
    _timer?.cancel();
    eventBus.off(_recvMsgEvent);
    _signaling?.close();
    _remoteRenderer.dispose();
  }

  /*
   Chức năng: khởi tạo
   Lưu ý: Tạo lớp Báo hiệu và triển khai chức năng gọi lại tương ứng
  */

  /*
      Chức năng: Bắt đầu cuộc gọi
      Lưu ý: Tạo phiên và tạo RTCPeerConnection rồi bắt đầu Ưu đãi
   */

  _invitePeer(String sessionId, String peerId) async {
    if (peerId != _selfId) {
      _signaling?.invite(sessionId, peerId, true, true, true, false, true,
          "live", "MainStream", "redgrain@sina.com", "WEeLXHKsXr");
    }
  }

  /*
      Chức năng: Bắt đầu cuộc gọi
      Lưu ý: Tạo phiên và tạo RTCPeerConnection rồi bắt đầu Ưu đãi
   */

  _callPeer(String sessionId, String peerId) async {
    if (peerId != _selfId) {
      _signaling?.startcall(sessionId, peerId, true, true, true, false, true,
          "live", "MainStream", "redgrain@sina.com", "WEeLXHKsXr");
    }
  }

/*
   Chức năng: ngắt cuộc gọi
     Lưu ý: Gửi tin nhắn __disconnect và quay lại trang trước
*/
  _hangUp() {
    _timer?.cancel();
    if (_session != null) {
      _signaling?.bye(_session!.sid);
    }
    Navigator.pop(context, true);
  }

  void _initWebrtc() async {
    _signaling ??= Signaling(widget.selfId, widget.peerId, false, true);
    _signaling?.onSendSignalMessge = (String eventName, dynamic data) {
      eventBus.emit(SendMsgEvent(eventName, data));
    };

    _signaling?.onSessionCreate =
        (String sessionId, String peerId, OnlineState state) {
      print(
          'onSessionCreateMessge sessionId = $sessionId   peerId = $peerId   $state');
      if (state == OnlineState.OnLine) {
        if (_isStartOffer == true) {
          _invitePeer(sessionId, peerId);
        } else {
          _callPeer(sessionId, peerId);
        }
      }
    };

    _signaling?.onSignalingStateChange = (SignalingState state) {
      switch (state) {
        case SignalingState.ConnectionClosed:
        case SignalingState.ConnectionError:
        case SignalingState.ConnectionOpen:
          break;
      }
    };
    _signaling?.onRedordState = (Session session, RecordState state) {
      if (state == RecordState.Redording) {
        setState(() {
          _recording = true;
        });
      } else if (state == RecordState.RecordClosed) {
        setState(() {
          _recording = false;
        });
      }
    };

    _signaling?.onCallStateChange = (Session session, CallState state) {
      switch (state) {
        case CallState.CallStateNew:
          eventBus.emit(NewSessionMsgEvent(session.sid));
          setState(() {
            _session = session;
            _inCalling = true;
          });
          if (_usedatachannel) {
            //  _timer = Timer.periodic(Duration(seconds: 1), _handleDataChannelTest);
          }

          break;
        case CallState.CallStateBye:
          eventBus.emit(DeleteSessionMsgEvent(session.sid));
          setState(() {
            _remoteRenderer.srcObject = null;
            _inCalling = false;
            _session = null;
          });

          _hangUp();
          break;
        case CallState.CallStateInvite:
        case CallState.CallStateConnected:
        case CallState.CallStateRinging:
      }
    };

    _signaling?.onLocalStream = ((stream) {
      stream.getAudioTracks().forEach((track) {
        _mute = track.enabled;

        print(
            'onLocalStream getAudioTracks track ++++++++++++++++++++++++++: ${track.enabled}');
      });
    });

    _signaling?.onAddRemoteStream = ((Session session, stream) {
      stream.getVideoTracks().forEach((track) {
        _remotevideo = true;
      });
      stream.getAudioTracks().forEach((track) {
        _speek = track.enabled;
        track.enableSpeakerphone(true);
      });
      _remoteRenderer.srcObject = stream;
    });

    _signaling?.onRemoveRemoteStream = ((Session session, stream) {
      _remoteRenderer.srcObject = null;
    });
    _signaling?.onSessionRTCConnectState =
        (Session session, RTCPeerConnectionState state) {
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected &&
          _session == session) {
        print('onSessionRTCConnectState -----------: $state');
      }
    };

    _signaling?.onDataChannel = (Session session, channel) {
      _dataChannel = channel;
    };

    _signaling?.onDataChannelState =
        (Session session, RTCDataChannelState state) {
      if (state == RTCDataChannelState.RTCDataChannelOpen) {
        setState(() {
          _dataChannelOpened = true;
        });
      } else if (state == RTCDataChannelState.RTCDataChannelClosed) {
        setState(() {
          _dataChannelOpened = false;
        });
      }
    };

    _signaling?.onDataChannelMessage =
        (Session session, dc, RTCDataChannelMessage data) {
      if (data.isBinary) {
        print('Got binary [${data.binary}]');
      } else {
        print('Got text [${data.text}]');
      }
    };

    _signaling?.onRecvSignalingMessage = (Session session, String message) {
      print('Got Signaling  Message [$message]');
    };

    _signaling?.connect();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
        canPop: false,
        onPopInvoked: (didPop) {
          if (didPop) {
            return;
          }
          _hangUp();
        },
        child: OrientationBuilder(builder: (context, orientation) {
          return Stack(children: <Widget>[
            Positioned(
              left: 0.0,
              right: 0.0,
              top: 0.0,
              height: 200.0,
              child: _showremotevideo
                  ? Container(
                      margin: const EdgeInsets.fromLTRB(0.0, 0.0, 0.0, 0.0),
                      width: MediaQuery.of(context).size.width,
                      height: MediaQuery.of(context).size.height,
                      decoration: const BoxDecoration(color: Colors.black),
                      child: RTCVideoView(_remoteRenderer),
                    )
                  : Container(
                      decoration: const BoxDecoration(color: Colors.black),
                      height: 300.0,
                      width: double.infinity,
                      child: const Center(
                        child: CircularProgressIndicator(
                          backgroundColor: Color(0xffff0000),
                        ),
                      )),
            ),
          ]);
        }));
  }
}
