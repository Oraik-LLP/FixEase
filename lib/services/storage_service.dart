import 'dart:io';

import 'package:path/path.dart' as p;

import '../config/supabase_config.dart';

/// Uploads images to Supabase Storage (bucket: "diagnostics").
/// Falls back to returning the local file path when Supabase is offline.
abstract final class StorageService {
  static const _bucket = 'diagnostics';

  static Future<String> uploadImage(File file, {String? folder}) async {
    if (!SupabaseConfig.isConfigured) return file.path;

    final ext = p.extension(file.path);
    final name =
        '${folder ?? 'photos'}/${DateTime.now().millisecondsSinceEpoch}$ext';

    try {
      await SupabaseConfig.client.storage
          .from(_bucket)
          .upload(name, file);

      final url = SupabaseConfig.client.storage
          .from(_bucket)
          .getPublicUrl(name);

      return url;
    } catch (_) {
      return file.path;
    }
  }

  static Future<List<String>> uploadImages(
    List<File> files, {
    String? folder,
  }) async {
    final urls = <String>[];
    for (final file in files) {
      urls.add(await uploadImage(file, folder: folder));
    }
    return urls;
  }
}
