import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

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

  static Future<DeviceCapability> checkCapability() async {
    final hasCamera = Platform.isAndroid || Platform.isIOS;
    final hasNetwork = await _checkNetwork();
    final hasApiKey = AiConfig.isConfigured;
    return DeviceCapability(
      hasCamera: hasCamera,
      hasNetwork: hasNetwork,
      hasApiKey: hasApiKey,
    );
  }

  static Future<bool> _checkNetwork() async {
    try {
      final result = await http
          .get(Uri.parse('https://www.google.com'))
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

    await Future<void>.delayed(const Duration(milliseconds: 800));

    if (!AiConfig.isConfigured) {
      _errorMessage = 'Gemini API key not configured';
      _state = LiveSessionState.error;
      notifyListeners();
      return;
    }

    _state = LiveSessionState.streaming;
    _addSystemMessage(
      'Connected. Point your camera at the area of concern and describe what you see.',
    );
    notifyListeners();
  }

  /// Submit a captured frame + user text for analysis.
  Future<void> sendFrame(Uint8List jpegBytes, String userMessage) async {
    if (_state != LiveSessionState.streaming) return;

    _capturedFrames.add(jpegBytes);
    _addUserMessage(userMessage);
    _state = LiveSessionState.analyzing;
    notifyListeners();

    try {
      final aiReply = await _callGeminiWithFrame(jpegBytes, userMessage);
      _addSystemMessage(aiReply);
      _state = LiveSessionState.streaming;
    } catch (e) {
      _addSystemMessage('Analysis failed: ${e.toString().split(":").last.trim()}');
      _state = LiveSessionState.streaming;
    }
    notifyListeners();
  }

  /// Send a text-only follow-up question.
  Future<void> sendText(String text) async {
    if (!isActive) return;

    _addUserMessage(text);
    _state = LiveSessionState.analyzing;
    notifyListeners();

    try {
      final aiReply = await _callGeminiText(text);
      _addSystemMessage(aiReply);
      _state = LiveSessionState.streaming;
    } catch (e) {
      _addSystemMessage('Could not process: ${e.toString().split(":").last.trim()}');
      _state = LiveSessionState.streaming;
    }
    notifyListeners();
  }

  void endSession() {
    if (_state == LiveSessionState.idle) return;
    _addSystemMessage('Session ended. Review your conversation above.');
    _state = LiveSessionState.done;
    notifyListeners();
  }

  void reset() {
    _state = LiveSessionState.idle;
    _messages.clear();
    _capturedFrames.clear();
    _errorMessage = null;
    _vehicle = null;
    _sessionStart = null;
    notifyListeners();
  }

  // ── Gemini API calls ──────────────────────────────────────────────────────

  Future<String> _callGeminiWithFrame(
      Uint8List jpegBytes, String userMessage) async {
    final b64 = base64Encode(jpegBytes);
    final contextHistory = _buildContextHistory();

    final body = jsonEncode({
      'contents': [
        {
          'parts': [
            {
              'text': _buildLivePrompt(userMessage, contextHistory),
            },
            {
              'inlineData': {'mimeType': 'image/jpeg', 'data': b64},
            },
          ],
        },
      ],
      'generationConfig': {
        'temperature': 0.4,
        'maxOutputTokens': 1024,
      },
    });

    final resp = await http
        .post(
          Uri.parse(AiConfig.geminiVisionEndpoint),
          headers: {'Content-Type': 'application/json'},
          body: body,
        )
        .timeout(const Duration(seconds: 30));

    if (resp.statusCode != 200) {
      throw HttpException('API returned ${resp.statusCode}');
    }

    return _extractText(resp.body);
  }

  Future<String> _callGeminiText(String text) async {
    final contextHistory = _buildContextHistory();

    final body = jsonEncode({
      'contents': [
        {
          'parts': [
            {'text': _buildFollowUpPrompt(text, contextHistory)},
          ],
        },
      ],
      'generationConfig': {
        'temperature': 0.4,
        'maxOutputTokens': 1024,
      },
    });

    final resp = await http
        .post(
          Uri.parse(AiConfig.geminiEndpoint),
          headers: {'Content-Type': 'application/json'},
          body: body,
        )
        .timeout(const Duration(seconds: 20));

    if (resp.statusCode != 200) {
      throw HttpException('API returned ${resp.statusCode}');
    }

    return _extractText(resp.body);
  }

  String _extractText(String responseBody) {
    final json = jsonDecode(responseBody) as Map<String, dynamic>;
    final candidates = json['candidates'] as List?;
    if (candidates == null || candidates.isEmpty) return 'No response.';
    final parts = (candidates[0]['content'] as Map?)?['parts'] as List?;
    if (parts == null || parts.isEmpty) return 'Empty response.';
    return parts[0]['text'] as String? ?? 'No text in response.';
  }

  String _buildContextHistory() {
    final recent = _messages.length > 6
        ? _messages.sublist(_messages.length - 6)
        : _messages;
    return recent
        .map((m) => '${m.isUser ? "USER" : "AI"}: ${m.text}')
        .join('\n');
  }

  String _buildLivePrompt(String userMessage, String history) {
    final v = _vehicle;
    return '''
You are FixEase Live, a real-time automotive diagnostic AI assistant. You are in a live video session.

VEHICLE: ${v?.displayName ?? 'Unknown'} (${v?.fuelLabel ?? 'Unknown fuel'}, ${v?.mileageKm ?? 0} km)

CONVERSATION SO FAR:
$history

The user just captured a frame from their camera and said: "$userMessage"

Analyze the image and respond conversationally. Be concise (2-4 sentences). If you spot an issue, name it clearly. If you need to see something from a different angle, ask. Always be helpful and specific.
''';
  }

  String _buildFollowUpPrompt(String userMessage, String history) {
    final v = _vehicle;
    return '''
You are FixEase Live, a real-time automotive diagnostic AI assistant in an active session.

VEHICLE: ${v?.displayName ?? 'Unknown'} (${v?.fuelLabel ?? 'Unknown fuel'}, ${v?.mileageKm ?? 0} km)

CONVERSATION SO FAR:
$history

USER: $userMessage

Respond concisely (2-4 sentences). Reference earlier observations if relevant. Be specific and actionable.
''';
  }

  // ── Message helpers ──────────────────────────────────────────────────────

  void _addUserMessage(String text) {
    _messages.add(LiveMessage(
      text: text,
      isUser: true,
      timestamp: DateTime.now(),
    ));
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
    required this.hasApiKey,
  });
  final bool hasCamera;
  final bool hasNetwork;
  final bool hasApiKey;

  bool get isReady => hasCamera && hasNetwork && hasApiKey;

  String? get blockerMessage {
    if (!hasApiKey) return 'Gemini API key not configured';
    if (!hasNetwork) return 'No internet connection detected';
    if (!hasCamera) return 'Camera not available on this device';
    return null;
  }
}
