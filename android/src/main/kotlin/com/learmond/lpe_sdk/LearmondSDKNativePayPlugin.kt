package com.learmond.lpe_sdk

import android.app.Activity
import android.content.Context
import android.content.Intent
import androidx.annotation.NonNull
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

// Google Pay imports - ensure you add Play Services Wallet dependency in app if you enable this
import com.google.android.gms.wallet.PaymentsClient
import com.google.android.gms.wallet.Wallet
import com.google.android.gms.wallet.WalletConstants
import com.google.android.gms.wallet.PaymentDataRequest
import com.google.android.gms.wallet.PaymentData
import com.google.android.gms.wallet.AutoResolveHelper
import com.google.android.gms.common.api.ApiException

import org.json.JSONObject
import org.json.JSONArray

/**
 * LearmondSDKNativePayPlugin
 *
 * Implements a Google Pay flow that returns the raw payment token to Dart.
 * This implementation does not use Stripe on device; it returns the
 * tokenization payload which your backend should exchange/verify.
 */
class LearmondSDKNativePayPlugin: FlutterPlugin, MethodCallHandler, ActivityAware {
  private lateinit var channel : MethodChannel
  private var context: Context? = null
  private var activity: Activity? = null
  private var activityBinding: ActivityPluginBinding? = null
  private var pendingResult: Result? = null

  private val LOAD_PAYMENT_DATA_REQUEST_CODE = 991

  override fun onAttachedToEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
    context = binding.applicationContext
    channel = MethodChannel(binding.binaryMessenger, "lpe/native_pay")
    channel.setMethodCallHandler(this)
  }

  override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
    context = null
  }

  // ActivityAware
  override fun onAttachedToActivity(binding: ActivityPluginBinding) {
    activity = binding.activity
    activityBinding = binding
    // register result listener
    binding.addActivityResultListener { requestCode, resultCode, data ->
      if (requestCode == LOAD_PAYMENT_DATA_REQUEST_CODE) {
        handleLoadPaymentDataResult(resultCode, data)
        return@addActivityResultListener true
      }
      return@addActivityResultListener false
    }
  }

  override fun onDetachedFromActivityForConfigChanges() {
    activity = null
    activityBinding = null
  }

  override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
    activity = binding.activity
    activityBinding = binding
  }

  override fun onDetachedFromActivity() {
    activity = null
    activityBinding = null
  }

  override fun onMethodCall(call: MethodCall, result: Result) {
    when (call.method) {
      "presentNativePay" -> handlePresentNativePay(call, result)
      else -> result.notImplemented()
    }
  }

  private fun handlePresentNativePay(call: MethodCall, result: Result) {
    val args = call.arguments as? Map<*, *>
    if (args == null) {
      result.success(mapOf("success" to false, "error" to "invalid_args"))
      return
    }

    val method = args["method"] as? String ?: ""

    when (method) {
      "google_pay" -> presentGooglePay(args, result)
      else -> result.success(mapOf("success" to false, "error" to "unsupported_method"))
    }
  }

  private fun presentGooglePay(args: Map<*, *>, result: Result) {
    android.util.Log.d("LpeNativePay", "presentGooglePay args: $args")
    val ctx = context
    val act = activity
    if (ctx == null || act == null) {
      result.success(mapOf("success" to false, "error" to "no_activity"))
      return
    }

    // Build PaymentsClient
    val paymentsClient: PaymentsClient = Wallet.getPaymentsClient(ctx, Wallet.WalletOptions.Builder()
      .setEnvironment(WalletConstants.ENVIRONMENT_TEST)
      .build())

    // Build PaymentDataRequest JSON according to Google Pay API
    try {
      val transactionInfo = JSONObject()
      val currency = (args["currency"] as? String)?.uppercase() ?: "USD"

      // Prefer merchantArgs map if provided (new API)
      val merchantArgs = args["merchantArgs"] as? Map<*, *>

      // Merchant display name / info (prefer nested merchantArgs fields)
      val merchantNameArg = when {
        merchantArgs?.get("merchantName") is String -> merchantArgs["merchantName"] as String
        else -> (args["merchantName"] as? String) ?: ""
      }
      val merchantInfoArg = when {
        merchantArgs?.get("merchantInfo") is String -> merchantArgs["merchantInfo"] as String
        else -> (args["merchantInfo"] as? String) ?: ""
      }

      // Compute authoritative total price from supplied summaryItems when present
      var totalCents = (args["amountCents"] as? Int) ?: 0
      try {
        val suppliedSummary = (merchantArgs?.get("summaryItems") as? List<*>) ?: (args["summaryItems"] as? List<*>)
        if (suppliedSummary != null && suppliedSummary.isNotEmpty()) {
          var computed = 0
          for (item in suppliedSummary) {
            if (item is Map<*, *>) {
              val cents = (item["amountCents"] as? Number)?.toInt() ?: 0
              computed += cents
            }
          }
          // Use computed sum if it differs from provided amount or if provided amount missing
          if (computed > 0) totalCents = computed
        }
      } catch (e: Exception) {
        // ignore and fall back to provided amountCents
      }

      val totalPrice = String.format("%.2f", totalCents / 100.0)
      transactionInfo.put("totalPrice", totalPrice)
      transactionInfo.put("totalPriceStatus", "FINAL")
      transactionInfo.put("currencyCode", currency)

      // Include displayItems built from summaryItems so Google Pay shows the breakdown
      try {
        val suppliedSummary = (merchantArgs?.get("summaryItems") as? List<*>) ?: (args["summaryItems"] as? List<*>)
        if (suppliedSummary != null && suppliedSummary.isNotEmpty()) {
          val displayItems = JSONArray()
          for (item in suppliedSummary) {
            if (item is Map<*, *>) {
              val label = (item["label"] as? String) ?: ""
              val cents = (item["amountCents"] as? Number)?.toInt() ?: 0
              val price = String.format("%.2f", cents / 100.0)
              val di = JSONObject()
              di.put("label", label)
              di.put("type", "LINE_ITEM")
              di.put("price", price)
              displayItems.put(di)
            }
          }
          // Add an optional merchant info row (zero-priced) if provided
          if (merchantInfoArg.isNotEmpty()) {
            val infoDi = JSONObject()
            infoDi.put("label", merchantInfoArg)
            infoDi.put("type", "LINE_ITEM")
            infoDi.put("price", String.format("%.2f", 0.0))
            displayItems.put(infoDi)
          }
          // Add a final display item labeled with merchant name showing the total
          val totalDi = JSONObject()
          totalDi.put("label", if (merchantNameArg.isNotEmpty()) merchantNameArg else "Source")
          totalDi.put("type", "LINE_ITEM")
          totalDi.put("price", totalPrice)
          displayItems.put(totalDi)

          android.util.Log.d("LpeNativePay", "displayItems=" + displayItems.toString())
          if (displayItems.length() > 0) {
            transactionInfo.put("displayItems", displayItems)
          }
        }
      } catch (e: Exception) {
        // ignore
      }

      val baseRequest = JSONObject()
      baseRequest.put("apiVersion", 2)
      baseRequest.put("apiVersionMinor", 0)

      // Optionally provide merchantInfo so Google Pay header shows the merchant name
      if (merchantNameArg.isNotEmpty()) {
        val merchantInfo = JSONObject()
        merchantInfo.put("merchantName", merchantNameArg)
        // We do not have a direct place to put merchant 'info' in the Google Pay merchantInfo object,
        // but we include 'merchantInfo' as a display item (above) so it's visible in the breakdown.
        baseRequest.put("merchantInfo", merchantInfo)
      }

      // Debug log computed total for diagnostics
      try {
        android.util.Log.d("LpeNativePay", "Computed totalPrice=$totalPrice, merchantName=$merchantNameArg")
      } catch (e: Exception) {
        // ignore logging errors
      }

      val cardPaymentMethod = JSONObject()
      cardPaymentMethod.put("type", "CARD")
      val parameters = JSONObject()
      parameters.put("allowedAuthMethods", JSONArray().put("PAN_ONLY").put("CRYPTOGRAM_3DS"))
      parameters.put("allowedCardNetworks", JSONArray().put("AMEX").put("DISCOVER").put("MASTERCARD").put("VISA"))
      cardPaymentMethod.put("parameters", parameters)

      // Tokenization: support PAYMENT_GATEWAY tokenization for common gateways.
      val tokenizationSpec = JSONObject()
      val gateway = (args["gateway"] as? String)?.lowercase() ?: ""
      val publishableKey = (args["publishableKey"] as? String) ?: ""
      val gatewayMerchantId = (args["gatewayMerchantId"] as? String) ?: ""

      if (publishableKey.isNotEmpty()) {
        // Prefer Stripe gateway tokenization when a publishable key is provided
        tokenizationSpec.put("type", "PAYMENT_GATEWAY")
        val tokenParams = JSONObject()
        tokenParams.put("gateway", "stripe")
        tokenParams.put("stripe:publishableKey", publishableKey)
        // Specify a stripe API version that is compatible with client tokenization
        tokenParams.put("stripe:version", "2020-08-27")
        if (gatewayMerchantId.isNotEmpty()) tokenParams.put("gatewayMerchantId", gatewayMerchantId)
        tokenizationSpec.put("parameters", tokenParams)

        // Debug: log tokenization spec details (mask publishable key)
        try {
          val maskedPk = if (publishableKey.length > 8) publishableKey.substring(0,4) + "..." + publishableKey.takeLast(4) else publishableKey
          android.util.Log.d("LpeNativePay", "tokenizationSpec: gateway=stripe, stripe_version=${tokenParams.optString("stripe:version")}, stripe_publishableKey_masked=${maskedPk}, gatewayMerchantId=${tokenParams.optString("gatewayMerchantId")} )")
        } catch (e: Exception) { }
      } else if (gateway.isNotEmpty() && gateway != "example") {
        tokenizationSpec.put("type", "PAYMENT_GATEWAY")
        val tokenParams = JSONObject()
        tokenParams.put("gateway", gateway)
        if (gatewayMerchantId.isNotEmpty()) tokenParams.put("gatewayMerchantId", gatewayMerchantId)
        tokenizationSpec.put("parameters", tokenParams)

        // Debug: log tokenization gateway details
        try {
          android.util.Log.d("LpeNativePay", "tokenizationSpec: gateway=${gateway}, gatewayMerchantId=${gatewayMerchantId}")
        } catch (e: Exception) { }
      } else {
        // Default placeholder tokenization for development/testing
        tokenizationSpec.put("type", "PAYMENT_GATEWAY")
        val tokenParams = JSONObject()
        tokenParams.put("gateway", "example")
        tokenParams.put("gatewayMerchantId", "exampleMerchantId")
        tokenizationSpec.put("parameters", tokenParams)

        try {
          android.util.Log.d("LpeNativePay", "tokenizationSpec: gateway=example (dev placeholder)")
        } catch (e: Exception) { }
      }
      cardPaymentMethod.put("tokenizationSpecification", tokenizationSpec)

      val allowedPaymentMethods = JSONArray()
      allowedPaymentMethods.put(cardPaymentMethod)

      val paymentDataRequestJson = JSONObject(baseRequest.toString())
      paymentDataRequestJson.put("allowedPaymentMethods", allowedPaymentMethods)
      paymentDataRequestJson.put("transactionInfo", transactionInfo)

      val request = PaymentDataRequest.fromJson(paymentDataRequestJson.toString())

      // Save pending result and launch Google Pay UI
      pendingResult = result
      // Use the local non-null activity variable to satisfy null-safety (act)
      AutoResolveHelper.resolveTask(paymentsClient.loadPaymentData(request), act, LOAD_PAYMENT_DATA_REQUEST_CODE)
    } catch (e: Exception) {
      result.success(mapOf("success" to false, "error" to (e.message ?: "request_build_failed")))
    }
  }

  private fun handleLoadPaymentDataResult(resultCode: Int, data: Intent?) {
    val res = pendingResult ?: return
    try {
      when (resultCode) {
        Activity.RESULT_OK -> {
          val paymentData = data?.let { PaymentData.getFromIntent(it) }
          val paymentJson = paymentData?.toJson()
          if (paymentJson != null) {
            val jo = JSONObject(paymentJson)
            val pm = jo.optJSONObject("paymentMethodData")
            val tokenization = pm?.optJSONObject("tokenizationData")
            val token = tokenization?.optString("token") ?: ""

            // Debug: log tokenization type and a safe preview of the token (trimmed)
            try {
              val tokenType = tokenization?.optString("type") ?: "unknown"
              val tokenLen = token.length
              val tokenPreview = if (token.length > 160) token.substring(0, 160) + "..." else token
              val desc = pm?.optString("description") ?: ""
              android.util.Log.d("LpeNativePay", "PaymentData returned: tokenization_type=${tokenType}, token_length=${tokenLen}, token_preview=${tokenPreview}")
              if (desc.isNotEmpty()) android.util.Log.d("LpeNativePay", "PaymentMethod description: ${desc}")
              // Also log a short prefix of the full payment JSON for context (avoid printing full payload)
              val jsonPreview = if (paymentJson.length > 1000) paymentJson.substring(0, 1000) + "..." else paymentJson
              android.util.Log.d("LpeNativePay", "paymentDataJson_preview=${jsonPreview}")
            } catch (e: Exception) { }

            val raw = mapOf("paymentToken" to token, "paymentDataJson" to paymentJson)
            res.success(mapOf("success" to true, "raw" to raw))
          } else {
            res.success(mapOf("success" to false, "error" to "empty_payment_data"))
          }
        }
        Activity.RESULT_CANCELED -> {
          res.success(mapOf("success" to false, "error" to "cancelled"))
        }
        else -> {
          // Try to extract status code
          val status = AutoResolveHelper.getStatusFromIntent(data)
          val code = status?.statusCode ?: -1
          res.success(mapOf("success" to false, "error" to "error", "raw" to mapOf("statusCode" to code)))
        }
      }
    } catch (e: ApiException) {
      res.success(mapOf("success" to false, "error" to e.message))
    } catch (e: Exception) {
      res.success(mapOf("success" to false, "error" to e.message))
    } finally {
      pendingResult = null
    }
  }
}
