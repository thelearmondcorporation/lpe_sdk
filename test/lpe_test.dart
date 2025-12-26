import 'package:flutter_test/flutter_test.dart';

import 'package:lpe_sdk/lpe_sdk.dart';

void main() {
  test('StripePaymentResult constructs', () {
    final result =
        const StripePaymentResult(success: true, status: 'succeeded');
    expect(result.success, true);
    expect(result.status, 'succeeded');
  });
}
