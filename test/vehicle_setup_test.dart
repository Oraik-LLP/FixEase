import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fixease/models/vehicle.dart';
import 'package:fixease/screens/vehicle/vehicle_setup_screen.dart';
import 'package:fixease/services/local_store_service.dart';
import 'package:fixease/services/vehicle_service.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStoreService.init();
  });
  test('selected vehicle and old records survive restart and edits', () async {
    await LocalStoreService.writeJsonList('vehicles.v1', [
      {'id': 'legacy', 'make': 'Honda', 'model': 'City', 'year': 2018},
    ]);
    final store = VehicleService.instance;
    await store.load();
    expect(store.selected!.id, 'legacy');
    final bike = Vehicle(id: 'bike', category: VehicleCategory.motorcycle);
    await store.add(bike);
    await store.select(store.vehicles.firstWhere((v) => v.id == 'legacy'));
    await store.load();
    expect(store.selected!.id, 'legacy');
    await store.upsert(store.selected!.copyWith(model: 'Brio'));
    await store.load();
    expect(store.selected!.model, 'Brio');
    expect(store.vehicles.length, 2);
    await store.remove('legacy');
    await store.load();
    expect(store.selected!.id, 'bike');
  });
  testWidgets('direct fields and skip work on a narrow screen', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    Vehicle? result;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Builder(
                builder: (context) => TextButton(
                    onPressed: () async {
                      result = await Navigator.of(context).push<Vehicle>(
                          MaterialPageRoute(
                              builder: (_) => const VehicleSetupScreen()));
                    },
                    child: const Text('Open'))))));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(
        find.widgetWithText(TextFormField, 'Make — optional'), findsOneWidget);
    expect(
        find.widgetWithText(TextFormField, 'Model — optional'), findsOneWidget);
    final skip = find.text('Skip for now — add details later');
    await tester.scrollUntilVisible(skip, 300,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(skip);
    await tester.pumpAndSettle();
    expect(result, isNotNull);
    expect(result!.year, isNull);
    expect(result!.fuelType, isNull);
    expect(result!.mileageKm, isNull);
    expect(tester.takeException(), isNull);
  });
}
