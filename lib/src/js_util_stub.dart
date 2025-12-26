// Stubbed subset of dart:js_util used for non-web analysis/runtime.
// When running on web, the real `dart:js_util` will be used via conditional import.

bool hasProperty(Object? /* dynamic */ o, String name) => false;

dynamic getProperty(Object? /* dynamic */ o, String name) => null;

dynamic callMethod(Object? /* dynamic */ o, String method, List? args) => null;

dynamic callConstructor(Object? /* dynamic */ ctor, List args) => null;

dynamic jsify(Object? o) => o;

Future<dynamic> promiseToFuture(Object? p) => Future.value(null);

// Stubs for additional helpers used by the web implementation.
dynamic setProperty(Object? o, String name, Object? value) => null;

// allowInterop wraps a Dart function for JS interop on web; in non-web
// analysis/runtime we just return the function itself.
T allowInterop<T>(T f) => f;
