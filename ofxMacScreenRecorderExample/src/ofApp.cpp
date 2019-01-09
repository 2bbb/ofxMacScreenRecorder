#include "ofMain.h"
#include "ofxMacScreenRecorder.h"

class ofApp : public ofBaseApp {
    ofxMacScreenRecorder recorder;
    ofxMacScreenRecorderSetting recorderSetting;
    ofImage image;
public:
    void setup() {
        recorderSetting.codecType = ofxMacScreenRecorder::CodecType::ProRes4444;
        if(!recorder.setup(recorderSetting)) ofExit(-1);
        
        image.load("image.png");
        recorder.registerFinishWritingCallback([this](const std::string &path) {
            ofLogNotice() << "success recording. save to: " << path;
        });
        recorder.registerStartWritingCallback([this] {
            ofLogNotice() << "start" << std::endl;
        });
        
        ofBackground(0);
    }
    void update() {}
    void draw() {
        ofSetColor(255);
        if(recorder.getStatus() != ofxMacScreenRecorder::Status::Recording || ofGetFrameNum() % 2) {
            image.draw(0, 0);
        }
        ofSetColor(255, 0, 0);
        ofDrawLine(0, 0, ofGetFrameNum() % ofGetWidth(), ofGetHeight());
        ofSetColor(0);
        ofDrawBitmapString(ofToString(ofGetFrameNum()), 20, 20);
    }
    
    void exit() {
        recorder.stop();
    }
    
    void keyPressed(int key) {
        if(key == 'r') {
            ofLogNotice() << ofGetWindowPositionX() << ", " << ofGetWindowPositionY();
            recorder.setSetting(recorderSetting);
            recorder.start(ofToDataPath("./test"));
        }
        if(key == 's') {
            recorder.stop();
        }
        if(key == 'f') {
            ofToggleFullscreen();
        }
    }
    void keyReleased(int key) {}
    void mouseMoved(int x, int y ) {}
    void mouseDragged(int x, int y, int button) {}
    void mousePressed(int x, int y, int button) {}
    void mouseReleased(int x, int y, int button) {}
    void mouseEntered(int x, int y) {}
    void mouseExited(int x, int y) {}
    void windowResized(int w, int h) {}
    void dragEvent(ofDragInfo dragInfo) {}
    void gotMessage(ofMessage msg) {}
};

int main() {
    ofSetupOpenGL(1280, 720, OF_WINDOW);
    ofRunApp(new ofApp());
}
