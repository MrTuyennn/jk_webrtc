

#if TARGET_OS_IPHONE
#import <Flutter/Flutter.h>
#elif TARGET_OS_OSX
#import <FlutterMacOS/FlutterMacOS.h>
#endif
#import <WebRTC/WebRTC.h>

@interface FlutterRTCMediaRecorder : NSObject<RTCVideoRenderer, RTCAudioRenderDelegate>

- (instancetype)initWithVideoTrack:(RTCVideoTrack *)videoTrack audioTrack:(RTCAudioTrack *)audioTrack toPath:(NSString *)path;

- (void)startRecord:(FlutterResult)result;
- (void)stopRecord:(FlutterResult)result;

@end
