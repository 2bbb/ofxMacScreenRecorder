//
//  ofxMacScreenRecorder.h
//
//  Created by ISHII 2bit on 2017/07/01.
//
//

#ifndef ofxMacScreenRecorder_h
#define ofxMacScreenRecorder_h

#include <string>

#include "ofRectangle.h"
#include "ofEvents.h"

class ofxMacScreenRecorder {
public:
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
    
private:
    Setting setting;
    std::string moviePath;
    void *recorder;
    
    inline void setContext(ofEventArgs &) { setContext(); }
    void setContext();
};

using ofxMacScreenRecorderSetting = ofxMacScreenRecorder::Setting;

#endif /* ofxMacScreenRecorder_h */
