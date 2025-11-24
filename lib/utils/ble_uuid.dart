import 'package:flutter_blue_plus/flutter_blue_plus.dart';

Guid parseBleUuid(String uuid) {
  final canonical = _canonicalizeUuid(uuid);
  return Guid(canonical);
}

Guid reverseBleUuid(String uuid) {
  final expanded = _expandTo32(uuid);
  final buffer = StringBuffer();
  for (var i = expanded.length; i > 0; i -= 2) {
    buffer.write(expanded.substring(i - 2, i));
  }
  final reversed = buffer.toString();
  return Guid(_formatWithHyphens(reversed));
}

String _canonicalizeUuid(String uuid) {
  final expanded = _expandTo32(uuid);
  return _formatWithHyphens(expanded);
}

String _expandTo32(String uuid) {
  final cleaned = uuid.toLowerCase().replaceAll('-', '');
  if (cleaned.length == 4) {
    return '0000$cleaned'
        '00001000800000805f9b34fb';
  }
  if (cleaned.length == 8) {
    return '$cleaned'
        '00001000800000805f9b34fb';
  }
  if (cleaned.length == 32) {
    return cleaned;
  }
  return cleaned.padLeft(32, '0');
}

String _formatWithHyphens(String hex) {
  return '${hex.substring(0, 8)}-'
      '${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-'
      '${hex.substring(16, 20)}-'
      '${hex.substring(20, 32)}';
}
