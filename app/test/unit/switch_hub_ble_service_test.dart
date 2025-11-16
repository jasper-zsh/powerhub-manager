import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:app/services/switch_hub_ble_service.dart';

void main() {
  test('computeSwitchHubCrc32 matches known test vector', () {
    final data = Uint8List.fromList('switchhub'.codeUnits);
    final crc = computeSwitchHubCrc32(data);
    expect(crc, equals(0x901FF0F8));
  });
}
