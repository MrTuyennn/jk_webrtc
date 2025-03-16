#import <Foundation/Foundation.h>
#import "FlutterWebrtcPlugin.h"

@interface FlutterWebrtcPlugin (RTCMediaStream)

-(void)getUserMedia:(NSDictionary *)constraints
             result:(FlutterResult)result;
#if TARGET_OS_IPHONE
-(void)getDisplayMedia:(NSDictionary *)constraints
             result:(FlutterResult)result;
#endif
-(void)createLocalMediaStream:(FlutterResult)result;

-(void)getSources:(FlutterResult)result;

-(void)mediaStreamTrackHasTorch:(RTCMediaStreamTrack *)track
                         result:(FlutterResult) result;

-(void)mediaStreamTrackSetTorch:(RTCMediaStreamTrack *)track
                          torch:(BOOL) torch
                         result:(FlutterResult) result;

-(void)mediaStreamTrackSwitchCamera:(RTCMediaStreamTrack *)track
                             result:(FlutterResult) result;

-(void)mediaStreamTrackCaptureFrame:(RTCMediaStreamTrack *)track
                             toPath:(NSString *) path
                             result:(FlutterResult) result;

-(void)mediaStreamTrackStartRecord:(RTCVideoTrack *)videoTrack
                             audioTrack: (RTCAudioTrack *)audioTrack
                             toPath:(NSString *) path
                             result:(FlutterResult) result;

-(void)mediaStreamTrackStopRecord:(FlutterResult) result;


@end
