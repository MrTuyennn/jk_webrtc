package com.rhrtc.flutter_webrtc;

import com.rhrtc.flutter_webrtc.utils.AnyThreadSink;
import com.rhrtc.flutter_webrtc.utils.ConstraintsMap;

import org.webrtc.DataChannel;

import java.nio.charset.Charset;

import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.EventChannel;
import android.util.Log;
import java.util.ArrayList;
import java.util.List;
import java.util.Iterator;
class DataChannelObserver implements DataChannel.Observer, EventChannel.StreamHandler {

    private final int mId;
    private final DataChannel mDataChannel;

    private EventChannel eventChannel;
    private EventChannel.EventSink eventSink;
    private List<ConstraintsMap> mTempEventlLists = new ArrayList<ConstraintsMap>();

    DataChannelObserver(BinaryMessenger messenger, String peerConnectionId, int id,
                        DataChannel dataChannel) {
        mId = id;
        mDataChannel = dataChannel;
        eventChannel =
                new EventChannel(messenger, "FlutterWebRTC/dataChannelEvent" + peerConnectionId + id);
        eventChannel.setStreamHandler(this);
    }

    private String dataChannelStateString(DataChannel.State dataChannelState) {
        switch (dataChannelState) {
            case CONNECTING:
                return "connecting";
            case OPEN:
                return "open";
            case CLOSING:
                return "closing";
            case CLOSED:
                return "closed";
        }
        return "";
    }

    @Override
    public void onListen(Object o, EventChannel.EventSink sink) {
        eventSink = new AnyThreadSink(sink);
        int i=0;
        for( i=0;i<mTempEventlLists.size();i++){
              ConstraintsMap params=mTempEventlLists.get(i);
              sendEvent(params);
             
        }
        List<ConstraintsMap> list1 = new ArrayList<ConstraintsMap>();
         mTempEventlLists.removeAll(list1);
     
    }

    @Override
    public void onCancel(Object o) {
        eventSink = null;
    }

    @Override
    public void onBufferedAmountChange(long amount) {
    }

    @Override
    public void onStateChange() {
        ConstraintsMap params = new ConstraintsMap();
        params.putString("event", "dataChannelStateChanged");
//        params.putInt("id", mDataChannel.id());
        params.putInt("id", mId);
        params.putString("state", dataChannelStateString(mDataChannel.state()));
        sendEvent(params);
    }

    @Override
    public void onMessage(DataChannel.Buffer buffer) {
        ConstraintsMap params = new ConstraintsMap();
        params.putString("event", "dataChannelReceiveMessage");
//        params.putInt("id", mDataChannel.id());
        params.putInt("id", mId);

        byte[] bytes;
        if (buffer.data.hasArray()) {
            bytes = buffer.data.array();
        } else {
            bytes = new byte[buffer.data.remaining()];
            buffer.data.get(bytes);
        }

        if (buffer.binary) {
            params.putString("type", "binary");
            params.putByte("data", bytes);
        } else {
            params.putString("type", "text");
            params.putString("data", new String(bytes, Charset.forName("UTF-8")));
        }

        sendEvent(params);
    }

    private void sendEvent(ConstraintsMap params) {
        if (eventSink != null) {
            eventSink.success(params.toMap());
        }else{
             mTempEventlLists.add(params);
        }
    }
}
