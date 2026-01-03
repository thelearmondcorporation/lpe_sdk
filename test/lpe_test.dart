import 'package:flutter_test/flutter_test.dart';

import 'package:lpe_sdk/lpe_sdk.dart';

void main() {
  test('PaymentResult constructs', () {
    final result = const PaymentResult(success: true);
    expect(result.success, true);
  });
}
