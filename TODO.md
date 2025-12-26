# TODO

TODO list for the SDK (created by tooling)

- [ ] Implement macOS Apple Pay integration
- [ ] Implement Windows payment bridge
- [ ] Implement Linux payment bridge
- [ ] Implement Web JS integration
- [ ] Add platform unit/integration tests
- [ ] Update README platform support section
- [ ] Run CI checks: format, analyze, dry-run publish
- [ ]  Implement learmondpaybuttons.dart and seperate from paysheet. Paysheet is stripe elements (Card, US Bank, EU Bank) only mounted in webview. 
- [ ] Patch to avoid importing dart:html on non:web (iOS, macOS, android emulator)

Notes:
- Platform stubs were added for macOS, Windows, Linux, and Web.
- Native implementations are currently placeholders returning NotImplemented.
- Run `flutter analyze` and `flutter pub get` after edits.

Created: 2025-12-20
