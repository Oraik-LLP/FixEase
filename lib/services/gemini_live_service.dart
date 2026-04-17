import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:record/record.dart';

import '../config/ai_config.dart';
import '../models/vehicle.dart';

enum LiveSessionState { idle, connecting, streaming, analyzing, done, error }

class LiveMessage {
  const LiveMessage({
    required this.text,
    required this.isUser,
    this.timestamp,
  });
  final String text;
  final bool isUser;
  final DateTime? timestamp;
}

class GeminiLiveService extends ChangeNotifier {
  GeminiLiveService._();
  static final instance = GeminiLiveService._();

  LiveSessionState _state = LiveSessionState.idle;
  final List<LiveMessage> _messages = [];
  final List<Uint8List> _capturedFrames = [];
  String? _errorMessage;
  Vehicle? _vehicle;
  DateTime? _sessionStart;

  LiveSessionState get state => _state;
  List<LiveMessage> get messages => List.unmodifiable(_messages);
  String? get errorMessage => _errorMessage;
  bool get isActive =>
      _state == LiveSessionState.streaming ||
      _state == LiveSessionState.analyzing;
  Duration get sessionDuration => _sessionStart != null
      ? DateTime.now().difference(_sessionStart!)
      : Duration.zero;

  WebSocketChannel? _channel;
  final AudioPlayer _audioPlayer = AudioPlayer();
  final AudioRecorder _audioRecorder = AudioRecorder();
  final List<Uint8List> _audioQueue = [];
  bool _isPlaying = false;

  Uint8List _addWavHeader(Uint8List pcmData, int sampleRate) {
    int byteRate = sampleRate * 2;
    final header = ByteData(44);
    header.setUint32(0, 0x52494646, Endian.big); 
    header.setUint32(4, 36 + pcmData.length, Endian.little);
    header.setUint32(8, 0x57415645, Endian.big); 
    header.setUint32(12, 0x666d7420, Endian.big); 
    header.setUint32(16, 16, Endian.little); 
    header.setUint16(20, 1, Endian.little); 
    header.setUint16(22, 1, Endian.little); 
    header.setUint32(24, sampleRate, Endian.little); 
    header.setUint32(28, byteRate, Endian.little); 
    header.setUint16(32, 2, Endian.little); 
    header.setUint16(34, 16, Endian.little); 
    header.setUint32(36, 0x64617461, Endian.big); 
    header.setUint32(40, pcmData.length, Endian.little); 
    
    final wavBytes = Uint8List(44 + pcmData.length);
    wavBytes.setAll(0, header.buffer.asUint8List());
    wavBytes.setAll(44, pcmData);
    return wavBytes;
  }

  Future<void> _processAudioQueue() async {
    if (_isPlaying || _audioQueue.isEmpty) return;
    _isPlaying = true;
    final chunk = _audioQueue.removeAt(0);
    final wavBytes = _addWavHeader(chunk, 24000);
    
    await _audioPlayer.play(BytesSource(wavBytes));
    _audioPlayer.onPlayerComplete.first.then((_) {
      _isPlaying = false;
      _processAudioQueue();
    });
  }

  static Future<DeviceCapability> checkCapability() async {
    final hasCamera = Platform.isAndroid || Platform.isIOS;
    final hasNetwork = await _checkBackend();
    final hasBackend = AiConfig.isConfigured;
    return DeviceCapability(
      hasCamera: hasCamera,
      hasNetwork: hasNetwork,
      hasBackend: hasBackend,
    );
  }

  static Future<bool> _checkBackend() async {
    if (!AiConfig.isConfigured) return false;
    try {
      final result = await http
          .get(AiConfig.endpoint('/health'))
          .timeout(const Duration(seconds: 5));
      return result.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<void> startSession(Vehicle vehicle) async {
    _vehicle = vehicle;
    _messages.clear();
    _capturedFrames.clear();
    _errorMessage = null;
    _sessionStart = DateTime.now();
    _state = LiveSessionState.connecting;
    notifyListeners();

    if (!AiConfig.isConfigured) {
      _errorMessage = 'AI backend not configured';
      _state = LiveSessionState.error;
      notifyListeners();
      return;
    }

    try {
      final wsUrl = AiConfig.endpoint('/api/live/stream').toString().replaceFirst('http', 'ws');
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      
      _channel!.stream.listen(
        (data) {
          try {
            final payload = jsonDecode(data as String);
            if (payload['serverContent'] != null) {
              final content = payload['serverContent'];
              
              if (content['modelTurn'] != null && content['modelTurn']['parts'] != null) {
                final parts = content['modelTurn']['parts'] as List;
                for (final part in parts) {
                  if (part['inlineData'] != null && part['inlineData']['data'] != null) {
                    final audioBytes = base64Decode(part['inlineData']['data']);
                    _audioQueue.add(audioBytes);
                    _processAudioQueue();
                  }
                }
              }

              if (content['interrupted'] == true) {
                _audioQueue.clear();
                _audioPlayer.stop();
                _isPlaying = false;
              }

              if (content['inputTranscription'] != null && content['inputTranscription']['text'] != null) {
                final txt = content['inputTranscription']['text'];
                if (txt.isNotEmpty) _appendTranscript(txt, isUser: true);
              }
              if (content['outputTranscription'] != null && content['outputTranscription']['text'] != null) {
                final txt = content['outputTranscription']['text'];
                if (txt.isNotEmpty) _appendTranscript(txt, isUser: false);
              }

              if (_state == LiveSessionState.analyzing) {
                _state = LiveSessionState.streaming;
              }
              notifyListeners();
            }
          } catch (_) {}
        },
        onError: (err) {
          _addSystemMessage('WebSocket Error: $err');
          _state = LiveSessionState.error;
          notifyListeners();
        },
        onDone: () {
          _state = LiveSessionState.done;
          notifyListeners();
        },
      );
      
      _state = LiveSessionState.streaming;
      _addSystemMessage(
        'Live stream connected. Point your camera at the area of concern and describe what you see.',
      );
      notifyListeners();
      
      // Send initial context
      _channel!.sink.add(jsonEncode({
        "realtimeInput": {
          "text": "Begin diagnostic session for ${_vehicle?.displayName ?? 'car'} (${_vehicle?.mileageKm ?? 0} km)."
        }
      }));

      // Start Microphone
      if (await _audioRecorder.hasPermission()) {
        final stream = await _audioRecorder.startStream(const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: 16000,
          numChannels: 1,
          echoCancel: true,
          noiseSuppress: true,
          autoGain: true,
        ));
        stream.listen((data) {
          if (_state == LiveSessionState.streaming && _channel != null) {
            _channel!.sink.add(jsonEncode({
              "realtimeInput": {
                "audio": {
                  "mimeType": "audio/pcm;rate=16000",
                  "data": base64Encode(data)
                }
              }
            }));
          }
        });
      }

    } catch (e) {
      _errorMessage = 'Failed to connect: $e';
      _state = LiveSessionState.error;
      notifyListeners();
    }
  }

  void sendFrame(Uint8List jpegBytes, String userMessage) {
    if (_state != LiveSessionState.streaming || _channel == null) return;

    _capturedFrames.add(jpegBytes);
    _addUserMessage(userMessage);
    _state = LiveSessionState.analyzing;
    notifyListeners();

    _channel!.sink.add(jsonEncode({
      "realtimeInput": {
        "text": userMessage
      }
    }));
    
    _channel!.sink.add(jsonEncode({
      "realtimeInput": {
        "video": {
          "mimeType": "image/jpeg",
          "data": base64Encode(jpegBytes)
        }
      }
    }));
  }

  void sendText(String text) {
    if (!isActive || _channel == null) return;

    _addUserMessage(text);
    _state = LiveSessionState.analyzing;
    notifyListeners();

    _channel!.sink.add(jsonEncode({
      "realtimeInput": {
        "text": text
      }
    }));
  }

  void endSession() {
    if (_state == LiveSessionState.idle) return;
    _addSystemMessage('Session ended. Review your conversation.');
    _audioRecorder.stop();
    _audioPlayer.stop();
    _channel?.sink.close();
    _channel = null;
    _state = LiveSessionState.done;
    notifyListeners();
  }

  void reset() {
    _audioRecorder.stop();
    _audioPlayer.stop();
    _channel?.sink.close();
    _channel = null;
    _state = LiveSessionState.idle;
    _messages.clear();
    _capturedFrames.clear();
    _errorMessage = null;
    _vehicle = null;
    _sessionStart = null;
    notifyListeners();
  }

  Map<String, dynamic>? _vehiclePayload(Vehicle? vehicle) {
    if (vehicle == null) return null;
    return {
      'display_name': vehicle.displayName,
      'fuel_label': vehicle.fuelLabel,
      'mileage_km': vehicle.mileageKm,
      'last_service_date': vehicle.lastServiceDate?.toIso8601String(),
    };
  }

  List<Map<String, dynamic>> _historyPayload() {
    return _messages
        .map((m) => {
              'role': m.isUser ? 'user' : 'assistant',
              'text': m.text,
            })
        .toList();
  }

  void _addUserMessage(String text) {
    _messages.add(LiveMessage(
      text: text,
      isUser: true,
      timestamp: DateTime.now(),
    ));
  }

  void _appendTranscript(String text, {required bool isUser}) {
    final now = DateTime.now();
    if (_messages.isNotEmpty && 
        _messages.last.isUser == isUser && 
        now.difference(_messages.last.timestamp ?? now).inSeconds < 5) {
      final last = _messages.last;
      _messages[_messages.length - 1] = LiveMessage(
        text: "${last.text} $text".trim(),
        isUser: isUser,
        timestamp: last.timestamp ?? now,
      );
    } else {
      _messages.add(LiveMessage(
        text: text,
        isUser: isUser,
        timestamp: now,
      ));
    }
  }

  void _addSystemMessage(String text) {
    _messages.add(LiveMessage(
      text: text,
      isUser: false,
      timestamp: DateTime.now(),
    ));
  }
}

class DeviceCapability {
  const DeviceCapability({
    required this.hasCamera,
    required this.hasNetwork,
    required this.hasBackend,
  });
  final bool hasCamera;
  final bool hasNetwork;
  final bool hasBackend;

  bool get isReady => hasCamera && hasNetwork && hasBackend;

  String? get blockerMessage {
    if (!hasBackend) return 'AI backend not configured';
    if (!hasNetwork) return 'No backend connection detected';
    if (!hasCamera) return 'Camera not available on this device';
    return null;
  }
}
