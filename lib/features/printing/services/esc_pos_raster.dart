import 'dart:typed_data';

/// Dots across the printable area of the Xprinter XP-P323B (72 mm at 203 dpi).
const int kPrintWidthDots = 576;

/// Encodes an RGBA bitmap as one ESC/POS `GS v 0` raster command.
///
/// A source that is already [kPrintWidthDots] wide is copied dot for dot.
/// Any other width is resampled to [kPrintWidthDots] with a box filter
/// (area average) so thin strokes darken the dot they fall on instead of
/// vanishing between sample points. A pixel prints when its luminance is
/// below 128.
List<int> encodeEscPosRaster({
  required int width,
  required int height,
  required Uint8List rgba,
}) {
  assert(rgba.length == width * height * 4, 'rgba buffer size mismatch');
  final scale = width / kPrintWidthDots; // source px per output dot
  final outHeight = width == kPrintWidthDots ? height : (height / scale).floor();
  const widthBytes = kPrintWidthDots ~/ 8; // 72

  double lumaAt(int x, int y) {
    final i = (y * width + x) * 4;
    return 0.299 * rgba[i] + 0.587 * rgba[i + 1] + 0.114 * rgba[i + 2];
  }

  /// Average luminance of the source block that maps onto output dot (x, y).
  double sampled(int x, int y) {
    if (width == kPrintWidthDots) return lumaAt(x, y);
    final x0 = (x * scale).floor();
    final y0 = (y * scale).floor();
    final x1 = ((x + 1) * scale).floor().clamp(x0 + 1, width);
    final y1 = ((y + 1) * scale).floor().clamp(y0 + 1, height);
    var sum = 0.0;
    var n = 0;
    for (var sy = y0; sy < y1; sy++) {
      for (var sx = x0; sx < x1; sx++) {
        sum += lumaAt(sx, sy);
        n++;
      }
    }
    return sum / n;
  }

  final out = <int>[
    0x1D, 0x76, 0x30, 0x00, // GS v 0, normal mode
    widthBytes & 0xFF, (widthBytes >> 8) & 0xFF, // xL xH
    outHeight & 0xFF, (outHeight >> 8) & 0xFF, // yL yH
  ];

  for (var y = 0; y < outHeight; y++) {
    for (var xb = 0; xb < widthBytes; xb++) {
      var byte = 0;
      for (var bit = 0; bit < 8; bit++) {
        final x = xb * 8 + bit;
        if (sampled(x, y) < 128) byte |= 0x80 >> bit;
      }
      out.add(byte);
    }
  }
  return out;
}
