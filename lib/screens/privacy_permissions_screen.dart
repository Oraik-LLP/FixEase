import 'package:flutter/material.dart';
import '../widgets/neuomorphic.dart';
import '../theme/app_theme.dart';

class PrivacyPermissionsScreen extends StatelessWidget {
  const PrivacyPermissionsScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Privacy & permissions')),
        body: AppBackground(
            child: ListView(padding: const EdgeInsets.all(20), children: const [
          _Purpose('Your vehicle records',
              'Vehicles, VINs, reports, conversations and preferences are saved on this device. There is no account sync in this release. You can add a vehicle without identifying it and fill in details later.'),
          _Purpose('Camera & selected photos',
              'Use the camera or system photo picker only when you choose a photo. Vehicle recognition and photo diagnosis send the selected images to the FixEase backend and its AI provider. Avoid unnecessary faces, documents and number plates. Denying camera access does not block manual setup.'),
          _Purpose('Microphone',
              'Voice assistance records a turn when you start recording. The selected recording is sent for remote AI processing. It is not a continuous live video or audio stream. You can use text instead.'),
          _Purpose('Bluetooth & location permissions',
              'OBD features use Bluetooth to connect to a supported adapter. Older Android versions may request location permission to discover Bluetooth devices. This release does not use GPS tracking. You can use symptom and photo assistance without an adapter.'),
          _Purpose('AI processing',
              'Requested symptoms, selected media and relevant vehicle/scan context are sent to the configured backend and Gemini. Unknown vehicle details stay unknown. VIN is excluded from diagnostic API payloads. Remote AI needs connectivity and does not replace inspection.'),
          _Purpose('Purchases',
              'Google Play and RevenueCat process purchases and store identifiers. A verified native purchase cache supports bounded offline access. Restoring or making new purchases requires connectivity. Clearing app storage also removes that offline cache.'),
          _Purpose('Control permissions',
              'On Android, open Settings → Apps → FixEase → Permissions to change camera, microphone, photo or Bluetooth access. Delete local vehicles/reports in the app or clear app storage to remove local records. Store purchase history and provider records are separate.'),
        ])),
      );
}

class _Purpose extends StatelessWidget {
  const _Purpose(this.title, this.body);
  final String title;
  final String body;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: NeuPane(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(body),
        ])),
      );
}
