import Flutter
import UIKit
import PassKit

public class LearmondSDKNativePayPlugin: NSObject, FlutterPlugin {
  var channel: FlutterMethodChannel?
  // Keep a reference to the pending Flutter result while PK flow runs
  private var pendingResult: FlutterResult?

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "lpe/native_pay", binaryMessenger: registrar.messenger())
    let instance: LearmondSDKNativePayPlugin = LearmondSDKNativePayPlugin()
    instance.channel = channel
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any] else {
      result(["success": false, "error": "invalid_args"])
      return
    }

    if call.method == "presentNativePay" {
      presentNativePay(args: args, result: result)
    } else {
      result(FlutterMethodNotImplemented)
    }
  }

  private func presentNativePay(args: [String: Any], result: @escaping FlutterResult) {
    let method = (args["method"] as? String) ?? ""
    NSLog("LPE presentNativePay method=\(method) args=\(args)")

    // Prefer merchantId and other merchant fields from nested `merchantArgs` map
    // so the builder can be the single source of truth.
    let merchantArgs = args["merchantArgs"] as? [String: Any]
    let suppliedMerchantId = (merchantArgs?[
      "merchantId"] as? String) ?? (args["merchantId"] as? String)

    switch method {
    case "apple_pay":
      // Validate merchant id (prefer nested merchantArgs)
      guard let merchantId = suppliedMerchantId, !merchantId.isEmpty else {
        result(["success": false, "error": "missing_merchant_id"])
        return
      }

      // Check Apple Pay availability for networks
      let supportedNetworks: [PKPaymentNetwork] = [.visa, .masterCard, .amex, .discover]
      let canMakePayments = PKPaymentAuthorizationController.canMakePayments()
      let canMakePaymentsWithNetworks = PKPaymentAuthorizationController.canMakePayments(usingNetworks: supportedNetworks)
      if !canMakePayments || !canMakePaymentsWithNetworks {
        result(["success": false, "error": "apple_pay_unavailable", "raw": ["canMakePayment": canMakePayments, "canMakePaymentUsingNetworks": canMakePaymentsWithNetworks]])
        return
      }

      // Build payment request
      let currency = (args["currency"] as? String)?.uppercased() ?? "USD"
      let country = (args["country"] as? String) ?? "US"
      let amountCents = (args["amountCents"] as? Int) ?? 0
      let amount = NSDecimalNumber(value: Double(amountCents) / 100.0)

      NSLog("LPE merchantArgs=\(merchantArgs ?? [:])")

      // Determine a merchant display name: prefer nested merchantArgs, then explicit arg, fall back to app bundle name
      var displayMerchantName: String? = nil
      if let m = merchantArgs?["merchantName"] as? String, !m.isEmpty {
        displayMerchantName = m
      } else if let m = args["merchantName"] as? String, !m.isEmpty {
        displayMerchantName = m
      } else if let bundleName = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String, !bundleName.isEmpty {
        displayMerchantName = bundleName
      } else if let bundleName = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String, !bundleName.isEmpty {
        displayMerchantName = bundleName
      }

      // Optional merchant info (one-line) that can be shown beneath the merchant name
      let merchantInfo = (merchantArgs?["merchantInfo"] as? String) ?? (args["merchantInfo"] as? String)

      let request = PKPaymentRequest()
      request.merchantIdentifier = merchantId
      request.countryCode = country
      request.currencyCode = currency
      request.merchantCapabilities = .capability3DS
      request.supportedNetworks = [.visa, .masterCard, .amex, .discover]

      // Build payment summary items in the requested order and then append
      // the required Total row. Do not prepend a zero-value merchant row
      // (that caused the header to show "Source 0.00").
      var summaryItems: [PKPaymentSummaryItem] = []

      // Prefer summaryItems passed inside merchantArgs, fall back to top-level summaryItems for backward compatibility
      if let supplied = (merchantArgs?["summaryItems"] as? [[String: Any]]) ?? (args["summaryItems"] as? [[String: Any]]) {
        NSLog("LPE applePay: supplied summaryItems=\(supplied)")
        for item in supplied {
          if let label = item["label"] as? String, let cents = item["amountCents"] as? Int {
            // Skip any supplied 'Total' rows — we'll append an explicit Total.
            if label.trimmingCharacters(in: .whitespacesAndNewlines).caseInsensitiveCompare("Total") == .orderedSame {
              continue
            }
            let qty = NSDecimalNumber(value: Double(cents) / 100.0)
            summaryItems.append(PKPaymentSummaryItem(label: label, amount: qty))
          }
        }
      }

      // Compute authoritative total from supplied summaryItems if available,
      // otherwise fall back to the provided `amount`.
      var totalAmount = amount
      if summaryItems.count > 0 {
        var running = NSDecimalNumber(value: 0)
        for si in summaryItems {
          running = running.adding(si.amount)
        }
        totalAmount = running
      }

      // Label the final total row with the merchant name (or 'Source')
      // as requested by the UI specification.
      let finalLabel = (merchantArgs?["merchantName"] as? String) ?? (args["merchantName"] as? String) ?? displayMerchantName ?? "Source"
      let totalItem = PKPaymentSummaryItem(label: finalLabel, amount: totalAmount)

      // Append the supplied detail rows, then the explicit Total row so
      // the first visible line remains the Recipient, and a single Total row
      // shows at the end.
      var finalItems: [PKPaymentSummaryItem] = []
      finalItems.append(contentsOf: summaryItems)
      finalItems.append(totalItem)
      request.paymentSummaryItems = finalItems
      // Debug: log the summary items and computed total so we can verify what's sent to Apple Pay
      #if DEBUG
      for si in summaryItems {
        NSLog("LPE applePay: summaryItem: label=\(si.label), amount=\(si.amount)")
      }
      NSLog("LPE applePay: final total label=\(finalLabel), amount=\(totalAmount)")
      #endif
      // Debug: log the summary items so we can verify what's being sent to Apple Pay
      #if DEBUG
      for si in summaryItems {
        NSLog("LPE applePay: summaryItem: label=\(si.label), amount=\(si.amount)")
      }
      #endif

      let controller = PKPaymentAuthorizationController(paymentRequest: request)
      controller.delegate = self

      // store pending result to respond later
      pendingResult = result

      // Determine if running in simulator for helpful diagnostics
      var isSimulator = false
      #if targetEnvironment(simulator)
      isSimulator = true
      #endif

      DispatchQueue.main.async {
        controller.present { presented in
          if !presented {
            self.pendingResult?( [
              "success": false,
              "error": "present_failed",
              "raw": [
                "canMakePayment": canMakePayments,
                "canMakePaymentUsingNetworks": canMakePaymentsWithNetworks,
                "merchantId": merchantId,
                "isSimulator": isSimulator
              ]
            ] )
            self.pendingResult = nil
          }
        }
      }

    default:
      result(["success": false, "error": "unsupported_method"])
    }
    }
  }
  // (class end)

extension LearmondSDKNativePayPlugin: PKPaymentAuthorizationControllerDelegate {
  public func paymentAuthorizationController(_ controller: PKPaymentAuthorizationController, didAuthorizePayment payment: PKPayment, handler completion: @escaping (PKPaymentAuthorizationResult) -> Void) {
    // Extract token data and return to Dart as base64
    let tokenData = payment.token.paymentData
    let b64 = tokenData.base64EncodedString()

    // Return success to Dart with token and some metadata
    pendingResult?( [
      "success": true,
      "raw": [
        "paymentDataBase64": b64,
        "transactionIdentifier": payment.token.transactionIdentifier ?? "",
        "paymentMethod": payment.token.paymentMethod.debugDescription
      ]
    ])
    pendingResult = nil

    // Complete with success so Apple Pay sheet shows success
    completion(PKPaymentAuthorizationResult(status: .success, errors: nil))
  }

  public func paymentAuthorizationControllerDidFinish(_ controller: PKPaymentAuthorizationController) {
    // If the user dismissed without authorizing, return cancelled
    if let pending = pendingResult {
      pending(["success": false, "error": "cancelled"]) 
      pendingResult = nil
    }
    controller.dismiss(completion: nil)
  }
}
// extension end
// No trailing braces. File ends here.
