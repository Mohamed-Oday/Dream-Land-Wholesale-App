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

const _header = [0x1D, 0x76, 0x30, 0x00];

/// Splits an encoded stream into (declaredRows, rowData) per band.
List<({int rows, List<int> data})> _bands(List<int> bytes) {
  final result = <({int rows, List<int> data})>[];
  var i = 0;
  while (i < bytes.length) {
    expect(bytes.sublist(i, i + 4), _header, reason: 'band header at $i');
    expect(bytes.sublist(i + 4, i + 6), [72, 0], reason: 'xL xH at $i');
    final rows = bytes[i + 6] | (bytes[i + 7] << 8);
    final start = i + 8;
    final end = start + rows * 72;
    result.add((rows: rows, data: bytes.sublist(start, end)));
    i = end;
  }
  return result;
}

void main() {
  group('encodeEscPosRaster', () {
    test('emits GS v 0 bands of at most bandRows with 72 bytes per row', () {
      // 300 rows, every row inked so nothing is trimmed.
      final r = encodeEscPosRaster(
        width: 576,
        height: 300,
        rgba: _rgba(576, 300, (x, _) => x == 0),
        bandRows: 128,
      );
      final bands = _bands(r.bytes);
      expect(bands.map((b) => b.rows), [128, 128, 44]);
      expect(r.rows, 300);
      expect(r.bytes.length, 3 * 8 + 72 * 300);
    });

    test('a 576-wide source is copied dot for dot', () {
      // Left 8 dots black, everything else white, 3 rows.
      final r = encodeEscPosRaster(
        width: 576,
        height: 3,
        rgba: _rgba(576, 3, (x, _) => x < 8),
      );
      final rows = _bands(r.bytes).single.data;
      for (var i = 0; i < 3; i++) {
        final row = rows.sublist(i * 72, (i + 1) * 72);
        expect(row.first, 0xFF, reason: 'row $i first byte');
        expect(row.skip(1).every((b) => b == 0), isTrue, reason: 'row $i rest');
      }
    });

    test('an oversize source is box-filtered, not point-sampled', () {
      // 1152 wide (2×). Alternate black/white columns: point sampling would
      // keep either all black or all white; averaging lands on grey 127.5,
      // which is < 128 and therefore prints black on every dot.
      final r = encodeEscPosRaster(
        width: 1152,
        height: 2,
        rgba: _rgba(1152, 2, (x, _) => x.isEven),
      );
      final row = _bands(r.bytes).single.data.sublist(0, 72);
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
      final row = _bands(
        encodeEscPosRaster(width: 576, height: 1, rgba: rgba).bytes,
      ).single.data;
      expect(row.take(36).every((b) => b == 0xFF), isTrue);
      expect(row.skip(36).every((b) => b == 0x00), isTrue);
    });

    test('resampled height follows the scale', () {
      // 288 wide → scale 0.5 → 4 rows become 8 dots tall (all inked).
      final r = encodeEscPosRaster(
        width: 288,
        height: 4,
        rgba: _rgba(288, 4, (x, _) => x == 0),
      );
      expect(r.rows, 8);
      expect(_bands(r.bytes).single.rows, 8);
    });

    test('trailing white rows are trimmed so the paper stops at the content',
        () {
      // 1000 rows tall, ink only on rows 0..39: the printed raster must end
      // at row 40 regardless of how much white the capture carried.
      final r = encodeEscPosRaster(
        width: 576,
        height: 1000,
        rgba: _rgba(576, 1000, (_, y) => y < 40),
      );
      expect(r.rows, 40);
      expect(r.millimetres, 5.0);
      expect(_bands(r.bytes).single.rows, 40);
    });

    test('white rows between content are kept; only the tail is trimmed', () {
      final r = encodeEscPosRaster(
        width: 576,
        height: 100,
        rgba: _rgba(576, 100, (_, y) => y == 0 || y == 59),
      );
      expect(r.rows, 60);
    });

    test('trimming can be disabled', () {
      final r = encodeEscPosRaster(
        width: 576,
        height: 100,
        rgba: _rgba(576, 100, (_, y) => y == 0),
        trimTrailingWhite: false,
      );
      expect(r.rows, 100);
    });

    test('an all-white image encodes to nothing', () {
      final r = encodeEscPosRaster(
        width: 576,
        height: 50,
        rgba: _rgba(576, 50, (_, _) => false),
      );
      expect(r.rows, 0);
      expect(r.bytes, isEmpty);
    });
  });
}
