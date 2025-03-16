#if TARGET_OS_IPHONE
#import <Flutter/Flutter.h>
#elif TARGET_OS_MAC
#import <FlutterMacOS/FlutterMacOS.h>
#endif


#import "FlutterRTCMediaRecorder.h"
#include <unistd.h>
#import <AVFoundation/AVFoundation.h>
#import <VideoToolbox/VideoToolbox.h>
#import <AudioToolbox/AudioToolbox.h>
#import <CoreAudio/CoreAudioTypes.h>
#import <Photos/Photos.h>
@import CoreImage;
@import CoreVideo;

@interface FlutterRTCMediaRecorder() {
    
}

@property (nonatomic,strong) NSFileHandle *h264FileHandle; //句柄

@property(nonatomic, assign) BOOL audio;
@property(nonatomic, assign) BOOL video;
@property(nonatomic, assign) BOOL audio_inited;
@property(nonatomic, assign) BOOL video_inited;
@property(nonatomic, assign) BOOL recording;
@property(nonatomic, assign) BOOL start_recorded;
@property(nonatomic, assign) BOOL can_record;
@property (nonatomic, assign)  int frameNO;
@property (nonatomic, assign)  int videoWidth;
@property (nonatomic, assign)  int videoHeight;
@property (nonatomic, assign)  int audioSampleRate;
@property (nonatomic, assign)  int audioChannels;
@property (nonatomic, assign)  int64_t audioFrameIndex;
@property (nonatomic, assign)  int64_t videoFirsttimestamp;
@property (nonatomic, assign)  uint32_t audioFirsttimestamp;
@property (nonatomic, strong)  NSString *path;
@property (nonatomic, strong)  NSString *folderName;
@property(nonatomic, retain)  NSLock *theLock;
@property(nonatomic, retain) AVAssetWriter* asseetWriter;
@property(nonatomic, retain) AVAssetWriterInput* videoAssetWriterInput;
@property(nonatomic, retain) AVAssetWriterInput* audioAssetWriterInput;
@property(nonatomic, retain)  RTCAudioRenderAdapter * audiorender;
@property (nonatomic, strong)  RTCVideoTrack* videoTrack;
@property (nonatomic, strong)  RTCAudioTrack* audioTrack;
@end

@implementation FlutterRTCMediaRecorder {
    
}
uint32_t webrtc_get_timestamp(void){
    
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (ts.tv_sec * 1000 + ts.tv_nsec / 1000000);
}
- (instancetype)initWithVideoTrack:(RTCVideoTrack *)videoTrack audioTrack:(RTCAudioTrack *)audioTrack toPath:(NSString *)path
{
    self = [super init];
    if (self) {
        _folderName=@"webrtc-app";
        _audiorender = [[RTC_OBJC_TYPE(RTCAudioRenderAdapter) alloc] initRender];
        [_audiorender setDelegate:self];
        _recording= false;
        _audio = false;
        _video = false;
        _audio_inited = false;
        _video_inited = false;
        _start_recorded = false;
        _can_record = false;
        _videoFirsttimestamp = 0;
        _audioFirsttimestamp = 0;
        _audioFrameIndex= 0;
        _audioSampleRate = 0;
        _audioChannels = 0;
        _videoWidth = 0;
        _videoHeight = 0;
        _videoTrack = videoTrack;
        _audioTrack = audioTrack;
        _path = path;
        _theLock = [[NSLock alloc] init];
        const char *cString = [_path UTF8String];
        unlink(cString);
        if(_videoTrack!=nil){
            _video = true;
            [_videoTrack addRenderer:self];
        }else{
            NSLog(@"media record video is nil");
        }
        
        if(_audioTrack!=nil){
            _audio = true;
            [_audioTrack.source AddRender:_audiorender];
        }else{
            NSLog(@"media record audio is nil");
            
        }
    }
    return self;
}

- (void)setSize:(CGSize)size
{
}

- (void)startRecord:(FlutterResult)result {
    NSLog(@"start record");
    
    // 请求授权
    //    [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status) {
    //    // 先判断是否可以授权
    //            switch(status) {
    //            case PHAuthorizationStatusNotDetermined:
    //            {
    //                NSLog(@"用户还没有开始做出选择");
    //            }
    //            break;
    //            case PHAuthorizationStatusAuthorized:
    //            {
    //                //NSLog(@"用户授权了");
    //                _start_recorded = true;
    //            }
    //            break;
    //            default:{
    //                NSLog(@"用户不允许");
    //            }
    //            break;
    //            }
    //    }];
    _start_recorded = true;
    
    result(nil);
}

- (void)stopRecord:(FlutterResult)result {
    if (!_recording) return;
    NSLog(@"stop record");
    _recording = false;
    _can_record = false;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if(_videoTrack!=nil){
            [_videoTrack removeRenderer:self];
        }
        if(_audioTrack!=nil){
            [_audioTrack.source RemoveRender:_audiorender];
        }
        
        _videoTrack = nil;
        _audioTrack = nil;
        
        //        result(nil);
    });
    [self stopRecordMp4: result];
    
    
}

/*
 * video frame callback
 */
- (void)renderFrame:(nullable RTCVideoFrame *)frame
{
#if TARGET_OS_IPHONE
    
    [_theLock lock];
    if(_start_recorded== FALSE){
        [_theLock unlock];
        return;
    }
    if(_video==FALSE){
        [_theLock unlock];
        return;
    }
    if(_video_inited == FALSE){
        _videoWidth = frame.width;
        _videoHeight = frame.height;
        _video_inited = TRUE;
    }else{
        
    }
    if(_audio== FALSE){
        if(_start_recorded && _recording==FALSE){
            [self startRecordWithFilePath:_path Width:_videoWidth height:_videoHeight frameRate:(NSInteger)25 audioSampleRate:_audioSampleRate];
        }
    }else{
        if(_start_recorded && _recording==FALSE && _audio_inited==TRUE){
            [self startRecordWithFilePath:_path Width:_videoWidth height:_videoHeight frameRate:(NSInteger)25 audioSampleRate:_audioSampleRate];
        }
    }
    if(_start_recorded && _recording){
        
        OSStatus status;
        id<RTCVideoFrameBuffer> buffer = frame.buffer;
        CVPixelBufferRef pixelBufferRef = ((RTCCVPixelBuffer *) buffer).pixelBuffer;
        //NSLog(@"%d   %d", frame.width, frame.height);
        
        int64_t kNumMillisecsPerSec = INT64_C(1000);
        int64_t kNumNanosecsPerSec = INT64_C(1000000000);
        int64_t kNumNanosecsPerMillisec = kNumNanosecsPerSec / kNumMillisecsPerSec;
        
        if(_videoFirsttimestamp ==0){
            _videoFirsttimestamp = frame.timeStampNs / kNumNanosecsPerMillisec;
            _audioFirsttimestamp = webrtc_get_timestamp();
        }
        CMTime presentationTimeStamp = CMTimeMake(frame.timeStampNs / kNumNanosecsPerMillisec, 1000);
        CMSampleTimingInfo sampleTime = {CMTimeMake(1,90000), presentationTimeStamp, kCMTimeInvalid };
        CMVideoFormatDescriptionRef videoInfo = NULL;
        status = CMVideoFormatDescriptionCreateForImageBuffer(kCFAllocatorDefault, pixelBufferRef, &videoInfo);
        if (status != 0) {
            NSLog(@"CMVideoFormatDescriptionCreateForImageBuffer error %d",(int)status);
        }
        
        CMSampleBufferRef cropBuffer;
        status = CMSampleBufferCreateForImageBuffer(kCFAllocatorDefault, pixelBufferRef, true, NULL, NULL, videoInfo, &sampleTime, &cropBuffer);
        if (status != 0) {
            NSLog(@"CMSampleBufferCreateForImageBuffer error %d",(int)status);
        }else{
            [self addVideoFrame:cropBuffer];
        }
        
        CFRelease(cropBuffer);
        CFRelease(videoInfo);
    }
    [_theLock unlock];
    
    
#endif
}

/*
 * audio stream callback
 */
-(void)OnData:(const void* )audio_data bits_per_sample:(int) bits_per_sample sample_rate:(int) sample_rate number_of_channels:(size_t) number_of_channels number_of_frames:(size_t)number_of_frames
{
#if TARGET_OS_IPHONE
    [_theLock lock];
    //NSLog(@"%s", __FUNCTION__);
    if(_start_recorded== FALSE){
        [_theLock unlock];
        return;
    }
    if(_audio==FALSE){
        [_theLock unlock];
        return;
    }
    if(_audio_inited == FALSE){
        _audioSampleRate = sample_rate;
        _audioChannels = (int)number_of_channels;
        _audio_inited = TRUE;
    }else{
        
    }
    
    if(_video== FALSE){
        if(_start_recorded && _recording==FALSE){
            [self startRecordWithFilePath:_path Width:_videoWidth height:_videoHeight frameRate:(NSInteger)25 audioSampleRate:_audioSampleRate];
        }
    }else{
        if(_start_recorded && _recording==FALSE && _video_inited==TRUE){
            [self startRecordWithFilePath:_path Width:_videoWidth height:_videoHeight frameRate:(NSInteger)25 audioSampleRate:_audioSampleRate];
        }
    }
    if(_videoFirsttimestamp !=0|| _video== FALSE){
        
        if(_start_recorded && _recording){
            //NSLog(@"%s", __FUNCTION__);
            int len = (int)(bits_per_sample*number_of_channels*number_of_frames/8);
            CMSampleBufferRef cropBuffer = [self createAudioSample:audio_data audiolen:len bits_per_sample:bits_per_sample sample_rate:sample_rate number_of_channels:number_of_channels number_of_frames:number_of_frames];
            if(cropBuffer){
                [self addAudioFrame:cropBuffer];
                CFRelease(cropBuffer);
            }
            
        }
    }
    [_theLock unlock];
    
    
#endif
}
-(AudioStreamBasicDescription) getAudioFormat:(const void* )audio_data bits_per_sample:(int) bits_per_sample sample_rate:(int) sample_rate number_of_channels:(size_t) number_of_channels number_of_frames:(size_t)number_of_frames
{
    AudioStreamBasicDescription format;
    format.mSampleRate = sample_rate;
    format.mFormatID = kAudioFormatLinearPCM;
    format.mFormatFlags = kLinearPCMFormatFlagIsPacked | kLinearPCMFormatFlagIsSignedInteger;
    format.mChannelsPerFrame = (UInt32)number_of_channels;
    format.mBitsPerChannel = bits_per_sample;
    format.mFramesPerPacket = 1;
    format.mBytesPerFrame = format.mBitsPerChannel/8;
    format.mBytesPerPacket = format.mBytesPerFrame*format.mFramesPerPacket;
    format.mReserved = 0;
    return format;
    
}

- (CMSampleBufferRef)createAudioSample:(const void* )audioData audiolen:(int) audiolen bits_per_sample:(int) bits_per_sample sample_rate:(int) sample_rate number_of_channels:(size_t) number_of_channels number_of_frames:(size_t)number_of_frames
{
    _audioFrameIndex++;
    size_t channels = number_of_channels;
    AudioBufferList audioBufferList;
    audioBufferList.mNumberBuffers = 1;
    audioBufferList.mBuffers[0].mNumberChannels=(int)number_of_channels;
    audioBufferList.mBuffers[0].mDataByteSize=(int)audiolen;
    audioBufferList.mBuffers[0].mData = (void*)audioData;
    AudioStreamBasicDescription asbd = [self getAudioFormat:audioData bits_per_sample:bits_per_sample sample_rate:sample_rate number_of_channels:number_of_channels number_of_frames:number_of_frames];
    CMSampleBufferRef buff = NULL;
    static CMFormatDescriptionRef format = NULL;
    CMTime presentationTimeStamp;
    //CMTime presentationTimeStamp = CMTimeMake(audiolen/2 , sample_rate);
    //CMTime presentationTimeStamp = CMTimeMake(webrtc_get_timestamp(), 1000);
    //CMTime presentationTimeStamp = CMTimeMake(_audioFrameIndex, sample_rate/number_of_frames);
    if(_video){
        uint32_t delay = webrtc_get_timestamp()-_audioFirsttimestamp;
        presentationTimeStamp = CMTimeMake(_videoFirsttimestamp+delay, 1000);
    }else{
        presentationTimeStamp = CMTimeMake(audiolen/2 , sample_rate);
        //presentationTimeStamp = CMTimeMake(_audioFrameIndex, sample_rate/number_of_frames);
    }
    CMSampleTimingInfo timing = {CMTimeMake(1,sample_rate), presentationTimeStamp, kCMTimeInvalid };
    OSStatus error = 0;
    if(format == NULL)
        error = CMAudioFormatDescriptionCreate(kCFAllocatorDefault, &asbd, 0, NULL, 0, NULL, NULL, &format);
    error = CMSampleBufferCreate(kCFAllocatorDefault, NULL, false, NULL, NULL, format, audiolen/(2*channels), 1, &timing, 0, NULL, &buff);
    if ( error ) {
        NSLog(@"CMSampleBufferCreate returned error: %ld", (long)error);
        return NULL;
        
    }
    error = CMSampleBufferSetDataBufferFromAudioBufferList(buff, kCFAllocatorDefault, kCFAllocatorDefault, 0, &audioBufferList);
    if( error )
    {
        NSLog(@"CMSampleBufferSetDataBufferFromAudioBufferList returned error: %ld", (long)error);
        return NULL;
    }
    return buff;
}
- (NSString *)getFilePath {
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    dateFormatter.dateFormat = @"yyyy_MM_dd_HH_mm_ss";
    NSString *filePath = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES).lastObject;
    filePath = [NSString stringWithFormat:@"%@/%@.mp4",filePath,[dateFormatter stringFromDate:[NSDate date]]];
    dateFormatter=nil;
    return filePath;
}


- (void)saveVideoPath:(NSString *)videoPath {
    NSURL *url = [NSURL fileURLWithPath:videoPath];
    
    //标识保存到系统相册中的标识
    __block NSString *localIdentifier;
    
    //首先获取相册的集合
    PHFetchResult *collectonResuts = [PHCollectionList fetchTopLevelUserCollectionsWithOptions:nil];
    //对获取到集合进行遍历
    [collectonResuts enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        PHAssetCollection *assetCollection = obj;
        //folderName是我们写入照片的相册
        if ([assetCollection.localizedTitle isEqualToString:_folderName])  {
            [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
                //请求创建一个Asset
                PHAssetChangeRequest *assetRequest = [PHAssetChangeRequest creationRequestForAssetFromVideoAtFileURL:url];
                //请求编辑相册
                PHAssetCollectionChangeRequest *collectonRequest = [PHAssetCollectionChangeRequest changeRequestForAssetCollection:assetCollection];
                //为Asset创建一个占位符，放到相册编辑请求中
                PHObjectPlaceholder *placeHolder = [assetRequest placeholderForCreatedAsset];
                //相册中添加视频
                [collectonRequest addAssets:@[placeHolder]];
                
                localIdentifier = placeHolder.localIdentifier;
            } completionHandler:^(BOOL success, NSError *error) {
                if (success) {
                    NSLog(@"保存视频成功!");
                    
                } else {
                    NSLog(@"保存视频失败:%@", error);
                }
            }];
        }
    }];
}
- (BOOL)isExistFolder:(NSString *)folderName {
    //首先获取用户手动创建相册的集合
    PHFetchResult *collectonResuts = [PHCollectionList fetchTopLevelUserCollectionsWithOptions:nil];
    
    __block BOOL isExisted = NO;
    //对获取到集合进行遍历
    [collectonResuts enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        PHAssetCollection *assetCollection = obj;
        //folderName是我们写入照片的相册
        if ([assetCollection.localizedTitle isEqualToString:folderName])  {
            isExisted = YES;
        }
    }];
    
    return isExisted;
}
- (void)createFolder:(NSString *)folderName {
    if (![self isExistFolder:folderName]) {
        [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
            //添加HUD文件夹
            [PHAssetCollectionChangeRequest creationRequestForAssetCollectionWithTitle:folderName];
            
        } completionHandler:^(BOOL success, NSError * _Nullable error) {
            if (success) {
                NSLog(@"创建相册文件夹成功!");
            } else {
                NSLog(@"创建相册文件夹失败:%@", error);
            }
        }];
    }
}
- (void)startRecordWithFilePath:(NSString *)filePath Width:(NSInteger)width height:(NSInteger)height frameRate:(NSInteger)frameRate audioSampleRate:(NSInteger)audioSampleRate{
    
    NSLog(@"startRecordWithFilePath %@   width =%d height=%d frameRate= %d audioSampleRate=%d",filePath,width,height,frameRate,audioSampleRate);
    NSURL *url = [NSURL fileURLWithPath:filePath];
    NSError *error;
    AVAssetWriter *writer = [AVAssetWriter assetWriterWithURL:url fileType:AVFileTypeMPEG4 error:&error];
    if (error) {
        NSLog(@"%@",error);
        return;
    }
    _asseetWriter = writer;
    if(_video==true && _videoTrack!=nil){
        //写入视频大小
        NSInteger numPixels = width * height;
        //每像素比特
        CGFloat bitsPerPixel = 6.0;
        NSInteger bitsPerSecond = numPixels * bitsPerPixel;
        // 码率和帧率设置
        NSDictionary *compressionProperties = @{ AVVideoAverageBitRateKey : @(bitsPerSecond),
                                                 AVVideoExpectedSourceFrameRateKey : @(frameRate),
                                                 AVVideoMaxKeyFrameIntervalKey : @(frameRate),
                                                 AVVideoProfileLevelKey : AVVideoProfileLevelH264BaselineAutoLevel };
        
        NSDictionary *setting = @{ AVVideoCodecKey : AVVideoCodecH264,
                                   AVVideoScalingModeKey : AVVideoScalingModeResizeAspectFill,
                                   AVVideoWidthKey : @(width),
                                   AVVideoHeightKey : @(height),
                                   AVVideoCompressionPropertiesKey : compressionProperties };
        
        
        AVAssetWriterInput *videoInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo outputSettings:setting];
        
        
        if(videoInput!=nil){
            if ([_asseetWriter canAddInput:videoInput]) {
                [_asseetWriter addInput:videoInput];
                _videoAssetWriterInput = videoInput;
                //expectsMediaDataInRealTime 必须设为yes，需要从capture session 实时获取数据
                _videoAssetWriterInput.expectsMediaDataInRealTime = YES;
                _videoAssetWriterInput.transform = CGAffineTransformMakeRotation(M_PI*0);
            }else {
                NSLog(@"can't add video input!");
                return;
            }
        }
        
        
    }
    if(  _audio==true && _audioTrack!= nil && audioSampleRate>0){
        
        
        NSDictionary *aduioSetting = @{AVFormatIDKey : @(kAudioFormatMPEG4AAC),
                                       AVNumberOfChannelsKey : @(1),
                                       AVSampleRateKey : @(audioSampleRate)
        };
        
        AVAssetWriterInput *audioInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeAudio outputSettings:aduioSetting];
        if(audioInput!=nil){
            audioInput.expectsMediaDataInRealTime = YES;
            if ([_asseetWriter canAddInput:audioInput]) {
                [_asseetWriter addInput:audioInput];
                _audioAssetWriterInput = audioInput;
            }else {
                NSLog(@"can't add audio input!");
                return;
            }
        }
        
    }
    [_asseetWriter startWriting];
    _can_record= true;
    _recording = TRUE;
    _audioFrameIndex=0;
    NSLog(@"startWriting");
}

- (void)addAudioFrame:(CMSampleBufferRef)sampleBufferRef {
    //[self printSamplebuffer:sampleBufferRef video:FALSE];
    if(_asseetWriter!=nil&& _audioAssetWriterInput!=nil){
        [_asseetWriter startSessionAtSourceTime:CMSampleBufferGetPresentationTimeStamp(sampleBufferRef)];
        if (_audioAssetWriterInput.readyForMoreMediaData) {
            [_audioAssetWriterInput appendSampleBuffer:sampleBufferRef];
            // NSLog(@"addAudioFrame");
        }
    }
    
}

- (void)addVideoFrame:(CMSampleBufferRef)sampleBufferRef {
//     [self printSamplebuffer:sampleBufferRef video:TRUE];
    if(_asseetWriter!=nil&& _videoAssetWriterInput!=nil){
        [_asseetWriter startSessionAtSourceTime:CMSampleBufferGetPresentationTimeStamp(sampleBufferRef)];
        if (_videoAssetWriterInput.readyForMoreMediaData) {
            [_videoAssetWriterInput appendSampleBuffer:sampleBufferRef];
        }
    }
}

- (void)stopRecordMp4:(FlutterResult) result {
    [_theLock lock];
    [_videoAssetWriterInput markAsFinished];
    [_audioAssetWriterInput markAsFinished];
    [_asseetWriter finishWritingWithCompletionHandler:^{
//        if(! [self isExistFolder:_folderName]){
//            [self createFolder:_folderName];
//        }
//        if(_path!=nil){
//            [self saveVideoPath:_path];
//        }
        result(nil);
    }];
    [_theLock unlock];
}
- (void)printSamplebuffer:(CMSampleBufferRef)samplebuffer video:(BOOL)video
{
    static int vnum = 0,anum = 0;
    CGFloat pts = CMTimeGetSeconds(CMSampleBufferGetOutputPresentationTimeStamp(samplebuffer));
    CGFloat dts = CMTimeGetSeconds(CMSampleBufferGetOutputDecodeTimeStamp(samplebuffer));
    CGFloat dur = CMTimeGetSeconds(CMSampleBufferGetOutputDuration(samplebuffer));
    size_t size = CMSampleBufferGetTotalSampleSize(samplebuffer);
    
    if (video) {
        vnum++;
        /** CMFormatDescriptionRef对象(格式描述对象)
         *  1、CMVideoFormatDescriptionRef、CMAudioFormatDescriptionRef、CMTextFormatDescriptionRef是它的具体子类，分别
         *  对应着视频、音频、字幕的封装参数对象
         *  2、所有关于音视频等等的编解码参数，宽高等等都存储在此对象中
         *
         *  对于视频来说，它包括编码参数，宽高以及extension扩展参数，CMFormatDescriptionGetExtensions可以查看扩展参数内容
         *
         *  对于一个容器中读取出来的所有音/视频数据对象CMSampleBufferRef，音频对应着一个CMFormatDescriptionRef，视频
         *  对应着一个CMFormatDescriptionRef(即所有视频数据对象得到的格式描述对象地址都一样)，音频也是一样
         */
        //            NSLog(@"extension %@",CMFormatDescriptionGetExtensions(curformat));
        //        NSLog(@"CMFormatDescriptionRef %@",CMSampleBufferGetFormatDescription(samplebuffer));
        NSLog(@"video pts(%f) dts(%f) duration(%f) size(%ld) num(%d)",pts,dts,dur,size,vnum);
    } else {
        anum++;
        NSLog(@"audio pts(%f) dts(%f) duration(%f) size(%ld) num(%d)",pts,dts,dur,size,anum);
    }
}
@end




