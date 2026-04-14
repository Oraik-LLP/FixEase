import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/vehicle.dart';
import '../../services/vehicle_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/neuomorphic.dart';

class AddVehicleScreen extends StatefulWidget {
  const AddVehicleScreen({super.key});

  @override
  State<AddVehicleScreen> createState() => _AddVehicleScreenState();
}

class _AddVehicleScreenState extends State<AddVehicleScreen> {
  int _step = 0;

  String? _make;
  String? _model;
  int? _year;
  String _variant = '';
  FuelType _fuel = FuelType.petrol;
  final _mileageCtrl = TextEditingController();
  DateTime? _lastService;

  bool get _canProceed => switch (_step) {
        0 => _make != null,
        1 => _model != null,
        2 => _year != null,
        3 => true,
        _ => true,
      };

  void _next() {
    if (!_canProceed) return;
    HapticFeedback.selectionClick();
    if (_step < 3) {
      setState(() => _step++);
    } else {
      _save();
    }
  }

  void _back() {
    HapticFeedback.lightImpact();
    if (_step > 0) {
      setState(() => _step--);
    } else {
      Navigator.of(context).pop();
    }
  }

  Future<void> _pickServiceDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _lastService ?? now,
      firstDate: DateTime(2000),
      lastDate: now,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.accent,
            surface: AppColors.surface,
            onSurface: AppColors.textPrimary,
          ),
          dialogTheme: DialogThemeData(
            backgroundColor: AppColors.background,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          ),
        ),
        child: child ?? const SizedBox.shrink(),
      ),
    );
    if (picked != null) setState(() => _lastService = picked);
  }

  void _save() {
    final km = int.tryParse(_mileageCtrl.text.replaceAll(',', '')) ?? 0;
    final vehicle = Vehicle(
      id: DateTime.now().microsecondsSinceEpoch.toRadixString(36),
      make: _make!,
      model: _model!,
      year: _year!,
      variant: _variant.isNotEmpty ? _variant : null,
      fuelType: _fuel,
      mileageKm: km,
      lastServiceDate: _lastService,
    );
    VehicleService.instance.add(vehicle);
    HapticFeedback.heavyImpact();
    Navigator.of(context).pop(vehicle);
  }

  @override
  void dispose() {
    _mileageCtrl.dispose();
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
                    FixEaseStepBackButton(onPressed: _back),
                    const Spacer(),
                    Text(
                      'Step ${_step + 1} of 4',
                      style: tt.bodySmall,
                    ),
                  ],
                ),
              ),

              // ── progress bar ──
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: (_step + 1) / 4,
                    minHeight: 4,
                    backgroundColor: AppColors.surfaceHighlight,
                    color: AppColors.accent,
                  ),
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: _buildStep(tt),
                  ),
                ),
              ),

              // ── bottom button ──
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: NeuPrimaryButton(
                  label: _step == 3 ? 'Save Vehicle' : 'Continue',
                  onPressed: _canProceed ? _next : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep(TextTheme tt) {
    return switch (_step) {
      0 => _StepMake(
          key: const ValueKey('make'),
          selected: _make,
          onSelect: (v) => setState(() {
            _make = v;
            _model = null;
          }),
          tt: tt,
        ),
      1 => _StepModel(
          key: const ValueKey('model'),
          make: _make!,
          selected: _model,
          onSelect: (v) => setState(() => _model = v),
          tt: tt,
        ),
      2 => _StepYear(
          key: const ValueKey('year'),
          selected: _year,
          onSelect: (v) => setState(() => _year = v),
          tt: tt,
        ),
      _ => _StepDetails(
          key: const ValueKey('details'),
          variant: _variant,
          fuel: _fuel,
          mileageCtrl: _mileageCtrl,
          lastService: _lastService,
          onVariant: (v) => setState(() => _variant = v),
          onFuel: (v) => setState(() => _fuel = v),
          onPickDate: _pickServiceDate,
          tt: tt,
        ),
    };
  }
}

// ── Step 1: Make ────────────────────────────────────────────────────────────

class _StepMake extends StatefulWidget {
  const _StepMake({
    super.key,
    required this.selected,
    required this.onSelect,
    required this.tt,
  });
  final String? selected;
  final ValueChanged<String> onSelect;
  final TextTheme tt;

  @override
  State<_StepMake> createState() => _StepMakeState();
}

class _StepMakeState extends State<_StepMake> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final filtered = _search.isEmpty
        ? VehicleData.makes
        : VehicleData.makes
            .where((m) => m.toLowerCase().contains(_search.toLowerCase()))
            .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Select Make', style: widget.tt.headlineMedium),
        const SizedBox(height: 6),
        Text('Choose your car brand', style: widget.tt.bodyMedium),
        const SizedBox(height: 16),
        NeuTextField(
          hint: 'Search brands...',
          icon: Icons.search_rounded,
          controller: TextEditingController.fromValue(
            TextEditingValue(text: _search),
          ),
          keyboardType: TextInputType.text,
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: filtered.map((make) {
            final sel = make == widget.selected;
            return _ChipButton(
              label: make,
              selected: sel,
              onTap: () {
                setState(() => _search = '');
                widget.onSelect(make);
              },
            );
          }).toList(),
        ),
      ],
    );
  }
}

// ── Step 2: Model ───────────────────────────────────────────────────────────

class _StepModel extends StatelessWidget {
  const _StepModel({
    super.key,
    required this.make,
    required this.selected,
    required this.onSelect,
    required this.tt,
  });
  final String make;
  final String? selected;
  final ValueChanged<String> onSelect;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    final models = VehicleData.modelsFor(make);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Select Model', style: tt.headlineMedium),
        const SizedBox(height: 6),
        Text('$make — pick a model', style: tt.bodyMedium),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: models.map((model) {
            return _ChipButton(
              label: model,
              selected: model == selected,
              onTap: () => onSelect(model),
            );
          }).toList(),
        ),
      ],
    );
  }
}

// ── Step 3: Year ────────────────────────────────────────────────────────────

class _StepYear extends StatelessWidget {
  const _StepYear({
    super.key,
    required this.selected,
    required this.onSelect,
    required this.tt,
  });
  final int? selected;
  final ValueChanged<int> onSelect;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Select Year', style: tt.headlineMedium),
        const SizedBox(height: 6),
        Text('Manufacturing year', style: tt.bodyMedium),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: VehicleData.years.map((y) {
            return _ChipButton(
              label: '$y',
              selected: y == selected,
              onTap: () => onSelect(y),
            );
          }).toList(),
        ),
      ],
    );
  }
}

// ── Step 4: Details ─────────────────────────────────────────────────────────

class _StepDetails extends StatelessWidget {
  const _StepDetails({
    super.key,
    required this.variant,
    required this.fuel,
    required this.mileageCtrl,
    required this.lastService,
    required this.onVariant,
    required this.onFuel,
    required this.onPickDate,
    required this.tt,
  });
  final String variant;
  final FuelType fuel;
  final TextEditingController mileageCtrl;
  final DateTime? lastService;
  final ValueChanged<String> onVariant;
  final ValueChanged<FuelType> onFuel;
  final VoidCallback onPickDate;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Vehicle Details', style: tt.headlineMedium),
        const SizedBox(height: 6),
        Text('Optional — helps us give better diagnostics',
            style: tt.bodyMedium),
        const SizedBox(height: 20),

        Text('Variant / Trim', style: tt.titleMedium),
        const SizedBox(height: 8),
        NeuTextField(
          hint: 'e.g. Sport, LX, GT…',
          icon: Icons.tune_rounded,
          onChanged: onVariant,
        ),
        const SizedBox(height: 18),

        Text('Fuel Type', style: tt.titleMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: FuelType.values.map((f) {
            final label = f.name[0].toUpperCase() + f.name.substring(1);
            return _ChipButton(
              label: label,
              selected: f == fuel,
              onTap: () => onFuel(f),
            );
          }).toList(),
        ),
        const SizedBox(height: 18),

        Text('Mileage (km)', style: tt.titleMedium),
        const SizedBox(height: 8),
        NeuTextField(
          hint: 'e.g. 45000',
          icon: Icons.speed_rounded,
          controller: mileageCtrl,
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 18),

        Text('Last Service Date', style: tt.titleMedium),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: onPickDate,
          child: NeuPane(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              children: [
                const Icon(Icons.calendar_month_rounded,
                    size: 18, color: AppColors.textTertiary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    lastService != null
                        ? '${lastService!.day}/${lastService!.month}/${lastService!.year}'
                        : 'Tap to select date',
                    style: tt.bodyMedium?.copyWith(
                      color: lastService != null
                          ? AppColors.textPrimary
                          : AppColors.textTertiary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Shared chip widget ──────────────────────────────────────────────────────

class _ChipButton extends StatelessWidget {
  const _ChipButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: selected
              ? AppColors.accent.withValues(alpha: 0.18)
              : AppColors.surface,
          border: Border.all(
            color: selected
                ? AppColors.accent.withValues(alpha: 0.5)
                : const Color(0x0CFFFFFF),
            width: selected ? 1 : 0.5,
          ),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color:
                    selected ? AppColors.accent : AppColors.textPrimary,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
        ),
      ),
    );
  }
}
