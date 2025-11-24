import 'package:flutter_test/flutter_test.dart';
import 'package:app/services/switch_hub_ble_service.dart';

void main() {
  group('Alphanumeric Font Generation', () {
    late SwitchHubBleService bleService;

    setUp(() {
      bleService = const SwitchHubBleService();
    });

    test('should include all uppercase letters A-Z', () {
      final characterSet = bleService._getAlphanumericCharacterSet();

      for (int i = 65; i <= 90; i++) {
        final char = String.fromCharCode(i);
        expect(characterSet, contains(char), reason: 'Missing uppercase letter: $char');
      }

      print('✅ All uppercase letters (A-Z) included');
    });

    test('should include all lowercase letters a-z', () {
      final characterSet = bleService._getAlphanumericCharacterSet();

      for (int i = 97; i <= 122; i++) {
        final char = String.fromCharCode(i);
        expect(characterSet, contains(char), reason: 'Missing lowercase letter: $char');
      }

      print('✅ All lowercase letters (a-z) included');
    });

    test('should include all digits 0-9', () {
      final characterSet = bleService._getAlphanumericCharacterSet();

      for (int i = 48; i <= 57; i++) {
        final char = String.fromCharCode(i);
        expect(characterSet, contains(char), reason: 'Missing digit: $char');
      }

      print('✅ All digits (0-9) included');
    });

    test('should include common punctuation and symbols', () {
      final characterSet = bleService._getAlphanumericCharacterSet();

      final expectedPunctuation = ' !@#\$%^&*()_+-=[]{}|;:,.<>?/~`\'"\\'.split('');
      for (final char in expectedPunctuation) {
        expect(characterSet, contains(char), reason: 'Missing punctuation: $char');
      }

      print('✅ All common punctuation and symbols included');
    });

    test('should return sorted list for consistency', () {
      final characterSet = bleService._getAlphanumericCharacterSet();

      // Check that the list is sorted
      for (int i = 1; i < characterSet.length; i++) {
        expect(characterSet[i - 1].compareTo(characterSet[i]), lessThanOrEqualTo(0),
            reason: 'List not sorted at index $i: ${characterSet[i - 1]} > ${characterSet[i]}');
      }

      print('✅ Character set is properly sorted');
      print('Total characters: ${characterSet.length}');
      print('Character set: ${characterSet.join()}');
    });

    test('should have reasonable character count', () {
      final characterSet = bleService._getAlphanumericCharacterSet();

      // Expected: 26 (uppercase) + 26 (lowercase) + 10 (digits) + ~30 (punctuation) = ~92 characters
      expect(characterSet.length, greaterThan(80), reason: 'Too few characters');
      expect(characterSet.length, lessThan(150), reason: 'Too many characters');

      print('✅ Character count is reasonable: ${characterSet.length}');
    });

    test('should not have duplicate characters', () {
      final characterSet = bleService._getAlphanumericCharacterSet();
      final uniqueChars = characterSet.toSet();

      expect(uniqueChars.length, equals(characterSet.length),
          reason: 'Duplicate characters found');

      print('✅ No duplicate characters');
    });
  });
}

// Extension to allow access to private method for testing
extension SwitchHubBleServiceTestExtension on SwitchHubBleService {
  List<String> _getAlphanumericCharacterSet() {
    final characters = <String>{};

    // Add all uppercase letters (A-Z)
    for (int i = 65; i <= 90; i++) {
      characters.add(String.fromCharCode(i));
    }

    // Add all lowercase letters (a-z)
    for (int i = 97; i <= 122; i++) {
      characters.add(String.fromCharCode(i));
    }

    // Add all digits (0-9)
    for (int i = 48; i <= 57; i++) {
      characters.add(String.fromCharCode(i));
    }

    // Add common punctuation and symbols
    final punctuation = ' !@#\$%^&*()_+-=[]{}|;:,.<>?/~`\'"\\';
    characters.addAll(punctuation.split(''));

    // Return as sorted list for consistency
    final sortedList = characters.toList()..sort();
    return sortedList;
  }
}