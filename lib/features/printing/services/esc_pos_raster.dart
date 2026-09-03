import 'dart:typed_data';

/// Dots across the printable area of the Xprinter XP-P323B (72 mm at 203 dpi).
const int kPrintWidthDots = 576;

/// Dots per millimetre at 203 dpi.
const double kDotsPerMm = 8;

/// Rows per `GS v 0` command. Tall receipts are sent as a sequence of
/// bands: portable printers with small input buffers handle many short
/// rasters better than one very tall one, and bands print back to back
/// with no visible seam.
const int kRasterBandRows = 128;

/// The encoded raster plus how many rows it will actually print.
class EscPosRaster {
  final List<int> bytes;

  /// Rows sent to the printer after trailing white rows were trimmed.
  final int rows;

  const EscPosRaster({required this.bytes, required this.rows});

  /// Printed length in millimetres at 203 dpi.
  double get millimetres => rows / kDotsPerMm;
}

/// Encodes an RGBA bitmap as ESC/POS `GS v 0` raster commands.
///
/// A source that is already [kPrintWidthDots] wide is copied dot for dot.
/// Any other width is resampled to [kPrintWidthDots] with a box filter
/// (area average) so thin strokes darken the dot they fall on instead of
/// vanishing between sample points. A pixel prints when its luminance is
/// below 128.
///
/// Trailing rows with no ink are dropped ([trimTrailingWhite]) so the paper
/// stops where the content stops, and the result is split into bands of
/// [bandRows] rows.
EscPosRaster encodeEscPosRaster({
  required int width,
  required int height,
  required Uint8List rgba,
  bool trimTrailingWhite = true,
  int bandRows = kRasterBandRows,
}) {
  assert(rgba.length == width * height * 4, 'rgba buffer size mismatch');
  assert(bandRows > 0, 'bandRows must be positive');
  final scale = width / kPrintWidthDots; // source px per output dot
  final fullHeight =
      width == kPrintWidthDots ? height : (height / scale).floor();
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

  // Threshold every row once; rows are 72 bytes each.
  final rowBytes = Uint8List(widthBytes * fullHeight);
  var lastInkRow = -1;
  for (var y = 0; y < fullHeight; y++) {
    var rowHasInk = false;
    for (var xb = 0; xb < widthBytes; xb++) {
      var byte = 0;
      for (var bit = 0; bit < 8; bit++) {
        if (sampled(xb * 8 + bit, y) < 128) byte |= 0x80 >> bit;
      }
      if (byte != 0) rowHasInk = true;
      rowBytes[y * widthBytes + xb] = byte;
    }
    if (rowHasInk) lastInkRow = y;
  }

  final rows = trimTrailingWhite ? lastInkRow + 1 : fullHeight;

  final out = <int>[];
  for (var start = 0; start < rows; start += bandRows) {
    final n = (rows - start).clamp(0, bandRows);
    out.addAll([
      0x1D, 0x76, 0x30, 0x00, // GS v 0, normal mode
      widthBytes & 0xFF, (widthBytes >> 8) & 0xFF, // xL xH
      n & 0xFF, (n >> 8) & 0xFF, // yL yH
    ]);
    out.addAll(rowBytes.sublist(start * widthBytes, (start + n) * widthBytes));
  }
  return EscPosRaster(bytes: out, rows: rows);
}
