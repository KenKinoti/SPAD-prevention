import 'dart:typed_data';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:flutter/services.dart';
import '../models/detection_result.dart';

class MLSignalDetector {
  static const String _modelPath = 'assets/models/signal_classifier.tflite';
  static const int _inputSize = 224; // Standard input size for MobileNet
  static const List<String> _labels = ['no_signal', 'red_signal', 'green_signal', 'yellow_signal'];

  Interpreter? _interpreter;
  bool _isModelLoaded = false;

  // Initialize the ML model
  Future<bool> initialize() async {
    try {
      print('ML: Loading TensorFlow Lite model...');

      // Load model from assets
      final modelData = await _loadModelFromAssets();
      if (modelData == null) {
        print('ML: Model file not found, will use fallback detection');
        return false;
      }

      // Initialize interpreter
      _interpreter = Interpreter.fromBuffer(modelData);
      _isModelLoaded = true;

      print('ML: Model loaded successfully');
      print('ML: Input shape: ${_interpreter!.getInputTensor(0).shape}');
      print('ML: Output shape: ${_interpreter!.getOutputTensor(0).shape}');

      return true;
    } catch (e) {
      print('ML: Error loading model: $e');
      return false;
    }
  }

  Future<Uint8List?> _loadModelFromAssets() async {
    try {
      final data = await rootBundle.load(_modelPath);
      return data.buffer.asUint8List();
    } catch (e) {
      print('ML: Model file not found at $_modelPath');
      return null;
    }
  }

  // Detect signals using ML model
  Future<DetectionResult> detectSignal(CameraImage cameraImage) async {
    if (!_isModelLoaded || _interpreter == null) {
      print('ML: Model not loaded, using fallback detection');
      return _fallbackDetection(cameraImage);
    }

    try {
      // Convert camera image to RGB
      final rgbImage = _convertCameraImageToRGB(cameraImage);
      if (rgbImage == null) {
        return _createUnknownResult();
      }

      // Preprocess image for model
      final inputData = _preprocessImage(rgbImage);

      // Run inference
      final output = List.filled(4, 0.0).reshape([1, 4]);
      _interpreter!.run(inputData, output);

      // Process results
      final predictions = output[0] as List<double>;
      return _processPredictions(predictions, cameraImage);

    } catch (e) {
      print('ML: Inference error: $e');
      return _createUnknownResult();
    }
  }

  img.Image? _convertCameraImageToRGB(CameraImage cameraImage) {
    try {
      final int width = cameraImage.width;
      final int height = cameraImage.height;

      var image = img.Image(width: width, height: height);

      // Convert YUV420 to RGB
      for (int x = 0; x < width; x++) {
        for (int y = 0; y < height; y++) {
          final int uvIndex = (y ~/ 2) * (width ~/ 2) + (x ~/ 2);
          final int yIndex = y * width + x;

          if (yIndex < cameraImage.planes[0].bytes.length &&
              uvIndex < cameraImage.planes[1].bytes.length &&
              uvIndex < cameraImage.planes[2].bytes.length) {

            final int yp = cameraImage.planes[0].bytes[yIndex];
            final int up = cameraImage.planes[1].bytes[uvIndex];
            final int vp = cameraImage.planes[2].bytes[uvIndex];

            int r = (yp + vp * 1436 / 1024 - 179).round().clamp(0, 255);
            int g = (yp - up * 46549 / 131072 + 44 - vp * 93604 / 131072 + 91).round().clamp(0, 255);
            int b = (yp + up * 1814 / 1024 - 227).round().clamp(0, 255);

            image.setPixelRgb(x, y, r, g, b);
          }
        }
      }

      return image;
    } catch (e) {
      print('ML: Image conversion error: $e');
      return null;
    }
  }

  List<List<List<List<double>>>> _preprocessImage(img.Image image) {
    // Resize image to model input size
    final resized = img.copyResize(image, width: _inputSize, height: _inputSize);

    // Convert to 4D tensor [1, height, width, channels]
    final input = List.generate(
      1,
      (_) => List.generate(
        _inputSize,
        (y) => List.generate(
          _inputSize,
          (x) {
            final pixel = resized.getPixel(x, y);
            return [
              (pixel.r / 127.5) - 1.0,  // Normalize to [-1, 1]
              (pixel.g / 127.5) - 1.0,
              (pixel.b / 127.5) - 1.0,
            ];
          },
        ),
      ),
    );

    return input;
  }

  DetectionResult _processPredictions(List<double> predictions, CameraImage cameraImage) {
    // Find the class with highest confidence
    double maxConfidence = 0.0;
    int maxIndex = 0;

    for (int i = 0; i < predictions.length; i++) {
      if (predictions[i] > maxConfidence) {
        maxConfidence = predictions[i];
        maxIndex = i;
      }
    }

    print('ML: Predictions - No Signal: ${predictions[0].toStringAsFixed(3)}, '
          'Red: ${predictions[1].toStringAsFixed(3)}, '
          'Green: ${predictions[2].toStringAsFixed(3)}, '
          'Yellow: ${predictions[3].toStringAsFixed(3)}');

    // Only accept predictions with high confidence
    if (maxConfidence < 0.7) {
      print('ML: Low confidence (${maxConfidence.toStringAsFixed(3)}), returning unknown');
      return _createUnknownResult();
    }

    // Map predictions to signal states
    SignalState signalState;
    switch (maxIndex) {
      case 1:
        signalState = SignalState.red;
        break;
      case 2:
        signalState = SignalState.green;
        break;
      case 3:
        signalState = SignalState.yellow;
        break;
      default:
        signalState = SignalState.unknown;
    }

    // Estimate distance (simplified)
    final distance = _estimateDistance(cameraImage.width.toDouble());

    return DetectionResult(
      signalState: signalState,
      confidence: maxConfidence,
      distance: distance,
      boundingBox: BoundingBox(
        left: cameraImage.width * 0.25,
        top: cameraImage.height * 0.25,
        width: cameraImage.width * 0.5,
        height: cameraImage.height * 0.5,
      ),
    );
  }

  double _estimateDistance(double imageWidth) {
    // Simple distance estimation based on image size
    // This could be improved with object detection that provides bounding box size
    return 50.0; // Default distance in meters
  }

  // Fallback detection when ML model is not available
  DetectionResult _fallbackDetection(CameraImage cameraImage) {
    print('ML: Using fallback color-based detection');

    // Simple red pixel counting as fallback
    int redPixelCount = 0;
    int totalSamples = 0;
    const sampleStep = 10;

    for (int y = 0; y < cameraImage.height; y += sampleStep) {
      for (int x = 0; x < cameraImage.width; x += sampleStep) {
        final yIndex = y * cameraImage.width + x;
        if (yIndex < cameraImage.planes[0].bytes.length) {
          final yp = cameraImage.planes[0].bytes[yIndex];

          // Simple brightness-based red detection
          if (yp > 150) {
            redPixelCount++;
          }
          totalSamples++;
        }
      }
    }

    final redRatio = totalSamples > 0 ? redPixelCount / totalSamples : 0.0;

    if (redRatio > 0.3) {
      return DetectionResult(
        signalState: SignalState.red,
        confidence: redRatio * 0.8, // Lower confidence for fallback
        distance: 100.0,
      );
    }

    return _createUnknownResult();
  }

  DetectionResult _createUnknownResult() {
    return DetectionResult(
      signalState: SignalState.unknown,
      confidence: 0.0,
      distance: 1000.0,
    );
  }

  void dispose() {
    _interpreter?.close();
    _isModelLoaded = false;
  }
}