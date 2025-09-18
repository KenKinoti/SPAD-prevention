import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/detection_result.dart';

class DetectionLogger {
  static final DetectionLogger _instance = DetectionLogger._internal();
  factory DetectionLogger() => _instance;
  DetectionLogger._internal();

  static const String _logFileName = 'detection_history.json';
  List<DetectionResult> _history = [];

  Future<void> logDetection(DetectionResult result) async {
    // Only log significant detections (not unknown with low confidence)
    if (result.signalState == SignalState.unknown && result.confidence < 0.5) {
      return;
    }

    _history.add(result);

    // Keep only last 1000 detections to prevent excessive storage
    if (_history.length > 1000) {
      _history.removeAt(0);
    }

    await _saveToFile();
  }

  Future<List<DetectionResult>> getHistory() async {
    if (_history.isEmpty) {
      await _loadFromFile();
    }
    return List.from(_history.reversed); // Most recent first
  }

  Future<List<DetectionResult>> getAlarmedDetections() async {
    final history = await getHistory();
    return history.where((detection) =>
        detection.signalState == SignalState.red &&
        detection.distance <= 100.0
    ).toList();
  }

  Future<void> clearHistory() async {
    _history.clear();
    await _saveToFile();
  }

  Future<File> _getLogFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/$_logFileName');
  }

  Future<void> _saveToFile() async {
    try {
      final file = await _getLogFile();
      final jsonData = _history.map((detection) => detection.toJson()).toList();
      await file.writeAsString(json.encode(jsonData));
    } catch (e) {
      print('Error saving detection history: $e');
    }
  }

  Future<void> _loadFromFile() async {
    try {
      final file = await _getLogFile();
      if (await file.exists()) {
        final jsonString = await file.readAsString();
        final List<dynamic> jsonData = json.decode(jsonString);
        _history = jsonData
            .map((item) => DetectionResult.fromJson(item))
            .toList();
      }
    } catch (e) {
      print('Error loading detection history: $e');
      _history = [];
    }
  }

  int get totalDetections => _history.length;

  int get redSignalDetections => _history
      .where((d) => d.signalState == SignalState.red)
      .length;

  int get alarmTriggered => _history
      .where((d) => d.signalState == SignalState.red && d.distance <= 100.0)
      .length;
}