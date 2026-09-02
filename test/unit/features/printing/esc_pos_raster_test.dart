import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tawzii/features/printing/services/esc_pos_raster.dart';

/// Builds an RGBA buffer where [isBlack] decides each pixel.
Uint8List _rgba(int w, int h, bool Function(int x, int y) isBlack) {
  final out = Uint8List(w * h * 4);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final v = isBlack(x, y) ? 0 : 255;
      final i = (y * w + x) * 4;
      out[i] = v;
      out[i + 1] = v;
      out[i + 2] = v;
      out[i + 3] = 255;
    }
  }
  return out;
}

void main() {
  group('encodeEscPosRaster', () {
    test('emits GS v 0 header with 72 bytes per row and the image height', () {
      final bytes = encodeEscPosRaster(
        width: 576,
        height: 300,
        rgba: _rgba(576, 300, (_, _) => false),
      );
      expect(bytes.sublist(0, 4), [0x1D, 0x76, 0x30, 0x00]);
      expect(bytes.sublist(4, 6), [72, 0]); // xL xH: 576 / 8
      expect(bytes.sublist(6, 8), [0x2C, 0x01]); // yL yH: 300
      expect(bytes.length, 8 + 72 * 300);
    });

    test('a 576-wide source is copied dot for dot', () {
      // Left 8 dots black, everything else white, 3 rows.
      final bytes = encodeEscPosRaster(
        width: 576,
        height: 3,
        rgba: _rgba(576, 3, (x, _) => x < 8),
      );
      final rows = bytes.sublist(8);
      for (var r = 0; r < 3; r++) {
        final row = rows.sublist(r * 72, (r + 1) * 72);
        expect(row.first, 0xFF, reason: 'row $r first byte');
        expect(row.skip(1).every((b) => b == 0), isTrue, reason: 'row $r rest');
      }
    });

    test('an oversize source is box-filtered, not point-sampled', () {
      // 1152 wide (2×). Alternate black/white columns: point sampling would
      // keep either all black or all white; averaging lands on grey 127.5,
      // which is < 128 and therefore prints black on every dot.
      final bytes = encodeEscPosRaster(
        width: 1152,
        height: 2,
        rgba: _rgba(1152, 2, (x, _) => x.isEven),
      );
      final row = bytes.sublist(8, 8 + 72);
      expect(row.every((b) => b == 0xFF), isTrue);
    });

    test('dark grey prints, light grey does not', () {
      final rgba = Uint8List(576 * 1 * 4);
      for (var x = 0; x < 576; x++) {
        final v = x < 288 ? 100 : 200; // < 128 prints, >= 128 does not
        rgba[x * 4] = v;
        rgba[x * 4 + 1] = v;
        rgba[x * 4 + 2] = v;
        rgba[x * 4 + 3] = 255;
      }
      final row = encodeEscPosRaster(width: 576, height: 1, rgba: rgba)
          .sublist(8, 8 + 72);
      expect(row.take(36).every((b) => b == 0xFF), isTrue);
      expect(row.skip(36).every((b) => b == 0x00), isTrue);
    });

    test('height is clamped to what the source can supply after resample', () {
      // 288 wide → scale 2.0 → 4 rows become 8 dots tall.
      final bytes = encodeEscPosRaster(
        width: 288,
        height: 4,
        rgba: _rgba(288, 4, (_, _) => false),
      );
      expect(bytes.sublist(6, 8), [8, 0]);
      expect(bytes.length, 8 + 72 * 8);
    });
  });
}
