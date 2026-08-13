import '../data/dtc_database.dart';
import '../models/dtc_info.dart';

/// Search and lookup OBD-II diagnostic trouble codes.
abstract final class DtcLookupService {
  static DtcInfo? lookup(String code) => DtcDatabase.get(code);

  static List<DtcInfo> search(String query, {DtcCategory? category}) =>
      DtcDatabase.search(query, category: category);

  static List<DtcInfo> byCategory(DtcCategory category) =>
      DtcDatabase.byCategory(category);

  static String describeCode(String code) {
    final info = lookup(code);
    if (info == null) return code;
    return '${info.code}: ${info.description}';
  }

  static DtcInfo resolve(String code) {
    final normalized = code.trim().toUpperCase();
    if (normalized.isEmpty) {
      return const DtcInfo(
        code: '----',
        description: 'Invalid code',
        category: DtcCategory.powertrain,
        severity: DtcSeverity.info,
      );
    }
    return lookup(normalized) ??
        DtcInfo(
          code: normalized,
          description: 'Not in local database — tap to search',
          category: DtcInfo.categoryFromCode(normalized),
          severity: DtcSeverity.info,
        );
  }

  static List<DtcInfo> describeCodes(Iterable<String> codes) {
    return codes.map(resolve).toList();
  }
}
