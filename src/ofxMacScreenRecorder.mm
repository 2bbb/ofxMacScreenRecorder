//
//  ofxMacScreenRecorder.mm
//
//  Created by ISHII 2bit on 2017/07/01.
//
//

#include <iostream>
#include <fstream>

#import "ofxMacScreenRecorder.h"
#include "ofAppRunner.h"
#include "ofEventUtils.h"
#include "ofLog.h"

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <AppKit/AppKit.h>

@interface MacScreenRecorder : NSObject<
    AVCaptureFileOutputDelegate,
    AVCaptureFileOutputRecordingDelegate
>
{
    AVCaptureSession *captureSession;
    AVCaptureScreenInput *captureScreenInput;
    
    CGDirectDisplayID display;
    AVCaptureMovieFileOutput *captureMovieFileOutput;
    ofxMacScreenRecorder *parent;
    BOOL isRecordingNow;
    ofxMacScreenRecorder::Status status;
}

- (instancetype)init;
- (BOOL)createCaptureSession:(NSError **)err;
- (BOOL)start:(NSString *)moviePath overwrite:(BOOL)overwrite;
- (void)stop;
- (BOOL)isRecordingNow;
- (ofxMacScreenRecorder::Status)status;
- (void)setParent:(ofxMacScreenRecorder *)parent;

@end

@implementation MacScreenRecorder

- (instancetype)init {
    self = [super init];
    if(!self) return nil;
    
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:AVCaptureSessionRuntimeErrorNotification
                                                  object:captureSession];
    [captureSession stopRunning];
    [super dealloc];
}

- (BOOL)createCaptureSession:(NSError **)err {
    captureSession = [[AVCaptureSession alloc] init];
    if([captureSession canSetSessionPreset:AVCaptureSessionPresetHigh]) {
        [captureSession setSessionPreset:AVCaptureSessionPresetHigh];
    }

    display = CGMainDisplayID();
    
    captureScreenInput = [[AVCaptureScreenInput alloc] initWithDisplayID:display];
    if([captureSession canAddInput:captureScreenInput]) {
        [captureSession addInput:captureScreenInput];
    } else {
        return NO;
    }
    
    captureMovieFileOutput = [[AVCaptureMovieFileOutput alloc] init];
    [captureMovieFileOutput setDelegate:self];
    
    if([captureSession canAddOutput:captureMovieFileOutput]) {
        [captureSession addOutput:captureMovieFileOutput];
    } else {
        return NO;
    }
    
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(captureSessionRuntimeErrorDidOccur:)
                                               name:AVCaptureSessionRuntimeErrorNotification
                                             object:captureSession];
    return YES;
}

- (void)startCaptureSession {
    [captureSession startRunning];
}

- (float)maximumScreenInputFramerate {
    Float64 minimumVideoFrameInterval = CMTimeGetSeconds(captureScreenInput.minFrameDuration);
    return minimumVideoFrameInterval > 0.0f ? 1.0f / minimumVideoFrameInterval : 0.0;
}

- (void)setMaximumScreenInputFramerate:(float)maximumFramerate {
    CMTime minimumFrameDuration = CMTimeMake(1, (int32_t)maximumFramerate);
    [captureScreenInput setMinFrameDuration:minimumFrameDuration];
}

- (void)setCapturesCursor:(BOOL)capturesCursor {
    [captureScreenInput setCapturesCursor:capturesCursor];
}

-(void)addDisplayInputToCaptureSession:(CGDirectDisplayID)newDisplay
                              cropRect:(CGRect)cropRect
                             frameRate:(float)frameRate
                                 scale:(float)scale
{
    [captureSession beginConfiguration];
    if(newDisplay != display) {
        [captureSession removeInput:captureScreenInput];
        AVCaptureScreenInput *newScreenInput = [[AVCaptureScreenInput alloc] initWithDisplayID:newDisplay];
        
        captureScreenInput = newScreenInput;
        if ([captureSession canAddInput:captureScreenInput]) {
            [captureSession addInput:captureScreenInput];
        }
        display = newDisplay;
    }
    [captureScreenInput setCropRect:cropRect];
    [captureScreenInput setScaleFactor:scale];
    [self setMaximumScreenInputFramerate:frameRate];
    [captureSession commitConfiguration];
}

- (void)setCaptureSessionPreset:(int)preset {
    [captureSession beginConfiguration];
    if(![captureSession.sessionPreset isEqualToString:AVCaptureSessionPresetHigh]) {
        if([captureSession canSetSessionPreset:AVCaptureSessionPresetHigh]) {
            [captureSession setSessionPreset:AVCaptureSessionPresetHigh];
        }
    }
    if([captureSession canSetSessionPreset:AVCaptureSessionPresetPhoto]) {
        [captureSession setSessionPreset:AVCaptureSessionPresetPhoto];
    }
    [captureSession commitConfiguration];
}

- (BOOL)captureOutputShouldProvideSampleAccurateRecordingStart:(AVCaptureOutput *)captureOutput {
    // We don't require frame accurate start when we start a recording. If we answer YES, the capture output
    // applies outputSettings immediately when the session starts previewing, resulting in higher CPU usage
    // and shorter battery life.
    return NO;
}

- (BOOL)start:(NSString *)moviePath overwrite:(BOOL)overwrite {
    isRecordingNow = YES;
    status = ofxMacScreenRecorder::Status::Preparing;
//    NSLog(@"Minimum Frame Duration: %f, Crop Rect: %@, Scale Factor: %f, Capture Mouse Clicks: %@, Capture Mouse Cursor: %@, Remove Duplicate Frames: %@",
//          CMTimeGetSeconds([captureScreenInput minFrameDuration]),
//          NSStringFromRect(NSRectFromCGRect([captureScreenInput cropRect])),
//          [captureScreenInput scaleFactor],
//          [captureScreenInput capturesMouseClicks] ? @"Yes" : @"No",
//          [captureScreenInput capturesCursor] ? @"Yes" : @"No",
//          [captureScreenInput removesDuplicateFrames] ? @"Yes" : @"No");
    
    /* Create a recording file */
    NSMutableDictionary *setting = @{}.mutableCopy;
    switch(parent->setting.codecType) {
        case ofxMacScreenRecorder::CodecType::H264:
            [setting setObject:AVVideoCodecH264
                        forKey:AVVideoCodecKey];
            break;
        case ofxMacScreenRecorder::CodecType::JPEG:
            [setting setObject:AVVideoCodecJPEG
                        forKey:AVVideoCodecKey];
            break;
        case ofxMacScreenRecorder::CodecType::ProRes422:
            [setting setObject:AVVideoCodecAppleProRes422
                        forKey:AVVideoCodecKey];
            break;
        case ofxMacScreenRecorder::CodecType::ProRes4444:
            [setting setObject:AVVideoCodecAppleProRes4444
                        forKey:AVVideoCodecKey];
            break;
//        case ofxMacScreenRecorder::CodecType::HEVC:
//            [setting setObject:AVVideoCodecHEVC
//                        forKey:AVVideoCodecKey];
//            break;
    }
    [captureMovieFileOutput setOutputSettings:setting
                                forConnection:captureMovieFileOutput.connections.firstObject];
    
    if(overwrite) {
        NSString *path = [moviePath stringByAppendingString:@".mov"];
        std::ifstream ifs(path.UTF8String);
        if(ifs.is_open()) {
            ofLogNotice() << "remove file " << path.UTF8String;
            std::remove(path.UTF8String);
        }
    }
    
    
    char *screenRecordingFileName = strdup(moviePath.stringByStandardizingPath.fileSystemRepresentation);
    if(screenRecordingFileName) {
        NSString *filenameStr = [NSFileManager.defaultManager stringWithFileSystemRepresentation:screenRecordingFileName length:strlen(screenRecordingFileName)];
        NSURL *url = [NSURL fileURLWithPath:[filenameStr stringByAppendingPathExtension:@"mov"]];
        [captureMovieFileOutput startRecordingToOutputFileURL:url
                                            recordingDelegate:self];
        remove(screenRecordingFileName);
        free(screenRecordingFileName);
        return true;
    }
    
    status = ofxMacScreenRecorder::Status::NotRecording;
    isRecordingNow = NO;
    return false;
}

- (void)stop {
    isRecordingNow = NO;
    status = ofxMacScreenRecorder::Status::NotRecording;
    [captureMovieFileOutput stopRecording];
}

- (void)              captureOutput:(AVCaptureFileOutput *)output
 didStartRecordingToOutputFileAtURL:(NSURL *)fileURL
                    fromConnections:(NSArray<AVCaptureConnection *> *)connections
{
    ofLogNotice() << "started";
    status = ofxMacScreenRecorder::Status::Recording;
    ofNotifyEvent(parent->didStartWriting, parent);
}

- (void)              captureOutput:(AVCaptureFileOutput *)output
 didPauseRecordingToOutputFileAtURL:(NSURL *)fileURL
                    fromConnections:(NSArray<AVCaptureConnection *> *)connections
{
    status = ofxMacScreenRecorder::Status::Pause;
    ofNotifyEvent(parent->didPauseWriting, parent);
}

- (void)               captureOutput:(AVCaptureFileOutput *)output
 didResumeRecordingToOutputFileAtURL:(NSURL *)fileURL
                     fromConnections:(NSArray<AVCaptureConnection *> *)connections
{
    status = ofxMacScreenRecorder::Status::Recording;
    ofNotifyEvent(parent->didResumeWriting, parent);
}

- (void)                captureOutput:(AVCaptureFileOutput *)output
 willFinishRecordingToOutputFileAtURL:(NSURL *)fileURL
                      fromConnections:(NSArray<AVCaptureConnection *> *)connections
                                error:(nullable NSError *)error
{
    ofNotifyEvent(parent->willFinishWriting, parent);
}

- (void)               captureOutput:(AVCaptureFileOutput *)captureOutput
 didFinishRecordingToOutputFileAtURL:(NSURL *)outputFileURL
                     fromConnections:(NSArray *)connections
                               error:(NSError *)error
{
    status = ofxMacScreenRecorder::Status::NotRecording;
    isRecordingNow = NO;
    if(error) {
        std::string error_str = error.description.UTF8String;
        ofLogError("ofxMacScreenRecorder::finishRecording") << error_str;
        ofNotifyEvent(parent->didFailedWriting, error_str, parent);
        return;
    }
    std::string url_str = outputFileURL.absoluteString.UTF8String;
    ofNotifyEvent(parent->didFinishWriting, url_str, parent);
}

- (void)captureSessionRuntimeErrorDidOccur:(NSNotification *)notification {
    NSError *error = notification.userInfo[AVCaptureSessionErrorKey];
    std::string error_str = error.description.UTF8String;
    ofLogError("ofxMacScreenRecorder::runtimeErrorDidOccur") << error_str;
    ofNotifyEvent(parent->didOccurRuntimeError, error_str, parent);
    isRecordingNow = NO;
}

- (BOOL)isRecordingNow {
    return isRecordingNow;
}

- (ofxMacScreenRecorder::Status)status {
    return status;
}

- (void)setParent:(ofxMacScreenRecorder *)parent_ {
    parent = parent_;
}

@end

bool ofxMacScreenRecorder::setup(const ofxMacScreenRecorderSetting &setting) {
    this->setting = setting;
    MacScreenRecorder* rec = [MacScreenRecorder new];
    this->recorder = rec;
    NSError *err = nil;
    BOOL b = [rec createCaptureSession:&err];
    if(b) {
        [rec startCaptureSession];
        if(setSetting(setting)) {
            this->recorder = rec;
        } else {
            return false;
        }
    } else {
        ofLogError("ofxMacScreenRecorder::setup") << "error at createCaptureSession: " << err.description.UTF8String;
        return false;
    }
    
    ofAddListener(ofEvents().draw, this, &ofxMacScreenRecorder::setContext, OF_EVENT_ORDER_BEFORE_APP);
    ofAddListener(didOccurRuntimeError, this, &ofxMacScreenRecorder::runtimeError);
    ofAddListener(didFailedWriting, this, &ofxMacScreenRecorder::failureWriting);
    ofAddListener(didFinishWriting, this, &ofxMacScreenRecorder::finishWriting);
    setContext();
    return true;
}

bool ofxMacScreenRecorder::setSetting(const ofxMacScreenRecorderSetting &setting) {
    this->setting = setting;
    MacScreenRecorder *recorder = (MacScreenRecorder *)this->recorder;
    [recorder setParent:this];
    ofRectangle rect = setting.recordingArea;
    [recorder setCapturesCursor:setting.willRecordCursor];
    if(setting.willRecordAppWindow) {
        rect = ofGetWindowRect();
        rect.x = ofGetWindowPositionX();
        rect.y = ofGetWindowPositionY();
    }
    CGRect rect_ = CGRectMake(rect.x, rect.y, rect.width, rect.height);
    CGDirectDisplayID displays[16];
    uint32_t matchingDisplayCount = 0;
    CGError err = CGGetDisplaysWithRect(rect_, 16, displays, &matchingDisplayCount);
    if(err != kCGErrorSuccess) {
        ofLogError("ofxMacScreenRecorder::setSetting") << "can't get displays with rect";
        return false;
    }
    if(matchingDisplayCount != 1) {
        ofLogError("ofxMacScreenRecorder::setSetting") << "display area crossing multiple displays";
        return false;
    }
    CGRect bound = CGDisplayBounds(displays[0]);
    CGDisplayModeRef modeRef = CGDisplayCopyDisplayMode(displays[0]);
    float w = CGDisplayModeGetPixelWidth(modeRef);
    float scale = bound.size.width / w;
    rect_.origin.y = bound.size.height - rect_.origin.y - rect_.size.height;
    CFRelease(modeRef);
    
    [recorder addDisplayInputToCaptureSession:displays[0]
                                     cropRect:rect_
                                    frameRate:0.0 < setting.frameRate ? setting.frameRate : 60.0f
                                        scale:0.0 < setting.scale ? setting.scale : scale];
    return true;
}

bool ofxMacScreenRecorder::start(const std::string &moviePath, bool overwrite) {
    MacScreenRecorder *recorder = (MacScreenRecorder *)this->recorder;
    if(recorder && ![recorder isRecordingNow]) {
        return [recorder start:[NSString stringWithUTF8String:moviePath.c_str()]
                     overwrite:overwrite ? YES : NO];
    } else {
        ofLogWarning("ofxMacScreenRecorder::start") << "already started recording";
        return false;
    }
}

void ofxMacScreenRecorder::stop() {
    MacScreenRecorder *recorder = (MacScreenRecorder *)this->recorder;
    if(recorder && recorder.isRecordingNow) {
        [recorder stop];
    } else {
        ofLogWarning("ofxMacScreenRecorder::stop") << "isn't recording now";
    }
}

bool ofxMacScreenRecorder::isRecordingNow() const {
    if(this->recorder == NULL) return false;
    MacScreenRecorder *recorder = (MacScreenRecorder *)this->recorder;
    return recorder.isRecordingNow;
}

ofxMacScreenRecorder::Status ofxMacScreenRecorder::getStatus() const {
    if(this->recorder == NULL) return ofxMacScreenRecorder::Status::NotRecording;
    MacScreenRecorder *recorder = (MacScreenRecorder *)this->recorder;
    return recorder.status;
}

void ofxMacScreenRecorder::setContext() {
    NSOpenGLContext *context = (NSOpenGLContext *)ofGetNSGLContext();
    [context makeCurrentContext];
}
