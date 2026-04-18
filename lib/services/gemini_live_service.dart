import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../config/ai_config.dart';
import '../models/conversation.dart';
import '../models/diagnostic.dart';
import '../models/vehicle.dart';
import 'conversation_service.dart';
import 'diagnostic_service.dart';

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
  GeminiLiveService._() {
    _tts = FlutterTts();
    _tts.setLanguage('en-US');
    _tts.setSpeechRate(0.5);
    _tts.setPitch(1.0);
    _tts.awaitSpeakCompletion(true);
  }

  static final instance = GeminiLiveService._();

  LiveSessionState _state = LiveSessionState.idle;
  final List<LiveMessage> _messages = [];
  String? _errorMessage;
  Vehicle? _vehicle;
  DateTime? _sessionStart;
  DiagnosticSession? _historySession;

  final AudioRecorder _recorder = AudioRecorder();
  late final FlutterTts _tts;
  bool _isRecording = false;
  bool _isSpeaking = false;

  LiveSessionState get state => _state;
  List<LiveMessage> get messages => List.unmodifiable(_messages);
  String? get errorMessage => _errorMessage;
  bool get isRecording => _isRecording;
  bool get isSpeaking => _isSpeaking;
  bool get isActive =>
      _state == LiveSessionState.streaming ||
      _state == LiveSessionState.analyzing;
  Duration get sessionDuration => _sessionStart != null
      ? DateTime.now().difference(_sessionStart!)
      : Duration.zero;

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
    _errorMessage = null;
    _sessionStart = DateTime.now();
    _historySession = null;
    _state = LiveSessionState.connecting;
    notifyListeners();

    if (!AiConfig.isConfigured) {
      _errorMessage = 'AI backend not configured';
      _state = LiveSessionState.error;
      notifyListeners();
      return;
    }

    _state = LiveSessionState.streaming;
    _addStatusMessage(
      'Session started. Tap the mic button to speak, or type a message.\nTap the camera strip to share a photo.',
    );
    notifyListeners();

    await _sendToBackend(
      text: 'Greet the user briefly and ask what car issue they are experiencing.',
    );
  }

  Future<void> toggleRecording() async {
    if (_state == LiveSessionState.analyzing) return;

    if (_isRecording) {
      await _stopAndSend();
    } else {
      await _startRecording();
    }
  }

  Future<void> _startRecording() async {
    if (!await _recorder.hasPermission()) return;

    if (_isSpeaking) {
      await _tts.stop();
      _isSpeaking = false;
    }

    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}/fixease_voice_${DateTime.now().millisecondsSinceEpoch}.wav';

    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 16000,
        numChannels: 1,
        echoCancel: true,
        noiseSuppress: true,
        autoGain: true,
      ),
      path: path,
    );

    _isRecording = true;
    notifyListeners();
  }

  Future<void> _stopAndSend() async {
    final path = await _recorder.stop();
    _isRecording = false;
    notifyListeners();

    if (path == null) return;

    final file = File(path);
    if (!await file.exists()) return;

    final bytes = await file.readAsBytes();
    if (bytes.length < 1000) {
      await file.delete();
      return;
    }

    _addUserMessage('Voice message');
    await _persistUserTurn(
      text: 'Voice note',
      source: ConversationMessageSource.audio,
    );
    _state = LiveSessionState.analyzing;
    notifyListeners();

    await _sendToBackend(
      audioData: base64Encode(bytes),
      audioMimeType: 'audio/wav',
    );

    try {
      await file.delete();
    } catch (_) {}
  }

  Future<void> sendImage(Uint8List jpegBytes) async {
    if (!isActive) return;

    _addUserMessage('Photo sent');
    await _persistUserTurn(
      text: 'Photo attached',
      source: ConversationMessageSource.image,
    );
    _state = LiveSessionState.analyzing;
    notifyListeners();

    await _sendToBackend(
      text: 'The user sent a photo of their car issue. Analyze it and describe what you see.',
      imageData: base64Encode(jpegBytes),
      imageMimeType: 'image/jpeg',
    );
  }

  Future<void> sendText(String text) async {
    if (!isActive) return;

    _addUserMessage(text);
    await _persistUserTurn(
      text: text,
      source: ConversationMessageSource.text,
    );
    _state = LiveSessionState.analyzing;
    notifyListeners();

    await _sendToBackend(text: text);
  }

  Future<void> _sendToBackend({
    String? text,
    String? audioData,
    String? audioMimeType,
    String? imageData,
    String? imageMimeType,
  }) async {
    try {
      final body = <String, dynamic>{
        'vehicle': _vehicle != null
            ? {
                'display_name': _vehicle!.displayName,
                'fuel_label': _vehicle!.fuelLabel,
                'mileage_km': _vehicle!.mileageKm,
              }
            : null,
        'history': _messages
            .where(
              (message) =>
                  message.text != 'Voice message' &&
                  message.text != 'Photo sent' &&
                  !message.text.startsWith('Session started.'),
            )
            .map(
              (message) => {
                'role': message.isUser ? 'user' : 'assistant',
                'text': message.text,
              },
            )
            .toList(),
      };

      if (text != null && audioData == null) {
        body['history'] = [
          ...body['history'] as List,
          {'role': 'user', 'text': text},
        ];
      }

      if (audioData != null && audioMimeType != null) {
        body['audio'] = {
          'data': audioData,
          'mimeType': audioMimeType,
        };
      }

      if (imageData != null && imageMimeType != null) {
        body['image'] = {
          'data': imageData,
          'mimeType': imageMimeType,
        };
      }

      final response = await http
          .post(
            AiConfig.endpoint('/api/live/voice'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final responseText = data['text'] as String? ??
            'I could not process that. Please try again.';

        _addAssistantMessage(responseText);
        await _persistAssistantTurn(responseText);
        _state = LiveSessionState.streaming;
        notifyListeners();

        _isSpeaking = true;
        notifyListeners();
        await _tts.speak(responseText);
        _isSpeaking = false;
        notifyListeners();
      } else {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final message = 'Error: ${data['message'] ?? 'Request failed'}';
        _addAssistantMessage(message);
        await _persistAssistantTurn(message);
        _state = LiveSessionState.streaming;
        notifyListeners();
      }
    } catch (_) {
      const message = 'Connection error. Please try again.';
      _addAssistantMessage(message);
      await _persistAssistantTurn(message);
      _state = LiveSessionState.streaming;
      notifyListeners();
    }
  }

  void endSession() {
    if (_state == LiveSessionState.idle) return;
    _addStatusMessage('Session ended.');
    _teardown();
    _state = LiveSessionState.done;
    notifyListeners();
  }

  void reset() {
    _teardown();
    _state = LiveSessionState.idle;
    _messages.clear();
    _errorMessage = null;
    _vehicle = null;
    _sessionStart = null;
    _historySession = null;
    notifyListeners();
  }

  void _teardown() {
    _recorder.stop();
    _tts.stop();
    _isRecording = false;
    _isSpeaking = false;
  }

  void _addUserMessage(String text) {
    _messages.add(
      LiveMessage(
        text: text,
        isUser: true,
        timestamp: DateTime.now(),
      ),
    );
  }

  void _addAssistantMessage(String text) {
    _messages.add(
      LiveMessage(
        text: text,
        isUser: false,
        timestamp: DateTime.now(),
      ),
    );
  }

  void _addStatusMessage(String text) {
    _messages.add(
      LiveMessage(
        text: text,
        isUser: false,
        timestamp: DateTime.now(),
      ),
    );
  }

  Future<DiagnosticSession?> _ensureHistorySession() async {
    if (_historySession != null) return _historySession;
    final vehicle = _vehicle;
    if (vehicle == null) return null;

    final session = DiagnosticSession(
      id: DateTime.now().microsecondsSinceEpoch.toRadixString(36),
      vehicleId: vehicle.id,
      type: DiagnosticType.live,
      description: 'Gemini Live conversation',
      vehicleName: vehicle.displayName,
      createdAt: _sessionStart ?? DateTime.now(),
    );

    _historySession = session;
    await DiagnosticService.instance.save(session);
    await ConversationService.instance.createOrGetThread(
      sessionId: session.id,
      vehicleId: session.vehicleId,
    );
    return session;
  }

  Future<void> _persistUserTurn({
    required String text,
    required ConversationMessageSource source,
  }) async {
    final session = await _ensureHistorySession();
    if (session == null) return;

    await ConversationService.instance.appendMessage(
      sessionId: session.id,
      vehicleId: session.vehicleId,
      message: ConversationMessage(
        id: DateTime.now().microsecondsSinceEpoch.toRadixString(36),
        role: ConversationMessageRole.user,
        text: text,
        createdAt: DateTime.now(),
        source: source,
      ),
    );
  }

  Future<void> _persistAssistantTurn(String text) async {
    final session = _historySession;
    if (session == null) return;

    await ConversationService.instance.appendMessage(
      sessionId: session.id,
      vehicleId: session.vehicleId,
      message: ConversationMessage(
        id: DateTime.now().microsecondsSinceEpoch.toRadixString(36),
        role: ConversationMessageRole.assistant,
        text: text,
        createdAt: DateTime.now(),
      ),
    );
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
