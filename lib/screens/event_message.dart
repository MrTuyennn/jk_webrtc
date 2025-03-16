class ReciveMsgEvent {
     final String _msg;
     ReciveMsgEvent(this._msg);
     String get msg {
       return _msg;
     }
}

class DeleteSessionMsgEvent {
     final String _msg;
     DeleteSessionMsgEvent(this._msg);
     String get msg {
       return _msg;
     }
}
class NewSessionMsgEvent {
     final String _msg;
     NewSessionMsgEvent(this._msg);
     String get msg {
       return _msg;
     }
}



class SendMsgEvent {
     final String _event;
     final Map _data;
     SendMsgEvent(this._event,this._data);
     String get event {
       return _event;
     }
      Map get data {
       return _data;
     }

}
