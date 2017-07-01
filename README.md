# ofxMacScreenRecorder

## Notice

* only MacOS
* now, this addon can't record screen of itself.

## How to use

```cpp
ofxMacScreenRecorder recorder;
...
void setup() {
    ofxMacScreenRecorderSetting setting;
    setting.recordingArea.set(0, 0, 1920, 1080);
    setting.frameRate = 60.0f;
    recorder.setup(setting);
}

void keyPressed() {
    if(recorder.isRecordingNow()) recorder.stop();
    else recorder.start(ofToDataPath("test")); // not need extension.
}
```

##  Update history

### 2017/07/01 ver 0.01 release

## License

MIT License.

## Author

- ISHII 2bit [bufferRenaiss co., ltd.]
- ishii[at]buffer-renaiss.com

## At the last

Please create new issue, if there is a problem. And please throw pull request, if you have a cool idea!!