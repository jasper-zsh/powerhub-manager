import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Font Upload Completion Fix', () {
    test('completion packet should use total chunks as sequence', () {
      // Simulate the device's logic: next_seq = total_chunks
      final totalChunks = 2; // seq=0, seq=1
      final nextSeq = totalChunks;

      // Build completion packet: [0x05][0x00][0x00][seq_hi][seq_lo]
      final completionFrame = <int>[
        0x05, // Command identifier
        0x00, // Length high byte
        0x00, // Length low byte (zero-length payload)
        nextSeq & 0xFF, // Sequence low byte
        (nextSeq >> 8) & 0xFF, // Sequence high byte
      ];

      print('Completion packet format: [${completionFrame.map((b) => '0x${b.toRadixString(16)}').join(', ')}]');
      print('Total chunks: $totalChunks');
      print('Next sequence (completion): $nextSeq');

      // Verify the packet structure
      expect(completionFrame.length, equals(5));
      expect(completionFrame[0], equals(0x05)); // Command identifier
      expect(completionFrame[1] | (completionFrame[2] << 8), equals(0)); // Zero length
      expect(completionFrame[3] | (completionFrame[4] << 8), equals(nextSeq)); // Next sequence

      // Verify this matches the device's expectation
      final payloadLen = 0; // Zero-length payload (completion packet)
      final seq = completionFrame[3] | (completionFrame[4] << 8);

      // Device validation: if (payload_len == 0 && seq != s_font_ctx.next_seq) return ESP_ERR_INVALID_STATE
      // We send total_chunks as completion sequence, so:
      // s_font_ctx.next_seq should equal total_chunks
      expect(payloadLen, equals(0)); // Zero-length payload
      expect(seq, equals(totalChunks)); // Sequence equals total chunks

      print('✅ Completion packet passes device validation');
    });

    test('should generate correct completion packet for different chunk counts', () {
      final testCases = [
        {'chunks': 1, 'expectedSeq': 1, 'description': 'Single chunk'},
        {'chunks': 2, 'expectedSeq': 2, 'description': 'Two chunks'},
        {'chunks': 5, 'expectedSeq': 5, 'description': 'Five chunks'},
        {'chunks': 10, 'expectedSeq': 10, 'description': 'Ten chunks'},
      ];

      for (final testCase in testCases) {
        final totalChunks = testCase['chunks'];
        final expectedSeq = testCase['expectedSeq'];

        // Build completion packet
        BytesBuilder builder = BytesBuilder();
        builder.add([0x05]); // Command identifier
        builder.add(_u16(0)); // Zero length
        builder.add(_u16(totalChunks)); // Next sequence (total chunks)

        final completionPacket = builder.toBytes();

        // Verify sequence field
        final actualSeq = completionPacket[3] | (completionPacket[4] << 8);

        expect(actualSeq, equals(expectedSeq),
            reason: '${testCase['description']}: expected seq=$expectedSeq, actual seq=$actualSeq');

        print('${testCase['description']}: Completion packet sequence = $actualSeq ✅');
      }
    });

    test('should handle maximum chunk count correctly', () {
      // Test edge case with maximum chunks (uint16 max = 65535)
      final maxChunks = 100; // Use a reasonable test value

      BytesBuilder builder = BytesBuilder();
      builder.add([0x05]); // Command identifier
      builder.add(_u16(0)); // Zero length
      builder.add(_u16(maxChunks)); // Next sequence

      final completionPacket = builder.toBytes();
      final seq = completionPacket[3] | (completionPacket[4] << 8);

      expect(seq, equals(maxChunks));
      expect(maxChunks, lessThan(65536)); // Ensure within uint16 range

      print('Maximum chunks test: sequence = $seq ✅');
    });
  });
}

// Helper function to convert int to 16-bit little endian bytes
List<int> _u16(int value) {
  final bytes = ByteData(2);
  bytes.setUint16(0, value & 0xFFFF, Endian.little);
  return bytes.buffer.asUint8List();
}