//
//  ofxMacScreenRecorder.h
//
//  Created by ISHII 2bit on 2017/07/01.
//
//

#ifndef ofxMacScreenRecorder_h
#define ofxMacScreenRecorder_h

#include <AvailabilityMacros.h>

#include <functional>
#include <string>

#include "ofRectangle.h"
#include "ofEvents.h"

#ifdef MAC_OS_X_VERSION_10_13
#   if MAC_OS_X_VERSION_10_13 <= MAC_OS_X_VERSION_MIN_REQUIRED
#       define BBB_IS_MACOS_13 1
#   endif
#endif

class ofxMacScreenRecorder {
public:
    enum class CodecType : std::uint8_t {
        H264,
        JPEG,
        ProRes422,
        ProRes4444,
#ifdef BBB_IS_MACOS_13
        HEVC
#endif
    };
    enum class Status : std::uint8_t {
        NotRecording,
        Preparing,
        Recording,
        Pause,
    };
    ofEvent<std::string> didOccurRuntimeError;
    ofEvent<std::string> didFailedWriting;
    ofEvent<void> didStartWriting;
    ofEvent<void> didPauseWriting;
    ofEvent<void> didResumeWriting;
    ofEvent<void> willFinishWriting;
    ofEvent<std::string> didFinishWriting;
    
    std::function<void(const std::string &)> runtimeErrorCallback{[](const std::string &){}};
    std::function<void(const std::string &)> finishWritingCallback{[](const std::string &){}};;
    std::function<void(const std::string &)> failureWritingCallback{[](const std::string &){}};;
    std::function<void()> didStartCallback{[]{}};
    std::function<void()> didPauseCallback{[]{}};
    std::function<void()> didResumeCallback{[]{}};

    ~ofxMacScreenRecorder() {
        ofRemoveListener(ofEvents().draw, this, &ofxMacScreenRecorder::setContext, OF_EVENT_ORDER_BEFORE_APP);
        ofRemoveListener(didOccurRuntimeError, this, &ofxMacScreenRecorder::runtimeError);
        ofRemoveListener(didFailedWriting, this, &ofxMacScreenRecorder::failureWriting);
        ofRemoveListener(didFinishWriting, this, &ofxMacScreenRecorder::finishWriting);
    }
    struct Setting {
        Setting() {};
        ofRectangle recordingArea{0, 0, -1, -1};
        bool willRecordCursor{false};
        bool willRecordAppWindow{true};
        float frameRate{60.0f};
        float scale{0.0f};
        CodecType codecType{CodecType::H264};
    };
    
    bool setup(const Setting &setting = Setting());
    bool setSetting(const Setting &setting = Setting());
    bool start(const std::string &moviePath, bool overwrite = true);
    void stop();
    bool isRecordingNow() const;
    Status getStatus() const;
    
    inline Setting &getSetting() { return setting; }
    
    inline void registerRuntimeErrorCallback(std::function<void(const std::string &)> callback)
    { runtimeErrorCallback = callback; };
    inline void registerStartWritingCallback(std::function<void()> callback)
    { didStartCallback = callback; };
    inline void registerFinishWritingCallback(std::function<void(const std::string &)> callback)
    { finishWritingCallback = callback; };
    inline void registerFailureWritingCallback(std::function<void(const std::string &)> callback)
    { failureWritingCallback = callback; };
    
    void setContext();
    
    Setting setting;
private:
    std::string moviePath;
    void *recorder;
    
    inline void setContext(ofEventArgs &) { setContext(); }
    void runtimeError(std::string &errorString) {
        runtimeErrorCallback(errorString);
    }
    void failureWriting(std::string &errorString) {
        failureWritingCallback(errorString);
    }
    void finishWriting(std::string &path) {
        finishWritingCallback(path);
    }
};

using ofxMacScreenRecorderSetting = ofxMacScreenRecorder::Setting;

#endif /* ofxMacScreenRecorder_h */
