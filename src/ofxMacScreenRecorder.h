//
//  ofxMacScreenRecorder.h
//
//  Created by ISHII 2bit on 2017/07/01.
//
//

#ifndef ofxMacScreenRecorder_h
#define ofxMacScreenRecorder_h

#include <functional>
#include <string>

#include "ofRectangle.h"
#include "ofEvents.h"

class ofxMacScreenRecorder {
public:
    ofEvent<std::string> didOccurRuntimeError;
    ofEvent<std::string> didFailedWriting;
    ofEvent<std::string> didFinishWriting;
    
    std::function<void(const std::string &)> runtimeErrorCallback{[](const std::string &){}};
    std::function<void(const std::string &)> finishWritingCallback{[](const std::string &){}};;
    std::function<void(const std::string &)> failureWritingCallback{[](const std::string &){}};;
    
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
    };
    
    bool setup(const Setting &setting = Setting());
    bool setSetting(const Setting &setting = Setting());
    void start(const std::string &moviePath);
    void stop();
    bool isRecordingNow() const;
    
    inline Setting &getSetting() { return setting; }
    
    void registerRuntimeErrorCallback(std::function<void(const std::string &)> callback) {
        runtimeErrorCallback = callback;
    }
    void registerFinishWritingCallback(std::function<void(const std::string &)> callback) {
        finishWritingCallback = callback;
    }
    void registerFailureWritingCallback(std::function<void(const std::string &)> callback) {
        failureWritingCallback = callback;
    }
    
    void setContext();
    
private:
    Setting setting;
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
