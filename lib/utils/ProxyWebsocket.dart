// ignore_for_file: file_names


import 'websocket.dart'
    if (dart.library.js) 'websocket_web.dart';
class ProxyWebsocket{

  final String _url;
  SimpleWebSocket? _socket;
  Function()? onOpen;
  Function(dynamic msg)? onMessage;
  Function(int code, String reason)? onClose;

  ProxyWebsocket(this._url);
  connect() async {
    try {
      _socket = SimpleWebSocket(_url);
      _socket?.onOpen=() {
        onOpen?.call();
      };
      _socket?.onMessage=(e) {
        onMessage?.call(e);
      };
      _socket?.onClose=(code,reason) {
        onClose?.call(code, reason);
      };
    } catch (e) {
      onClose?.call(500, e.toString());
    }
    await _socket?.connect();
  }
  send(data) { 
      _socket?.send(data);  
  }
  close() { 
      _socket?.close();
  }

}