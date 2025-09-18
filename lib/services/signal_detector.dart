import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;
import '../models/detection_result.dart';
import 'dart:math';

class _ColorRange {
  final double hMin, hMax;  // Hue range (0-360)
  final double sMin, sMax;  // Saturation range (0-255)
  final double vMin, vMax;  // Value/Brightness range (0-255)

  _ColorRange(this.hMin, this.sMin, this.vMin, this.hMax, this.sMax, this.vMax);
}

class SignalDetector {
  static const double _minimumCircleDiameterMeters = 0.02; // 2cm minimum diameter
  static const double _cameraFocalLengthPixels = 1000.0; // Approximate focal length
  static const double _standardSignalHeightMeters = 0.15; // Typical signal height: 15cm

  Future<DetectionResult> detectSignal(CameraImage cameraImage) async {
    try {
      // Convert CameraImage to Image for processing
      final image = _convertCameraImage(cameraImage);
      if (image == null) {
        print('Failed to convert camera image');
        return _createUnknownResult();
      }

      print('Processing image: ${image.width}x${image.height}');

      // Real computer vision processing for red circles ≥2cm
      final result = _processRealImage(image);

      return result;
    } catch (e) {
      print('Detection error: $e');
      return _createUnknownResult();
    }
  }

  img.Image? _convertCameraImage(CameraImage cameraImage) {
    print('Converting camera image: ${cameraImage.width}x${cameraImage.height}');

    // Use the working YUV420 conversion but with careful debugging
    final convertedImage = _convertYUV420ToImage(cameraImage);

    if (convertedImage != null) {
      // Sample a few center pixels to verify conversion quality
      _debugCenterPixels(convertedImage);
    }

    return convertedImage;
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

  DetectionResult _processRealImage(img.Image image) {
    print('Processing image with EXTREMELY strict red detection: ${image.width}x${image.height}');

    // Sample a few pixels first to understand the image content
    _sampleImageColors(image);

    // Look for actual red signal patterns
    final redCircles = _detectActualRedSignals(image);

    if (redCircles.isEmpty) {
      print('No valid red signals detected');
      return _createUnknownResult();
    }

    print('Found ${redCircles.length} valid red signal(s)');
    return redCircles.first;
  }

  void _sampleImageColors(img.Image image) {
    // Sample center pixels to see actual RGB values
    final centerX = image.width ~/ 2;
    final centerY = image.height ~/ 2;

    print('=== CAMERA IMAGE COLOR SAMPLE ===');
    for (int i = 0; i < 9; i++) {
      final x = centerX + (i % 3 - 1) * 20;
      final y = centerY + (i ~/ 3 - 1) * 20;

      if (x >= 0 && x < image.width && y >= 0 && y < image.height) {
        final pixel = image.getPixel(x, y);
        final r = pixel.r.toInt();
        final g = pixel.g.toInt();
        final b = pixel.b.toInt();

        print('Pixel [$x,$y]: RGB($r,$g,$b)');
      }
    }
    print('=== END SAMPLE ===');
  }

  List<DetectionResult> _detectActualRedSignals(img.Image image) {
    final detections = <DetectionResult>[];
    final width = image.width;
    final height = image.height;

    print('Scanning for actual red signals with extreme validation...');

    // Balanced grid search
    const stepX = 50;  // Moderate steps
    const stepY = 50;
    const minRadius = 15;  // Minimum 30px diameter
    const maxRadius = 80;  // Maximum 160px diameter

    int checkCount = 0;
    int redPassCount = 0;
    int circularPassCount = 0;
    int brightPassCount = 0;

    for (int y = maxRadius; y < height - maxRadius; y += stepY) {
      for (int x = maxRadius; x < width - maxRadius; x += stepX) {
        for (int radius = minRadius; radius <= maxRadius; radius += 10) {
          checkCount++;

          // First check: Is this region actually red?
          final isRed = _isRegionActuallyRed(image, x, y, radius);
          if (isRed) redPassCount++;
          if (!isRed) continue;

          // Second check: Is it circular?
          final isCircular = _isRegionCircular(image, x, y, radius);
          if (isCircular) circularPassCount++;
          if (!isCircular) continue;

          // Third check: Is it bright enough (signal lights are bright)?
          final isBright = _isRegionBrightEnough(image, x, y, radius);
          if (isBright) brightPassCount++;
          if (!isBright) continue;

          // Fourth check: Size validation for real-world signal
          final distance = _calculateDistance(radius * 2.0);
          final realDiameter = (radius * 2.0 * distance) / _cameraFocalLengthPixels;

          if (realDiameter >= _minimumCircleDiameterMeters) {
            print('VALID RED SIGNAL: center=($x,$y), radius=${radius}px, diameter=${(realDiameter*100).toStringAsFixed(1)}cm');

            final boundingBox = BoundingBox(
              left: (x - radius).toDouble(),
              top: (y - radius).toDouble(),
              width: (radius * 2).toDouble(),
              height: (radius * 2).toDouble(),
            );

            detections.add(DetectionResult(
              signalState: SignalState.red,
              confidence: 0.98, // High confidence for validated signals
              distance: distance,
              boundingBox: boundingBox,
            ));
          }
        }
      }
    }

    print('Detection summary: checked $checkCount regions, red: $redPassCount, circular: $circularPassCount, bright: $brightPassCount, valid: ${detections.length}');
    return detections;
  }

  bool _isRegionActuallyRed(img.Image image, int centerX, int centerY, int radius) {
    int totalPixels = 0;
    int redPixels = 0;
    int strongRedPixels = 0;

    for (int dy = -radius; dy <= radius; dy++) {
      for (int dx = -radius; dx <= radius; dx++) {
        if (dx * dx + dy * dy <= radius * radius) {
          final x = centerX + dx;
          final y = centerY + dy;

          if (x >= 0 && x < image.width && y >= 0 && y < image.height) {
            final pixel = image.getPixel(x, y);
            final r = pixel.r.toInt();
            final g = pixel.g.toInt();
            final b = pixel.b.toInt();

            totalPixels++;

            // Balanced red criteria - more reasonable thresholds
            if (r >= 180 &&       // Good red level
                g <= 100 &&       // Moderate green limit
                b <= 100 &&       // Moderate blue limit
                r >= g + 80 &&    // Red dominates green by 80+
                r >= b + 80) {    // Red dominates blue by 80+
              redPixels++;

              // Count very strong reds separately
              if (r >= 200 && g <= 80 && b <= 80) {
                strongRedPixels++;
              }
            }
          }
        }
      }
    }

    final redRatio = totalPixels > 0 ? (redPixels / totalPixels) : 0;
    final strongRedRatio = totalPixels > 0 ? (strongRedPixels / totalPixels) : 0;

    // Either 60% red pixels OR 30% very strong red pixels
    return redRatio >= 0.6 || strongRedRatio >= 0.3;
  }

  bool _isRegionCircular(img.Image image, int centerX, int centerY, int radius) {
    // Check if red pixels are concentrated in center (circular pattern)
    int innerPixels = 0;
    int innerRedPixels = 0;
    final innerRadius = radius * 0.6;

    for (int dy = -innerRadius.round(); dy <= innerRadius.round(); dy++) {
      for (int dx = -innerRadius.round(); dx <= innerRadius.round(); dx++) {
        if (dx * dx + dy * dy <= innerRadius * innerRadius) {
          final x = centerX + dx;
          final y = centerY + dy;

          if (x >= 0 && x < image.width && y >= 0 && y < image.height) {
            final pixel = image.getPixel(x, y);
            final r = pixel.r.toInt();
            final g = pixel.g.toInt();
            final b = pixel.b.toInt();

            innerPixels++;

            // More lenient red criteria for shape check
            if (r >= 160 && g <= 120 && b <= 120 && r > g && r > b) {
              innerRedPixels++;
            }
          }
        }
      }
    }

    final innerRedRatio = innerPixels > 0 ? (innerRedPixels / innerPixels) : 0;
    return innerRedRatio >= 0.5; // 50% of inner pixels should be reddish
  }

  bool _isRegionBrightEnough(img.Image image, int centerX, int centerY, int radius) {
    int totalPixels = 0;
    int brightPixels = 0;
    int moderateBrightPixels = 0;

    for (int dy = -radius; dy <= radius; dy++) {
      for (int dx = -radius; dx <= radius; dx++) {
        if (dx * dx + dy * dy <= radius * radius) {
          final x = centerX + dx;
          final y = centerY + dy;

          if (x >= 0 && x < image.width && y >= 0 && y < image.height) {
            final pixel = image.getPixel(x, y);
            final r = pixel.r.toInt();
            final g = pixel.g.toInt();
            final b = pixel.b.toInt();

            totalPixels++;

            // Count bright pixels
            if (r >= 180) {
              brightPixels++;
            }

            // Count moderately bright pixels (overall brightness)
            final brightness = (r + g + b) / 3;
            if (brightness >= 120) {
              moderateBrightPixels++;
            }
          }
        }
      }
    }

    final brightRatio = totalPixels > 0 ? (brightPixels / totalPixels) : 0;
    final moderateBrightRatio = totalPixels > 0 ? (moderateBrightPixels / totalPixels) : 0;

    // Either 40% bright red pixels OR 60% overall bright pixels
    return brightRatio >= 0.4 || moderateBrightRatio >= 0.6;
  }

  List<DetectionResult> _findPureRedRegions(img.Image image) {
    final detections = <DetectionResult>[];
    final width = image.width;
    final height = image.height;

    // Much larger grid - only sample key areas
    const stepX = 60;
    const stepY = 60;
    const sampleRadius = 15; // Smaller radius for more precision

    for (int y = sampleRadius; y < height - sampleRadius; y += stepY) {
      for (int x = sampleRadius; x < width - sampleRadius; x += stepX) {

        // Check if this region is 100% red
        final pureRed = _checkPureRedRegion(image, x, y, sampleRadius);

        if (pureRed) {
          print('100% RED region found at ($x,$y)');

          // Create detection result
          final boundingBox = BoundingBox(
            left: (x - sampleRadius).toDouble(),
            top: (y - sampleRadius).toDouble(),
            width: (sampleRadius * 2).toDouble(),
            height: (sampleRadius * 2).toDouble(),
          );

          final distance = _calculateDistance(boundingBox.height);
          final realDiameter = (boundingBox.height * distance) / _cameraFocalLengthPixels;

          // Only accept if ≥2cm diameter
          if (realDiameter >= _minimumCircleDiameterMeters) {
            print('Pure red region meets size requirement: ${(realDiameter*100).toStringAsFixed(1)}cm');
            detections.add(DetectionResult(
              signalState: SignalState.red,
              confidence: 1.0, // 100% confidence for pure red
              distance: distance,
              boundingBox: boundingBox,
            ));
          } else {
            print('Pure red region too small: ${(realDiameter*100).toStringAsFixed(1)}cm < 2cm');
          }
        }
      }
    }

    return detections;
  }

  bool _checkPureRedRegion(img.Image image, int centerX, int centerY, int radius) {
    int totalPixels = 0;
    int pureRedPixels = 0;

    // Check every pixel in the circular region
    for (int dy = -radius; dy <= radius; dy++) {
      for (int dx = -radius; dx <= radius; dx++) {
        if (dx * dx + dy * dy <= radius * radius) {
          final x = centerX + dx;
          final y = centerY + dy;

          if (x >= 0 && x < image.width && y >= 0 && y < image.height) {
            final pixel = image.getPixel(x, y);
            final r = pixel.r.toInt();
            final g = pixel.g.toInt();
            final b = pixel.b.toInt();

            totalPixels++;

            // EXTREMELY strict red criteria
            if (r >= 200 &&           // Red channel must be very high
                g <= 80 &&            // Green channel must be low
                b <= 80 &&            // Blue channel must be low
                r >= g + 120 &&       // Red must dominate green by 120+
                r >= b + 120) {       // Red must dominate blue by 120+
              pureRedPixels++;
            }
          }
        }
      }
    }

    // Require 100% of pixels to be pure red
    final redPercentage = totalPixels > 0 ? (pureRedPixels / totalPixels) : 0;

    if (redPercentage >= 1.0) {
      print('Region analysis: ${pureRedPixels}/${totalPixels} pixels = ${(redPercentage*100).toInt()}% pure red');
      return true;
    }

    return false;
  }

  double _analyzeRegionForRed(img.Image image, int centerX, int centerY, int radius) {
    int totalPixels = 0;
    int redPixels = 0;
    int brightRedPixels = 0;

    // Sample in circular pattern
    for (int dy = -radius; dy <= radius; dy++) {
      for (int dx = -radius; dx <= radius; dx++) {
        if (dx * dx + dy * dy <= radius * radius) {
          final x = centerX + dx;
          final y = centerY + dy;

          if (x >= 0 && x < image.width && y >= 0 && y < image.height) {
            final pixel = image.getPixel(x, y);
            final r = pixel.r.toInt();
            final g = pixel.g.toInt();
            final b = pixel.b.toInt();

            totalPixels++;

            // Check for red: R > G and R > B, and bright enough
            if (r > 180 && r > g + 50 && r > b + 50) {
              redPixels++;

              // Check for very bright red
              if (r > 220 && g < 100 && b < 100) {
                brightRedPixels++;
              }
            }
          }
        }
      }
    }

    if (totalPixels == 0) return 0;

    final redRatio = redPixels / totalPixels;
    final brightRedRatio = brightRedPixels / totalPixels;

    // Require both red pixels AND bright red pixels
    return redRatio * 0.5 + brightRedRatio * 0.5;
  }

  void _debugCenterPixels(img.Image image) {
    // Sample a few pixels from center of image
    final centerX = image.width ~/ 2;
    final centerY = image.height ~/ 2;

    for (int i = 0; i < 5; i++) {
      final x = centerX + (i - 2) * 10;
      final y = centerY + (i - 2) * 10;

      if (x >= 0 && x < image.width && y >= 0 && y < image.height) {
        final pixel = image.getPixel(x, y);
        final hsv = _rgbToHsv(pixel.r.toInt(), pixel.g.toInt(), pixel.b.toInt());
        print('Pixel [$x,$y]: RGB(${pixel.r},${pixel.g},${pixel.b}) -> HSV(${hsv[0].toInt()},${hsv[1].toInt()},${hsv[2].toInt()})');
      }
    }
  }

  List<DetectionResult> _detectCircularLights(img.Image image) {
    final List<DetectionResult> detections = [];

    // Convert to HSV for better color detection
    final processedImage = _preprocessImage(image);

    // Define VERY strict color ranges - only detect strong red for now
    final redRange1 = _ColorRange(0, 200, 220, 8, 255, 255);     // Very strong red (low hue)
    final redRange2 = _ColorRange(172, 200, 220, 180, 255, 255); // Very strong red (high hue)

    // Only search for strong red signals for now
    _searchForSignalColor(processedImage, redRange1, SignalState.red, detections);
    _searchForSignalColor(processedImage, redRange2, SignalState.red, detections);

    // Sort by confidence and return top detections
    detections.sort((a, b) => b.confidence.compareTo(a.confidence));
    return detections.take(3).toList();
  }

  img.Image _preprocessImage(img.Image image) {
    // Resize for faster processing
    final resized = img.copyResize(image, width: 320, height: 240);

    // Apply Gaussian blur to reduce noise
    return img.gaussianBlur(resized, radius: 1);
  }

  void _searchForSignalColor(img.Image image, _ColorRange colorRange, SignalState signalState, List<DetectionResult> detections) {
    final width = image.width;
    final height = image.height;

    // Calculate minimum pixel radius for 2cm diameter
    // Assume 1 meter distance for minimum size calculation
    final minPixelRadius = (_minimumCircleDiameterMeters * _cameraFocalLengthPixels / 1.0) / 2;

    // Grid-based search for efficiency - smaller steps for precision
    const stepSize = 8;
    final minRadius = (minPixelRadius * 0.3).round(); // Allow some detection tolerance
    const maxRadius = 80; // Larger circles for closer objects

    print('Searching for red circles: minRadius=${minRadius}px, maxRadius=${maxRadius}px (for ≥2cm diameter)');

    for (int y = minRadius; y < height - minRadius; y += stepSize) {
      for (int x = minRadius; x < width - minRadius; x += stepSize) {

        // Check multiple radii at this position - more granular steps
        for (int radius = minRadius; radius <= maxRadius; radius += 3) {
          final detection = _analyzeCircularRegion(image, x, y, radius, colorRange, signalState);

          if (detection != null && detection.confidence > 0.85) {
            // Calculate real-world diameter
            final distance = _calculateDistance(radius * 2.0);
            final realDiameter = (radius * 2.0 * distance) / _cameraFocalLengthPixels;

            // Only accept circles that are at least 2cm in diameter
            if (realDiameter >= _minimumCircleDiameterMeters) {
              print('Found red circle: radius=${radius}px, diameter=${(realDiameter*100).toStringAsFixed(1)}cm, distance=${distance.toStringAsFixed(1)}m');

              // Scale coordinates back to original image size
              final scaleFactor = image.width / 320.0;
              final scaledBox = BoundingBox(
                left: (detection.boundingBox!.left * scaleFactor),
                top: (detection.boundingBox!.top * scaleFactor),
                width: (detection.boundingBox!.width * scaleFactor),
                height: (detection.boundingBox!.height * scaleFactor),
              );

              detections.add(DetectionResult(
                signalState: detection.signalState,
                confidence: detection.confidence,
                distance: distance,
                boundingBox: scaledBox,
              ));
            } else {
              print('Rejected circle: diameter=${(realDiameter*100).toStringAsFixed(1)}cm < 2cm minimum');
            }
          }
        }
      }
    }
  }

  DetectionResult? _analyzeCircularRegion(img.Image image, int centerX, int centerY, int radius, _ColorRange colorRange, SignalState signalState) {
    int totalPixels = 0;
    int matchingPixels = 0;
    int brightPixels = 0;

    // Sample pixels in circular region
    for (int dy = -radius; dy <= radius; dy++) {
      for (int dx = -radius; dx <= radius; dx++) {
        final distance = sqrt(dx * dx + dy * dy);
        if (distance <= radius) {
          final x = centerX + dx;
          final y = centerY + dy;

          if (x >= 0 && x < image.width && y >= 0 && y < image.height) {
            final pixel = image.getPixel(x, y);
            final hsv = _rgbToHsv(pixel.r.toInt(), pixel.g.toInt(), pixel.b.toInt());

            totalPixels++;

            // Check if pixel matches color range
            if (_isColorInRange(hsv, colorRange)) {
              matchingPixels++;
            }

            // Check brightness (signals are typically very bright)
            if (hsv[2] > 200) {
              brightPixels++;
            }
          }
        }
      }
    }

    if (totalPixels == 0) return null;

    final colorMatch = matchingPixels / totalPixels;
    final brightness = brightPixels / totalPixels;

    // Calculate confidence based on color match, brightness, and circularity
    var confidence = (colorMatch * 0.6 + brightness * 0.3 + 0.1);

    // Boost confidence for red signals (safety critical)
    if (signalState == SignalState.red && colorMatch > 0.4) {
      confidence *= 1.2;
    }

    // EXTREMELY strict thresholds for red circles only
    if (colorMatch < 0.8 || brightness < 0.7) {
      return null;
    }

    // Check for circular shape - red should be concentrated in center
    final centerColorMatch = _checkCenterConcentration(image, centerX, centerY, radius, colorRange);
    if (centerColorMatch < 0.9) {
      return null;
    }

    // Additional check: reject if image region is too uniform (like white paper)
    final variance = _calculateColorVariance(image, centerX, centerY, radius);
    if (variance < 300) { // Even higher variance required for actual objects
      return null;
    }

    // Debug output for successful detections
    print('DETECTION: State=${signalState.name}, ColorMatch=${(colorMatch*100).toInt()}%, Brightness=${(brightness*100).toInt()}%, Variance=${variance.toInt()}, Confidence=${(confidence*100).toInt()}%');

    final boundingBox = BoundingBox(
      left: (centerX - radius).toDouble(),
      top: (centerY - radius).toDouble(),
      width: (radius * 2).toDouble(),
      height: (radius * 2).toDouble(),
    );

    return DetectionResult(
      signalState: signalState,
      confidence: confidence.clamp(0.0, 1.0),
      distance: _calculateDistance(boundingBox.height),
      boundingBox: boundingBox,
    );
  }

  List<double> _rgbToHsv(int r, int g, int b) {
    final rNorm = r / 255.0;
    final gNorm = g / 255.0;
    final bNorm = b / 255.0;

    final max = [rNorm, gNorm, bNorm].reduce((a, b) => a > b ? a : b);
    final min = [rNorm, gNorm, bNorm].reduce((a, b) => a < b ? a : b);
    final delta = max - min;

    double h = 0, s = 0, v = max;

    if (delta != 0) {
      s = delta / max;

      if (max == rNorm) {
        h = ((gNorm - bNorm) / delta) % 6;
      } else if (max == gNorm) {
        h = (bNorm - rNorm) / delta + 2;
      } else {
        h = (rNorm - gNorm) / delta + 4;
      }
      h *= 60;
      if (h < 0) h += 360;
    }

    return [h, s * 255, v * 255];
  }

  bool _isColorInRange(List<double> hsv, _ColorRange range) {
    final h = hsv[0];
    final s = hsv[1];
    final v = hsv[2];

    return h >= range.hMin && h <= range.hMax &&
           s >= range.sMin && s <= range.sMax &&
           v >= range.vMin && v <= range.vMax;
  }

  double _calculateColorVariance(img.Image image, int centerX, int centerY, int radius) {
    final List<int> rValues = [];
    final List<int> gValues = [];
    final List<int> bValues = [];

    // Sample pixels in circular region
    for (int dy = -radius; dy <= radius; dy++) {
      for (int dx = -radius; dx <= radius; dx++) {
        final distance = sqrt(dx * dx + dy * dy);
        if (distance <= radius) {
          final x = centerX + dx;
          final y = centerY + dy;

          if (x >= 0 && x < image.width && y >= 0 && y < image.height) {
            final pixel = image.getPixel(x, y);
            rValues.add(pixel.r.toInt());
            gValues.add(pixel.g.toInt());
            bValues.add(pixel.b.toInt());
          }
        }
      }
    }

    if (rValues.isEmpty) return 0;

    // Calculate variance for each color channel
    final rVariance = _variance(rValues);
    final gVariance = _variance(gValues);
    final bVariance = _variance(bValues);

    // Return average variance across all channels
    return (rVariance + gVariance + bVariance) / 3;
  }

  double _variance(List<int> values) {
    if (values.isEmpty) return 0;

    final mean = values.reduce((a, b) => a + b) / values.length;
    final squaredDiffs = values.map((value) => pow(value - mean, 2));
    return squaredDiffs.reduce((a, b) => a + b) / values.length;
  }

  double _checkCenterConcentration(img.Image image, int centerX, int centerY, int radius, _ColorRange colorRange) {
    // Check if red color is concentrated in the center (typical of circular objects)
    final innerRadius = radius * 0.6; // Check inner 60% of circle
    int totalInnerPixels = 0;
    int matchingInnerPixels = 0;

    for (int dy = -innerRadius.round(); dy <= innerRadius.round(); dy++) {
      for (int dx = -innerRadius.round(); dx <= innerRadius.round(); dx++) {
        final distance = sqrt(dx * dx + dy * dy);
        if (distance <= innerRadius) {
          final x = centerX + dx;
          final y = centerY + dy;

          if (x >= 0 && x < image.width && y >= 0 && y < image.height) {
            final pixel = image.getPixel(x, y);
            final hsv = _rgbToHsv(pixel.r.toInt(), pixel.g.toInt(), pixel.b.toInt());

            totalInnerPixels++;

            if (_isColorInRange(hsv, colorRange)) {
              matchingInnerPixels++;
            }
          }
        }
      }
    }

    return totalInnerPixels > 0 ? matchingInnerPixels / totalInnerPixels : 0;
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