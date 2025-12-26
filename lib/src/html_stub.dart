// Minimal stub for `dart:html` APIs used by the SDK when running on non-web
// platforms. This prevents importing `dart:html` on e.g. iOS, Android, macOS
// while allowing type-safe access in the web implementation via conditional
// imports.

class _NavigatorStub {
  String? get userAgent => null;
}

class _WindowStub {
  final _NavigatorStub navigator = _NavigatorStub();
}

// Expose a minimal `window` object with `navigator.userAgent`.
final _WindowStub window = _WindowStub();

// Minimal HttpRequest stub used by the web implementation when analyzing
// off-web. The real `dart:html` provides `HttpRequest.request` which
// returns a Future<HttpRequest> with `responseText` available. Here we
// provide a no-op implementation for analysis and non-web runtime.
class _HttpResponseStub {
  final String? responseText = null;
}

class HttpRequest {
  // Mimic the static async `request` method signature used in the web code.
  static Future<_HttpResponseStub> request(String url,
      {String method = 'GET',
      Map<String, String>? requestHeaders,
      String? sendData}) {
    return Future.value(_HttpResponseStub());
  }
}
