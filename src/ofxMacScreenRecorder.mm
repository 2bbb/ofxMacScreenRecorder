//
//  ofxMacScreenRecorder.mm
//
//  Created by ISHII 2bit on 2017/07/01.
//
//

#import "ofxMacScreenRecorder.h"
#include "ofAppRunner.h"
#include "ofEventUtils.h"

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
    
    BOOL isRecordingNow;
}

- (instancetype)init;
- (BOOL)createCaptureSession:(NSError **)err;
- (void)start:(NSString *)moviePath;
- (void)stop;
- (BOOL)isRecordingNow;

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
    NSLog(@"addDisplayInputToCaptureSession %f, %f, %f, %f", cropRect.origin.x, cropRect.origin.y, cropRect.size.width, cropRect.size.height);
    [captureSession beginConfiguration];
    if (newDisplay != display) {
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
    NSLog(@"%f, %f", captureScreenInput.cropRect.origin.x, captureScreenInput.cropRect.origin.y);
    [captureSession commitConfiguration];
}

- (BOOL)captureOutputShouldProvideSampleAccurateRecordingStart:(AVCaptureOutput *)captureOutput {
    // We don't require frame accurate start when we start a recording. If we answer YES, the capture output
    // applies outputSettings immediately when the session starts previewing, resulting in higher CPU usage
    // and shorter battery life.
    return NO;
}

- (void)start:(NSString *)moviePath {
    isRecordingNow = YES;
    NSLog(@"Minimum Frame Duration: %f, Crop Rect: %@, Scale Factor: %f, Capture Mouse Clicks: %@, Capture Mouse Cursor: %@, Remove Duplicate Frames: %@",
          CMTimeGetSeconds([captureScreenInput minFrameDuration]),
          NSStringFromRect(NSRectFromCGRect([captureScreenInput cropRect])),
          [captureScreenInput scaleFactor],
          [captureScreenInput capturesMouseClicks] ? @"Yes" : @"No",
          [captureScreenInput capturesCursor] ? @"Yes" : @"No",
          [captureScreenInput removesDuplicateFrames] ? @"Yes" : @"No");
    
    /* Create a recording file */
    char *screenRecordingFileName = strdup([[moviePath stringByStandardizingPath] fileSystemRepresentation]);
    if (screenRecordingFileName) {
        NSLog(@"%s", screenRecordingFileName);
        int fileDescriptor = mkstemp(screenRecordingFileName);
        if(fileDescriptor != -1) {
            NSString *filenameStr = [[NSFileManager defaultManager] stringWithFileSystemRepresentation:screenRecordingFileName length:strlen(screenRecordingFileName)];
            NSURL *url = [NSURL fileURLWithPath:[filenameStr stringByAppendingPathExtension:@"mov"]];
            [captureMovieFileOutput startRecordingToOutputFileURL:url
                                                recordingDelegate:self];
        }
        
        remove(screenRecordingFileName);
        free(screenRecordingFileName);
        return true;
    }
    
    isRecordingNow = NO;
    return false;
}

- (void)stop {
    isRecordingNow = NO;
    [captureMovieFileOutput stopRecording];
}

- (void)               captureOutput:(AVCaptureFileOutput *)captureOutput
 didFinishRecordingToOutputFileAtURL:(NSURL *)outputFileURL
                     fromConnections:(NSArray *)connections
                               error:(NSError *)error
{
    isRecordingNow = NO;
    if(error) {
        NSLog(@"%s %@", __func__, error);
        return;
    }
    NSLog(@"success to write at %@", outputFileURL);
}

- (void)captureSessionRuntimeErrorDidOccur:(NSNotification *)notification {
    NSError *error = [notification userInfo][AVCaptureSessionErrorKey];
    //    NSAlert *alert = [[NSAlert alloc] init];
    //    [alert setAlertStyle:NSCriticalAlertStyle];
    //    [alert setMessageText:[error localizedDescription]];
    //    NSString *informativeText = [error localizedRecoverySuggestion];
    //    informativeText = informativeText ? informativeText : [error localizedFailureReason]; // No recovery suggestion, then at least tell the user why it failed.
    //    [alert setInformativeText:informativeText];
    //
    //    [alert beginSheetModalForWindow:[self windowForSheet]
    //                      modalDelegate:self
    //                     didEndSelector:@selector(alertDidEnd:returnCode:contextInfo:)
    //                        contextInfo:NULL];
    NSLog(@"%s %@", __func__, error);
    isRecordingNow = NO;
}

- (BOOL)isRecordingNow {
    return isRecordingNow;
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
            NSLog(@"error at setSetting");
            return false;
        }
    } else {
        NSLog(@"error at createCaptureSession: %@", err);
        return false;
    }
//    ofAddListener(ofEvents().update, this, &ofxMacScreenRecorder::setContext, OF_EVENT_ORDER_BEFORE_APP);
    ofAddListener(ofEvents().draw, this, &ofxMacScreenRecorder::setContext, OF_EVENT_ORDER_BEFORE_APP);
    setContext();
    return true;
}

bool ofxMacScreenRecorder::setSetting(const ofxMacScreenRecorderSetting &setting) {
    this->setting = setting;
    MacScreenRecorder *recorder = (MacScreenRecorder *)this->recorder;
    NSLog(@"%@", recorder);
    ofRectangle rect = setting.recordingArea;
    [recorder setCapturesCursor:setting.willRecordCursor];
    if(setting.willRecordAppWindow) {
        rect = ofGetWindowRect();
        rect.x = ofGetWindowPositionX();
        rect.y = ofGetWindowPositionY();
    }
    NSLog(@"setSetting: %f, %f, %f, %f", rect.x, rect.y, rect.width, rect.height);
    CGRect rect_ = CGRectMake(rect.x, rect.y, rect.width, rect.height);
    CGDirectDisplayID displays[16];
    uint32_t matchingDisplayCount = 0;
    CGError err = CGGetDisplaysWithRect(rect_, 16, displays, &matchingDisplayCount);
    if(err != kCGErrorSuccess) {
        NSLog(@"can't get displays with rect");
        return false;
    }
    if(matchingDisplayCount != 1) {
        NSLog(@"%d", matchingDisplayCount);
        return false;
    }
    NSLog(@"matchingDisplayCount = %d", matchingDisplayCount);
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

void ofxMacScreenRecorder::start(const std::string &moviePath) {
    MacScreenRecorder *recorder = (MacScreenRecorder *)this->recorder;
    if(recorder && ![recorder isRecordingNow]) {
        [recorder start:[NSString stringWithUTF8String:moviePath.c_str()]];
    } else {
        NSLog(@"warning: already started recording");
    }
}

void ofxMacScreenRecorder::stop() {
    MacScreenRecorder *recorder = (MacScreenRecorder *)this->recorder;
    if(recorder && [recorder isRecordingNow]) {
        NSLog(@"stop recording");
        [recorder stop];
    } else {
        NSLog(@"isn't recorindg now");
    }
}

bool ofxMacScreenRecorder::isRecordingNow() const {
    if(this->recorder == NULL) return false;
    MacScreenRecorder *recorder = (MacScreenRecorder *)this->recorder;
    return recorder.isRecordingNow;
}

void ofxMacScreenRecorder::setContext() {
    NSOpenGLContext *context = (NSOpenGLContext *)ofGetNSGLContext();
    [context makeCurrentContext];
}
