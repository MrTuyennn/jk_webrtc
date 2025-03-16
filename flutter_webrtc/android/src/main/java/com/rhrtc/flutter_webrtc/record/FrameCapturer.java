package com.rhrtc.flutter_webrtc.record;

import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.ImageFormat;
import android.graphics.Matrix;
import android.graphics.Rect;
import android.graphics.YuvImage;
import android.os.Handler;
import android.os.Looper;
import android.util.Log;
import org.webrtc.VideoFrame;
import org.webrtc.VideoSink;
import org.webrtc.VideoTrack;
import org.webrtc.YuvHelper;

import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.nio.ByteBuffer;

import io.flutter.plugin.common.MethodChannel;

public class FrameCapturer implements VideoSink {
    private VideoTrack videoTrack;
    private File file;
    private final MethodChannel.Result callback;
    private boolean gotFrame = false;

    public FrameCapturer(VideoTrack track, File file, MethodChannel.Result callback) {
        videoTrack = track;
        this.file = file;
        this.callback = callback;
        track.addSink(this);
    }

    @Override
    public void onFrame(VideoFrame videoFrame) {
        if (gotFrame == true)
            return;
        gotFrame = true;
        videoFrame.retain();
         //Log.w("FrameCapturer", "captureFrame()------onFrame---------------------------------------------------------");
       /*
        VideoFrame.Buffer buffer = videoFrame.getBuffer();
        VideoFrame.I420Buffer i420Buffer = buffer.toI420();
        ByteBuffer y = i420Buffer.getDataY();
        ByteBuffer u = i420Buffer.getDataU();
        ByteBuffer v = i420Buffer.getDataV();
        int width = i420Buffer.getWidth();
        int height = i420Buffer.getHeight();
        int[] strides = new int[] {
            i420Buffer.getStrideY(),
            i420Buffer.getStrideU(),
            i420Buffer.getStrideV()
        };
        
        final int chromaWidth = (width + 1) / 2;
        final int chromaHeight = (height + 1) / 2;
        final int minSize = width * height + chromaWidth * chromaHeight * 2;
        ByteBuffer yuvBuffer = ByteBuffer.allocateDirect(minSize);
        YuvHelper.I420ToNV12(y, strides[0], v, strides[2], u, strides[1], yuvBuffer, width, height);
        */
         VideoFrame.Buffer buffer = videoFrame.getBuffer();
         VideoFrame.I420Buffer i420Buffer = buffer.toI420();
        int[] strides = new int[] {
            i420Buffer.getStrideY(),
            i420Buffer.getStrideU(),
            i420Buffer.getStrideV()
        };

         int width = i420Buffer.getWidth();
         int height = i420Buffer.getHeight();
         int chromaStride = width;
         int chromaWidth = (width + 1) / 2;
         int chromaHeight = (height + 1) / 2;
        int frameSize = width * height;

         ByteBuffer nv21Buffer = ByteBuffer.allocate(frameSize + chromaStride * chromaHeight);
        // We don't care what the array offset is since we only want an array that is direct.
         byte[] nv21Data = nv21Buffer.array();

        byte[] remainingYBytes = new byte[i420Buffer.getDataY().remaining()];
        i420Buffer.getDataY().slice().get(remainingYBytes);
        if(remainingYBytes.length>0) {
          System.arraycopy(remainingYBytes, 0, nv21Data, 0, frameSize);
        }
        byte[] remainingUBytes = new byte[i420Buffer.getDataU().remaining()];
        i420Buffer.getDataU().slice().get(remainingUBytes);

        byte[] remainingVBytes = new byte[i420Buffer.getDataV().remaining()];
        i420Buffer.getDataV().slice().get(remainingVBytes);


        for (int y = 0; y < chromaHeight; ++y) {
          for (int x = 0; x < chromaWidth; ++x) {

            nv21Data[frameSize + y * chromaStride + 2 * x + 1] = remainingUBytes[y * i420Buffer.getStrideU() + x];
            nv21Data[frameSize + y * chromaStride + 2 * x + 0] = remainingVBytes[y * i420Buffer.getStrideV() + x];
          }
        }


        YuvImage yuvImage = new YuvImage(
            nv21Data,
            ImageFormat.NV21,
            width,
            height,
            strides
        );
        i420Buffer.release();
        videoFrame.release();

        new Handler(Looper.getMainLooper()).post(() -> {
            //Log.w("FrameCapturer", "captureFrame()------removeSink---------------------------------------------------------");
            videoTrack.removeSink(this);
        });
        try {
            if (!file.exists()) {
                //noinspection ResultOfMethodCallIgnored
                file.getParentFile().mkdirs();
                //noinspection ResultOfMethodCallIgnored
                file.createNewFile();
            }
        } catch (IOException io) {
            callback.error("IOException", io.getLocalizedMessage(), io);
            return;
        }
        try (FileOutputStream outputStream = new FileOutputStream(file)) {
            yuvImage.compressToJpeg(
                new Rect(0, 0, width, height),
                100,
                outputStream
            );
            switch (videoFrame.getRotation()) {
                case 0:
                    break;
                case 90:
                case 180:
                case 270:
                    Bitmap original = BitmapFactory.decodeFile(file.toString());
                    Matrix matrix = new Matrix();
                    matrix.postRotate(videoFrame.getRotation());
                    Bitmap rotated = Bitmap.createBitmap(original, 0, 0, original.getWidth(), original.getHeight(), matrix, true);
                    FileOutputStream rotatedOutputStream = new FileOutputStream(file);
                    rotated.compress(Bitmap.CompressFormat.JPEG, 100, rotatedOutputStream);
                    break;
                default:
                    // Rotation is checked to always be 0, 90, 180 or 270 by VideoFrame
                    throw new RuntimeException("Invalid rotation");
            }
            callback.success(null);
        } catch (IOException io) {
            callback.error("IOException", io.getLocalizedMessage(), io);
        } catch (IllegalArgumentException iae) {
            callback.error("IllegalArgumentException", iae.getLocalizedMessage(), iae);
        } finally {
            file = null;
        }
    }

}
