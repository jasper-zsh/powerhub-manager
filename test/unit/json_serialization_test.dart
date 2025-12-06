import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/models/orchestration/toggle_scene.dart';

void main() {
  group('Dynamic Action JSON Serialization Tests', () {
    test('strobe mode action serializes to JSON correctly', () {
      final strobeAction = CommandAction(
        controllerId: 'test-controller-1',
        type: CommandActionType.strobeMode,
        channel: 3,
        count: 5,
        totalTime: 2000,
        pauseTime: 300,
      );

      final json = strobeAction.toJson();

      // Verify all strobe mode parameters are included in JSON
      expect(json['controllerId'], equals('test-controller-1'));
      expect(json['type'], equals('strobeMode'));
      expect(json['channel'], equals(3));
      expect(json['count'], equals(5));
      expect(json['totalTime'], equals(2000));
      expect(json['pauseTime'], equals(300));

      // Verify irrelevant parameters are null (not included in serialized JSON typically)
      expect(json['value'], isNull);
      expect(json['duration'], isNull);
      expect(json['period'], isNull);
      expect(json['presetId'], isNull);
    });

    test('gradient mode action serializes to JSON correctly', () {
      final gradientAction = CommandAction(
        controllerId: 'test-controller-2',
        type: CommandActionType.gradientMode,
        channel: 2,
        value: 200,
        duration: 1500,
      );

      final json = gradientAction.toJson();

      expect(json['controllerId'], equals('test-controller-2'));
      expect(json['type'], equals('gradientMode'));
      expect(json['channel'], equals(2));
      expect(json['value'], equals(200));
      expect(json['duration'], equals(1500));

      // Verify irrelevant parameters are null
      expect(json['count'], isNull);
      expect(json['totalTime'], isNull);
      expect(json['pauseTime'], isNull);
      expect(json['period'], isNull);
      expect(json['presetId'], isNull);
    });

    test('blink mode action serializes to JSON correctly', () {
      final blinkAction = CommandAction(
        controllerId: 'test-controller-3',
        type: CommandActionType.blinkMode,
        channel: 1,
        period: 1000,
      );

      final json = blinkAction.toJson();

      expect(json['controllerId'], equals('test-controller-3'));
      expect(json['type'], equals('blinkMode'));
      expect(json['channel'], equals(1));
      expect(json['period'], equals(1000));

      // Verify irrelevant parameters are null
      expect(json['value'], isNull);
      expect(json['duration'], isNull);
      expect(json['count'], isNull);
      expect(json['totalTime'], isNull);
      expect(json['pauseTime'], isNull);
      expect(json['presetId'], isNull);
    });

    test('regular channelValue action still works', () {
      final channelAction = CommandAction(
        controllerId: 'test-controller-4',
        type: CommandActionType.channelValue,
        channel: 0,
        value: 128,
      );

      final json = channelAction.toJson();

      expect(json['controllerId'], equals('test-controller-4'));
      expect(json['type'], equals('channelValue'));
      expect(json['channel'], equals(0));
      expect(json['value'], equals(128));

      // Verify dynamic parameters are null
      expect(json['duration'], isNull);
      expect(json['period'], isNull);
      expect(json['count'], isNull);
      expect(json['totalTime'], isNull);
      expect(json['pauseTime'], isNull);
      expect(json['presetId'], isNull);
    });

    test('complete orchestration with strobe mode serializes correctly', () {
      final strobeAction = CommandAction(
        controllerId: 'controller-1',
        type: CommandActionType.strobeMode,
        channel: 3,
        count: 5,
        totalTime: 2000,
        pauseTime: 300,
      );

      final bundle = CommandBundle(
        id: 'bundle-1',
        label: 'Strobe Test Bundle',
        actions: [strobeAction],
      );

      final state = ToggleState(
        toggleId: 'toggle-1',
        stateId: 'on',
        label: 'On State',
        commandBundles: [bundle],
      );

      final scene = ToggleScene(
        id: 'scene-1',
        name: 'Test Scene with Strobe',
        states: [state],
      );

      final json = scene.toJson();
      final jsonStr = jsonEncode(json);

      // Verify the JSON contains our strobe mode data
      expect(jsonStr, contains('strobeMode'));
      expect(jsonStr, contains('count'));
      expect(jsonStr, contains('totalTime'));
      expect(jsonStr, contains('pauseTime'));
      expect(jsonStr, contains('controller-1'));
    });

    test('round trip serialization preserves strobe mode data', () {
      final originalAction = CommandAction(
        controllerId: 'test-controller-roundtrip',
        type: CommandActionType.strobeMode,
        channel: 4,
        count: 8,
        totalTime: 3500,
        pauseTime: 750,
      );

      // Serialize to JSON
      final json = originalAction.toJson();

      // Deserialize from JSON
      final deserializedAction = CommandAction.fromJson(json);

      // Verify all parameters are preserved
      expect(deserializedAction.controllerId, equals(originalAction.controllerId));
      expect(deserializedAction.type, equals(originalAction.type));
      expect(deserializedAction.channel, equals(originalAction.channel));
      expect(deserializedAction.count, equals(originalAction.count));
      expect(deserializedAction.totalTime, equals(originalAction.totalTime));
      expect(deserializedAction.pauseTime, equals(originalAction.pauseTime));
    });

    test('JSON structure matches expected export format', () {
      final strobeAction = CommandAction(
        controllerId: 'export-test',
        type: CommandActionType.strobeMode,
        channel: 2,
        count: 10,
        totalTime: 5000,
        pauseTime: 1000,
      );

      final json = strobeAction.toJson();

      // Verify JSON structure is what export/import would expect
      expect(json, isA<Map<String, dynamic>>());
      expect(json.keys, contains('controllerId'));
      expect(json.keys, contains('type'));
      expect(json.keys, contains('channel'));
      expect(json.keys, contains('count'));
      expect(json.keys, contains('totalTime'));
      expect(json.keys, contains('pauseTime'));
      expect(json.keys, contains('duration'));
      expect(json.keys, contains('period'));
      expect(json.keys, contains('value'));
      expect(json.keys, contains('presetId'));
    });
  });
}