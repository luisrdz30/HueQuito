import 'package:flutter_test/flutter_test.dart';
import 'package:hue_quito/services/gemini_menu_service.dart';

void main() {
  group('GeminiMenuService', () {
    test('no requiere API Key local (usa Firebase AI Logic)', () async {
      expect(await GeminiMenuService.hasApiKey(), isTrue);
    });
  });
}
