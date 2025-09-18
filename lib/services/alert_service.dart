import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

class AlertService {
  static final AlertService _instance = AlertService._internal();
  factory AlertService() => _instance;
  AlertService._internal();

  AudioPlayer? _audioPlayer;
  bool _isAlarmActive = false;

  Future<void> triggerAlarm() async {
    print('ALERT SERVICE: triggerAlarm() called with controlled response');

    if (_isAlarmActive) {
      print('Alarm already active, ignoring duplicate trigger');
      return;
    }

    print('Activating alarm with vibration only (audio disabled)');
    _isAlarmActive = true;

    // Only use haptic feedback - disable audio to prevent loops
    HapticFeedback.vibrate();

    // Start controlled vibration without audio
    _startVibrationLoop();
  }

  Future<void> stopAlarm() async {
    _isAlarmActive = false;

    // Stop audio
    await _audioPlayer?.stop();
    _audioPlayer?.dispose();
    _audioPlayer = null;
  }

  Future<void> _playAlarmSound() async {
    print('AUDIO: _playAlarmSound() called but DISABLED for testing');
    return; // Completely disable audio

    try {
      _audioPlayer = AudioPlayer();

      // Create a simple alarm tone using frequency generator
      // In a real app, you'd use an actual alarm sound file
      await _audioPlayer!.setSource(AssetSource('sounds/alarm.mp3'));
      await _audioPlayer!.setReleaseMode(ReleaseMode.loop);
      await _audioPlayer!.setVolume(1.0);
      await _audioPlayer!.resume();
    } catch (e) {
      print('Audio alarm error: $e');
      // Fallback to system sounds if custom audio fails
      _playSystemAlarm();
    }
  }

  void _playSystemAlarm() {
    print('SYSTEM ALARM: _playSystemAlarm() called but DISABLED for testing');
    return; // Completely disable system alarm

    // Use system sounds as fallback
    SystemSound.play(SystemSoundType.alert);

    // Repeat system sound if alarm is still active
    Future.delayed(const Duration(seconds: 1), () {
      if (_isAlarmActive) {
        _playSystemAlarm();
      }
    });
  }

  void _startVibrationLoop() {
    if (!_isAlarmActive) return;

    HapticFeedback.heavyImpact();

    // Continue vibrating every 500ms while alarm is active
    Future.delayed(const Duration(milliseconds: 500), () {
      if (_isAlarmActive) {
        _startVibrationLoop();
      }
    });
  }

  bool get isAlarmActive => _isAlarmActive;
}