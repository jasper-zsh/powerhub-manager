import 'package:flutter_test/flutter_test.dart';
import 'package:app/models/switch_hub/status_data_type.dart';

void main() {
  group('StatusDataType Multi-Channel Tests', () {
    test('parseChannelList parses single channel', () {
      final result = StatusDataType.parseChannelList('5');
      expect(result, equals([5]));
    });

    test('parseChannelList parses multiple channels', () {
      final result = StatusDataType.parseChannelList('0,1,2');
      expect(result, equals([0, 1, 2]));
    });

    test('parseChannelList parses mixed order channels', () {
      final result = StatusDataType.parseChannelList('3,1,4');
      expect(result, equals([3, 1, 4]));
    });

    test('parseChannelList handles whitespace', () {
      final result = StatusDataType.parseChannelList(' 1 , 2 , 3 ');
      expect(result, equals([1, 2, 3]));
    });

    test('channelCurrent validation accepts valid multi-channel', () {
      final result = StatusDataType.channelCurrent.validateParameters('0,1,2');
      expect(result, isNull);
    });

    test('channelCurrent validation rejects invalid channel in multi-channel', () {
      final result = StatusDataType.channelCurrent.validateParameters('0,16,2');
      expect(result, contains('Channel number 16 must be between 0 and 15'));
    });

    test('channelCurrent validation rejects duplicate channels', () {
      final result = StatusDataType.channelCurrent.validateParameters('0,1,0');
      expect(result, equals('Duplicate channels not allowed in sum parameters'));
    });

    test('channelCurrent validation rejects too many channels', () {
      final result = StatusDataType.channelCurrent.validateParameters('0,1,2,3,4,5,6,7,8');
      expect(result, equals('Maximum 8 channels allowed in sum parameters'));
    });

    test('channelCurrent validation maintains backward compatibility', () {
      final result = StatusDataType.channelCurrent.validateParameters('5');
      expect(result, isNull);
    });

    test('parameterDescription includes multi-channel examples', () {
      final description = StatusDataType.channelCurrent.parameterDescription;
      expect(description, contains('comma-separated'));
      expect(description, contains('max 8 channels'));
    });
  });
}