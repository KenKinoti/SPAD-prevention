enum SignalState {
  red,
  green,
  yellow,
  unknown,
}

class BoundingBox {
  final double left;
  final double top;
  final double width;
  final double height;

  BoundingBox({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });
}

class DetectionResult {
  final SignalState signalState;
  final double confidence;
  final double distance;
  final BoundingBox? boundingBox;
  final DateTime timestamp;

  DetectionResult({
    required this.signalState,
    required this.confidence,
    required this.distance,
    this.boundingBox,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'signalState': signalState.toString(),
      'confidence': confidence,
      'distance': distance,
      'boundingBox': boundingBox != null
          ? {
              'left': boundingBox!.left,
              'top': boundingBox!.top,
              'width': boundingBox!.width,
              'height': boundingBox!.height,
            }
          : null,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory DetectionResult.fromJson(Map<String, dynamic> json) {
    return DetectionResult(
      signalState: SignalState.values.firstWhere(
        (e) => e.toString() == json['signalState'],
        orElse: () => SignalState.unknown,
      ),
      confidence: json['confidence'],
      distance: json['distance'],
      boundingBox: json['boundingBox'] != null
          ? BoundingBox(
              left: json['boundingBox']['left'],
              top: json['boundingBox']['top'],
              width: json['boundingBox']['width'],
              height: json['boundingBox']['height'],
            )
          : null,
      timestamp: DateTime.parse(json['timestamp']),
    );
  }
}