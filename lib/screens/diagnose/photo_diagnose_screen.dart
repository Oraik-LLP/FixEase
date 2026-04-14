import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/ai_response.dart';
import '../../models/diagnostic.dart';
import '../../services/ai_service.dart';
import '../../services/diagnostic_service.dart';
import '../../services/storage_service.dart';
import '../../services/vehicle_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/health_score_card.dart';
import '../../widgets/neuomorphic.dart';

class PhotoDiagnoseScreen extends StatefulWidget {
  const PhotoDiagnoseScreen({super.key});

  @override
  State<PhotoDiagnoseScreen> createState() => _PhotoDiagnoseScreenState();
}

class _PhotoDiagnoseScreenState extends State<PhotoDiagnoseScreen> {
  final _picker = ImagePicker();
  final List<File> _images = [];
  final _descCtrl = TextEditingController();
  int _step = 0; // 0=capture, 1=preview+describe, 2=analyzing, 3=result
  AiDiagnosticResponse? _result;

  bool get _canProceed => switch (_step) {
        0 => _images.isNotEmpty,
        1 => true,
        _ => false,
      };

  void _next() {
    if (!_canProceed) return;
    HapticFeedback.selectionClick();
    if (_step == 0) {
      setState(() => _step = 1);
    } else if (_step == 1) {
      _analyze();
    }
  }

  void _back() {
    HapticFeedback.lightImpact();
    if (_step == 1) {
      setState(() => _step = 0);
    } else {
      Navigator.of(context).pop();
    }
  }

  Future<void> _pickCamera() async {
    final xfile = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
      maxWidth: 1920,
    );
    if (xfile != null) {
      setState(() => _images.add(File(xfile.path)));
    }
  }

  Future<void> _pickGallery() async {
    final xfiles = await _picker.pickMultiImage(
      imageQuality: 85,
      maxWidth: 1920,
    );
    if (xfiles.isNotEmpty) {
      setState(() {
        _images.addAll(xfiles.map((x) => File(x.path)));
      });
    }
  }

  void _removeImage(int index) {
    HapticFeedback.lightImpact();
    setState(() => _images.removeAt(index));
  }

  Future<void> _analyze() async {
    final vehicle = VehicleService.instance.selected;
    if (vehicle == null) {
      if (mounted) Navigator.of(context).pop();
      return;
    }

    setState(() => _step = 2);
    HapticFeedback.heavyImpact();

    try {
      final urls =
          await StorageService.uploadImages(_images, folder: vehicle.id);

      final response = await AiService.instance.analyzePhotos(
        vehicle: vehicle,
        images: _images,
        description:
            _descCtrl.text.trim().isNotEmpty ? _descCtrl.text.trim() : null,
      );

      final session = DiagnosticSession(
        id: DateTime.now().microsecondsSinceEpoch.toRadixString(36),
        vehicleId: vehicle.id,
        type: DiagnosticType.photo,
        description:
            _descCtrl.text.trim().isNotEmpty ? _descCtrl.text.trim() : null,
        imageUrls: urls,
        aiResponse: response.summary,
        aiResponseJson: response.toJson(),
        healthScore: response.healthScore,
        vehicleName: vehicle.displayName,
      );
      await DiagnosticService.instance.save(session);

      if (!mounted) return;
      setState(() {
        _result = response;
        _step = 3;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _step = 1);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Analysis failed: ${e.toString().split(":").last.trim()}'),
          backgroundColor: AppColors.surface,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── top bar ──
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 16, 0),
                child: Row(
                  children: [
                    if (_step < 2)
                      FixEaseStepBackButton(onPressed: _back),
                    if (_step == 3)
                      FixEaseStepBackButton(
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    const Spacer(),
                    if (_step < 2)
                      Text('Step ${_step + 1} of 2', style: tt.bodySmall),
                  ],
                ),
              ),

              if (_step < 2)
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: (_step + 1) / 2,
                      minHeight: 4,
                      backgroundColor: AppColors.surfaceHighlight,
                      color: AppColors.accent,
                    ),
                  ),
                ),

              Expanded(
                child: switch (_step) {
                  0 => _buildCaptureStep(tt),
                  1 => _buildPreviewStep(tt),
                  2 => _buildAnalyzing(tt),
                  _ => _buildResult(tt),
                },
              ),

              if (_step < 2)
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: NeuPrimaryButton(
                    label: _step == 1 ? 'Analyze Photos' : 'Continue',
                    icon: _step == 1 ? Icons.auto_fix_high_rounded : null,
                    onPressed: _canProceed ? _next : null,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Step 0: Capture ───────────────────────────────────────────────────

  Widget _buildCaptureStep(TextTheme tt) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.camera_alt_rounded,
                  color: AppColors.accent, size: 24),
              const SizedBox(width: 8),
              Text('Photo Diagnosis', style: tt.headlineMedium),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Take or upload up to 8 photos of the issue area.',
            style: tt.bodyMedium,
          ),
          const SizedBox(height: 20),

          // action buttons
          Row(
            children: [
              Expanded(
                child: _CaptureButton(
                  icon: Icons.camera_rounded,
                  label: 'Camera',
                  onTap: _pickCamera,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _CaptureButton(
                  icon: Icons.photo_library_rounded,
                  label: 'Gallery',
                  onTap: _pickGallery,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // grid of images
          if (_images.isNotEmpty) ...[
            Text(
              '${_images.length} photo(s) selected',
              style: tt.titleMedium,
            ),
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
              ),
              itemCount: _images.length,
              itemBuilder: (ctx, i) => _ImageTile(
                file: _images[i],
                onRemove: () => _removeImage(i),
              ),
            ),
          ] else
            NeuPane(
              child: Column(
                children: [
                  const Icon(Icons.add_photo_alternate_rounded,
                      size: 48, color: AppColors.textTertiary),
                  const SizedBox(height: 10),
                  Text('No photos yet', style: tt.bodyMedium),
                  const SizedBox(height: 4),
                  Text(
                    'Use the buttons above to capture or select images',
                    style: tt.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

          const SizedBox(height: 16),
          NeuPane(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Tips for better results', style: tt.titleMedium),
                const SizedBox(height: 8),
                _Tip('Take photos in good lighting'),
                _Tip('Include close-ups of the affected area'),
                _Tip('Capture the issue from multiple angles'),
                _Tip('Include any dashboard warning lights'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Step 1: Preview + describe ────────────────────────────────────────

  Widget _buildPreviewStep(TextTheme tt) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Review & Describe', style: tt.headlineMedium),
          const SizedBox(height: 6),
          Text(
            'Review your photos and add any details about the issue.',
            style: tt.bodyMedium,
          ),
          const SizedBox(height: 16),

          // horizontal scroll of images
          SizedBox(
            height: 200,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _images.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, i) => ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.file(
                  _images[i],
                  width: 200,
                  height: 200,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 200, height: 200,
                    color: AppColors.surface,
                    child: const Icon(Icons.broken_image_rounded,
                        color: AppColors.textTertiary),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${_images.length} photo(s)',
            style: tt.bodySmall,
          ),
          const SizedBox(height: 20),

          Text('Describe the issue (optional)', style: tt.titleMedium),
          const SizedBox(height: 8),
          NeuTextField(
            hint: 'e.g. "Strange noise from front left when turning…"',
            icon: Icons.edit_note_rounded,
            controller: _descCtrl,
          ),
          const SizedBox(height: 20),

          NeuPane(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('What happens next', style: tt.titleMedium),
                const SizedBox(height: 8),
                Text(
                  'Our AI will analyze your photos for visible damage, '
                  'fluid leaks, tire condition, rust, and other issues. '
                  'Results typically take 5–15 seconds.',
                  style: tt.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Step 2: Analyzing ─────────────────────────────────────────────────

  Widget _buildAnalyzing(TextTheme tt) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 80,
            height: 80,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: AppColors.accent,
              backgroundColor: AppColors.surfaceHighlight,
            ),
          ),
          const SizedBox(height: 28),
          Text('Analyzing photos…', style: tt.headlineMedium),
          const SizedBox(height: 8),
          Text(
            'Our AI is examining your images',
            style: tt.bodyMedium,
          ),
        ],
      ),
    );
  }

  // ── Step 3: Result ────────────────────────────────────────────────────

  Widget _buildResult(TextTheme tt) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle_rounded,
                  color: AppColors.accent, size: 28),
              const SizedBox(width: 10),
              Text('Photo Analysis Complete', style: tt.headlineMedium),
            ],
          ),
          const SizedBox(height: 16),

          // thumbnail strip
          SizedBox(
            height: 72,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _images.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (_, i) => ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.file(_images[i],
                    width: 72, height: 72, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 72, height: 72,
                      color: AppColors.surface,
                      child: const Icon(Icons.broken_image_rounded,
                          size: 20, color: AppColors.textTertiary),
                    )),
              ),
            ),
          ),
          const SizedBox(height: 16),

          if (_result != null) DiagnosticResultCard(response: _result!),

          const SizedBox(height: 20),
          NeuPrimaryButton(
            label: 'Done',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}

// ── Supporting widgets ──────────────────────────────────────────────────────

class _CaptureButton extends StatelessWidget {
  const _CaptureButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: NeuPane(
        padding: const EdgeInsets.symmetric(vertical: 28),
        child: Column(
          children: [
            Icon(icon, size: 36, color: AppColors.accent),
            const SizedBox(height: 8),
            Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .labelLarge
                  ?.copyWith(color: AppColors.accent),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImageTile extends StatelessWidget {
  const _ImageTile({required this.file, required this.onRemove});
  final File file;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.file(file, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: AppColors.surface,
                child: const Icon(Icons.broken_image_rounded,
                    color: AppColors.textTertiary),
              ),
            ),
          ),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              width: 24,
              height: 24,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xCC000000),
              ),
              child: const Icon(Icons.close_rounded,
                  size: 14, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}

class _Tip extends StatelessWidget {
  const _Tip(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline_rounded,
              size: 14, color: AppColors.accent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}
