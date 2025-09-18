import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/signal_detector.dart';
import '../services/alert_service.dart';
import '../services/detection_logger.dart';
import '../models/detection_result.dart';
import 'history_screen.dart';
import 'training_screen.dart';

class CameraScreen extends StatefulWidget {
  final CameraDescription camera;

  const CameraScreen({super.key, required this.camera});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _controller;
  bool _isDetecting = false;
  bool _isInitialized = false;
  String _status = 'Initializing...';
  DetectionResult? _lastDetection;
  bool _isAlarmActive = false;

  final SignalDetector _detector = SignalDetector();
  final AlertService _alertService = AlertService();
  final DetectionLogger _logger = DetectionLogger();

  @override
  void initState() {
    super.initState();
    // Force clear any cached detection state
    _lastDetection = null;
    _isAlarmActive = false;
    _isDetecting = false;
    print('Camera screen initialized - all detection state cleared');
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    final cameraPermission = await Permission.camera.request();
    if (cameraPermission.isDenied) {
      setState(() {
        _status = 'Camera permission denied';
      });
      return;
    }

    _controller = CameraController(
      widget.camera,
      ResolutionPreset.high,
      enableAudio: false,
    );

    try {
      await _controller!.initialize();
      setState(() {
        _isInitialized = true;
        _status = 'Ready';
      });
    } catch (e) {
      setState(() {
        _status = 'Camera initialization failed: $e';
      });
    }
  }

  void _startDetection() {
    print('=== START DETECTION CALLED ===');
    print('_isInitialized: $_isInitialized');
    print('_isDetecting: $_isDetecting');
    print('_lastDetection: $_lastDetection');
    print('_isAlarmActive: $_isAlarmActive');

    if (!_isInitialized || _isDetecting) {
      print('Detection blocked: not initialized or already detecting');
      return;
    }

    print('Setting detection state...');
    setState(() {
      _isDetecting = true;
      _status = 'Detection Active (Training Data Ready)...';
      _lastDetection = null;
      _isAlarmActive = false;
    });

    print('Starting image stream with controlled detection...');

    // Re-enable image stream with careful monitoring
    _controller!.startImageStream((CameraImage image) async {
      if (!_isDetecting) return;

      try {
        print('Processing camera frame: ${image.width}x${image.height}');
        final result = await _detector.detectSignal(image);

        if (result.signalState != SignalState.unknown) {
          print('DETECTION RESULT: ${result.signalState.name}, confidence: ${(result.confidence * 100).toStringAsFixed(1)}%');

          setState(() {
            _lastDetection = result;
          });

          // Only trigger alarm for high-confidence red signals
          if (result.signalState == SignalState.red && result.confidence > 0.7) {
            print('HIGH CONFIDENCE RED SIGNAL - triggering alarm');
            _alertService.triggerAlarm();
            _logger.logDetection(result);

            setState(() {
              _isAlarmActive = true;
            });
          } else {
            _logger.logDetection(result);
          }
        }
      } catch (e) {
        print('Detection error: $e');
      }
    });
  }

  void _stopDetection() {
    if (!_isDetecting) return;

    _controller!.stopImageStream();
    _alertService.stopAlarm();

    setState(() {
      _isDetecting = false;
      _isAlarmActive = false;
      _status = 'Detection stopped';
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    _alertService.stopAlarm();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _isAlarmActive ? Colors.red : Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Camera Preview
            if (_isInitialized)
              Positioned.fill(
                child: CameraPreview(_controller!),
              )
            else
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(color: Colors.red),
                    const SizedBox(height: 20),
                    Text(
                      _status,
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ],
                ),
              ),

            // Alarm Overlay
            if (_isAlarmActive)
              Positioned.fill(
                child: Container(
                  color: Colors.red.withOpacity(0.8),
                  child: const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.warning,
                          size: 100,
                          color: Colors.white,
                        ),
                        SizedBox(height: 20),
                        Text(
                          'STOP!',
                          style: TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'RED SIGNAL AHEAD',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // Detection Info Overlay
            Positioned(
              top: 20,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Status: $_status',
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                    if (_lastDetection != null) ...[
                      const SizedBox(height: 5),
                      Text(
                        'Signal: ${_getSignalStateText(_lastDetection!.signalState)}',
                        style: TextStyle(
                          color: _getSignalColor(_lastDetection!.signalState),
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Distance: ${_lastDetection!.distance.toStringAsFixed(1)}m',
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                      ),
                      Text(
                        'Confidence: ${(_lastDetection!.confidence * 100).toStringAsFixed(1)}%',
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Railway Signal Detection Overlay
            if (_lastDetection != null && _lastDetection!.boundingBox != null)
              Positioned(
                left: _lastDetection!.boundingBox!.left,
                top: _lastDetection!.boundingBox!.top,
                child: Container(
                  width: _lastDetection!.boundingBox!.width,
                  height: _lastDetection!.boundingBox!.height,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: _getSignalColor(_lastDetection!.signalState),
                      width: 3,
                    ),
                  ),
                  child: Stack(
                    children: [
                      // Railway Signal Housing
                      Center(
                        child: Container(
                          width: _lastDetection!.boundingBox!.width * 0.6,
                          height: _lastDetection!.boundingBox!.height * 0.8,
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.8),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey[400]!, width: 2),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              // Top light (red in red signal, dark in others)
                              Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: _lastDetection!.signalState == SignalState.red
                                      ? Colors.red
                                      : Colors.grey[800],
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 1),
                                  boxShadow: _lastDetection!.signalState == SignalState.red
                                      ? [
                                          BoxShadow(
                                            color: Colors.red.withOpacity(0.8),
                                            blurRadius: 8,
                                            spreadRadius: 2,
                                          )
                                        ]
                                      : null,
                                ),
                              ),
                              // Middle light (yellow in yellow signal, dark in others)
                              Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: _lastDetection!.signalState == SignalState.yellow
                                      ? Colors.yellow
                                      : Colors.grey[800],
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 1),
                                  boxShadow: _lastDetection!.signalState == SignalState.yellow
                                      ? [
                                          BoxShadow(
                                            color: Colors.yellow.withOpacity(0.8),
                                            blurRadius: 8,
                                            spreadRadius: 2,
                                          )
                                        ]
                                      : null,
                                ),
                              ),
                              // Bottom light (green in green signal, dark in others)
                              Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: _lastDetection!.signalState == SignalState.green
                                      ? Colors.green
                                      : Colors.grey[800],
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 1),
                                  boxShadow: _lastDetection!.signalState == SignalState.green
                                      ? [
                                          BoxShadow(
                                            color: Colors.green.withOpacity(0.8),
                                            blurRadius: 8,
                                            spreadRadius: 2,
                                          )
                                        ]
                                      : null,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Signal Label
                      Positioned(
                        top: 0,
                        left: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          color: _getSignalColor(_lastDetection!.signalState),
                          child: Text(
                            _getSignalStateText(_lastDetection!.signalState),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Control Buttons
            Positioned(
              bottom: 30,
              left: 20,
              right: 20,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Main action row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      FloatingActionButton(
                        onPressed: () => Navigator.pop(context),
                        backgroundColor: Colors.grey[800],
                        child: const Icon(Icons.arrow_back, color: Colors.white),
                      ),
                      FloatingActionButton.extended(
                        onPressed: _isDetecting ? _stopDetection : _startDetection,
                        backgroundColor: _isDetecting ? Colors.red : Colors.green,
                        icon: Icon(_isDetecting ? Icons.stop : Icons.play_arrow),
                        label: Text(_isDetecting ? 'STOP' : 'START'),
                      ),
                      FloatingActionButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const HistoryScreen(),
                            ),
                          );
                        },
                        backgroundColor: Colors.grey[800],
                        child: const Icon(Icons.history, color: Colors.white),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Training button
                  FloatingActionButton.extended(
                    onPressed: () {
                      // Stop detection before going to training
                      if (_isDetecting) _stopDetection();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => TrainingScreen(camera: widget.camera),
                        ),
                      );
                    },
                    backgroundColor: Colors.blue,
                    icon: const Icon(Icons.school),
                    label: const Text('TRAINING'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getSignalStateText(SignalState state) {
    switch (state) {
      case SignalState.red:
        return 'RED';
      case SignalState.green:
        return 'GREEN';
      case SignalState.yellow:
        return 'YELLOW';
      case SignalState.unknown:
        return 'UNKNOWN';
    }
  }

  Color _getSignalColor(SignalState state) {
    switch (state) {
      case SignalState.red:
        return Colors.red;
      case SignalState.green:
        return Colors.green;
      case SignalState.yellow:
        return Colors.yellow;
      case SignalState.unknown:
        return Colors.grey;
    }
  }
}