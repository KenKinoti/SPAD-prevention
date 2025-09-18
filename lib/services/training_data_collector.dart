import 'dart:io';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import '../models/detection_result.dart';

class TrainingDataCollector {
  static const int _captureSize = 224; // Standard training image size

  // Capture and save training image
  Future<bool> captureTrainingImage(
    CameraImage cameraImage,
    SignalState signalType,
    String description,
  ) async {
    try {
      print('Training: Capturing ${signalType.name} signal image');

      // Convert camera image
      final rgbImage = _convertCameraImageToRGB(cameraImage);
      if (rgbImage == null) {
        print('Training: Failed to convert camera image');
        return false;
      }

      // Resize to standard training size
      final resized = img.copyResize(rgbImage, width: _captureSize, height: _captureSize);

      // Save to appropriate directory
      final saved = await _saveTrainingImage(resized, signalType, description);

      if (saved) {
        print('Training: Image saved successfully');
      } else {
        print('Training: Failed to save image');
      }

      return saved;
    } catch (e) {
      print('Training: Error capturing image: $e');
      return false;
    }
  }

  img.Image? _convertCameraImageToRGB(CameraImage cameraImage) {
    try {
      final int width = cameraImage.width;
      final int height = cameraImage.height;

      var image = img.Image(width: width, height: height);

      // Convert YUV420 to RGB (same as ML detector)
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
      print('Training: Image conversion error: $e');
      return null;
    }
  }

  Future<bool> _saveTrainingImage(
    img.Image image,
    SignalState signalType,
    String description,
  ) async {
    try {
      // Get documents directory
      final directory = await getApplicationDocumentsDirectory();

      // Create training data folder structure
      final trainingDir = Directory('${directory.path}/training_data');
      if (!trainingDir.existsSync()) {
        trainingDir.createSync(recursive: true);
      }

      // Create signal type folder
      String folderName;
      switch (signalType) {
        case SignalState.red:
          folderName = 'red_signals';
          break;
        case SignalState.green:
          folderName = 'green_signals';
          break;
        case SignalState.yellow:
          folderName = 'yellow_signals';
          break;
        case SignalState.unknown:
          folderName = 'no_signals';
          break;
      }

      final signalDir = Directory('${trainingDir.path}/$folderName');
      if (!signalDir.existsSync()) {
        signalDir.createSync(recursive: true);
      }

      // Generate filename with timestamp
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final cleanDescription = description.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
      final filename = '${timestamp}_${cleanDescription}.jpg';
      final filePath = '${signalDir.path}/$filename';

      // Encode and save image
      final jpegBytes = img.encodeJpg(image, quality: 90);
      final file = File(filePath);
      await file.writeAsBytes(jpegBytes);

      print('Training: Saved to $filePath');
      return true;

    } catch (e) {
      print('Training: Error saving image: $e');
      return false;
    }
  }

  // Get training data statistics
  Future<Map<String, int>> getTrainingDataStats() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final trainingDir = Directory('${directory.path}/training_data');

      final stats = <String, int>{
        'red_signals': 0,
        'green_signals': 0,
        'yellow_signals': 0,
        'no_signals': 0,
      };

      if (!trainingDir.existsSync()) {
        return stats;
      }

      for (final folderName in stats.keys) {
        final folder = Directory('${trainingDir.path}/$folderName');
        if (folder.existsSync()) {
          final files = folder.listSync().where((entity) => entity is File).toList();
          stats[folderName] = files.length;
        }
      }

      return stats;
    } catch (e) {
      print('Training: Error getting stats: $e');
      return <String, int>{};
    }
  }

  // Export training data for external model training
  Future<String?> exportTrainingData() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final trainingDir = Directory('${directory.path}/training_data');

      if (!trainingDir.existsSync()) {
        return null;
      }

      // Create export info file
      final exportInfo = StringBuffer();
      exportInfo.writeln('# RailSafe SPAD Training Data Export');
      exportInfo.writeln('# Generated: ${DateTime.now()}');
      exportInfo.writeln('# Format: filename,label');
      exportInfo.writeln();

      final labels = ['red_signals', 'green_signals', 'yellow_signals', 'no_signals'];

      for (int labelIndex = 0; labelIndex < labels.length; labelIndex++) {
        final folderName = labels[labelIndex];
        final folder = Directory('${trainingDir.path}/$folderName');

        if (folder.existsSync()) {
          final files = folder.listSync().where((entity) => entity is File).toList();

          for (final file in files) {
            final fileName = file.path.split('/').last;
            exportInfo.writeln('$folderName/$fileName,$labelIndex');
          }
        }
      }

      // Save export info
      final exportFile = File('${trainingDir.path}/dataset_info.csv');
      await exportFile.writeAsString(exportInfo.toString());

      print('Training: Export info saved to ${exportFile.path}');
      return trainingDir.path;

    } catch (e) {
      print('Training: Error exporting data: $e');
      return null;
    }
  }
}