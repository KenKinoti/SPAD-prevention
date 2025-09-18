import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/training_data_collector.dart';
import '../models/detection_result.dart';

class TrainingScreen extends StatefulWidget {
  final CameraDescription camera;

  const TrainingScreen({super.key, required this.camera});

  @override
  State<TrainingScreen> createState() => _TrainingScreenState();
}

class _TrainingScreenState extends State<TrainingScreen> {
  CameraController? _controller;
  bool _isInitialized = false;
  String _status = 'Initializing...';
  SignalState _selectedSignalType = SignalState.red;
  String _description = '';
  Map<String, int> _trainingStats = {};

  final TrainingDataCollector _collector = TrainingDataCollector();
  final TextEditingController _descriptionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _loadTrainingStats();
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
        _status = 'Ready to capture training images';
      });
    } catch (e) {
      setState(() {
        _status = 'Camera initialization failed: $e';
      });
    }
  }

  Future<void> _loadTrainingStats() async {
    final stats = await _collector.getTrainingDataStats();
    setState(() {
      _trainingStats = stats;
    });
  }

  Future<void> _captureTrainingImage() async {
    if (!_isInitialized || _controller == null) return;

    try {
      setState(() {
        _status = 'Capturing training image...';
      });

      // Start image stream to get current frame
      bool imageCaptured = false;

      _controller!.startImageStream((CameraImage image) async {
        if (imageCaptured) return;
        imageCaptured = true;

        // Stop the stream immediately
        await _controller!.stopImageStream();

        // Capture the training image
        final success = await _collector.captureTrainingImage(
          image,
          _selectedSignalType,
          _description.isEmpty ? 'training_sample' : _description,
        );

        if (success) {
          setState(() {
            _status = 'Image captured successfully!';
          });
          _loadTrainingStats(); // Refresh stats
          _descriptionController.clear();
        } else {
          setState(() {
            _status = 'Failed to capture image';
          });
        }

        // Reset status after delay
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            setState(() {
              _status = 'Ready to capture training images';
            });
          }
        });
      });

    } catch (e) {
      setState(() {
        _status = 'Capture error: $e';
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.blue,
        title: const Text('Training Data Collection'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info),
            onPressed: _showTrainingInfo,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Camera Preview
            Expanded(
              flex: 3,
              child: _isInitialized
                  ? CameraPreview(_controller!)
                  : Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const CircularProgressIndicator(color: Colors.blue),
                          const SizedBox(height: 20),
                          Text(
                            _status,
                            style: const TextStyle(color: Colors.white, fontSize: 16),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
            ),

            // Training Controls
            Expanded(
              flex: 2,
              child: Container(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Status
                    Text(
                      _status,
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),

                    // Signal Type Selection
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildSignalTypeButton(SignalState.red, 'Red', Colors.red),
                        _buildSignalTypeButton(SignalState.green, 'Green', Colors.green),
                        _buildSignalTypeButton(SignalState.yellow, 'Yellow', Colors.yellow),
                        _buildSignalTypeButton(SignalState.unknown, 'None', Colors.grey),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Description Input
                    TextField(
                      controller: _descriptionController,
                      onChanged: (value) => _description = value,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Description (optional)',
                        labelStyle: TextStyle(color: Colors.grey),
                        border: OutlineInputBorder(),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.grey),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.blue),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Capture Button
                    ElevatedButton.icon(
                      onPressed: _isInitialized ? _captureTrainingImage : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      ),
                      icon: const Icon(Icons.camera_alt),
                      label: Text('Capture ${_selectedSignalType.name.toUpperCase()}'),
                    ),
                  ],
                ),
              ),
            ),

            // Training Statistics
            Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Text(
                    'Training Data Statistics',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatItem('Red', _trainingStats['red_signals'] ?? 0, Colors.red),
                      _buildStatItem('Green', _trainingStats['green_signals'] ?? 0, Colors.green),
                      _buildStatItem('Yellow', _trainingStats['yellow_signals'] ?? 0, Colors.yellow),
                      _buildStatItem('None', _trainingStats['no_signals'] ?? 0, Colors.grey),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSignalTypeButton(SignalState type, String label, Color color) {
    final isSelected = _selectedSignalType == type;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedSignalType = type;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.transparent,
          border: Border.all(color: color, width: 2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : color,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, int count, Color color) {
    return Column(
      children: [
        Text(
          count.toString(),
          style: TextStyle(
            color: color,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  void _showTrainingInfo() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title: const Text(
            'Training Data Collection',
            style: TextStyle(color: Colors.white),
          ),
          content: const Text(
            'Instructions:\n\n'
            '1. Select signal type (Red/Green/Yellow/None)\n'
            '2. Point camera at the signal or background\n'
            '3. Add optional description\n'
            '4. Tap CAPTURE to save training image\n\n'
            'Collect diverse images:\n'
            '• Different lighting conditions\n'
            '• Various angles and distances\n'
            '• Different signal types and backgrounds\n\n'
            'Aim for 50+ images per category for good training.',
            style: TextStyle(color: Colors.white),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Got it!'),
            ),
          ],
        );
      },
    );
  }
}