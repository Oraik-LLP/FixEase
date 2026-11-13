import 'package:flutter/material.dart';
import '../services/local_store_service.dart';

abstract final class PermissionPurpose {
  static Future<bool> explain(
    BuildContext context, {
    required String feature,
    required String title,
    required String purpose,
  }) async {
    final key = 'permission_explanation.$feature';
    if (LocalStoreService.readJsonMap(key)?['shown'] == true) return true;
    final accepted = await showDialog<bool>(
        context: context,
        builder: (dialog) =>
            AlertDialog(title: Text(title), content: Text(purpose), actions: [
              TextButton(
                  onPressed: () => Navigator.pop(dialog, false),
                  child: const Text('Not now')),
              TextButton(
                  onPressed: () => Navigator.pop(dialog, true),
                  child: const Text('Continue')),
            ]));
    if (accepted != true) return false;
    await LocalStoreService.writeJsonMap(key, {'shown': true});
    return true;
  }
}
