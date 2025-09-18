import 'package:flutter/material.dart';
import '../models/detection_result.dart';
import '../services/detection_logger.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final DetectionLogger _logger = DetectionLogger();
  List<DetectionResult> _history = [];
  bool _showOnlyAlarms = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);

    final history = _showOnlyAlarms
        ? await _logger.getAlarmedDetections()
        : await _logger.getHistory();

    setState(() {
      _history = history;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.red,
        title: const Text('Detection History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _showClearConfirmation,
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Toggle
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Text(
                  'Show only alarms:',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
                const SizedBox(width: 10),
                Switch(
                  value: _showOnlyAlarms,
                  onChanged: (value) {
                    setState(() => _showOnlyAlarms = value);
                    _loadHistory();
                  },
                  activeColor: Colors.red,
                ),
              ],
            ),
          ),

          // Statistics
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem('Total', _logger.totalDetections.toString()),
                _buildStatItem('Red Signals', _logger.redSignalDetections.toString()),
                _buildStatItem('Alarms', _logger.alarmTriggered.toString()),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // History List
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.red),
                  )
                : _history.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.history,
                              size: 64,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _showOnlyAlarms
                                  ? 'No alarm events recorded'
                                  : 'No detections recorded yet',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 18,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _history.length,
                        itemBuilder: (context, index) {
                          final detection = _history[index];
                          return _buildDetectionCard(detection);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildDetectionCard(DetectionResult detection) {
    final isAlarm = detection.signalState == SignalState.red &&
                   detection.distance <= 100.0;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      color: isAlarm ? Colors.red[900] : Colors.grey[900],
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.8),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.grey[400]!, width: 1),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Top light (red)
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: detection.signalState == SignalState.red
                      ? Colors.red
                      : Colors.grey[700],
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 0.5),
                ),
              ),
              // Middle light (yellow)
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: detection.signalState == SignalState.yellow
                      ? Colors.yellow
                      : Colors.grey[700],
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 0.5),
                ),
              ),
              // Bottom light (green)
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: detection.signalState == SignalState.green
                      ? Colors.green
                      : Colors.grey[700],
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 0.5),
                ),
              ),
            ],
          ),
        ),
        title: Text(
          _getSignalStateText(detection.signalState),
          style: TextStyle(
            color: Colors.white,
            fontWeight: isAlarm ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Distance: ${detection.distance.toStringAsFixed(1)}m | '
              'Confidence: ${(detection.confidence * 100).toStringAsFixed(1)}%',
              style: const TextStyle(color: Colors.grey),
            ),
            Text(
              _formatDateTime(detection.timestamp),
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
        trailing: isAlarm
            ? const Icon(Icons.alarm, color: Colors.red)
            : null,
      ),
    );
  }

  String _getSignalStateText(SignalState state) {
    switch (state) {
      case SignalState.red:
        return 'RED SIGNAL';
      case SignalState.green:
        return 'GREEN SIGNAL';
      case SignalState.yellow:
        return 'YELLOW SIGNAL';
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

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} '
           '${dateTime.hour.toString().padLeft(2, '0')}:'
           '${dateTime.minute.toString().padLeft(2, '0')}:'
           '${dateTime.second.toString().padLeft(2, '0')}';
  }

  void _showClearConfirmation() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title: const Text(
            'Clear History',
            style: TextStyle(color: Colors.white),
          ),
          content: const Text(
            'Are you sure you want to clear all detection history? This action cannot be undone.',
            style: TextStyle(color: Colors.white),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                await _logger.clearHistory();
                Navigator.pop(context);
                _loadHistory();
              },
              child: const Text(
                'Clear',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
  }
}