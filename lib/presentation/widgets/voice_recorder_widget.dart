import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../../core/theme/app_theme.dart';
import '../../core/services/media_service.dart';

class VoiceRecorderWidget extends ConsumerStatefulWidget {
  final Function(String base64Data, String filename) onSendVoice;
  final VoidCallback onCancel;

  const VoiceRecorderWidget({
    super.key,
    required this.onSendVoice,
    required this.onCancel, required void Function(String path, String filename) onComplete,
  });

  @override
  ConsumerState<VoiceRecorderWidget> createState() => _VoiceRecorderWidgetState();
}

class _VoiceRecorderWidgetState extends ConsumerState<VoiceRecorderWidget>
    with TickerProviderStateMixin {
  FlutterSoundRecorder? _recorder;

  bool _isRecording = false;
  bool _isPaused = false;
  bool _isPlaying = false;
  Duration _recordingDuration = Duration.zero;
  Timer? _timer;
  String? _recordedFilePath;
  bool _isInitialized = false;

  late AnimationController _pulseController;
  late AnimationController _waveController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _waveAnimation;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _waveController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _waveAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _waveController,
      curve: Curves.linear,
    ));

    _initRecorder();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    _waveController.dispose();
    _closeRecorder();

    if (_recordedFilePath != null) {
      try {
        File(_recordedFilePath!).deleteSync();
      } catch (e) {
        print('Error cleaning up recorded file: $e');
      }
    }

    super.dispose();
  }

  Future<void> _initRecorder() async {
    try {
      _recorder = FlutterSoundRecorder();
      await _recorder!.openRecorder();

      setState(() {
        _isInitialized = true;
      });

      _startRecording();
    } catch (e) {
      print('Error initializing recorder: $e');
      _showError('Failed to initialize recorder: $e');
      widget.onCancel();
    }
  }

  Future<void> _closeRecorder() async {
    try {
      if (_recorder != null) {
        await _recorder!.closeRecorder();
        _recorder = null;
      }
    } catch (e) {
      print('Error closing recorder: $e');
    }
  }

  Future<void> _startRecording() async {
    if (!_isInitialized || _recorder == null) return;

    try {
      final permission = await Permission.microphone.request();
      if (!permission.isGranted) {
        _showError('Microphone permission is required to record voice messages');
        widget.onCancel();
        return;
      }

      final tempDir = Directory.systemTemp;
      final filePath = '${tempDir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.aac';

      await _recorder!.startRecorder(
        toFile: filePath,
        codec: Codec.aacADTS,
        bitRate: 128000,
        sampleRate: 44100,
      );

      setState(() {
        _isRecording = true;
        _recordingDuration = Duration.zero;
      });

      _pulseController.repeat(reverse: true);
      _waveController.repeat();

      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted) {
          setState(() {
            _recordingDuration = Duration(seconds: timer.tick);
          });
        }
      });

      print('Voice recording started in AAC format');
    } catch (e) {
      print('Error starting recording: $e');
      _showError('Failed to start recording: $e');
      widget.onCancel();
    }
  }

  Future<void> _stopRecording() async {
    if (_recorder == null) return;

    try {
      final path = await _recorder!.stopRecorder();

      setState(() {
        _isRecording = false;
      });

      _timer?.cancel();
      _pulseController.stop();
      _waveController.stop();

      if (path != null) {
        setState(() {
          _recordedFilePath = path;
        });
        print('Recording stopped, AAC file saved at: $path');
      } else {
        _showError('Failed to save recording');
        widget.onCancel();
      }
    } catch (e) {
      print('Error stopping recording: $e');
      _showError('Failed to stop recording: $e');
      widget.onCancel();
    }
  }

  Future<void> _pauseRecording() async {
    if (_recorder == null) return;

    try {
      await _recorder!.pauseRecorder();
      setState(() {
        _isPaused = true;
      });
      _timer?.cancel();
      _pulseController.stop();
      _waveController.stop();
    } catch (e) {
      print('Error pausing recording: $e');
    }
  }

  Future<void> _resumeRecording() async {
    if (_recorder == null) return;

    try {
      await _recorder!.resumeRecorder();
      setState(() {
        _isPaused = false;
      });

      final currentSeconds = _recordingDuration.inSeconds;
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted) {
          setState(() {
            _recordingDuration = Duration(seconds: currentSeconds + timer.tick);
          });
        }
      });

      _pulseController.repeat(reverse: true);
      _waveController.repeat();
    } catch (e) {
      print('Error resuming recording: $e');
    }
  }

  Future<void> _sendVoiceNote() async {
    if (_recordedFilePath == null) return;

    try {
      final file = File(_recordedFilePath!);
      final bytes = await file.readAsBytes();
      final base64Data = base64Encode(bytes);
      final filename = 'voice_${DateTime.now().millisecondsSinceEpoch}.aac';

      widget.onSendVoice(base64Data, filename);

      print('Voice note sent: $filename');
    } catch (e) {
      print('Error sending voice note: $e');
      _showError('Failed to send voice note: $e');
    }
  }

  void _cancelRecording() async {
    if (_isRecording && _recorder != null) {
      await _recorder!.stopRecorder();
    }
    widget.onCancel();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.errorColor,
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _isRecording || _isPaused ? 'Recording Voice Note' : 'Voice Note Ready',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              IconButton(
                onPressed: _cancelRecording,
                icon: const Icon(Icons.close),
                color: AppTheme.textSecondary,
              ),
            ],
          ),

          const SizedBox(height: 20),

          if (_isRecording || _isPaused)
            _buildRecordingVisualization()
          else
            _buildPlaybackControls(),

          const SizedBox(height: 20),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.neutralLight,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _formatDuration(_recordingDuration),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
                fontFamily: 'monospace',
              ),
            ),
          ),

          const SizedBox(height: 20),

          if (_isRecording || _isPaused)
            _buildRecordingControls()
          else
            _buildPlaybackActions(),
        ],
      ),
    );
  }

  Widget _buildRecordingVisualization() {
    return SizedBox(
      height: 100,
      child: Center(
        child: AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _pulseAnimation.value,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: _isPaused ? AppTheme.warningColor : AppTheme.errorColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: (_isPaused ? AppTheme.warningColor : AppTheme.errorColor).withOpacity(0.3),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Icon(
                  _isPaused ? Icons.pause : Icons.mic,
                  color: Colors.white,
                  size: 40,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildPlaybackControls() {
    return Container(
      height: 100,
      child: Center(
        child: Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: AppTheme.successColor,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppTheme.successColor.withOpacity(0.3),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: const Icon(
            Icons.check,
            color: Colors.white,
            size: 40,
          ),
        ),
      ),
    );
  }

  Widget _buildRecordingControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Container(
          decoration: BoxDecoration(
            color: AppTheme.errorColor.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            onPressed: _cancelRecording,
            icon: const Icon(Icons.delete_outline),
            color: AppTheme.errorColor,
            iconSize: 28,
            padding: const EdgeInsets.all(12),
          ),
        ),

        Container(
          decoration: BoxDecoration(
            color: AppTheme.warningColor.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            onPressed: _isPaused ? _resumeRecording : _pauseRecording,
            icon: Icon(_isPaused ? Icons.play_arrow : Icons.pause),
            color: AppTheme.warningColor,
            iconSize: 28,
            padding: const EdgeInsets.all(12),
          ),
        ),

        Container(
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            onPressed: _stopRecording,
            icon: const Icon(Icons.stop),
            color: AppTheme.primaryColor,
            iconSize: 28,
            padding: const EdgeInsets.all(12),
          ),
        ),
      ],
    );
  }

  Widget _buildPlaybackActions() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () {
              setState(() {
                _recordedFilePath = null;
                _recordingDuration = Duration.zero;
              });
              _startRecording();
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Re-record'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.primaryColor,
              side: BorderSide(color: AppTheme.primaryColor),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),

        const SizedBox(width: 12),

        Expanded(
          child: ElevatedButton.icon(
            onPressed: _sendVoiceNote,
            icon: const Icon(Icons.send),
            label: const Text('Send'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ],
    );
  }
}
