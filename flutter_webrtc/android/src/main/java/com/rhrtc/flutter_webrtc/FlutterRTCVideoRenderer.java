package com.rhrtc.flutter_webrtc;

import android.util.Log;
import android.graphics.SurfaceTexture;

import com.rhrtc.flutter_webrtc.utils.AnyThreadSink;
import com.rhrtc.flutter_webrtc.utils.ConstraintsMap;
import com.rhrtc.flutter_webrtc.utils.EglUtils;

import java.util.List;

import org.webrtc.EglBase;
import org.webrtc.MediaStream;
import org.webrtc.MediaStreamTrack;
import org.webrtc.RendererCommon.RendererEvents;
import org.webrtc.VideoTrack;

import io.flutter.plugin.common.EventChannel;
import io.flutter.view.TextureRegistry;

public class FlutterRTCVideoRenderer implements EventChannel.StreamHandler {

    private static final String TAG = FlutterWebRTCPlugin.TAG;
    private final SurfaceTexture texture;
    private TextureRegistry.SurfaceTextureEntry entry;
    private int id = -1;
    private MediaStream mediaStream;

    public void Dispose() {
        //destroy
        if (surfaceTextureRenderer != null) {
            surfaceTextureRenderer.release();
        }
        if (eventChannel != null)
            eventChannel.setStreamHandler(null);

        eventSink = null;
        entry.release();
    }

    /**
     * The {@code RendererEvents} which listens to rendering events reported by
     * {@link #surfaceTextureRenderer}.
     */
    private RendererEvents rendererEvents;

    private void listenRendererEvents() {
        rendererEvents = new RendererEvents() {
            private int _rotation = -1;
            private int _width = 0, _height = 0;

            @Override
            public void onFirstFrameRendered() {
                ConstraintsMap params = new ConstraintsMap();
                params.putString("event", "didFirstFrameRendered");
                params.putInt("id", id);
                eventSink.success(params.toMap());
            }

            @Override
            public void onFrameResolutionChanged(
                    int videoWidth, int videoHeight,
                    int rotation) {

                if (eventSink != null) {
                    if (_width != videoWidth || _height != videoHeight) {
                        ConstraintsMap params = new ConstraintsMap();
                        params.putString("event", "didTextureChangeVideoSize");
                        params.putInt("id", id);
                        params.putDouble("width", (double) videoWidth);
                        params.putDouble("height", (double) videoHeight);
                        _width = videoWidth;
                        _height = videoHeight;
                        eventSink.success(params.toMap());
                    }

                    if (_rotation != rotation) {
                        ConstraintsMap params2 = new ConstraintsMap();
                        params2.putString("event", "didTextureChangeRotation");
                        params2.putInt("id", id);
                        params2.putInt("rotation", rotation);
                        _rotation = rotation;
                        eventSink.success(params2.toMap());
                    }
                }
            }
        };
    }

    private SurfaceTextureRenderer surfaceTextureRenderer;

    /**
     * The {@code VideoTrack}, if any, rendered by this {@code FlutterRTCVideoRenderer}.
     */
    private VideoTrack videoTrack;

    EventChannel eventChannel;
    EventChannel.EventSink eventSink;

    public FlutterRTCVideoRenderer(SurfaceTexture texture, TextureRegistry.SurfaceTextureEntry entry) {
        this.surfaceTextureRenderer = new SurfaceTextureRenderer("");
        listenRendererEvents();
        surfaceTextureRenderer.init(EglUtils.getRootEglBaseContext(), rendererEvents);
        surfaceTextureRenderer.surfaceCreated(texture);

        this.texture = texture;
        this.eventSink = null;
        this.entry = entry;
    }

    public void setEventChannel(EventChannel eventChannel) {
        this.eventChannel = eventChannel;
    }

    public void setId(int id) {
        this.id = id;
    }

    @Override
    public void onListen(Object o, EventChannel.EventSink sink) {
        eventSink = new AnyThreadSink(sink);
    }

    @Override
    public void onCancel(Object o) {
        eventSink = null;
    }

    /**
     * Stops rendering {@link #videoTrack} and releases the associated acquired
     * resources (if rendering is in progress).
     */
    private void removeRendererFromVideoTrack() {
        videoTrack.removeSink(surfaceTextureRenderer);
    }

    /**
     * Sets the {@code MediaStream} to be rendered by this {@code FlutterRTCVideoRenderer}.
     * The implementation renders the first {@link VideoTrack}, if any, of the
     * specified {@code mediaStream}.
     *
     * @param mediaStream The {@code MediaStream} to be rendered by this
     *                    {@code FlutterRTCVideoRenderer} or {@code null}.
     */
    public void setStream(MediaStream mediaStream) {
        VideoTrack videoTrack;
        this.mediaStream = mediaStream;
        if (mediaStream == null) {
            videoTrack = null;
        } else {
            List<VideoTrack> videoTracks = mediaStream.videoTracks;

            videoTrack = videoTracks.isEmpty() ? null : videoTracks.get(0);
        }

        setVideoTrack(videoTrack);
    }

    /**
     * Sets the {@code VideoTrack} to be rendered by this {@code FlutterRTCVideoRenderer}.
     *
     * @param videoTrack The {@code VideoTrack} to be rendered by this
     *                   {@code FlutterRTCVideoRenderer} or {@code null}.
     */
    public void setVideoTrack(VideoTrack videoTrack) {
        VideoTrack oldValue = this.videoTrack;

        if (oldValue != videoTrack) {
            if (oldValue != null) {
                removeRendererFromVideoTrack();
            }

            this.videoTrack = videoTrack;

            if (videoTrack != null) {
                Log.w(TAG, "FlutterRTCVideoRenderer.setVideoTrack, set video track to " + videoTrack.id());
                tryAddRendererToVideoTrack();
            } else {
                Log.i(TAG, "FlutterRTCVideoRenderer.setVideoTrack, set video track to null");
            }
        }
    }

    /**
     * Starts rendering {@link #videoTrack} if rendering is not in progress and
     * all preconditions for the start of rendering are met.
     */
    private void tryAddRendererToVideoTrack() {
        if (videoTrack != null) {
            EglBase.Context sharedContext = EglUtils.getRootEglBaseContext();

            if (sharedContext == null) {
                // If SurfaceViewRenderer#init() is invoked, it will throw a
                // RuntimeException which will very likely kill the application.
                Log.e(TAG, "Failed to render a VideoTrack!");
                return;
            }

            surfaceTextureRenderer.release();
            listenRendererEvents();
            surfaceTextureRenderer.init(sharedContext, rendererEvents);
            surfaceTextureRenderer.surfaceCreated(texture);

            videoTrack.addSink(surfaceTextureRenderer);
        }
    }

    public boolean checkMediaStream(String id) {
        if (null == id || null == mediaStream) {
            return false;
        }
        return id.equals(mediaStream.getId());
    }

    public boolean checkVideoTrack(String id) {
        if (null == id || null == videoTrack) {
            return false;
        }
        return id.equals(videoTrack.id());
    }
}
