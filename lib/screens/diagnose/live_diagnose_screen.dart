import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../config/feature_flags.dart';
import '../../services/gemini_live_service.dart';
import '../../services/subscription_service.dart';
import '../../services/vehicle_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/neuomorphic.dart';
import '../subscription/paywall_screen.dart';

class LiveDiagnoseScreen extends StatefulWidget {
  const LiveDiagnoseScreen({super.key});

  @override
  State<LiveDiagnoseScreen> createState() => _LiveDiagnoseScreenState();
}

class _LiveDiagnoseScreenState extends State<LiveDiagnoseScreen> {
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _picker = ImagePicker();
  bool _checking = true;
  DeviceCapability? _capability;

  @override
  void initState() {
    super.initState();
    _runChecks();
  }

  bool _disposed = false;

  Future<void> _runChecks() async {
    try {
      final cap = await GeminiLiveService.checkCapability();
      if (!mounted) return;
      setState(() {
        _capability = cap;
        _checking = false;
      });

      if (cap.isReady) {
        final vehicle = VehicleService.instance.selected;
        if (vehicle != null) {
          await GeminiLiveService.instance.startSession(vehicle);
        }
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _checking = false);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    if (GeminiLiveService.instance.isActive) {
      GeminiLiveService.instance.endSession();
    }
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_disposed) return;
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _captureAndSend() async {
    HapticFeedback.heavyImpact();
    try {
      final xfile = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 75,
        maxWidth: 1280,
      );
      if (xfile == null || !mounted) return;

      final bytes = await xfile.readAsBytes();
      if (!mounted) return;
      final text = _msgCtrl.text.trim().isNotEmpty
          ? _msgCtrl.text.trim()
          : 'What do you see here?';
      _msgCtrl.clear();

      await GeminiLiveService.instance
          .sendFrame(Uint8List.fromList(bytes), text);
      _scrollToBottom();
    } catch (_) {
      // Camera cancelled or read error — silently ignore
    }
  }

  Future<void> _sendText() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;
    HapticFeedback.selectionClick();
    _msgCtrl.clear();

    await GeminiLiveService.instance.sendText(text);
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Column(
            children: [
              // top bar
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 12, 0),
                child: Row(
                  children: [
                    FixEaseStepBackButton(
                      onPressed: () {
                        GeminiLiveService.instance.endSession();
                        Navigator.of(context).pop();
                      },
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: const Color(0xFF4CAF50).withValues(alpha: 0.15),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFF4CAF50),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text('LIVE',
                              style: tt.bodySmall?.copyWith(
                                color: const Color(0xFF4CAF50),
                                fontWeight: FontWeight.w700,
                                fontSize: 10,
                                letterSpacing: 1,
                              )),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Text('Gemini Live',
                        style: tt.bodySmall?.copyWith(
                            color: AppColors.textTertiary)),
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(5),
                        color: const Color(0xFFFF9800).withValues(alpha: 0.2),
                      ),
                      child: Text('BETA',
                          style: tt.bodySmall?.copyWith(
                            color: const Color(0xFFFF9800),
                            fontWeight: FontWeight.w700,
                            fontSize: 8,
                            letterSpacing: 0.5,
                          )),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: _checking
                    ? _buildLoading(tt)
                    : _capability != null && !_capability!.isReady
                        ? _buildBlocker(tt)
                        : _buildChatView(tt),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoading(TextTheme tt) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(
            strokeWidth: 2.5,
            color: AppColors.accent,
          ),
          const SizedBox(height: 20),
          Text('Checking device capabilities…', style: tt.bodyMedium),
        ],
      ),
    );
  }

  Widget _buildBlocker(TextTheme tt) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 56, color: Color(0xFFFF9800)),
            const SizedBox(height: 16),
            Text('Cannot Start Live Session',
                style: tt.headlineMedium, textAlign: TextAlign.center),
            const SizedBox(height: 10),
            Text(
              _capability?.blockerMessage ?? 'Unknown issue',
              style: tt.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            NeuSecondaryButton(
              label: 'Go Back',
              icon: Icons.arrow_back_rounded,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatView(TextTheme tt) {
    return ListenableBuilder(
      listenable: GeminiLiveService.instance,
      builder: (context, _) {
        final svc = GeminiLiveService.instance;
        final msgs = svc.messages;
        final isAnalyzing = svc.state == LiveSessionState.analyzing;
        final isDone = svc.state == LiveSessionState.done;

        _scrollToBottom();

        return Column(
          children: [
            Expanded(
              child: msgs.isEmpty
                  ? _buildWelcome(tt)
                  : ListView.builder(
                      controller: _scrollCtrl,
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                      itemCount: msgs.length + (isAnalyzing ? 1 : 0),
                      itemBuilder: (_, i) {
                        if (i == msgs.length && isAnalyzing) {
                          return _TypingIndicator();
                        }
                        return _ChatBubble(message: msgs[i]);
                      },
                    ),
            ),

            if (!isDone)
              Container(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                decoration: BoxDecoration(
                  color: AppColors.surface.withValues(alpha: 0.5),
                  border: const Border(
                    top: BorderSide(color: Color(0x0CFFFFFF)),
                  ),
                ),
                child: Row(
                  children: [
                    // camera capture button
                    GestureDetector(
                      onTap: isAnalyzing ? null : _captureAndSend,
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isAnalyzing
                              ? AppColors.surfaceHighlight
                              : AppColors.accent.withValues(alpha: 0.15),
                          border: Border.all(
                            color: isAnalyzing
                                ? const Color(0x0CFFFFFF)
                                : AppColors.accent.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Icon(
                          Icons.camera_alt_rounded,
                          size: 20,
                          color: isAnalyzing
                              ? AppColors.textTertiary
                              : AppColors.accent,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: NeuTextField(
                        hint: 'Ask about what you see…',
                        icon: Icons.chat_rounded,
                        controller: _msgCtrl,
                      ),
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: isAnalyzing ? null : _sendText,
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isAnalyzing
                              ? AppColors.surfaceHighlight
                              : AppColors.accent,
                        ),
                        child: Icon(
                          Icons.send_rounded,
                          size: 18,
                          color: isAnalyzing
                              ? AppColors.textTertiary
                              : Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.all(16),
                child: NeuPrimaryButton(
                  label: 'End Session',
                  icon: Icons.check_circle_rounded,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildWelcome(TextTheme tt) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.accent.withValues(alpha: 0.1),
              ),
              child: const Icon(Icons.videocam_rounded,
                  size: 40, color: AppColors.accent),
            ),
            const SizedBox(height: 20),
            Text('Gemini Live', style: tt.headlineMedium),
            const SizedBox(height: 8),
            Text(
              'Point your camera at the issue area and tap the camera button to capture a frame. Gemini will analyze it in real-time.',
              style: tt.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            NeuPrimaryButton(
              expanded: false,
              label: 'Capture First Frame',
              icon: Icons.camera_alt_rounded,
              onPressed: _captureAndSend,
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Chat bubble
// ═══════════════════════════════════════════════════════════════════════════════

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.message});
  final LiveMessage message;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final isUser = message.isUser;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.accent.withValues(alpha: 0.15),
              ),
              child: const Icon(Icons.auto_awesome_rounded,
                  size: 14, color: AppColors.accent),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
                color: isUser
                    ? AppColors.accent.withValues(alpha: 0.15)
                    : AppColors.surface,
                border: Border.all(
                  color: isUser
                      ? AppColors.accent.withValues(alpha: 0.3)
                      : const Color(0x0CFFFFFF),
                  width: 0.5,
                ),
              ),
              child: Text(
                message.text,
                style: tt.bodyMedium?.copyWith(
                  color: isUser ? AppColors.accent : AppColors.textPrimary,
                ),
              ),
            ),
          ),
          if (isUser) const SizedBox(width: 8),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Typing indicator
// ═══════════════════════════════════════════════════════════════════════════════

class _TypingIndicator extends StatefulWidget {
  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.accent.withValues(alpha: 0.15),
            ),
            child: const Icon(Icons.auto_awesome_rounded,
                size: 14, color: AppColors.accent),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomLeft: Radius.circular(4),
                bottomRight: Radius.circular(16),
              ),
              color: AppColors.surface,
              border: Border.all(
                  color: const Color(0x0CFFFFFF), width: 0.5),
            ),
            child: AnimatedBuilder(
              animation: _ctrl,
              builder: (_, __) {
                final v = _ctrl.value;
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(3, (i) {
                    final delay = i * 0.25;
                    final opacity =
                        (0.3 + 0.7 * ((v + delay) % 1.0)).clamp(0.3, 1.0);
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Opacity(
                        opacity: opacity,
                        child: Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.accent,
                          ),
                        ),
                      ),
                    );
                  }),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Helper to gate access to Gemini Live from the Diagnose tab.
Future<void> launchLiveDiagnosis(BuildContext context) async {
  final vehicle = VehicleService.instance.selected;
  if (vehicle == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Add a vehicle first')),
    );
    return;
  }

  if (!FeatureFlags.geminiLiveBeta) {
    _showBetaDialog(context);
    return;
  }

  final sub = SubscriptionService.instance;
  if (!sub.limits.hasGeminiLive) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) =>
          const PaywallScreen(requiredFeature: 'Gemini Live'),
    ));
    return;
  }

  GeminiLiveService.instance.reset();
  Navigator.of(context).push(MaterialPageRoute<void>(
    builder: (_) => const LiveDiagnoseScreen(),
  ));
}

void _showBetaDialog(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Row(
        children: [
          const Icon(Icons.science_rounded, color: AppColors.accent, size: 22),
          const SizedBox(width: 8),
          Text('Beta Feature',
              style: Theme.of(ctx).textTheme.titleLarge),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Gemini Live video diagnosis is currently in closed beta.',
            style: Theme.of(ctx).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          Text(
            'Would you like to opt in?',
            style: Theme.of(ctx).textTheme.bodyMedium,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text('Not Now',
              style: TextStyle(color: AppColors.textSecondary)),
        ),
        TextButton(
          onPressed: () {
            FeatureFlags.override('gemini_live_beta', true);
            Navigator.pop(ctx);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                backgroundColor: AppColors.surface,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                content: const Text('Beta enabled! Try Gemini Live now.'),
              ),
            );
          },
          child: const Text('Opt In',
              style: TextStyle(color: AppColors.accent)),
        ),
      ],
    ),
  );
}
