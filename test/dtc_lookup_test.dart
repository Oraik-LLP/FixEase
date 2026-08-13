import 'package:fixease/data/dtc_database.dart';
import 'package:fixease/services/dtc_lookup_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('DtcDatabase has 4000+ codes', () {
    DtcDatabase.ensureInitialized();
    expect(DtcDatabase.all().length, greaterThanOrEqualTo(4000));
  });

  test('DtcLookupService finds P0420', () {
    final info = DtcLookupService.lookup('P0420');
    expect(info, isNotNull);
    expect(info!.code, 'P0420');
    expect(info.description.toLowerCase(), contains('catalyst'));
  });

  test('DtcLookupService wildcard search P04*', () {
    final results = DtcLookupService.search('P04*');
    expect(results.length, greaterThan(5));
    expect(results.every((r) => r.code.startsWith('P04')), isTrue);
  });

  test('DtcLookupService resolves unknown codes', () {
    final info = DtcLookupService.resolve('P9999');
    expect(info.code, 'P9999');
    expect(info.description.toLowerCase(), contains('not in local'));
    expect(DtcLookupService.describeCodes(['P0420', 'P9999']).length, 2);
  });
}
