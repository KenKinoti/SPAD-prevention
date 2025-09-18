import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;
import '../models/detection_result.dart';
import 'dart:math';

class SignalDetector {
  static const double _standardSignalHeightMeters = 0.3; // 30cm typical signal height
  static const double _cameraFocalLengthPixels = 1000.0; // Approximate focal length

  Future<DetectionResult> detectSignal(CameraImage cameraImage) async {
    try {
      // Convert CameraImage to Image for processing
      final image = _convertCameraImage(cameraImage);
      if (image == null) {
        return _createUnknownResult();
      }

      // Simulate ML model inference
      // In a real implementation, this would use TensorFlow Lite
      final result = _simulateMLInference(image);

      return result;
    } catch (e) {
      print('Detection error: $e');
      return _createUnknownResult();
    }
  }

  img.Image? _convertCameraImage(CameraImage cameraImage) {
    try {
      // This is a simplified conversion
      // In practice, you'd need to handle different image formats
      if (cameraImage.format.group == ImageFormatGroup.yuv420) {
        return _convertYUV420ToImage(cameraImage);
      }
      return null;
    } catch (e) {
      print('Image conversion error: $e');
      return null;
    }
  }

  img.Image? _convertYUV420ToImage(CameraImage cameraImage) {
    final int width = cameraImage.width;
    final int height = cameraImage.height;
    final int uvRowStride = cameraImage.planes[1].bytesPerRow;
    final int uvPixelStride = cameraImage.planes[1].bytesPerPixel!;

    var image = img.Image(width: width, height: height);

    for (int x = 0; x < width; x++) {
      for (int y = 0; y < height; y++) {
        final int uvIndex = uvPixelStride * (x / 2).floor() + uvRowStride * (y / 2).floor();
        final int index = y * width + x;

        final yp = cameraImage.planes[0].bytes[index];
        final up = cameraImage.planes[1].bytes[uvIndex];
        final vp = cameraImage.planes[2].bytes[uvIndex];

        int r = (yp + vp * 1436 / 1024 - 179).round().clamp(0, 255);
        int g = (yp - up * 46549 / 131072 + 44 - vp * 93604 / 131072 + 91).round().clamp(0, 255);
        int b = (yp + up * 1814 / 1024 - 227).round().clamp(0, 255);

        image.setPixelRgb(x, y, r, g, b);
      }
    }

    return image;
  }

  DetectionResult _simulateMLInference(img.Image image) {
    // This simulates what a trained ML model would do
    // In reality, you'd load a TensorFlow Lite model here

    final random = Random();

    // Simulate finding a signal with some probability
    if (random.nextDouble() > 0.7) {
      return _createUnknownResult();
    }

    // Simulate signal detection
    final signalStates = [SignalState.red, SignalState.green, SignalState.yellow];
    final detectedState = signalStates[random.nextInt(signalStates.length)];

    // Simulate bounding box (center area of image)
    final centerX = image.width * 0.4 + random.nextDouble() * image.width * 0.2;
    final centerY = image.height * 0.3 + random.nextDouble() * image.height * 0.4;
    final boxWidth = 80.0 + random.nextDouble() * 40;
    final boxHeight = 120.0 + random.nextDouble() * 60;

    final boundingBox = BoundingBox(
      left: centerX - boxWidth / 2,
      top: centerY - boxHeight / 2,
      width: boxWidth,
      height: boxHeight,
    );

    // Calculate distance based on bounding box height
    final distance = _calculateDistance(boxHeight);

    // Simulate confidence (higher for red signals in this demo)
    final confidence = detectedState == SignalState.red
        ? 0.85 + random.nextDouble() * 0.1
        : 0.70 + random.nextDouble() * 0.2;

    return DetectionResult(
      signalState: detectedState,
      confidence: confidence,
      distance: distance,
      boundingBox: boundingBox,
    );
  }

  double _calculateDistance(double signalHeightPixels) {
    // Using pinhole camera model: distance = (real_height * focal_length) / pixel_height
    if (signalHeightPixels <= 0) return 1000.0; // Default far distance

    final distance = (_standardSignalHeightMeters * _cameraFocalLengthPixels) / signalHeightPixels;
    return distance.clamp(10.0, 1000.0); // Clamp between 10m and 1000m
  }

  DetectionResult _createUnknownResult() {
    return DetectionResult(
      signalState: SignalState.unknown,
      confidence: 0.0,
      distance: 1000.0,
    );
  }
}