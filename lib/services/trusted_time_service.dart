import 'package:ntp/ntp.dart';

class TrustedTimeService {
  TrustedTimeService._();
  static final TrustedTimeService instance = TrustedTimeService._();

  Future<DateTime?> fetchUtcNow() async {
    try {
      final now = await NTP.now(timeout: const Duration(seconds: 4));
      return now.toUtc();
    } catch (_) {
      return null;
    }
  }
}
