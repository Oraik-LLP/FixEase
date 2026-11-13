import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fixease/models/vehicle.dart';
import 'package:fixease/widgets/vehicle_autocomplete.dart';

void main() {
  test('common H makes and Honda B models work offline', () {
    expect(VehicleCatalogue.makes('H'), contains('Honda'));
    expect(
        VehicleCatalogue.models('honda', 'B'), containsAll(['BR-V', 'Brio']));
    expect(VehicleCatalogue.models('Honda', 'brv'), contains('BR-V'));
    expect(VehicleCatalogue.makes(''), isEmpty);
    expect(VehicleCatalogue.models('Custom make', 'custom'), isEmpty);
  });
  test(
      'unknown vehicle details survive persistence without fabricated defaults',
      () {
    final v = Vehicle.fromJson(
        Vehicle(id: 'bike', category: VehicleCategory.motorcycle).toJson());
    expect(v.category, VehicleCategory.motorcycle);
    expect(v.year, isNull);
    expect(v.fuelType, isNull);
    expect(v.mileageKm, isNull);
    expect(v.displayName, 'My motorcycle');
    expect(v.diagnosticContext['year'], isNull);
    expect(v.diagnosticContext.containsKey('vin'), false);
  });
  test(
      'legacy vehicles retain their known details and nullable edits clear them',
      () {
    final v = Vehicle.fromJson({
      'id': 'old',
      'make': 'Honda',
      'model': 'City',
      'year': 2018,
      'fuel_type': 'petrol',
      'mileage_km': 42000
    });
    expect(v.category, VehicleCategory.car);
    expect(v.year, 2018);
    expect(v.mileageKm, 42000);
    final edited = v.copyWith(year: null, fuelType: null, mileageKm: null);
    expect(edited.year, isNull);
    expect(edited.fuelType, isNull);
    expect(edited.mileageKm, isNull);
    expect(edited.id, v.id);
  });
  testWidgets('compact input permits suggestions and unlisted custom text',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = TextEditingController();
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Padding(
                padding: const EdgeInsets.all(20),
                child: VehicleAutocomplete(
                    label: 'Make',
                    controller: controller,
                    options: VehicleCatalogue.makes)))));
    await tester.enterText(find.byType(TextFormField), 'H');
    await tester.pumpAndSettle();
    expect(find.text('Honda'), findsOneWidget);
    await tester.tap(find.text('Honda'));
    await tester.pumpAndSettle();
    expect(controller.text, 'Honda');
    await tester.enterText(find.byType(TextFormField), 'My custom vehicle');
    await tester.pumpAndSettle();
    expect(controller.text, 'My custom vehicle');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });
}
