import 'package:fixease/utils/vin_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('VinUtils validates 17-character VIN', () {
    expect(VinUtils.isValid('MA3ERLF1S00123456'), isTrue);
    expect(VinUtils.isValid('MA3ERLF1S0012345'), isFalse);
  });

  test('VinUtils masks all but last 4 digits', () {
    expect(
      VinUtils.maskDisplay('MA3ERLF1S00123456'),
      '*************3456',
    );
  });
}
