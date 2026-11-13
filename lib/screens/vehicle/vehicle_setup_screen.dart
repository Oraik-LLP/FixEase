import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../models/vehicle.dart';
import '../../models/vehicle_recognition.dart';
import '../../services/ai_service.dart';
import '../../services/vehicle_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/neuomorphic.dart';
import '../../widgets/vehicle_autocomplete.dart';

class VehicleSetupScreen extends StatefulWidget {
  const VehicleSetupScreen({super.key, this.initialVehicle});
  final Vehicle? initialVehicle;
  @override
  State<VehicleSetupScreen> createState() => _VehicleSetupScreenState();
}

class _VehicleSetupScreenState extends State<VehicleSetupScreen> {
  final _form = GlobalKey<FormState>();
  final _make = TextEditingController();
  final _model = TextEditingController();
  final _year = TextEditingController();
  final _variant = TextEditingController();
  final _mileage = TextEditingController();
  final _vin = TextEditingController();
  final _photos = <File>[];
  VehicleCategory _category = VehicleCategory.other;
  FuelType? _fuel;
  DateTime? _serviceDate;
  VehicleRecognition? _recognition;
  String? _error;
  bool _recognizing = false;
  bool _saving = false;
  bool _manual = false;
  int _request = 0;

  @override
  void initState() {
    super.initState();
    final v = widget.initialVehicle;
    if (v != null) {
      _category = v.category;
      _fuel = v.fuelType;
      _serviceDate = v.lastServiceDate;
      _make.text = v.make;
      _model.text = v.model;
      _year.text = v.year?.toString() ?? '';
      _variant.text = v.variant ?? '';
      _mileage.text = v.mileageKm?.toString() ?? '';
      _vin.text = v.vin ?? '';
      _manual = true;
    }
  }

  @override
  void dispose() {
    _request++;
    for (final c in [_make, _model, _year, _variant, _mileage, _vin]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pick(ImageSource source) async {
    if (_photos.length >= 2 || _recognizing) return;
    try {
      final selected = await ImagePicker().pickImage(
          source: source, maxWidth: 1600, maxHeight: 1600, imageQuality: 80);
      if (!mounted || selected == null) return;
      setState(() {
        _photos.add(File(selected.path));
        _error = null;
      });
      await _recognize();
    } on PlatformException {
      if (mounted) {
        setState(() => _error =
            'Camera or photo access is unavailable. You can allow it in Settings, type details, or skip for now.');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'That photo could not be opened. Try another photo or type details.');
      }
    }
  }

  Future<void> _recognize() async {
    if (_photos.isEmpty || _recognizing) return;
    final request = ++_request;
    setState(() {
      _recognizing = true;
      _error = null;
    });
    try {
      final result = await AiService.instance
          .recognizeVehicle(_photos)
          .timeout(const Duration(seconds: 60));
      if (!mounted || request != _request) return;
      setState(() => _recognition = result);
    } catch (_) {
      if (mounted && request == _request) {
        setState(() => _error =
            'Vehicle recognition is unavailable right now. Your photos are still here. Retry, type details, or skip identification.');
      }
    } finally {
      if (mounted && request == _request) setState(() => _recognizing = false);
    }
  }

  void _useSuggestion(VehicleSuggestion suggestion) {
    setState(() {
      _category = suggestion.category;
      _make.text = suggestion.make;
      _model.text = suggestion.model;
      _year.text = suggestion.year?.toString() ?? '';
      _fuel = suggestion.fuelType;
      _manual = true;
    });
  }

  Future<void> _save({bool provisional = false}) async {
    if (_saving ||
        (!provisional && !(_form.currentState?.validate() ?? false))) {
      return;
    }
    if (!provisional) {
      final year = int.tryParse(_year.text.trim());
      final mileage = int.tryParse(_mileage.text.trim());
      final invalidYear = _year.text.trim().isNotEmpty &&
          (year == null || year < 1886 || year > DateTime.now().year + 1);
      final invalidMileage =
          _mileage.text.trim().isNotEmpty && (mileage == null || mileage < 0);
      final invalidVin = _vin.text.trim().isNotEmpty &&
          !RegExp(r'^[A-HJ-NPR-Z0-9]{17}$')
              .hasMatch(_vin.text.trim().toUpperCase());
      if (invalidYear || invalidMileage || invalidVin) {
        setState(() {
          _manual = true;
          _error =
              'Correct the entered year, mileage or VIN, or clear it to leave it unknown.';
        });
        return;
      }
    }
    setState(() => _saving = true);
    try {
      final old = widget.initialVehicle;
      final id =
          old?.id ?? DateTime.now().microsecondsSinceEpoch.toRadixString(36);
      var imagePath = old?.imagePath;
      if (_photos.isNotEmpty && !provisional) {
        final directory = Directory(p.join(
            (await getApplicationDocumentsDirectory()).path, 'vehicles'));
        await directory.create(recursive: true);
        final target =
            p.join(directory.path, id + p.extension(_photos.first.path));
        imagePath = (await _photos.first.copy(target)).path;
      }
      final vehicle = Vehicle(
          id: id,
          category: _category,
          make: provisional ? '' : _make.text.trim(),
          model: provisional ? '' : _model.text.trim(),
          year: provisional ? null : int.tryParse(_year.text.trim()),
          variant: provisional || _variant.text.trim().isEmpty
              ? null
              : _variant.text.trim(),
          fuelType: provisional ? null : _fuel,
          mileageKm: provisional ? null : int.tryParse(_mileage.text.trim()),
          vin: provisional || _vin.text.trim().isEmpty
              ? null
              : _vin.text.trim().toUpperCase(),
          lastServiceDate: provisional ? null : _serviceDate,
          imagePath: imagePath,
          userId: old?.userId,
          createdAt: old?.createdAt);
      if (old == null) {
        await VehicleService.instance.add(vehicle);
      } else {
        await VehicleService.instance.upsert(vehicle);
      }
      if (!mounted) return;
      HapticFeedback.selectionClick();
      Navigator.of(context).pop(vehicle);
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'The vehicle could not be saved. Your details are still here; please try again.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _field(String label, TextEditingController controller,
          {TextInputType? keyboard, String? Function(String?)? validator}) =>
      Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: TextFormField(
              controller: controller,
              keyboardType: keyboard,
              validator: validator,
              decoration: InputDecoration(labelText: label)));

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
          title: Text(
              widget.initialVehicle == null ? 'Add vehicle' : 'Edit vehicle')),
      body: AppBackground(
          child: SafeArea(
              child: Form(
        key: _form,
        child: ListView(padding: const EdgeInsets.all(20), children: [
          Text('Set up your vehicle', style: tt.headlineSmall),
          const SizedBox(height: 8),
          const Text(
              'Type a make and model, use a photo, or skip identification. All details can be corrected later.'),
          const SizedBox(height: 18),
          DropdownButtonFormField<VehicleCategory>(
              initialValue: _category,
              key: ValueKey(_category),
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Vehicle type'),
              items: VehicleCategory.values
                  .map((v) => DropdownMenuItem(value: v, child: Text(v.label)))
                  .toList(),
              onChanged: _saving
                  ? null
                  : (v) =>
                      setState(() => _category = v ?? VehicleCategory.other)),
          const SizedBox(height: 16),
          VehicleAutocomplete(
              label: 'Make — optional',
              controller: _make,
              options: VehicleCatalogue.makes),
          VehicleAutocomplete(
              label: 'Model — optional',
              controller: _model,
              options: (query) => VehicleCatalogue.models(_make.text, query)),
          Text(
              'Only photos you choose are sent to FixEase’s AI service for identification. Avoid faces, documents, and plates when they are unnecessary. Photo access is optional.',
              style: tt.bodySmall),
          const SizedBox(height: 12),
          Wrap(spacing: 10, runSpacing: 8, children: [
            OutlinedButton.icon(
                onPressed: _recognizing || _photos.length >= 2
                    ? null
                    : () => _pick(ImageSource.camera),
                icon: const Icon(Icons.camera_alt_outlined),
                label: const Text('Take photo')),
            OutlinedButton.icon(
                onPressed: _recognizing || _photos.length >= 2
                    ? null
                    : () => _pick(ImageSource.gallery),
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('Choose photo')),
          ]),
          if (_photos.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
                spacing: 12,
                children: _photos
                    .map((file) => Stack(children: [
                          ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.file(file,
                                  width: 120, height: 100, fit: BoxFit.cover)),
                          Positioned(
                              right: 0,
                              top: 0,
                              child: IconButton(
                                  tooltip: 'Remove photo',
                                  onPressed: _recognizing
                                      ? null
                                      : () => setState(() {
                                            _photos.remove(file);
                                            _recognition = null;
                                          }),
                                  icon: const Icon(Icons.close))),
                        ]))
                    .toList()),
          ],
          if (_recognizing) ...[
            const SizedBox(height: 16),
            const LinearProgressIndicator(),
            const SizedBox(height: 8),
            const Text(
                'Checking the vehicle… You can still skip identification.'),
          ],
          if (_recognition case final result?) ...[
            const SizedBox(height: 12),
            Text(result.guidance),
            for (final suggestion in result.candidates)
              Card(
                  child: ListTile(
                      title: Text(suggestion.label),
                      subtitle: Text(
                          'AI suggestion · ${(suggestion.confidence * 100).round()}% confidence · confirm or correct'),
                      trailing: const Icon(Icons.edit_outlined),
                      onTap: () => _useSuggestion(suggestion))),
            if (result.needsAnotherPhoto && _photos.length < 2)
              const Text(
                  'Another angle may help. Choose one more photo above.'),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!,
                style: tt.bodyMedium?.copyWith(color: AppColors.accent)),
            if (_photos.isNotEmpty)
              TextButton(
                  onPressed: _recognizing ? null : _recognize,
                  child: const Text('Retry recognition')),
          ],
          const SizedBox(height: 14),
          TextButton.icon(
              onPressed: () => setState(() => _manual = !_manual),
              icon: Icon(_manual ? Icons.expand_less : Icons.edit_outlined),
              label: const Text('Year and other details — optional')),
          if (_manual) ...[
            _field('Year — optional', _year, keyboard: TextInputType.number,
                validator: (v) {
              if (v == null || v.trim().isEmpty) return null;
              final year = int.tryParse(v);
              return year == null ||
                      year < 1886 ||
                      year > DateTime.now().year + 1
                  ? 'Enter a valid year or leave blank.'
                  : null;
            }),
            ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text('Add details — optional'),
                children: [
                  _field('Variant — optional', _variant),
                  DropdownButtonFormField<FuelType>(
                      key: ValueKey(_fuel),
                      initialValue: _fuel,
                      isExpanded: true,
                      decoration: const InputDecoration(
                          labelText: 'Fuel / powertrain — optional'),
                      items: [
                        const DropdownMenuItem<FuelType>(
                            value: null, child: Text('Unknown')),
                        ...FuelType.values.map((v) =>
                            DropdownMenuItem(value: v, child: Text(v.name)))
                      ],
                      onChanged: (v) => setState(() => _fuel = v)),
                  const SizedBox(height: 14),
                  _field('Mileage in km — optional', _mileage,
                      keyboard: TextInputType.number,
                      validator: (v) => v == null ||
                              v.trim().isEmpty ||
                              (int.tryParse(v) != null && int.parse(v) >= 0)
                          ? null
                          : 'Enter a non-negative mileage or leave blank.'),
                  _field('VIN — optional', _vin,
                      validator: (v) => v == null ||
                              v.trim().isEmpty ||
                              RegExp(r'^[A-HJ-NPR-Z0-9]{17}$')
                                  .hasMatch(v.trim().toUpperCase())
                          ? null
                          : 'Enter 17 valid VIN characters or leave blank.'),
                  const Text(
                      'VIN stays on this device and is excluded from AI requests. Add or edit it later in My Vehicles.'),
                  ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Last service — optional'),
                      subtitle: Text(
                          _serviceDate?.toIso8601String().split('T').first ??
                              'Unknown'),
                      trailing: _serviceDate == null
                          ? const Icon(Icons.calendar_today_outlined)
                          : IconButton(
                              tooltip: 'Clear service date',
                              onPressed: () =>
                                  setState(() => _serviceDate = null),
                              icon: const Icon(Icons.clear)),
                      onTap: () async {
                        final date = await showDatePicker(
                            context: context,
                            initialDate: _serviceDate ?? DateTime.now(),
                            firstDate: DateTime(1950),
                            lastDate: DateTime.now());
                        if (mounted && date != null) {
                          setState(() => _serviceDate = date);
                        }
                      }),
                ]),
          ],
          const SizedBox(height: 12),
          const Text(
              'OBD compatibility depends on the exact vehicle, market, adapter and protocol. Motorcycle, scooter and heavy-duty coverage is not yet verified. Symptom and photo assistance remain available.'),
          const SizedBox(height: 20),
          NeuPrimaryButton(
              label: _saving ? 'Saving…' : 'Save vehicle',
              onPressed: _saving ? null : () => _save()),
          if (widget.initialVehicle == null)
            TextButton(
                onPressed: _saving ? null : () => _save(provisional: true),
                child: const Text('Skip for now — add details later')),
          const SizedBox(height: 20),
        ]),
      ))),
    );
  }
}
