import 'package:flutter_test/flutter_test.dart';

import 'package:lpe_sdk/lpe_sdk.dart';

void main() {
  test('StripePaymentResult constructs', () {
    final result = const StripePaymentResult(success: true);
    expect(result.success, true);
  });
}
