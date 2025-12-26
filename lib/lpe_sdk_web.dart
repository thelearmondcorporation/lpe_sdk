// Web plugin implementation for lpe_sdk.
// Implements a minimal web native-pay bridge that supports capability checks
// and a PaymentRequest fallback for Google Pay (basic-card) development.
// The file uses some deprecated web interop helpers which are appropriate
// for this web-only implementation. Suppress the related analyzer info.
// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'dart:convert';
// The web plugin intentionally uses `dart:html` for DOM/Window access.
import 'src/html_stub.dart' if (dart.library.html) 'dart:html' as html;
import 'src/js_util_stub.dart' if (dart.library.js) 'dart:js_util' as js_util;

import 'package:flutter/services.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';

class LpeSdkWeb {
  static void registerWith(Registrar registrar) {
    // `registrar.messenger` is deprecated but still required for legacy web plugins.
    final channel = MethodChannel(
        'lpe/native_pay', const StandardMethodCodec(), registrar.messenger);
    channel.setMethodCallHandler((call) async {
      if (call.method == 'presentNativePay') {
        final args = (call.arguments ?? <String, dynamic>{}) as Map;
        return _handlePresentNativePay(args);
      }
      throw PlatformException(
          code: 'unimplemented', message: 'Method not implemented on web');
    });
  }
}

Future<Map<String, dynamic>> _handlePresentNativePay(Map args) async {
  final method = (args['method'] ?? 'unknown') as String;
  final amountCents = args['amountCents'] ?? 0;
  final currency = (args['currency'] ?? 'USD') as String;
  // Prefer an explicit merchant name passed inside `merchantArgs`, then
  // a top-level `merchantName` argument. Default to the company name so
  // PaymentRequest / Google Pay dialogs show a friendly label.
  final merchantArgs = (args['merchantArgs'] is Map)
      ? Map<String, dynamic>.from(args['merchantArgs'] as Map)
      : <String, dynamic>{};
  final merchantName = (merchantArgs['merchantName'] ??
      args['merchantName'] ??
      'The Learmond Corporation') as String;

  try {
    if (method == 'apple_pay') {
      final hasApple = js_util.hasProperty(html.window, 'ApplePaySession');
      if (!hasApple) {
        return {'success': false, 'error': 'unsupported_method'};
      }

      // Expect a server endpoint to perform Apple merchant validation.
      // The caller should include `appleMerchantValidationUrl` (HTTPS)
      // in `merchantArgs` or top-level args. If absent, return an
      // informative error so the app can implement server-side validation.
      final merchantArgs = (args['merchantArgs'] is Map)
          ? Map<String, dynamic>.from(args['merchantArgs'] as Map)
          : <String, dynamic>{};
      final validationEndpoint = (merchantArgs['appleMerchantValidationUrl'] ??
          args['appleMerchantValidationUrl'] ??
          merchantArgs['merchantValidationUrl'] ??
          args['merchantValidationUrl']) as String?;

      if (validationEndpoint == null) {
        return {
          'success': false,
          'error': 'merchant_validation_required',
          'canMakePayment': true
        };
      }

      try {
        final appleConstructor =
            js_util.getProperty(html.window, 'ApplePaySession');

        // Minimal payment request — apps may pass richer details in merchantArgs
        final value = (amountCents is num)
            ? (amountCents / 100.0).toStringAsFixed(2)
            : '0.00';
        final paymentRequest = js_util.jsify({
          'countryCode': merchantArgs['countryCode'] ?? 'US',
          'currencyCode': currency,
          'merchantCapabilities': js_util.jsify(['supports3DS']),
          'supportedNetworks': js_util.jsify(['visa', 'masterCard', 'amex']),
          'total': js_util.jsify({'label': merchantName, 'amount': value}),
        });

        final session =
            js_util.callConstructor(appleConstructor, [3, paymentRequest]);

        final completer = Completer<Map<String, dynamic>>();

        // onvalidatemerchant -> POST validationURL to server endpoint
        js_util.setProperty(session, 'onvalidatemerchant',
            js_util.allowInterop((dynamic event) {
          try {
            final validationUrl =
                js_util.getProperty(event, 'validationURL') as String?;
            if (validationUrl == null) return;

            // Send the validationURL to the merchant server which will
            // call Apple's validation endpoint using the merchant identity
            // certificate and return the merchantSession JSON.
            html.HttpRequest.request(
              validationEndpoint,
              method: 'POST',
              requestHeaders: {'Content-Type': 'application/json'},
              sendData: jsonEncode({'validationURL': validationUrl}),
            ).then((resp) {
              try {
                final String txt = resp.responseText ?? '';
                final dynamic merchantSession = jsonDecode(txt);
                js_util.callMethod(session, 'completeMerchantValidation',
                    [js_util.jsify(merchantSession)]);
              } catch (e) {
                // If parsing fails, attempt to forward raw text
                js_util.callMethod(session, 'completeMerchantValidation', [
                  js_util.jsify({'error': 'invalid_merchant_session'})
                ]);
              }
            }).catchError((err) {
              // Could not contact merchant server — abort session.
              try {
                js_util.callMethod(session, 'abort', []);
              } catch (_) {}
            });
          } catch (_) {}
        }));

        // onpaymentauthorized -> capture token and resolve completer
        js_util.setProperty(session, 'onpaymentauthorized',
            js_util.allowInterop((dynamic event) {
          try {
            final payment = js_util.getProperty(event, 'payment');
            final token = js_util.getProperty(payment, 'token');
            final jsonObj = js_util.getProperty(html.window, 'JSON');
            final tokenJson =
                js_util.callMethod(jsonObj, 'stringify', [token]) as String? ??
                    '{}';
            // Tell the Apple Pay UI the payment succeeded and close the sheet
            js_util.callMethod(session, 'completePayment', [
              js_util.jsify({'status': 'SUCCESS'})
            ]);
            completer.complete({'paymentDataJson': tokenJson});
          } catch (e) {
            try {
              js_util.callMethod(session, 'completePayment', [
                js_util.jsify({'status': 'FAILURE'})
              ]);
            } catch (_) {}
            if (!completer.isCompleted) completer.completeError(e);
          }
        }));

        // Begin the Apple Pay session — UI will appear to the user
        js_util.callMethod(session, 'begin', []);

        final result = await completer.future;
        return {'success': true, 'raw': result};
      } catch (e) {
        return {'success': false, 'error': e.toString()};
      }
    }

    if (method == 'google_pay') {
      // Prefer the Google Pay JS SDK (when present) which provides a native
      // Google Pay experience even on Safari; fall back to PaymentRequest
      // using the Google Pay method identifier to avoid Apple Pay interception.
      try {
        final hasGoogle = js_util.hasProperty(html.window, 'google');
        if (hasGoogle &&
            js_util.hasProperty(
                js_util.getProperty(html.window, 'google'), 'payments')) {
          final payments = js_util.getProperty(
              js_util.getProperty(html.window, 'google'), 'payments');
          if (js_util.hasProperty(payments, 'api')) {
            final paymentsClientConstructor = js_util.getProperty(
                js_util.getProperty(payments, 'api'), 'PaymentsClient');
            // Use TEST environment for dev; production users should pass env via args in the future.
            final client = js_util.callConstructor(paymentsClientConstructor, [
              js_util.jsify({'environment': 'TEST'})
            ]);

            // Prepare an isReadyToPay request
            final isReadyReq = js_util.jsify({
              'apiVersion': 2,
              'apiVersionMinor': 0,
              'allowedPaymentMethods': js_util.jsify([
                {
                  'type': 'CARD',
                  'parameters': {
                    'allowedAuthMethods':
                        js_util.jsify(['PAN_ONLY', 'CRYPTOGRAM_3DS']),
                    'allowedCardNetworks':
                        js_util.jsify(['VISA', 'MASTERCARD', 'AMEX'])
                  }
                }
              ])
            });

            final isReady = await js_util.promiseToFuture(
                js_util.callMethod(client, 'isReadyToPay', [isReadyReq]));
            if (isReady == true) {
              final value = (amountCents is num)
                  ? (amountCents / 100.0).toStringAsFixed(2)
                  : '0.00';
              final paymentDataRequest = js_util.jsify({
                'apiVersion': 2,
                'apiVersionMinor': 0,
                'transactionInfo': {
                  'totalPriceStatus': 'FINAL',
                  'totalPrice': value,
                  'currencyCode': currency
                },
                'merchantInfo': {'merchantName': merchantName},
                'allowedPaymentMethods': js_util.jsify([
                  {
                    'type': 'CARD',
                    'parameters': {
                      'allowedAuthMethods':
                          js_util.jsify(['PAN_ONLY', 'CRYPTOGRAM_3DS']),
                      'allowedCardNetworks':
                          js_util.jsify(['VISA', 'MASTERCARD', 'AMEX'])
                    },
                    'tokenizationSpecification': js_util.jsify({
                      'type': 'PAYMENT_GATEWAY',
                      'parameters': js_util.jsify({
                        'gateway': 'stripe',
                        'stripe:version': '2020-08-27',
                        'stripe:publishableKey': args['publishableKey'] ?? ''
                      })
                    })
                  }
                ])
              });

              final paymentData = await js_util.promiseToFuture(js_util
                  .callMethod(client, 'loadPaymentData', [paymentDataRequest]));

              // Serialize the returned paymentData
              final jsonObject = js_util.getProperty(html.window, 'JSON');
              final detailsJson = js_util
                  .callMethod(jsonObject, 'stringify', [paymentData]) as String;

              return {
                'success': true,
                'raw': {'paymentDataJson': detailsJson}
              };
            }
          }
        }

        // Fallback: PaymentRequest using Google Pay method identifier which
        // avoids triggering Apple Pay on Safari (unlike 'basic-card').
        if (!js_util.hasProperty(html.window, 'PaymentRequest')) {
          return {'success': false, 'error': 'unsupported_method'};
        }

        final methodData = js_util.jsify([
          {
            'supportedMethods': 'https://google.com/pay',
            'data': js_util.jsify({
              'environment': 'TEST',
              'apiVersion': 2,
              'apiVersionMinor': 0,
              'merchantInfo': js_util.jsify({'merchantName': merchantName}),
              'allowedPaymentMethods': js_util.jsify([
                {
                  'type': 'CARD',
                  'parameters': js_util.jsify({
                    'allowedAuthMethods':
                        js_util.jsify(['PAN_ONLY', 'CRYPTOGRAM_3DS']),
                    'allowedCardNetworks':
                        js_util.jsify(['VISA', 'MASTERCARD', 'AMEX'])
                  }),
                  'tokenizationSpecification': js_util.jsify({
                    'type': 'PAYMENT_GATEWAY',
                    'parameters': js_util.jsify({
                      'gateway': 'stripe',
                      'stripe:publishableKey': args['publishableKey'] ?? ''
                    })
                  })
                }
              ])
            })
          }
        ]);

        final value = (amountCents is num)
            ? (amountCents / 100.0).toStringAsFixed(2)
            : '0.00';
        final details = js_util.jsify({
          'total': {
            'label': merchantName,
            'amount': {'currency': currency, 'value': value}
          }
        });

        final paymentRequestConstructor =
            js_util.getProperty(html.window, 'PaymentRequest');
        final pr = js_util
            .callConstructor(paymentRequestConstructor, [methodData, details]);

        // If canMakePayment exists, call it to check availability.
        bool canMakePayment = true;
        try {
          if (js_util.hasProperty(pr, 'canMakePayment')) {
            final res = await js_util
                .promiseToFuture(js_util.callMethod(pr, 'canMakePayment', []));
            canMakePayment = res == true;
          }
        } catch (_) {
          canMakePayment = true;
        }

        if (!canMakePayment) {
          return {'success': false, 'error': 'canMakePayment:false'};
        }

        final showResult =
            await js_util.promiseToFuture(js_util.callMethod(pr, 'show', []));

        try {
          await js_util.promiseToFuture(
              js_util.callMethod(showResult, 'complete', ['success']));
        } catch (_) {}

        String detailsJson;
        try {
          final jsonObject = js_util.getProperty(html.window, 'JSON');
          detailsJson = js_util.callMethod(jsonObject, 'stringify',
              [js_util.getProperty(showResult, 'details')]) as String;
        } catch (_) {
          detailsJson =
              js_util.getProperty(showResult, 'details')?.toString() ?? '{}';
        }

        return {
          'success': true,
          'raw': {'paymentDataJson': detailsJson}
        };
      } catch (e) {
        return {'success': false, 'error': e.toString()};
      }
    }

    return {'success': false, 'error': 'unsupported_method'};
  } catch (e) {
    return {'success': false, 'error': e.toString()};
  }
}
