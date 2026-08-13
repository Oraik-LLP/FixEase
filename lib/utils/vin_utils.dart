abstract final class VinUtils {
  static final _vinPattern = RegExp(r'^[A-HJ-NPR-Z0-9]{17}$');

  static String normalize(String raw) =>
      raw.trim().toUpperCase().replaceAll(RegExp(r'[^A-HJ-NPR-Z0-9]'), '');

  static bool isValid(String raw) => _vinPattern.hasMatch(normalize(raw));

  static String? validationMessage(String raw) {
    final vin = normalize(raw);
    if (vin.isEmpty) return 'Enter your 17-character VIN';
    if (vin.length < 17) return 'VIN must be 17 characters (${vin.length}/17)';
    if (!_vinPattern.hasMatch(vin)) {
      return 'VIN uses letters A–Z and digits 0–9 (no I, O, or Q)';
    }
    return null;
  }

  /// Shows only the last 4 characters; the rest are asterisks.
  static String maskDisplay(String vin) {
    final normalized = normalize(vin);
    if (normalized.isEmpty) return '';
    if (normalized.length <= 4) return normalized;
    final last4 = normalized.substring(normalized.length - 4);
    return '${'*' * (normalized.length - 4)}$last4';
  }
}
