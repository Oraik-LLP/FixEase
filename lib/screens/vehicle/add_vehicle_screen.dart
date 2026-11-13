import 'package:flutter/material.dart';
import '../../models/vehicle.dart';
import 'vehicle_setup_screen.dart';

class AddVehicleScreen extends StatelessWidget {
  const AddVehicleScreen({super.key, this.initialVehicle});
  final Vehicle? initialVehicle;
  @override
  Widget build(BuildContext context) =>
      VehicleSetupScreen(initialVehicle: initialVehicle);
}
