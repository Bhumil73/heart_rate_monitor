import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:wakelock/wakelock.dart';
import 'chart.dart';
import 'heartClipper.dart';

class HomePage extends StatefulWidget {
  @override
  HomePageView createState() {
    return HomePageView();
  }
}

class HomePageView extends State<HomePage> with SingleTickerProviderStateMixin {
  bool toggled = false; // toggle button value
  List<SensorValue> _data = <SensorValue>[]; // array to store the values
  late CameraController _controller;
  double _alpha = 0.3; // factor for the mean value
  late AnimationController _animationController;
  double _iconScale = 1;
  int _bpm = 0; // beats per minute
  int _fs = 30; // sampling frequency (fps)
  int _windowLen = 30 * 6; // window length to display - 6 seconds
  CameraImage? _image; // store the last camera image
  late double _avg; // store the average value during calculation
  late DateTime _now; // store the now Datetime
  late Timer _timer; // time
  late Timer _countdown;
  late List cameras; // r for image processing

  static const int timerSecondsComplete = 30;
  int timerSeconds = timerSecondsComplete; //Timer value

  @override
  void initState() {
    super.initState();
    _animationController =
        AnimationController(duration: Duration(milliseconds: 500), vsync: this);
    _animationController
      ..addListener(() {
        setState(() {
          _iconScale = 1.0 + _animationController.value * 0.4;
        });
      });
  }

  @override
  void dispose() {
    _timer.cancel();
    toggled = false;
    _disposeController();
    Wakelock.disable();
    _animationController.stop();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Expanded(
              flex: 2,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: <Widget>[
                        Text(
                          "Estimated BPM",
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                        Text(
                          (_bpm > 15 ? _bpm.toString() : "--"),
                          style: TextStyle(
                              fontSize: 32, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 3,
              child: Stack(
                children: [
                  Center(
                    child: AspectRatio(
                      aspectRatio: 1.0,
                      child: CircularProgressIndicator(
                        color: Colors.red,
                        backgroundColor: Colors.grey.shade300,
                        semanticsValue: "Timer",
                        strokeWidth: 10,
                        value: ((timerSecondsComplete-timerSeconds).toDouble() /
                            timerSecondsComplete.toDouble()),
                      ),
                    ),
                  ),
                  Container(
                    //color: Colors.orange,
                    height: MediaQuery.of(context).size.height * 0.3,
                    padding: EdgeInsets.only(bottom: MediaQuery.of(context).size.height * 0.3*0.15),
                    child: Center(
                      child: !toggled
                          ? InkWell(
                              onTap: () {
                                toggle();
                                startTimer();
                              },
                              child: Center(
                                child: AspectRatio(
                                  aspectRatio: 0.9,
                                  child: Transform.scale(
                                    scale: !toggled ? _iconScale : 0,
                                    child: ClipPath(
                                      clipper: HeartClipper(),
                                      child: Container(
                                        color: Colors.red,
                                        padding: EdgeInsets.only(top: 30),
                                        child: Center(
                                          child: Text(
                                            "Start",
                                            style: TextStyle(color: Colors.white),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            )
                          : AspectRatio(
                              aspectRatio: 0.9,
                              child: Transform.scale(
                                scale: toggled ? _iconScale : 0,
                                child: ClipPath(
                                  clipper: HeartClipper(),
                                  child: CameraPreview(_controller),
                                ),
                              ),
                            ),
                    ),
                  ),

                ],
              ),
            ),
            SizedBox(
              height: 50,
            ),
            Expanded(
              flex: 2,
              child: Column(
                children: [
                  Text(
                    toggled
                        ? "Cover both the camera and the flash with your finger"
                        : "Click on Start to monitor your heart rate",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                    ),
                  ),
                  if (toggled)
                    Text(
                      "Hold for 30 Seconds",
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.red),
                    ),
                  SizedBox(
                    height: 10,
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 3,
              child: Container(
                margin: EdgeInsets.all(12),
                decoration: BoxDecoration(
                    borderRadius: BorderRadius.all(
                      Radius.circular(18),
                    ),
                    color: Colors.black),
                child: Chart(_data),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _clearData() {
    // create array of 128 ~= 255/2
    _data.clear();
    int now = DateTime.now().millisecondsSinceEpoch;
    for (int i = 0; i < _windowLen; i++)
      _data.insert(
          0,
          SensorValue(
              DateTime.fromMillisecondsSinceEpoch(now - i * 1000 ~/ _fs), 128));
  }

  void toggle() {
    _clearData();
    _initController().then((onValue) {
      Wakelock.enable();
      _animationController.repeat(reverse: true);
      setState(() {
        toggled = true;
      });
      // after is toggled
      _initTimer();
      _updateBPM();
    });
  }

  void unToggle() {
    _disposeController();
    Wakelock.disable();
    _animationController.stop();
    _animationController.value = 0.0;
    setState(() {
      toggled = false;
    });
  }

  void _disposeController() {
    _controller.dispose();
    //_controller = null;
  }

  Future<void> _initController() async {
    try {
      List _cameras = await availableCameras();
      _controller = CameraController(_cameras.first, ResolutionPreset.low);
      await _controller.initialize();
      Future.delayed(Duration(milliseconds: 100)).then((onValue) {
        _controller.setFlashMode(FlashMode.torch);
      });
      _controller.startImageStream((CameraImage image) {
        _image = image;
      });
    } catch (Exception) {
      print(Exception);
    }
  }

  void _initTimer() {
    _timer = Timer.periodic(Duration(milliseconds: 1000 ~/ _fs), (timer) {
      if (toggled && _image != null) {
        _scanImage(_image!);
      } else {
        timer.cancel();
      }
    });
  }

  void _scanImage(CameraImage image) {
    _now = DateTime.now();
    _avg =
        image.planes.first.bytes.reduce((value, element) => value + element) /
            image.planes.first.bytes.length;
    if (_data.length >= _windowLen) {
      _data.removeAt(0);
    }
    setState(() {
      _data.add(SensorValue(_now, 255 - _avg));
    });

    // Check if there's a sudden drop in avg, (in under .5 sec)
    // it means finger removed from cam; then unToggle
    int consideringSamplesCount = _fs ~/ 2;
    if (_data.length > consideringSamplesCount) {
      var slope = (_avg -
              _data.elementAt(_data.length - consideringSamplesCount).value) /
          consideringSamplesCount;
      print("Slope ---- $slope");
      if (slope > 3) {
        print("here");
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Finger moved away from camera!")));
        unToggle();
      }
    }
  }

  void _updateBPM() async {
    List<SensorValue> _values;
    double _avg;
    int _n;
    double _m;
    double _threshold;
    double _bpm;
    int _counter;
    int _previous;
    while (toggled) {
      _values = List.from(_data); // create a copy of the current data array
      _avg = 0;
      _n = _values.length;
      _m = 0;
      _values.forEach((SensorValue value) {
        _avg += value.value / _n;
        if (value.value > _m) _m = value.value;
      });
      _threshold = (_m + _avg) / 2;
      _bpm = 0;
      _counter = 0;
      _previous = 0;
      for (int i = 1; i < _n; i++) {
        if (_values[i - 1].value < _threshold &&
            _values[i].value > _threshold) {
          if (_previous != 0) {
            _counter++;
            _bpm += 60 *
                1000 /
                (_values[i].time.millisecondsSinceEpoch - _previous);
          }
          _previous = _values[i].time.millisecondsSinceEpoch;
        }
      }
      if (_counter > 0) {
        _bpm = _bpm / _counter;
        print(_bpm);
        setState(() {
          this._bpm = ((1 - _alpha) * this._bpm + _alpha * _bpm).toInt();
        });
      }
      await Future.delayed(Duration(
          milliseconds:
              1000 * _windowLen ~/ _fs)); // wait for a new set of _data values
    }
  }

  void startTimer() {
    timerSeconds = timerSecondsComplete;
    const oneSec = const Duration(seconds: 1);
    _countdown = new Timer.periodic(
      oneSec,
      (Timer timer) {
        if (!toggled) {
          setState(() {
            timer.cancel();
          });
        } else if (timerSeconds == 0) {
          setState(() {
            unToggle();
            timer.cancel();
          });
        } else {
          setState(() {
            timerSeconds--;
            print(timerSeconds);
          });
        }
      },
    );
  }
}
