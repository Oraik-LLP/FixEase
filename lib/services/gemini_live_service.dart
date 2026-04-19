import 'dart:async';
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
import 'subscription_service.dart';

enum LiveSessionState { idle, connecting, streaming, analyzing, done, error }

class LiveMessage {
  const LiveMessage({
    required this.text,
    required this.isUser,
    this.timestamp,
    this.source = ConversationMessageSource.text,
    this.attachmentPath,
    this.attachmentName,
  });

  final String text;
  final bool isUser;
  final DateTime? timestamp;
  final ConversationMessageSource source;
  final String? attachmentPath;
  final String? attachmentName;

  bool get hasAttachment =>
      attachmentPath != null ||
      attachmentName != null ||
      source != ConversationMessageSource.text;

  String get previewText {
    if (text.trim().isNotEmpty) return text.trim();
    return switch (source) {
      ConversationMessageSource.audio => 'Voice note',
      ConversationMessageSource.image => 'Photo sent',
      ConversationMessageSource.file => 'File attached',
      ConversationMessageSource.text => 'Message',
    };
  }
}

class GeminiLiveService extends ChangeNotifier {
  GeminiLiveService._() {
    _tts = FlutterTts();
    _tts.setLanguage('en-US');
    _tts.setSpeechRate(0.5);
    _tts.setPitch(1.0);
    _tts.awaitSpeakCompletion(true);
    _syncAudioLimit();
  }

  static final GeminiLiveService instance = GeminiLiveService._();

  LiveSessionState _state = LiveSessionState.idle;
  final List<LiveMessage> _messages = [];
  String? _errorMessage;
  Vehicle? _vehicle;
  DateTime? _sessionStart;
  DiagnosticSession? _historySession;
  bool _historySessionSaved = false;
  String? _threadId;
  int _sessionGeneration = 0;

  final AudioRecorder _recorder = AudioRecorder();
  late final FlutterTts _tts;
  bool _isRecording = false;
  bool _isSpeaking = false;
  bool _isStoppingRecording = false;
  DateTime? _recordingStartedAt;
  Duration _recordingElapsed = Duration.zero;
  Duration _recordingLimit = const Duration(minutes: 3);
  Timer? _recordingTicker;
  int _recordingCapEvents = 0;

  LiveSessionState get state => _state;
  List<LiveMessage> get messages => List.unmodifiable(_messages);
  String? get errorMessage => _errorMessage;
  bool get isRecording => _isRecording;
  bool get isSpeaking => _isSpeaking;
  String? get threadId => _threadId;
  bool get isActive =>
      _state == LiveSessionState.streaming ||
      _state == LiveSessionState.analyzing;
  Duration get sessionDuration => _sessionStart != null
      ? DateTime.now().difference(_sessionStart!)
      : Duration.zero;
  Duration get recordingElapsed => _recordingElapsed;
  Duration get recordingLimit => _recordingLimit;
  int get recordingCapEvents => _recordingCapEvents;
  double get recordingProgress {
    if (_recordingLimit.inMilliseconds == 0) return 0;
    return (_recordingElapsed.inMilliseconds / _recordingLimit.inMilliseconds)
        .clamp(0.0, 1.0);
  }

  bool get isNearRecordingLimit {
    if (!_isRecording) return false;
    return _recordingLimit - _recordingElapsed <= const Duration(seconds: 30);
  }

  String get recordingTimeLabel => _formatDuration(_recordingElapsed);
  String get recordingLimitLabel => _formatDuration(_recordingLimit);

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
    _sessionGeneration++;
    _vehicle = vehicle;
    _messages.clear();
    _errorMessage = null;
    _sessionStart = DateTime.now();
    _historySession = null;
    _historySessionSaved = false;
    _threadId = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    _syncAudioLimit();
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

    _syncAudioLimit();
    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}/fixease_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

    _recordingStartedAt = DateTime.now();
    _recordingElapsed = Duration.zero;
    _isStoppingRecording = false;

    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 64000,
        sampleRate: 16000,
        numChannels: 1,
        echoCancel: true,
        noiseSuppress: true,
        autoGain: true,
      ),
      path: path,
    );

    _isRecording = true;
    _startRecordingTicker();
    notifyListeners();
  }

  Future<void> _stopAndSend({bool reachedCap = false}) async {
    if (_isStoppingRecording) return;
    _isStoppingRecording = true;

    final path = await _recorder.stop();
    _stopRecordingTicker();
    _isRecording = false;
    _recordingElapsed = reachedCap ? _recordingLimit : _recordingElapsed;
    _recordingStartedAt = null;

    if (reachedCap && !SubscriptionService.instance.hasPremiumAccess) {
      _recordingCapEvents++;
    }
    notifyListeners();

    if (path == null) {
      _resetRecordingState();
      _isStoppingRecording = false;
      return;
    }

    final file = File(path);
    if (!await file.exists()) {
      _resetRecordingState();
      _isStoppingRecording = false;
      return;
    }

    final bytes = await file.readAsBytes();
    if (bytes.length < 1000) {
      try {
        await file.delete();
      } catch (_) {}
      _resetRecordingState();
      _isStoppingRecording = false;
      notifyListeners();
      return;
    }

    if (_threadId == null ||
        !SubscriptionService.instance.checkAccess(
          FeatureType.liveAudioTurn,
          threadId: _threadId,
          threadType: DiagnosticType.live,
        )) {
      _resetRecordingState();
      _isStoppingRecording = false;
      notifyListeners();
      return;
    }

    if (!SubscriptionService.instance.hasPremiumAccess) {
      await SubscriptionService.instance.recordThreadEvent(
        sessionId: _threadId!,
        sessionType: DiagnosticType.live,
        event: ThreadUsageEvent.liveAudio,
      );
    }

    _addUserMessage('Voice message', source: ConversationMessageSource.audio);
    await _persistUserTurn(
      text: 'Voice note',
      source: ConversationMessageSource.audio,
    );
    _state = LiveSessionState.analyzing;
    notifyListeners();

    await _sendToBackend(
      audioData: base64Encode(bytes),
      audioMimeType: 'audio/mp4',
      countsAsDiagnosisStart: true,
    );

    try {
      await file.delete();
    } catch (_) {}

    _resetRecordingState();
    _isStoppingRecording = false;
    notifyListeners();
  }

  Future<void> sendImage(Uint8List jpegBytes) async {
    if (!isActive) return;
    if (_threadId == null ||
        !SubscriptionService.instance.checkAccess(
          FeatureType.liveImageUpload,
          threadId: _threadId,
          threadType: DiagnosticType.live,
        )) {
      return;
    }

    await SubscriptionService.instance.recordThreadEvent(
      sessionId: _threadId!,
      sessionType: DiagnosticType.live,
      event: ThreadUsageEvent.liveImage,
    );

    final dir = await getTemporaryDirectory();
    final previewPath =
        '${dir.path}/fixease_live_photo_${DateTime.now().millisecondsSinceEpoch}.jpg';
    await File(previewPath).writeAsBytes(jpegBytes, flush: true);

    _addUserMessage(
      'Photo sent',
      source: ConversationMessageSource.image,
      attachmentPath: previewPath,
      attachmentName: 'Live photo',
    );
    await _persistUserTurn(
      text: 'Photo attached',
      source: ConversationMessageSource.image,
      attachmentPath: previewPath,
      attachmentName: 'Live photo',
    );
    _state = LiveSessionState.analyzing;
    notifyListeners();

    await _sendToBackend(
      text: 'The user sent a photo of their car issue. Analyze it and describe what you see.',
      imageData: base64Encode(jpegBytes),
      imageMimeType: 'image/jpeg',
      countsAsDiagnosisStart: true,
    );
  }

  Future<void> sendText(String text) async {
    if (!isActive) return;
    if (_threadId == null ||
        !SubscriptionService.instance.checkAccess(
          FeatureType.liveTextMessage,
          threadId: _threadId,
          threadType: DiagnosticType.live,
        )) {
      return;
    }

    await SubscriptionService.instance.recordThreadEvent(
      sessionId: _threadId!,
      sessionType: DiagnosticType.live,
      event: ThreadUsageEvent.liveText,
    );

    _addUserMessage(text, source: ConversationMessageSource.text);
    await _persistUserTurn(
      text: text,
      source: ConversationMessageSource.text,
    );
    _state = LiveSessionState.analyzing;
    notifyListeners();

    await _sendToBackend(
      text: text,
      countsAsDiagnosisStart: true,
    );
  }

  Future<void> _sendToBackend({
    String? text,
    String? audioData,
    String? audioMimeType,
    String? imageData,
    String? imageMimeType,
    bool countsAsDiagnosisStart = false,
  }) async {
    final requestGeneration = _sessionGeneration;
    final requestThreadId = _threadId;
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
        if (!_isCurrentRequest(requestGeneration, requestThreadId)) return;
        if (countsAsDiagnosisStart && requestThreadId != null) {
          await SubscriptionService.instance.recordLiveDiagnosisIfNeeded(
            sessionId: requestThreadId,
          );
        }
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final responseText =
            data['text'] as String? ?? 'I could not process that. Please try again.';

        _addAssistantMessage(responseText);
        await _persistAssistantTurn(responseText);
        _state = LiveSessionState.streaming;
        notifyListeners();

        if (!_isCurrentRequest(requestGeneration, requestThreadId)) return;
        _isSpeaking = true;
        notifyListeners();
        await _tts.speak(responseText);
        if (!_isCurrentRequest(requestGeneration, requestThreadId)) return;
        _isSpeaking = false;
        notifyListeners();
      } else {
        if (!_isCurrentRequest(requestGeneration, requestThreadId)) return;
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final message = 'Error: ${data['message'] ?? 'Request failed'}';
        _addAssistantMessage(message);
        await _persistAssistantTurn(message);
        _state = LiveSessionState.streaming;
        notifyListeners();
      }
    } catch (_) {
      if (!_isCurrentRequest(requestGeneration, requestThreadId)) return;
      const message = 'Connection error. Please try again.';
      _addAssistantMessage(message);
      await _persistAssistantTurn(message);
      _state = LiveSessionState.streaming;
      notifyListeners();
    }
  }

  void endSession() {
    if (_state == LiveSessionState.idle) return;
    _sessionGeneration++;
    _addStatusMessage('Session ended.');
    _teardown();
    _state = LiveSessionState.done;
    notifyListeners();
  }

  void reset() {
    _sessionGeneration++;
    _teardown();
    _state = LiveSessionState.idle;
    _messages.clear();
    _errorMessage = null;
    _vehicle = null;
    _sessionStart = null;
    _historySession = null;
    _historySessionSaved = false;
    _threadId = null;
    notifyListeners();
  }

  void _teardown() {
    _stopRecordingTicker();
    _recorder.stop();
    _tts.stop();
    _isRecording = false;
    _isSpeaking = false;
    _recordingStartedAt = null;
    _resetRecordingState();
  }

  bool _isCurrentRequest(int generation, String? threadId) {
    return generation == _sessionGeneration &&
        threadId != null &&
        threadId == _threadId &&
        _state != LiveSessionState.done &&
        _state != LiveSessionState.idle;
  }

  void _addUserMessage(
    String text, {
    ConversationMessageSource source = ConversationMessageSource.text,
    String? attachmentPath,
    String? attachmentName,
  }) {
    _messages.add(
      LiveMessage(
        text: text,
        isUser: true,
        timestamp: DateTime.now(),
        source: source,
        attachmentPath: attachmentPath,
        attachmentName: attachmentName,
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

  void _syncAudioLimit() {
    _recordingLimit = SubscriptionService.instance.liveAudioLimit;
  }

  void _startRecordingTicker() {
    _stopRecordingTicker();
    _recordingTicker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isRecording || _recordingStartedAt == null) {
        timer.cancel();
        return;
      }

      _recordingElapsed = DateTime.now().difference(_recordingStartedAt!);
      if (_recordingElapsed >= _recordingLimit) {
        timer.cancel();
        unawaited(_stopAndSend(reachedCap: true));
        return;
      }
      notifyListeners();
    });
  }

  void _stopRecordingTicker() {
    _recordingTicker?.cancel();
    _recordingTicker = null;
  }

  void _resetRecordingState() {
    _recordingElapsed = Duration.zero;
    _recordingStartedAt = null;
  }

  String _formatDuration(Duration duration) {
    final totalSeconds = duration.inSeconds;
    final minutes = (totalSeconds ~/ 60).toString().padLeft(1, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Future<DiagnosticSession?> _ensureHistorySession() async {
    if (_historySession != null) return _historySession;
    final vehicle = _vehicle;
    if (vehicle == null) return null;

    final session = DiagnosticSession(
      id: _threadId ?? DateTime.now().microsecondsSinceEpoch.toRadixString(36),
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
    String? attachmentPath,
    String? attachmentName,
  }) async {
    final session = await _ensureHistorySession();
    if (session == null) return;

    if (!_historySessionSaved) {
      await DiagnosticService.instance.save(session);
      _historySessionSaved = true;
    }

    await ConversationService.instance.appendMessage(
      sessionId: session.id,
      vehicleId: session.vehicleId,
      message: ConversationMessage(
        id: DateTime.now().microsecondsSinceEpoch.toRadixString(36),
        role: ConversationMessageRole.user,
        text: text,
        createdAt: DateTime.now(),
        source: source,
        attachmentPath: attachmentPath,
        attachmentName: attachmentName,
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
