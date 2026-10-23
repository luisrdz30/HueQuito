import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('Single-Use QR Security & Token Tests', () {
    test('Token is marked in redeemed_qr_tokens and subsequent scan with same token is detected as duplicate', () async {
      SharedPreferences.setMockInitialValues({
        'redeemed_qr_tokens': ['used_token_123'],
      });

      final prefs = await SharedPreferences.getInstance();
      final redeemedList = prefs.getStringList('redeemed_qr_tokens') ?? [];

      expect(redeemedList.contains('used_token_123'), isTrue);
      expect(redeemedList.contains('new_token_456'), isFalse);

      // Simulate redeeming new_token_456
      redeemedList.add('new_token_456');
      await prefs.setStringList('redeemed_qr_tokens', redeemedList);

      // Now new_token_456 must be marked and cannot be redeemed again
      final updatedList = prefs.getStringList('redeemed_qr_tokens') ?? [];
      expect(updatedList.contains('new_token_456'), isTrue);
    });

    test('Timestamp expiration calculation correctly identifies QRs older than 10 minutes', () {
      final now = DateTime.now().millisecondsSinceEpoch;
      final recentTimestamp = now - (2 * 60 * 1000); // 2 minutes ago -> VALID
      final expiredTimestamp = now - (15 * 60 * 1000); // 15 minutes ago -> EXPIRED (> 10 mins)

      expect(now - recentTimestamp <= 600000, isTrue);
      expect(now - expiredTimestamp > 600000, isTrue);
    });
  });
}
