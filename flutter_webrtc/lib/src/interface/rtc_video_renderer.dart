import 'media_stream.dart';

class RTCVideoValue {
  const RTCVideoValue({
    this.width = 0.0,
    this.height = 0.0,
    this.rotation = 0,
    this.renderVideo = false,
    this.firstFrameArrival = false,
  });
  static const RTCVideoValue empty = RTCVideoValue();
  final double width;
  final double height;
  final int rotation;
  final bool renderVideo;
  final bool firstFrameArrival;
  double get aspectRatio {
    if (width == 0.0 || height == 0.0) {
      return 1.0;
    }
    return (rotation == 90 || rotation == 270)
        ? height / width
        : width / height;
  }

  RTCVideoValue copyWith({
    double? width,
    double? height,
    int? rotation,
    bool renderVideo = true,
    bool firstFrameArrival = false,
  }) {
    return RTCVideoValue(
      width: width ?? this.width,
      height: height ?? this.height,
      rotation: rotation ?? this.rotation,
      renderVideo: this.width != 0 && this.height != 0 && renderVideo,
      firstFrameArrival: firstFrameArrival,
    );
  }

  @override
  String toString() =>
      '$runtimeType(width: $width, height: $height, rotation: $rotation)';
}

abstract class VideoRenderer {
  VideoRenderer();

  /// When the video size changes, or the native texture
  /// changes (angle or size), notify the user to redraw the Widget.
  Function? onResize;
  Function? onFirstFrameRendered;
  int get videoWidth;

  int get videoHeight;

  bool get muted;
  set muted(bool mute);

  ///Return true if the audioOutput have been succesfully changed
  Future<bool> audioOutput(String deviceId);

  bool get renderVideo;

  int? get textureId;

  Future<void> initialize();

  MediaStream? get srcObject;

  set srcObject(MediaStream? stream);

  Future<void> dispose();
}
