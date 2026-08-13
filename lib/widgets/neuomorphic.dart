import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';
import '../services/theme_service.dart';

// ---------------------------------------------------------------------------
// Shadow system: subtle dark-glass style from Cybertruck reference.
// Much softer than standard neumorphism — think dark frosted panels.
// ---------------------------------------------------------------------------

List<BoxShadow> _panelShadows({double i = 1.0}) => [
      BoxShadow(
        color: AppColors.shadowDark,
        offset: Offset(4 * i, 4 * i),
        blurRadius: 12 * i,
      ),
      BoxShadow(
        color: AppColors.shadowLight,
        offset: Offset(-2 * i, -2 * i),
        blurRadius: 8 * i,
      ),
    ];

List<BoxShadow> _insetShadows({double i = 1.0}) => [
      BoxShadow(
        color: AppColors.shadowDark,
        offset: Offset(2 * i, 2 * i),
        blurRadius: 5 * i,
        spreadRadius: -1,
      ),
      BoxShadow(
        color: AppColors.shadowLight,
        offset: Offset(-1 * i, -1 * i),
        blurRadius: 4 * i,
        spreadRadius: -1,
      ),
    ];

// ---------------------------------------------------------------------------
// NeuPane — dark glass card (reference Status/Information panels)
// ---------------------------------------------------------------------------

class NeuPane extends StatelessWidget {
  const NeuPane({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = 18,
    this.intensity = 1.0,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final double intensity;

  @override
  Widget build(BuildContext context) {
    final surface = fxColor(
      context,
      dark: AppColors.surface,
      light: AppColorsLight.surface,
    );
    final borderColor = Theme.of(context).brightness == Brightness.light
        ? const Color(0x14000000)
        : const Color(0x0CFFFFFF);
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: borderColor, width: 0.5),
        boxShadow: _panelShadows(i: intensity),
      ),
      child: child,
    );
  }
}

// ---------------------------------------------------------------------------
// NeuPrimaryButton — accent-filled pill (reference lock/power buttons)
// ---------------------------------------------------------------------------

class NeuPrimaryButton extends StatelessWidget {
  const NeuPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.expanded = true,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool expanded;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final isEnabled = onPressed != null;
    final button = GestureDetector(
      onTap: isEnabled
          ? () {
              HapticFeedback.lightImpact();
              onPressed!();
            }
          : null,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 22),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          color: isEnabled
              ? AppColors.accent
              : AppColors.accent.withValues(alpha: 0.3),
          boxShadow: isEnabled
              ? [
                  BoxShadow(
                    color: AppColors.accent.withValues(alpha: 0.35),
                    blurRadius: 18,
                    offset: const Offset(0, 5),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18, color: Colors.white),
              const SizedBox(width: 7),
            ],
            Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .labelLarge
                  ?.copyWith(color: Colors.white),
            ),
          ],
        ),
      ),
    );
    return expanded ? SizedBox(width: double.infinity, child: button) : button;
  }
}

// ---------------------------------------------------------------------------
// NeuSecondaryButton — dark surface pill (reference navigation buttons)
// ---------------------------------------------------------------------------

class NeuSecondaryButton extends StatelessWidget {
  const NeuSecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.expanded = true,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool expanded;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final button = GestureDetector(
      onTap: onPressed == null
          ? null
          : () {
              HapticFeedback.lightImpact();
              onPressed!();
            },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 22),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          color: FxColors.surface(context),
          border: Border.all(color: FxColors.borderSubtle(context), width: 0.5),
          boxShadow: _panelShadows(i: 0.6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18, color: FxColors.textSecondary(context)),
              const SizedBox(width: 7),
            ],
            Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .labelLarge
                  ?.copyWith(color: FxColors.textPrimary(context)),
            ),
          ],
        ),
      ),
    );
    return expanded ? SizedBox(width: double.infinity, child: button) : button;
  }
}

// ---------------------------------------------------------------------------
// NeuIconButton — small dark circle (reference settings gear, minimize)
// ---------------------------------------------------------------------------

class NeuIconButton extends StatefulWidget {
  const NeuIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.size = 44,
    this.color,
    this.selected = false,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final double size;
  final Color? color;
  final bool selected;

  @override
  State<NeuIconButton> createState() => _NeuIconButtonState();
}

class _NeuIconButtonState extends State<NeuIconButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final isActive = _pressed || widget.selected;
    final fg = widget.selected
        ? FxColors.accent(context)
        : (widget.color ?? FxColors.textSecondary(context));

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        HapticFeedback.lightImpact();
        widget.onPressed();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 90),
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: widget.selected
              ? FxColors.accent(context).withValues(alpha: 0.15)
              : FxColors.surface(context),
          border: Border.all(
            color: widget.selected
                ? FxColors.accent(context).withValues(alpha: 0.35)
                : FxColors.borderSubtle(context),
            width: 0.5,
          ),
          boxShadow: isActive ? _insetShadows(i: 0.7) : _panelShadows(i: 0.5),
        ),
        child: Center(
          child: Icon(widget.icon, size: widget.size * 0.42, color: fg),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// NeuTextField — inset input field
// ---------------------------------------------------------------------------

class NeuTextField extends StatelessWidget {
  const NeuTextField({
    super.key,
    this.hint,
    this.icon,
    this.trailing,
    this.obscure = false,
    this.controller,
    this.keyboardType,
    this.onChanged,
    this.onTap,
    this.onSubmitted,
    this.readOnly = false,
    this.enabled = true,
    this.minLines = 1,
    this.maxLines = 1,
    this.textInputAction,
  });

  final String? hint;
  final IconData? icon;
  final Widget? trailing;
  final bool obscure;
  final TextEditingController? controller;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;
  final ValueChanged<String>? onSubmitted;
  final bool readOnly;
  final bool enabled;
  final int? minLines;
  final int? maxLines;
  final TextInputAction? textInputAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: FxColors.surface(context),
        border: Border.all(color: FxColors.borderSubtle(context), width: 0.5),
        boxShadow: _insetShadows(i: 0.7),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboardType,
        minLines: minLines,
        maxLines: maxLines,
        textInputAction: textInputAction,
        onChanged: onChanged,
        onTap: onTap,
        onSubmitted: onSubmitted,
        readOnly: readOnly,
        enabled: enabled,
        style: GoogleFonts.inter(
          fontSize: 13,
          color: enabled
              ? FxColors.textPrimary(context)
              : FxColors.textTertiary(context),
          fontWeight: FontWeight.w400,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.inter(
            fontSize: 13,
            color: FxColors.textTertiary(context),
            fontWeight: FontWeight.w400,
          ),
          prefixIcon: icon != null
              ? Icon(icon, size: 18, color: FxColors.textTertiary(context))
              : null,
          suffixIcon: trailing,
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// NeuToggle — ON/OFF switch (reference A/C toggle)
// ---------------------------------------------------------------------------

class NeuToggle extends StatelessWidget {
  const NeuToggle({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final accent = FxColors.accent(context);
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onChanged(!value);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeInOut,
        width: 52,
        height: 28,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: value
              ? accent.withValues(alpha: 0.2)
              : FxColors.surface(context),
          border: Border.all(
            color: value
                ? accent.withValues(alpha: 0.45)
                : FxColors.borderSubtle(context),
            width: 0.5,
          ),
          boxShadow: _insetShadows(i: 0.5),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeInOut,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: value ? accent : FxColors.surfaceHighlight(context),
              boxShadow: _panelShadows(i: 0.35),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// NeuProgressRing — donut gauge (reference temperature dial)
// ---------------------------------------------------------------------------

class NeuProgressRing extends StatelessWidget {
  const NeuProgressRing({
    super.key,
    required this.progress,
    this.size = 100,
    this.strokeWidth = 6,
    this.label,
  });

  final double progress;
  final double size;
  final double strokeWidth;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final surface = FxColors.surface(context);
    final track = FxColors.surfaceHighlight(context);
    final accent = FxColors.accent(context);
    final labelColor = FxColors.textPrimary(context);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: surface,
        border: Border.all(color: FxColors.borderSubtle(context), width: 0.5),
        boxShadow: _panelShadows(i: 0.75),
      ),
      child: Padding(
        padding: EdgeInsets.all(strokeWidth * 0.5),
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox.expand(
              child: CustomPaint(
                painter: _RingPainter(
                  progress: progress,
                  trackColor: track,
                  fillColor: accent,
                  strokeWidth: strokeWidth,
                ),
              ),
            ),
            Text(
              label ?? '${(progress * 100).round()}%',
              style: GoogleFonts.inter(
                fontSize: size * 0.17,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
                color: labelColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progress,
    required this.trackColor,
    required this.fillColor,
    required this.strokeWidth,
  });

  final double progress;
  final Color trackColor;
  final Color fillColor;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final center = (Offset.zero & size).center;
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;

    final track = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final fill = Paint()
      ..color = fillColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, track);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      fill,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.fillColor != fillColor;
}

// ---------------------------------------------------------------------------
// NeuSlider — thin progress bar with accent fill
// ---------------------------------------------------------------------------

class NeuSlider extends StatelessWidget {
  const NeuSlider({
    super.key,
    required this.value,
    this.onChanged,
    this.height = 6,
  });

  final double value;
  final ValueChanged<double>? onChanged;
  final double height;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final trackW = box.maxWidth;
        const thumbSize = 14.0;
        final clampedValue = value.clamp(0.0, 1.0);
        final travelW = math.max(0.0, trackW - thumbSize);
        final thumbLeft = clampedValue * travelW;
        final fillWidth = (thumbLeft + (thumbSize / 2)).clamp(0.0, trackW);
        return GestureDetector(
          onHorizontalDragUpdate: onChanged == null
              ? null
              : (details) {
                  if (trackW <= 0) return;
                  final v = (details.localPosition.dx / trackW).clamp(0.0, 1.0);
                  onChanged!(v);
                },
          child: SizedBox(
            height: 24,
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                Container(
                  height: height,
                  width: trackW,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(height / 2),
                    color: AppColors.surfaceHighlight,
                  ),
                ),
                Container(
                  height: height,
                  width: fillWidth,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(height / 2),
                    color: AppColors.accent,
                  ),
                ),
                Positioned(
                  left: thumbLeft,
                  child: Container(
                    width: thumbSize,
                    height: thumbSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.accent,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.accent.withValues(alpha: 0.35),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// NeuDropdown
// ---------------------------------------------------------------------------

class NeuDropdown<T> extends StatelessWidget {
  const NeuDropdown({
    super.key,
    required this.items,
    required this.value,
    required this.onChanged,
    this.hint,
  });

  final List<DropdownMenuItem<T>> items;
  final T? value;
  final ValueChanged<T?> onChanged;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: FxColors.surface(context),
        border: Border.all(color: FxColors.borderSubtle(context), width: 0.5),
        boxShadow: _panelShadows(i: 0.5),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          items: items,
          onChanged: (v) {
            HapticFeedback.selectionClick();
            onChanged(v);
          },
          isExpanded: true,
          hint: hint != null
              ? Text(
                  hint!,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: FxColors.textTertiary(context),
                  ),
                )
              : null,
          style: GoogleFonts.inter(
            fontSize: 13,
            color: FxColors.textPrimary(context),
            fontWeight: FontWeight.w400,
          ),
          dropdownColor: FxColors.surface(context),
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: FxColors.textTertiary(context),
            size: 18,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// VehicleImageSlot
// ---------------------------------------------------------------------------

class VehicleImageSlot extends StatelessWidget {
  const VehicleImageSlot({
    super.key,
    this.imagePath,
    this.size = 88,
    this.borderRadius = 14,
  });

  static const String addVehicleAsset = 'assets/logo/add_vehicle_icon.png';

  final String? imagePath;
  final double size;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final path = imagePath ?? addVehicleAsset;
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Container(
        width: size,
        height: size,
        color: AppColors.surfaceHighlight,
        child: Image.asset(
          path,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Image.asset(
            addVehicleAsset,
            width: size,
            height: size,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => Icon(
              Icons.add_road_rounded,
              size: size * 0.45,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
