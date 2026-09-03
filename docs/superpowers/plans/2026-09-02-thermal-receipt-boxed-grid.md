# Thermal Receipt (Delivery Invoice + Boxed Grid) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the on-screen-only receipt with a 576-dot thermal delivery invoice whose item table is the boxed 4-column grid (column template A), printed without resampling on the Xprinter XP-P323B.

**Architecture:** The paper becomes a standalone `ReceiptPaper` widget with a fixed 288-logical-px width that is captured at `pixelRatio: 2.0` (= 576 dots, no resample). It is built from a small set of thermal primitives that only ever use pure black and pure white. A pure-Dart `ReceiptLine` model turns an order line map into the strings each grid cell shows (packages, loose pieces, piece price), so the piece logic is unit-tested without widgets. The ESC/POS raster encoder is extracted into a pure function so its byte output is unit-tested too.

**Tech Stack:** Flutter 3.41.4 (the version CI builds with), Dart ^3.11, flutter_riverpod 2.6, supabase_flutter 2.8, `print_bluetooth_thermal`, `flutter_test` (no new dependencies).

**Spec:** `docs/superpowers/specs/2026-08-24-thermal-receipt-template-design.md` — §5.1 defines the grid.

## Global Constraints

- Printed bitmap is **576 dots wide**; the paper widget is **288 logical px** wide and captured at **pixelRatio 2.0**. 1 logical px = 2 dots everywhere; size constants are written in dots via `Dots.px(n)`.
- The only colours allowed anywhere on the paper are `ThermalInk.black` (`#000000`) and `ThermalInk.paper` (`#FFFFFF`). No greys, no theme tokens, no opacity.
- Rules are **3 dots** (outer frames, section rules, header bottom) or **2 dots** (inner grid rules, hair rules). Never 1 dot.
- Body text 22 dots. Grid: header 19 dots bold, body 21, name 23 semibold (line-height 1.25), sub-lines and unit letters 17.
- Grid column widths in dots: `الصنف` 236 / `الكمية` 84 / `السعر` 96 / `الإجمالي` 120 (sum 536 = 576 − 2×20 margins).
- Money is formatted by `Money.format` (whole dinars, figure-space grouping, no decimals) and every number is wrapped as `\u2066…\u2069`.
- Font family on the paper is `IBMPlexSansArabic` (already bundled in `pubspec.yaml`, weights 400/500/600/700).
- `order_lines.unit_price` is the **package** price. `quantity` = packages, `pieces_quantity` = loose pieces, `products.units_per_package` = pieces per package (nullable).
- Files stay under 500 lines. No new documentation files. No new dependencies.
- Text scaling is disabled inside the paper (`TextScaler.noScaling`).
- Run `flutter analyze` and `flutter test` before every commit; both must be clean.

---

### Task 0: Flutter SDK on this machine

The SDK is not installed on this PC (`flutter` is not on PATH and not in `C:\src`, `C:\flutter`, `%LOCALAPPDATA%`, `%USERPROFILE%`). Nothing below can be verified without it.

**Files:** none in the repo.

- [x] **Step 1: Install Flutter 3.41.4 (the version pinned in `.github/workflows/build-apk.yml`)**

Run in PowerShell:

```powershell
git clone --depth 1 --branch 3.41.4 https://github.com/flutter/flutter.git C:\src\flutter
[Environment]::SetEnvironmentVariable("Path", $env:Path + ";C:\src\flutter\bin", "User")
$env:Path += ";C:\src\flutter\bin"
flutter --version
```

Expected: first line `Flutter 3.41.4 • channel stable`.

- [x] **Step 2: Fetch packages and confirm the existing suite is green**

```powershell
cd "C:\Users\Admin\Desktop\Dev Projects\Whole-Sale\Dream-Land-Wholesale-App"
flutter pub get
flutter test
```

Expected: `All tests passed!` (4 existing test files under `test/unit`).

Done 2026-09-02: 59 tests passed.

- [x] **Step 3: Confirm the analyzer baseline**

```powershell
flutter analyze
```

Expected: `No issues found!`. If pre-existing issues are reported, note them; later tasks must not add to the count.

Done 2026-09-02: baseline is **6 info-level lints**, all pre-existing (`withOpacity` deprecation in `order_list_screen.dart`, `_makeItem` underscore locals in two tests, `gotrue` import in `app_user_test.dart`). Every later task's `flutter analyze` must report at most these 6.

---

### Task 1: Pure ESC/POS raster encoder

**Files:**
- Create: `lib/features/printing/services/esc_pos_raster.dart`
- Modify: `lib/features/printing/services/print_service.dart:85-175`
- Test: `test/unit/features/printing/esc_pos_raster_test.dart`

**Interfaces:**
- Produces: `List<int> encodeEscPosRaster({required int width, required int height, required Uint8List rgba})` — converts an RGBA buffer to a `GS v 0` raster command for a 576-dot printer. Source width 576 is copied 1:1; any other width is box-filter resampled to 576.
- Produces: `PrintService.printFromWidget(GlobalKey key, {double pixelRatio = 2.0})` (default changed from 3.0).

- [x] **Step 1: Write the failing tests**

```dart
// test/unit/features/printing/esc_pos_raster_test.dart
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
```

- [x] **Step 2: Run the test to verify it fails**

```powershell
flutter test test/unit/features/printing/esc_pos_raster_test.dart
```

Expected: compile error `Target of URI doesn't exist: 'package:tawzii/features/printing/services/esc_pos_raster.dart'`.

- [x] **Step 3: Write the encoder**

```dart
// lib/features/printing/services/esc_pos_raster.dart
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
```

- [x] **Step 4: Run the test to verify it passes**

```powershell
flutter test test/unit/features/printing/esc_pos_raster_test.dart
```

Expected: `All tests passed!` (5 tests).

- [x] **Step 5: Wire the encoder into `PrintService` and change the default pixel ratio**

In `lib/features/printing/services/print_service.dart`:

Add the import after the `print_bluetooth_thermal` import:

```dart
import 'package:tawzii/features/printing/services/esc_pos_raster.dart';
```

Replace the `printFromWidget` signature line:

```dart
  Future<bool> printFromWidget(GlobalKey receiptKey, {double pixelRatio = 2.0}) async {
```

Replace the whole `_pngToEscPos` method (from `/// Convert PNG bytes to ESC/POS raster bitmap commands.` to the end of the class) with:

```dart
  /// Convert PNG bytes to ESC/POS raster bitmap commands.
  ///
  /// Decodes the PNG to RGBA and hands it to [encodeEscPosRaster]. The
  /// receipt paper is 288 logical px captured at 2.0, so the decoded width
  /// should already be [kPrintWidthDots]; anything else means the paper
  /// width and the capture ratio were changed independently.
  Future<List<int>> _pngToEscPos(Uint8List pngBytes) async {
    try {
      final codec = await ui.instantiateImageCodec(pngBytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;
      assert(
        image.width == kPrintWidthDots,
        'Receipt capture is ${image.width} dots wide; expected $kPrintWidthDots. '
        'ReceiptPaper.width × pixelRatio must equal $kPrintWidthDots.',
      );
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (byteData == null) return [];
      return encodeEscPosRaster(
        width: image.width,
        height: image.height,
        rgba: byteData.buffer.asUint8List(),
      );
    } catch (e) {
      debugPrint('PNG to ESC/POS conversion failed: $e');
      return [];
    }
  }
}
```

- [x] **Step 6: Analyze and run the full suite**

```powershell
flutter analyze
flutter test
```

Expected: `No issues found!` and `All tests passed!`.

- [x] **Step 7: Commit**

```powershell
git add lib/features/printing/services/esc_pos_raster.dart lib/features/printing/services/print_service.dart test/unit/features/printing/esc_pos_raster_test.dart
git commit -m "feat(printing): pure ESC/POS raster encoder with box-filter resample, capture at 2.0"
```

---

### Task 2: `ReceiptLine` — what each grid cell says for an order line

**Files:**
- Create: `lib/features/receipts/models/receipt_line.dart`
- Test: `test/unit/features/receipts/receipt_line_test.dart`

**Interfaces:**
- Produces: `String ltr(Object v)` — wraps a value in U+2066…U+2069 (bidi-isolated LTR run).
- Produces: `enum ReceiptLineMode { packagesOnly, mixed, piecesOnly }`.
- Produces: `class ReceiptLine` with `factory ReceiptLine.fromOrderLine(Map<String, dynamic> line)` and getters `name`, `packages`, `pieces`, `unitsPerPackage`, `packagePrice`, `piecePrice`, `lineTotal`, `mode`, `perPackageLabel` (`String?`), `qtyMain`, `qtySub` (`String?`), `priceMain`, `priceSub` (`String?`), `totalText`. All `*Main/*Sub/*Text/*Label` values are already formatted and bidi-isolated.

Cell rules (spec §5.1):

| Cell | Packages only | Packages + pieces | Pieces only |
|---|---|---|---|
| qtyMain / qtySub | `6 ع` / null | `4 ع` / `+6 ق` | `10 ق` / null |
| priceMain / priceSub | `240` / null | `480` / `20/ق` | `15` / `للقطعة` |

- [x] **Step 1: Write the failing tests**

```dart
// test/unit/features/receipts/receipt_line_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:tawzii/features/receipts/models/receipt_line.dart';

Map<String, dynamic> _line({
  String name = 'بيبسي 330 مل',
  int quantity = 0,
  int? pieces,
  int? unitsPerPackage = 24,
  num unitPrice = 480,
  num? lineTotal,
}) {
  return {
    'quantity': quantity,
    'pieces_quantity': pieces,
    'unit_price': unitPrice,
    'line_total': lineTotal,
    'products': {
      'name': name,
      'units_per_package': unitsPerPackage,
    },
  };
}

void main() {
  const iso = '\u2066';
  const pdi = '\u2069';
  const fs = '\u2007'; // figure space used by Money.format

  test('ltr wraps the value in isolate marks', () {
    expect(ltr(1440), '${iso}1440$pdi');
  });

  group('mode', () {
    test('packages only', () {
      final l = ReceiptLine.fromOrderLine(_line(quantity: 6, pieces: null));
      expect(l.mode, ReceiptLineMode.packagesOnly);
    });
    test('mixed', () {
      final l = ReceiptLine.fromOrderLine(_line(quantity: 4, pieces: 6));
      expect(l.mode, ReceiptLineMode.mixed);
    });
    test('pieces only', () {
      final l = ReceiptLine.fromOrderLine(_line(quantity: 0, pieces: 10));
      expect(l.mode, ReceiptLineMode.piecesOnly);
    });
    test('zero of both still counts as packages only so the row prints', () {
      final l = ReceiptLine.fromOrderLine(_line(quantity: 0, pieces: 0));
      expect(l.mode, ReceiptLineMode.packagesOnly);
      expect(l.qtyMain, '${iso}0$pdi ع');
    });
  });

  group('prices', () {
    test('piece price is package price over units per package', () {
      final l = ReceiptLine.fromOrderLine(_line(unitPrice: 480, unitsPerPackage: 24));
      expect(l.piecePrice, 20);
    });
    test('missing units per package makes piece price equal package price', () {
      final l = ReceiptLine.fromOrderLine(_line(unitsPerPackage: null));
      expect(l.piecePrice, 480);
      expect(l.perPackageLabel, isNull);
    });
    test('line_total is used when present', () {
      final l = ReceiptLine.fromOrderLine(_line(quantity: 4, pieces: 6, lineTotal: 2040));
      expect(l.lineTotal, 2040);
    });
    test('line_total is derived when missing or zero', () {
      final l = ReceiptLine.fromOrderLine(_line(quantity: 4, pieces: 6, lineTotal: 0));
      expect(l.lineTotal, 4 * 480 + 6 * 20);
    });
  });

  group('cell text', () {
    test('packages only', () {
      final l = ReceiptLine.fromOrderLine(
          _line(name: 'مياه نقي 0.5 لتر', quantity: 6, unitsPerPackage: 12, unitPrice: 240));
      expect(l.perPackageLabel, '${iso}12$pdi ق/ع');
      expect(l.qtyMain, '${iso}6$pdi ع');
      expect(l.qtySub, isNull);
      expect(l.priceMain, '${iso}240$pdi');
      expect(l.priceSub, isNull);
      expect(l.totalText, '${iso}1${fs}440$pdi');
    });
    test('mixed', () {
      final l = ReceiptLine.fromOrderLine(_line(quantity: 4, pieces: 6));
      expect(l.qtyMain, '${iso}4$pdi ع');
      expect(l.qtySub, '+${iso}6$pdi ق');
      expect(l.priceMain, '${iso}480$pdi');
      expect(l.priceSub, '${iso}20$pdi/ق');
      expect(l.totalText, '${iso}2${fs}040$pdi');
    });
    test('pieces only', () {
      final l = ReceiptLine.fromOrderLine(
          _line(quantity: 0, pieces: 10, unitsPerPackage: 20, unitPrice: 300));
      expect(l.qtyMain, '${iso}10$pdi ق');
      expect(l.qtySub, isNull);
      expect(l.priceMain, '${iso}15$pdi');
      expect(l.priceSub, 'للقطعة');
      expect(l.totalText, '${iso}150$pdi');
    });
    test('piece price rounds to whole dinars in text', () {
      // 500 / 3 = 166.67 → "167"
      final l = ReceiptLine.fromOrderLine(
          _line(quantity: 0, pieces: 1, unitsPerPackage: 3, unitPrice: 500));
      expect(l.priceMain, '${iso}167$pdi');
    });
  });
}
```

- [x] **Step 2: Run the test to verify it fails**

```powershell
flutter test test/unit/features/receipts/receipt_line_test.dart
```

Expected: compile error, `receipt_line.dart` does not exist.

- [x] **Step 3: Write the model**

```dart
// lib/features/receipts/models/receipt_line.dart
import 'package:tawzii/core/ui/money_text.dart';

/// Wraps [v] in U+2066 (LRI) … U+2069 (PDI) so a Latin number keeps its
/// own direction inside Arabic text. Without it the `+`/`−` of a quantity
/// or discount jumps to the wrong end of the run.
String ltr(Object v) => '\u2066$v\u2069';

/// Which kinds of quantity an order line carries.
enum ReceiptLineMode { packagesOnly, mixed, piecesOnly }

/// One order line, reduced to the strings the receipt grid prints.
///
/// Input is the raw `order_lines` row joined with `products`, exactly as
/// `OrderRepository.getById` returns it. `unit_price` is the **package**
/// price; a loose piece costs `unit_price ÷ units_per_package`.
class ReceiptLine {
  final String name;
  final int packages;
  final int pieces;
  final int? unitsPerPackage;
  final double packagePrice;
  final double lineTotal;

  const ReceiptLine({
    required this.name,
    required this.packages,
    required this.pieces,
    required this.unitsPerPackage,
    required this.packagePrice,
    required this.lineTotal,
  });

  factory ReceiptLine.fromOrderLine(Map<String, dynamic> line) {
    final product = line['products'] as Map<String, dynamic>?;
    final packages = (line['quantity'] as num?)?.toInt() ?? 0;
    final pieces = (line['pieces_quantity'] as num?)?.toInt() ?? 0;
    final upp = (product?['units_per_package'] as num?)?.toInt();
    final packagePrice = ((line['unit_price'] as num?) ?? 0).toDouble();
    final storedTotal = ((line['line_total'] as num?) ?? 0).toDouble();
    final piecePrice = packagePrice / _unitsOrOne(upp);
    return ReceiptLine(
      name: (product?['name'] ?? '').toString(),
      packages: packages,
      pieces: pieces,
      unitsPerPackage: upp,
      packagePrice: packagePrice,
      lineTotal: storedTotal > 0
          ? storedTotal
          : packagePrice * packages + piecePrice * pieces,
    );
  }

  static int _unitsOrOne(int? upp) => (upp == null || upp < 1) ? 1 : upp;

  double get piecePrice => packagePrice / _unitsOrOne(unitsPerPackage);

  ReceiptLineMode get mode {
    if (pieces > 0 && packages > 0) return ReceiptLineMode.mixed;
    if (pieces > 0) return ReceiptLineMode.piecesOnly;
    return ReceiptLineMode.packagesOnly;
  }

  /// `12 ق/ع` — pieces per package, or null when the product has no size.
  String? get perPackageLabel =>
      unitsPerPackage == null ? null : '${ltr(unitsPerPackage)} ق/ع';

  String get qtyMain => switch (mode) {
        ReceiptLineMode.packagesOnly => '${ltr(packages)} ع',
        ReceiptLineMode.mixed => '${ltr(packages)} ع',
        ReceiptLineMode.piecesOnly => '${ltr(pieces)} ق',
      };

  String? get qtySub =>
      mode == ReceiptLineMode.mixed ? '+${ltr(pieces)} ق' : null;

  String get priceMain => switch (mode) {
        ReceiptLineMode.piecesOnly => ltr(Money.format(piecePrice)),
        _ => ltr(Money.format(packagePrice)),
      };

  String? get priceSub => switch (mode) {
        ReceiptLineMode.packagesOnly => null,
        ReceiptLineMode.mixed => '${ltr(Money.format(piecePrice))}/ق',
        ReceiptLineMode.piecesOnly => 'للقطعة',
      };

  String get totalText => ltr(Money.format(lineTotal));
}
```

- [x] **Step 4: Run the test to verify it passes**

```powershell
flutter test test/unit/features/receipts/receipt_line_test.dart
```

Expected: `All tests passed!` (13 tests).

- [x] **Step 5: Commit**

```powershell
git add lib/features/receipts/models/receipt_line.dart test/unit/features/receipts/receipt_line_test.dart
git commit -m "feat(receipts): ReceiptLine model — grid cell text for package, mixed and piece lines"
```

---

### Task 3: Thermal primitives

**Files:**
- Create: `lib/features/receipts/widgets/thermal.dart`
- Test: `test/widget/receipts/thermal_primitives_test.dart`

**Interfaces:**
- Produces: `abstract final class ThermalInk { static const Color black; static const Color paper; }`
- Produces: `abstract final class Dots { static double px(num dots) }` — dots → logical px (÷ 2).
- Produces: `const kThermalFont = 'IBMPlexSansArabic'`.
- Produces widgets: `ThermalRule({ThermalRuleKind kind = solid})` (solid = 3 dots, hair = 2 dots), `ThermalKv({label, value, bool bold, double sizeDots = 22, double? valueSizeDots, FontWeight? valueWeight})`, `TotalBar({label, value})`, `Stamp({label, value})`, `DueBox({label, value})`, `SignatureLine({label})`.

- [x] **Step 1: Write the failing test**

```dart
// test/widget/receipts/thermal_primitives_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tawzii/features/receipts/widgets/thermal.dart';

Widget _wrap(Widget child) => MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(body: SizedBox(width: 288, child: child)),
      ),
    );

void main() {
  test('Dots converts printer dots to logical px at 2 dots per px', () {
    expect(Dots.px(22), 11.0);
    expect(Dots.px(3), 1.5);
  });

  testWidgets('solid rule is 1.5 logical px (3 dots) of pure black',
      (tester) async {
    await tester.pumpWidget(_wrap(const ThermalRule()));
    final box = tester.widget<Container>(find.byType(Container));
    expect(box.color, ThermalInk.black);
    expect(tester.getSize(find.byType(Container)).height, 1.5);
  });

  testWidgets('hair rule is 1.0 logical px (2 dots)', (tester) async {
    await tester.pumpWidget(_wrap(const ThermalRule(kind: ThermalRuleKind.hair)));
    expect(tester.getSize(find.byType(Container)).height, 1.0);
  });

  testWidgets('TotalBar is white on black', (tester) async {
    await tester.pumpWidget(_wrap(const TotalBar(label: 'الإجمالي', value: '13 000 د.ج')));
    final bar = tester.widget<Container>(find.byType(Container).first);
    expect(bar.color, ThermalInk.black);
    for (final t in tester.widgetList<Text>(find.byType(Text))) {
      expect(t.style?.color, ThermalInk.paper, reason: t.data);
    }
  });

  testWidgets('Stamp and DueBox draw a 2.0 px (4 dot) black border',
      (tester) async {
    await tester.pumpWidget(_wrap(const Column(children: [
      Stamp(label: 'حالة الدفع', value: 'مدفوع جزئياً'),
      DueBox(label: 'المتبقي', value: '8 000'),
    ])));
    final boxes = tester.widgetList<Container>(find.byType(Container));
    final bordered = boxes.where((c) => c.decoration is BoxDecoration).toList();
    expect(bordered.length, 2);
    for (final c in bordered) {
      final b = (c.decoration! as BoxDecoration).border! as Border;
      expect(b.top.width, 2.0);
      expect(b.top.color, ThermalInk.black);
    }
  });

  testWidgets('SignatureLine shows a rule then its label', (tester) async {
    await tester.pumpWidget(_wrap(const SignatureLine(label: 'توقيع المستلم')));
    expect(find.text('توقيع المستلم'), findsOneWidget);
    expect(tester.getSize(find.byType(Container)).height, 1.5);
  });
}
```

- [x] **Step 2: Run the test to verify it fails**

```powershell
flutter test test/widget/receipts/thermal_primitives_test.dart
```

Expected: compile error, `thermal.dart` does not exist.

- [x] **Step 3: Write the primitives**

```dart
// lib/features/receipts/widgets/thermal.dart
import 'package:flutter/material.dart';

/// The only two colours that may appear on thermal paper. The ESC/POS
/// converter thresholds at luminance 128, so any grey resolves
/// unpredictably; hierarchy on paper comes from weight, size and rules.
abstract final class ThermalInk {
  static const Color black = Color(0xFF000000);
  static const Color paper = Color(0xFFFFFFFF);
}

/// Dot-denominated sizing. The paper is 288 logical px captured at
/// pixelRatio 2.0, so 1 logical px = 2 printer dots.
abstract final class Dots {
  static double px(num dots) => dots / 2;
}

const String kThermalFont = 'IBMPlexSansArabic';

enum ThermalRuleKind { solid, hair }

/// Full-width horizontal rule. Solid = 3 dots, hair = 2 dots. A 1-dot rule
/// can fall between sample rows and vanish; these never do.
class ThermalRule extends StatelessWidget {
  final ThermalRuleKind kind;
  const ThermalRule({super.key, this.kind = ThermalRuleKind.solid});

  @override
  Widget build(BuildContext context) {
    final solid = kind == ThermalRuleKind.solid;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: Dots.px(solid ? 14 : 11)),
      child: Container(height: Dots.px(solid ? 3 : 2), color: ThermalInk.black),
    );
  }
}

/// Label on the start side, value on the end side.
class ThermalKv extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  final double sizeDots;
  final double? valueSizeDots;
  final FontWeight? valueWeight;

  const ThermalKv({
    super.key,
    required this.label,
    required this.value,
    this.bold = false,
    this.sizeDots = 22,
    this.valueSizeDots,
    this.valueWeight,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: Dots.px(sizeDots),
                fontWeight: FontWeight.w500,
                color: ThermalInk.black)),
        SizedBox(width: Dots.px(14)),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.left,
            style: TextStyle(
              fontSize: Dots.px(valueSizeDots ?? sizeDots),
              fontWeight: valueWeight ?? (bold ? FontWeight.w700 : FontWeight.w600),
              color: ThermalInk.black,
            ),
          ),
        ),
      ],
    );
  }
}

/// The one inverted block a receipt may spend: white text on solid black.
class TotalBar extends StatelessWidget {
  final String label;
  final String value;
  const TotalBar({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: ThermalInk.black,
      margin: EdgeInsets.symmetric(vertical: Dots.px(14)),
      padding: EdgeInsets.symmetric(vertical: Dots.px(9), horizontal: Dots.px(14)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: Dots.px(26),
                  fontWeight: FontWeight.w700,
                  color: ThermalInk.paper)),
          Text(value,
              style: TextStyle(
                  fontSize: Dots.px(32),
                  fontWeight: FontWeight.w700,
                  color: ThermalInk.paper)),
        ],
      ),
    );
  }
}

BoxDecoration _box() => BoxDecoration(
      border: Border.all(color: ThermalInk.black, width: Dots.px(4)),
    );

/// Centred boxed status, e.g. payment state.
class Stamp extends StatelessWidget {
  final String label;
  final String value;
  const Stamp({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _box(),
      margin: EdgeInsets.symmetric(vertical: Dots.px(14)),
      padding: EdgeInsets.symmetric(vertical: Dots.px(9), horizontal: Dots.px(14)),
      child: Column(
        children: [
          Text(label,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: Dots.px(18),
                  fontWeight: FontWeight.w600,
                  color: ThermalInk.black)),
          Text(value,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: Dots.px(30),
                  fontWeight: FontWeight.w700,
                  height: 1.25,
                  color: ThermalInk.black)),
        ],
      ),
    );
  }
}

/// Boxed label/amount row for the balance still owed.
class DueBox extends StatelessWidget {
  final String label;
  final String value;
  const DueBox({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _box(),
      margin: EdgeInsets.symmetric(vertical: Dots.px(14)),
      padding: EdgeInsets.symmetric(vertical: Dots.px(10), horizontal: Dots.px(14)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: Dots.px(24),
                  fontWeight: FontWeight.w700,
                  color: ThermalInk.black)),
          Text(value,
              style: TextStyle(
                  fontSize: Dots.px(32),
                  fontWeight: FontWeight.w700,
                  color: ThermalInk.black)),
        ],
      ),
    );
  }
}

/// A 3-dot line to sign on, with its caption under it.
class SignatureLine extends StatelessWidget {
  final String label;
  const SignatureLine({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(height: Dots.px(3), color: ThermalInk.black),
        SizedBox(height: Dots.px(6)),
        Text(label,
            style: TextStyle(fontSize: Dots.px(18), color: ThermalInk.black)),
      ],
    );
  }
}
```

- [x] **Step 4: Run the test to verify it passes**

```powershell
flutter test test/widget/receipts/thermal_primitives_test.dart
```

Expected: `All tests passed!` (6 tests).

- [x] **Step 5: Commit**

```powershell
git add lib/features/receipts/widgets/thermal.dart test/widget/receipts/thermal_primitives_test.dart
git commit -m "feat(receipts): thermal primitives — ink palette, dot sizing, rules, bars, stamp, signature"
```

---

### Task 4: `ThermalGrid` — the boxed table

**Files:**
- Create: `lib/features/receipts/widgets/thermal_grid.dart`
- Test: `test/widget/receipts/thermal_grid_test.dart`

**Interfaces:**
- Consumes: `ThermalInk`, `Dots` from Task 3.
- Produces: `class ThermalCell extends StatelessWidget` with `ThermalCell({required List<InlineSpan> main, List<InlineSpan>? sub, TextAlign align = TextAlign.start, double mainSizeDots = 21, FontWeight mainWeight = FontWeight.w400})`. Convenience constructor `ThermalCell.text(String text, {String? sub, TextAlign align, double mainSizeDots, FontWeight mainWeight})`.
- Produces: `typedef GridFooterRow = ({String label, String value})`.
- Produces: `class ThermalGrid extends StatelessWidget` with `ThermalGrid({required List<double> columnDots, required List<String> headers, required List<TextAlign> aligns, required List<List<Widget>> rows, List<GridFooterRow> footer = const []})`. `columnDots` must sum to 536. The footer spans all columns but the last for its label.

Rule weights: outer frame and header bottom 3 dots; every inner rule 2 dots; footer top 3 dots. Cell padding 6 dots vertical, 5 dots horizontal.

- [x] **Step 1: Write the failing test**

```dart
// test/widget/receipts/thermal_grid_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tawzii/features/receipts/widgets/thermal.dart';
import 'package:tawzii/features/receipts/widgets/thermal_grid.dart';

Widget _wrap(Widget child) => MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: Center(child: SizedBox(width: 268, child: child)),
        ),
      ),
    );

ThermalGrid _grid({List<GridFooterRow> footer = const []}) => ThermalGrid(
      columnDots: const [236, 84, 96, 120],
      headers: const ['الصنف', 'الكمية', 'السعر', 'الإجمالي'],
      aligns: const [TextAlign.start, TextAlign.center, TextAlign.center, TextAlign.end],
      rows: [
        [
          ThermalCell.text('مياه نقي 0.5 لتر', sub: '12 ق/ع', mainSizeDots: 23, mainWeight: FontWeight.w600),
          ThermalCell.text('6 ع', align: TextAlign.center),
          ThermalCell.text('240', align: TextAlign.center),
          ThermalCell.text('1 440', align: TextAlign.end, mainWeight: FontWeight.w700),
        ],
      ],
      footer: footer,
    );

void main() {
  testWidgets('columns are fixed at the dot widths (÷2) and sum to 268',
      (tester) async {
    await tester.pumpWidget(_wrap(_grid()));
    final tables = tester.widgetList<Table>(find.byType(Table)).toList();
    expect(tables.length, 2); // header + body, no footer
    final widths = tables.first.columnWidths!;
    expect((widths[0]! as FixedColumnWidth).value, 118);
    expect((widths[1]! as FixedColumnWidth).value, 42);
    expect((widths[2]! as FixedColumnWidth).value, 48);
    expect((widths[3]! as FixedColumnWidth).value, 60);
    expect(tester.getSize(find.byType(Table).first).width, 268);
  });

  testWidgets('outer frame is 1.5 px and inner rules are 1.0 px black',
      (tester) async {
    await tester.pumpWidget(_wrap(_grid()));
    final tables = tester.widgetList<Table>(find.byType(Table)).toList();
    final header = tables[0].border!;
    expect(header.top.width, 1.5);
    expect(header.bottom.width, 1.5); // header bottom is a 3-dot rule
    expect(header.left.width, 1.5);
    expect(header.right.width, 1.5);
    expect(header.verticalInside.width, 1.0);
    final body = tables[1].border!;
    expect(body.top, BorderSide.none); // shares the header's bottom rule
    expect(body.bottom.width, 1.5);
    expect(body.horizontalInside.width, 1.0);
    expect(body.verticalInside.width, 1.0);
    for (final s in [header.top, body.bottom, body.verticalInside]) {
      expect(s.color, ThermalInk.black);
    }
  });

  testWidgets('footer rows span the first three columns and sit in the frame',
      (tester) async {
    await tester.pumpWidget(_wrap(_grid(footer: const [
      (label: 'المجموع الفرعي', value: '13 230'),
      (label: 'الخصم', value: '−230'),
    ])));
    final tables = tester.widgetList<Table>(find.byType(Table)).toList();
    expect(tables.length, 3);
    final foot = tables[2];
    expect((foot.columnWidths![0]! as FixedColumnWidth).value, 118 + 42 + 48);
    expect((foot.columnWidths![1]! as FixedColumnWidth).value, 60);
    expect(foot.border!.top.width, 1.5);
    expect(foot.border!.horizontalInside.width, 1.0);
    expect(foot.children.length, 2);
    expect(find.text('المجموع الفرعي'), findsOneWidget);
    expect(find.text('−230'), findsOneWidget);
    // Body no longer closes the frame; the footer does.
    expect(tables[1].border!.bottom, BorderSide.none);
  });

  testWidgets('every text in the grid is pure black', (tester) async {
    await tester.pumpWidget(_wrap(_grid(footer: const [(label: 'x', value: 'y')])));
    for (final t in tester.widgetList<Text>(find.byType(Text))) {
      expect(t.style?.color, ThermalInk.black, reason: t.data);
    }
    for (final r in tester.widgetList<RichText>(find.byType(RichText))) {
      expect(r.text.style?.color, ThermalInk.black);
    }
  });
}
```

- [x] **Step 2: Run the test to verify it fails**

```powershell
flutter test test/widget/receipts/thermal_grid_test.dart
```

Expected: compile error, `thermal_grid.dart` does not exist.

- [x] **Step 3: Write the grid**

```dart
// lib/features/receipts/widgets/thermal_grid.dart
import 'package:flutter/material.dart';

import 'package:tawzii/features/receipts/widgets/thermal.dart';

/// One label/amount row printed inside the grid frame under the items.
typedef GridFooterRow = ({String label, String value});

/// A grid cell: a main line of spans and an optional smaller second line.
class ThermalCell extends StatelessWidget {
  final List<InlineSpan> main;
  final List<InlineSpan>? sub;
  final TextAlign align;
  final double mainSizeDots;
  final FontWeight mainWeight;

  const ThermalCell({
    super.key,
    required this.main,
    this.sub,
    this.align = TextAlign.start,
    this.mainSizeDots = 21,
    this.mainWeight = FontWeight.w400,
  });

  ThermalCell.text(
    String text, {
    super.key,
    String? sub,
    this.align = TextAlign.start,
    this.mainSizeDots = 21,
    this.mainWeight = FontWeight.w400,
  })  : main = [TextSpan(text: text)],
        sub = sub == null ? null : [TextSpan(text: sub)];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: Dots.px(6), horizontal: Dots.px(5)),
      child: Column(
        crossAxisAlignment: switch (align) {
          TextAlign.center => CrossAxisAlignment.center,
          TextAlign.end || TextAlign.left => CrossAxisAlignment.end,
          _ => CrossAxisAlignment.start,
        },
        children: [
          RichText(
            textAlign: align,
            text: TextSpan(
              style: TextStyle(
                fontFamily: kThermalFont,
                fontSize: Dots.px(mainSizeDots),
                fontWeight: mainWeight,
                height: 1.25,
                color: ThermalInk.black,
              ),
              children: main,
            ),
          ),
          if (sub != null)
            RichText(
              textAlign: align,
              text: TextSpan(
                style: TextStyle(
                  fontFamily: kThermalFont,
                  fontSize: Dots.px(17),
                  fontWeight: FontWeight.w400,
                  height: 1.3,
                  color: ThermalInk.black,
                ),
                children: sub,
              ),
            ),
        ],
      ),
    );
  }
}

/// The boxed item table (column template A): every cell ruled.
///
/// Built as up to three stacked [Table]s that share fixed column widths so
/// their vertical rules line up: header, body, and an optional footer whose
/// label spans every column but the last. Flutter's [Table] has no colspan,
/// which is why the footer is its own table.
class ThermalGrid extends StatelessWidget {
  /// Column widths in printer dots. Must sum to 536.
  final List<double> columnDots;
  final List<String> headers;
  final List<TextAlign> aligns;
  final List<List<Widget>> rows;
  final List<GridFooterRow> footer;

  const ThermalGrid({
    super.key,
    required this.columnDots,
    required this.headers,
    required this.aligns,
    required this.rows,
    this.footer = const [],
  })  : assert(headers.length == columnDots.length),
        assert(aligns.length == columnDots.length);

  static final BorderSide _thick =
      BorderSide(color: ThermalInk.black, width: Dots.px(3));
  static final BorderSide _thin =
      BorderSide(color: ThermalInk.black, width: Dots.px(2));

  Map<int, TableColumnWidth> get _widths => {
        for (var i = 0; i < columnDots.length; i++)
          i: FixedColumnWidth(Dots.px(columnDots[i])),
      };

  @override
  Widget build(BuildContext context) {
    assert(columnDots.fold<double>(0, (a, b) => a + b) == 536,
        'grid columns must span the 536-dot content width');
    final hasFooter = footer.isNotEmpty;

    final header = Table(
      columnWidths: _widths,
      defaultVerticalAlignment: TableCellVerticalAlignment.top,
      border: TableBorder(
        top: _thick,
        left: _thick,
        right: _thick,
        bottom: _thick,
        verticalInside: _thin,
      ),
      children: [
        TableRow(children: [
          for (var i = 0; i < headers.length; i++)
            ThermalCell.text(headers[i],
                align: aligns[i], mainSizeDots: 19, mainWeight: FontWeight.w700),
        ]),
      ],
    );

    final body = Table(
      columnWidths: _widths,
      defaultVerticalAlignment: TableCellVerticalAlignment.top,
      border: TableBorder(
        left: _thick,
        right: _thick,
        bottom: hasFooter ? BorderSide.none : _thick,
        horizontalInside: _thin,
        verticalInside: _thin,
      ),
      children: [for (final r in rows) TableRow(children: r)],
    );

    final footerTable = hasFooter
        ? Table(
            columnWidths: {
              0: FixedColumnWidth(Dots.px(columnDots
                  .take(columnDots.length - 1)
                  .fold<double>(0, (a, b) => a + b))),
              1: FixedColumnWidth(Dots.px(columnDots.last)),
            },
            defaultVerticalAlignment: TableCellVerticalAlignment.top,
            border: TableBorder(
              top: _thick,
              left: _thick,
              right: _thick,
              bottom: _thick,
              horizontalInside: _thin,
              verticalInside: _thin,
            ),
            children: [
              for (final f in footer)
                TableRow(children: [
                  ThermalCell.text(f.label, mainWeight: FontWeight.w700),
                  ThermalCell.text(f.value,
                      align: aligns.last, mainWeight: FontWeight.w700),
                ]),
            ],
          )
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [header, body, if (footerTable != null) footerTable],
    );
  }
}
```

- [x] **Step 4: Run the test to verify it passes**

```powershell
flutter test test/widget/receipts/thermal_grid_test.dart
```

Expected: `All tests passed!` (4 tests).

- [x] **Step 5: Commit**

```powershell
git add lib/features/receipts/widgets/thermal_grid.dart test/widget/receipts/thermal_grid_test.dart
git commit -m "feat(receipts): ThermalGrid boxed table with fixed dot-width columns and in-frame footer"
```

---

### Task 5: `ReceiptConfig` — business phone and footer from `app_config`

**Files:**
- Create: `lib/features/receipts/models/receipt_config.dart`
- Create: `lib/features/receipts/providers/receipt_config_provider.dart`
- Test: `test/unit/features/receipts/receipt_config_test.dart`

**Interfaces:**
- Produces: `class ReceiptConfig { final String? phone; final String? footer; const ReceiptConfig({this.phone, this.footer}); static const empty = ReceiptConfig(); factory ReceiptConfig.fromRows(List<Map<String, dynamic>> rows); }` — rows are `{key, value}` maps; keys `receipt.phone` and `receipt.footer`; blank values count as unset.
- Produces: `final receiptConfigProvider = FutureProvider<ReceiptConfig>` that reads the current user's business rows from Supabase table `app_config` and returns `ReceiptConfig.empty` when signed out or on error.

- [x] **Step 1: Write the failing test**

```dart
// test/unit/features/receipts/receipt_config_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:tawzii/features/receipts/models/receipt_config.dart';

void main() {
  test('empty has no phone and no footer', () {
    expect(ReceiptConfig.empty.phone, isNull);
    expect(ReceiptConfig.empty.footer, isNull);
  });

  test('fromRows picks the two receipt keys and ignores others', () {
    final c = ReceiptConfig.fromRows([
      {'key': 'receipt.phone', 'value': '0770 12 34 56'},
      {'key': 'receipt.footer', 'value': 'شكراً لثقتكم'},
      {'key': 'something.else', 'value': 'x'},
    ]);
    expect(c.phone, '0770 12 34 56');
    expect(c.footer, 'شكراً لثقتكم');
  });

  test('blank values are treated as unset', () {
    final c = ReceiptConfig.fromRows([
      {'key': 'receipt.phone', 'value': '   '},
    ]);
    expect(c.phone, isNull);
  });

  test('values are trimmed', () {
    final c = ReceiptConfig.fromRows([
      {'key': 'receipt.footer', 'value': ' مرحباً '},
    ]);
    expect(c.footer, 'مرحباً');
  });
}
```

- [x] **Step 2: Run the test to verify it fails**

```powershell
flutter test test/unit/features/receipts/receipt_config_test.dart
```

Expected: compile error, `receipt_config.dart` does not exist.

- [x] **Step 3: Write the model and provider**

```dart
// lib/features/receipts/models/receipt_config.dart
/// Business-level lines printed on every receipt, read from `app_config`.
///
/// `stores.phone` is the customer's number, not ours — the business phone
/// lives in `app_config` under `receipt.phone`, and an optional custom
/// footer under `receipt.footer`. Both are omitted from the paper when unset.
class ReceiptConfig {
  final String? phone;
  final String? footer;

  const ReceiptConfig({this.phone, this.footer});

  static const ReceiptConfig empty = ReceiptConfig();

  static const String phoneKey = 'receipt.phone';
  static const String footerKey = 'receipt.footer';

  factory ReceiptConfig.fromRows(List<Map<String, dynamic>> rows) {
    String? pick(String key) {
      for (final r in rows) {
        if (r['key'] == key) {
          final v = (r['value'] ?? '').toString().trim();
          return v.isEmpty ? null : v;
        }
      }
      return null;
    }

    return ReceiptConfig(phone: pick(phoneKey), footer: pick(footerKey));
  }
}
```

```dart
// lib/features/receipts/providers/receipt_config_provider.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:tawzii/features/auth/providers/auth_provider.dart';
import 'package:tawzii/features/receipts/models/receipt_config.dart';

/// The business phone and footer for the current user's business.
/// Resolves to [ReceiptConfig.empty] when signed out or when the read fails,
/// so a receipt can always be printed.
final receiptConfigProvider = FutureProvider<ReceiptConfig>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return ReceiptConfig.empty;
  try {
    final rows = await Supabase.instance.client
        .from('app_config')
        .select('key, value')
        .eq('business_id', user.businessId)
        .inFilter('key', [ReceiptConfig.phoneKey, ReceiptConfig.footerKey]);
    return ReceiptConfig.fromRows(List<Map<String, dynamic>>.from(rows));
  } catch (e) {
    debugPrint('receipt config read failed: $e');
    return ReceiptConfig.empty;
  }
});
```

- [x] **Step 4: Run the test and the analyzer**

```powershell
flutter test test/unit/features/receipts/receipt_config_test.dart
flutter analyze
```

Expected: `All tests passed!` (4 tests) and `No issues found!`.

- [x] **Step 5: Commit**

```powershell
git add lib/features/receipts/models/receipt_config.dart lib/features/receipts/providers/receipt_config_provider.dart test/unit/features/receipts/receipt_config_test.dart
git commit -m "feat(receipts): ReceiptConfig from app_config (receipt.phone, receipt.footer)"
```

---

### Task 6: `ReceiptPaper` — the order document

**Files:**
- Create: `lib/features/receipts/widgets/receipt_paper.dart`
- Test: `test/widget/receipts/receipt_palette_test.dart`
- Test: `test/widget/receipts/receipt_capture_test.dart`
- Test fixture: `test/widget/receipts/fixtures.dart`

**Note on finders:** grid cells are `RichText` widgets, so any `find.text` / `find.textContaining` aimed at a cell must pass `findRichText: true` (verified in Task 4).

**Interfaces:**
- Consumes: everything from Tasks 2–5; `AppLocalizations` (`lib/core/l10n/app_localizations.dart`); `Money.format`.
- Produces: `enum ReceiptDocType { order, load, returns }` (moved here from the screen; Task 8 re-exports it).
- Produces: `class ReceiptPaper extends StatelessWidget` with `static const double width = 288;` and constructor `ReceiptPaper({required ReceiptDocType docType, required AppLocalizations l10n, ReceiptConfig config = ReceiptConfig.empty, Map<String, dynamic>? order, Map<String, dynamic>? loadData, Map<String, dynamic>? returnData, int? packageBalance})`.
- In this task only the **order** body is implemented; `load` and `returns` bodies are added in Task 7 and return an empty column until then.

Order body, top to bottom (spec §5): company name 34 dots bold centred; phone line 19 dots (if set); solid rule; `فاتورة تسليم` 24 dots; order reference `#` + first 8 chars of the id, upper-cased, 28 dots bold; hair rule; `ملغى` 30 dots bold centred when cancelled; metadata rows at 19 dots: date, store (23 bold), address, driver; the grid; total bar; payment stamp; paid + boxed due when partial; hair rule + package balance; two signature lines; solid rule; footer.

- [x] **Step 1: Write the shared fixture**

```dart
// test/widget/receipts/fixtures.dart
import 'package:flutter/material.dart';
import 'package:tawzii/core/l10n/app_localizations_ar.dart';
import 'package:tawzii/features/receipts/models/receipt_config.dart';
import 'package:tawzii/features/receipts/widgets/receipt_paper.dart';

final l10nAr = AppLocalizationsAr();

Map<String, dynamic> _line(String name, int upp, int qty, int? pieces, num price, num total) => {
      'quantity': qty,
      'pieces_quantity': pieces,
      'unit_price': price,
      'line_total': total,
      'products': {'name': name, 'units_per_package': upp},
    };

/// The four-line sample order from the column proof: packages only,
/// mixed, pieces only, packages only. Subtotal 13 230, discount 230,
/// total 13 000, partially paid 5 000.
Map<String, dynamic> sampleOrder({String status = 'delivered'}) => {
      'id': '3f9a2c1b-7e5d-4a10-9b2f-000000000000',
      'status': status,
      'created_at': '2026-09-02T11:05:00Z',
      'subtotal': 13230,
      'tax_amount': 0,
      'discount': 230,
      'discount_status': 'approved',
      'total': 13000,
      'payment_status': 'partial',
      'paid_amount': 5000,
      'stores': {'name': 'متجر النخيل', 'address': 'شارع العربي بن مهيدي'},
      'users': {'name': 'كريم بوعلام'},
      'order_lines': [
        _line('مياه نقي 0.5 لتر', 12, 6, null, 240, 1440),
        _line('بيبسي 330 مل', 24, 4, 6, 480, 2040),
        _line('شيبس تشيبسي وسط', 20, 0, 10, 300, 150),
        _line('زيت إليو 5 لتر', 4, 3, null, 3200, 9600),
      ],
    };

Map<String, dynamic> sampleLoad() => {
      'driver_name': 'كريم بوعلام',
      'loaded_by_name': 'أحمد',
      'opened_at': '2026-09-02T07:30:00Z',
      'items': [
        {'product_name': 'مياه نقي 0.5 لتر', 'quantity_loaded': 40},
        {'product_name': 'بيبسي 330 مل', 'quantity_loaded': 24},
      ],
    };

Map<String, dynamic> sampleReturn() => {
      'driver_name': 'كريم بوعلام',
      'closed_at': '2026-09-02T18:10:00Z',
      'items': [
        {'product_name': 'مياه نقي 0.5 لتر', 'quantity_loaded': 40, 'quantity_sold': 33, 'quantity_returned': 7},
        {'product_name': 'بيبسي 330 مل', 'quantity_loaded': 24, 'quantity_sold': 24, 'quantity_returned': 0},
      ],
    };

const sampleConfig = ReceiptConfig(phone: '0770 12 34 56', footer: null);

/// Pumps [paper] at natural size on a tall test surface so the whole
/// receipt lays out (the default 800×600 surface would clip it).
Widget host(Widget paper) => MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: Align(alignment: Alignment.topCenter, child: paper),
        ),
      ),
    );

ReceiptPaper orderPaper({Map<String, dynamic>? order, int? packageBalance = 21}) =>
    ReceiptPaper(
      docType: ReceiptDocType.order,
      l10n: l10nAr,
      config: sampleConfig,
      order: order ?? sampleOrder(),
      packageBalance: packageBalance,
    );
```

- [x] **Step 2: Write the failing palette test**

```dart
// test/widget/receipts/receipt_palette_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tawzii/features/receipts/widgets/receipt_paper.dart';
import 'package:tawzii/features/receipts/widgets/thermal.dart';

import 'fixtures.dart';

const _allowed = {ThermalInk.black, ThermalInk.paper};

void _expectInk(Color? c, String where) {
  if (c == null) return;
  expect(_allowed.contains(c), isTrue,
      reason: '$where uses $c — only ThermalInk.black / paper may print');
}

void _checkSpan(InlineSpan span, String where) {
  _expectInk(span.style?.color, where);
  if (span is TextSpan) {
    for (final child in span.children ?? const <InlineSpan>[]) {
      _checkSpan(child, where);
    }
  }
}

void _checkBorder(BoxBorder? b, String where) {
  if (b is Border) {
    for (final s in [b.top, b.bottom, b.left, b.right]) {
      if (s != BorderSide.none) _expectInk(s.color, where);
    }
  }
}

/// Walks every widget under the paper and asserts each declared colour.
Future<void> expectOnlyInk(WidgetTester tester) async {
  final inPaper = find.descendant(
    of: find.byType(ReceiptPaper),
    matching: find.byWidgetPredicate((_) => true),
  );
  expect(find.descendant(of: find.byType(ReceiptPaper), matching: find.byType(CustomPaint)),
      findsNothing, reason: 'no CustomPaint on the paper — painters hide colours');
  var checked = 0;
  for (final w in tester.widgetList(inPaper)) {
    checked++;
    switch (w) {
      case Text():
        _expectInk(w.style?.color, 'Text "${w.data}"');
      case RichText():
        _checkSpan(w.text, 'RichText');
      case DefaultTextStyle():
        _expectInk(w.style.color, 'DefaultTextStyle');
      case Container():
        _expectInk(w.color, 'Container');
        if (w.decoration case BoxDecoration d) {
          _expectInk(d.color, 'Container.decoration');
          _checkBorder(d.border, 'Container.border');
        }
      case DecoratedBox():
        if (w.decoration case BoxDecoration d) {
          _expectInk(d.color, 'DecoratedBox');
          _checkBorder(d.border, 'DecoratedBox.border');
        }
      case Table():
        final b = w.border;
        if (b != null) {
          for (final s in [b.top, b.bottom, b.left, b.right, b.horizontalInside, b.verticalInside]) {
            if (s != BorderSide.none) _expectInk(s.color, 'Table border');
          }
        }
      case ColoredBox():
        _expectInk(w.color, 'ColoredBox');
      default:
        break;
    }
  }
  expect(checked, greaterThan(20), reason: 'the walk should visit the paper');
}

void main() {
  setUp(() {
    // Tall surface so the full receipt lays out.
  });

  testWidgets('order paper declares only black and white', (tester) async {
    tester.view.physicalSize = const Size(600, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(host(orderPaper()));
    await expectOnlyInk(tester);
  });

  testWidgets('order paper is exactly 288 logical px wide', (tester) async {
    tester.view.physicalSize = const Size(600, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(host(orderPaper()));
    expect(tester.getSize(find.byType(ReceiptPaper)).width, 288);
  });

  testWidgets('order paper shows the grid, stamp, due box and signatures',
      (tester) async {
    tester.view.physicalSize = const Size(600, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(host(orderPaper()));
    expect(find.text('فاتورة تسليم'), findsOneWidget);
    expect(find.text('#3F9A2C1B'), findsOneWidget);
    expect(find.text('مدفوع جزئياً'), findsOneWidget);
    expect(find.text('المتبقي'), findsOneWidget);
    expect(find.text('توقيع المستلم'), findsOneWidget);
    expect(find.text('توقيع السائق'), findsOneWidget);
    expect(find.textContaining('0770 12 34 56'), findsNWidgets(2)); // header + footer
    expect(find.textContaining('للقطعة', findRichText: true), findsOneWidget);
    expect(find.textContaining('+\u20666\u2069 ق', findRichText: true), findsOneWidget);
  });

  testWidgets('cancelled order shows ملغى and no payment block', (tester) async {
    tester.view.physicalSize = const Size(600, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(host(orderPaper(order: sampleOrder(status: 'cancelled'))));
    expect(find.text(l10nAr.statusCancelled), findsOneWidget);
    expect(find.text('حالة الدفع'), findsNothing);
    expect(find.text('المتبقي'), findsNothing);
  });

  testWidgets('text scaling is disabled inside the paper', (tester) async {
    tester.view.physicalSize = const Size(600, 4000);
    tester.view.devicePixelRatio = 1.0;
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(host(orderPaper()));
    final mq = tester.widget<MediaQuery>(find.descendant(
        of: find.byType(ReceiptPaper), matching: find.byType(MediaQuery)).first);
    expect(mq.data.textScaler, TextScaler.noScaling);
  });
}
```

- [x] **Step 3: Write the failing capture test**

```dart
// test/widget/receipts/receipt_capture_test.dart
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tawzii/features/printing/services/print_service.dart';
import 'package:tawzii/features/receipts/widgets/receipt_paper.dart';
import 'package:tawzii/features/receipts/widgets/thermal.dart';

import 'fixtures.dart';

void main() {
  testWidgets('capturing the paper at 2.0 yields exactly 576 dots and prints its rules',
      (tester) async {
    tester.view.physicalSize = const Size(600, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final key = GlobalKey();
    await tester.pumpWidget(host(RepaintBoundary(key: key, child: orderPaper())));

    Uint8List? png;
    ui.Image? image;
    await tester.runAsync(() async {
      png = await PrintService.captureWidget(key, pixelRatio: 2.0);
      expect(png, isNotNull);
      final codec = await ui.instantiateImageCodec(png!);
      image = (await codec.getNextFrame()).image;
    });
    expect(image!.width, 576);

    // The first solid rule must contain black after the 128 threshold.
    final paperRect = tester.getRect(find.byType(ReceiptPaper));
    final ruleRect = tester.getRect(find.descendant(
        of: find.byType(ThermalRule).first, matching: find.byType(Container)));
    final y = ((ruleRect.center.dy - paperRect.top) * 2).floor();
    final x = 288; // middle of the 576-dot row
    ByteData? rgba;
    await tester.runAsync(() async {
      rgba = await image!.toByteData(format: ui.ImageByteFormat.rawRgba);
    });
    final i = (y * image!.width + x) * 4;
    final gray = 0.299 * rgba!.getUint8(i) +
        0.587 * rgba!.getUint8(i + 1) +
        0.114 * rgba!.getUint8(i + 2);
    expect(gray, lessThan(128), reason: 'rule row $y must print');
  });
}
```

- [x] **Step 4: Run both tests to verify they fail**

```powershell
flutter test test/widget/receipts/receipt_palette_test.dart test/widget/receipts/receipt_capture_test.dart
```

Expected: compile error, `receipt_paper.dart` does not exist.

- [x] **Step 5: Write `ReceiptPaper` with the order body**

```dart
// lib/features/receipts/widgets/receipt_paper.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:tawzii/core/l10n/app_localizations.dart';
import 'package:tawzii/core/ui/money_text.dart';
import 'package:tawzii/features/receipts/models/receipt_config.dart';
import 'package:tawzii/features/receipts/models/receipt_line.dart';
import 'package:tawzii/features/receipts/widgets/thermal.dart';
import 'package:tawzii/features/receipts/widgets/thermal_grid.dart';

/// The three document types the receipt paper can render.
enum ReceiptDocType { order, load, returns }

/// The thermal paper. Fixed at 288 logical px so a capture at pixelRatio 2.0
/// is exactly 576 dots — the printer's width — with no resampling.
///
/// Every colour on it is [ThermalInk.black] or [ThermalInk.paper]; see
/// `test/widget/receipts/receipt_palette_test.dart`.
class ReceiptPaper extends StatelessWidget {
  static const double width = 288;

  final ReceiptDocType docType;
  final AppLocalizations l10n;
  final ReceiptConfig config;
  final Map<String, dynamic>? order;
  final Map<String, dynamic>? loadData;
  final Map<String, dynamic>? returnData;
  final int? packageBalance;

  const ReceiptPaper({
    super.key,
    required this.docType,
    required this.l10n,
    this.config = ReceiptConfig.empty,
    this.order,
    this.loadData,
    this.returnData,
    this.packageBalance,
  });

  static String _fmtDate(String? iso) {
    if (iso == null) return '';
    try {
      return DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(iso).toLocal());
    } catch (_) {
      return iso;
    }
  }

  static String _amt(num v) => ltr(Money.format(v));

  @override
  Widget build(BuildContext context) {
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
      child: Container(
        width: width,
        color: ThermalInk.paper,
        padding: EdgeInsets.fromLTRB(
            Dots.px(20), Dots.px(26), Dots.px(20), Dots.px(30)),
        child: DefaultTextStyle(
          style: TextStyle(
            fontFamily: kThermalFont,
            fontSize: Dots.px(22),
            height: 1.5,
            color: ThermalInk.black,
            fontFeatures: const [
              FontFeature.tabularFigures(),
              FontFeature.liningFigures(),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: switch (docType) {
              ReceiptDocType.order => _orderBody(),
              ReceiptDocType.load => _loadBody(),
              ReceiptDocType.returns => _returnBody(),
            },
          ),
        ),
      ),
    );
  }

  // --- shared pieces ---

  List<Widget> _masthead(String docTitle, {String? reference}) {
    return [
      Text(
        l10n.appTitle,
        textAlign: TextAlign.center,
        style: TextStyle(
            fontSize: Dots.px(34), fontWeight: FontWeight.w700, height: 1.2),
      ),
      if (config.phone != null)
        Text(
          'توزيع الجملة — ${ltr(config.phone!)}',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: Dots.px(19)),
        ),
      const ThermalRule(),
      Text(
        docTitle,
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: Dots.px(24), fontWeight: FontWeight.w600),
      ),
      if (reference != null)
        Text(
          reference,
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: Dots.px(28), fontWeight: FontWeight.w700, height: 1.2),
        ),
      const ThermalRule(kind: ThermalRuleKind.hair),
    ];
  }

  List<Widget> _footer() {
    final lines = <String>[
      config.footer ?? 'شكراً لثقتكم',
      if (config.phone != null) 'للاستفسار: ${ltr(config.phone!)}',
    ];
    return [
      const ThermalRule(),
      Text(
        lines.join('\n'),
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: Dots.px(19), height: 1.45),
      ),
    ];
  }

  Widget _meta(String label, String value,
          {double valueSizeDots = 19, FontWeight valueWeight = FontWeight.w600}) =>
      ThermalKv(
        label: label,
        value: value,
        sizeDots: 19,
        valueSizeDots: valueSizeDots,
        valueWeight: valueWeight,
      );

  static TextSpan _unit(String letter) => TextSpan(
        text: ' $letter',
        style: TextStyle(fontSize: Dots.px(17), fontWeight: FontWeight.w500),
      );

  /// `6 ع` / `+6 ق` / `10 ق` — number at cell size, unit letter at 17 dots.
  static List<InlineSpan> _qtySpans(String s) {
    final space = s.lastIndexOf(' ');
    return [
      TextSpan(text: s.substring(0, space)),
      _unit(s.substring(space + 1)),
    ];
  }

  // --- order receipt ---

  static String _orderRef(Map<String, dynamic> o) {
    final id = (o['id'] ?? '').toString();
    return '#${ltr(id.substring(0, id.length < 8 ? id.length : 8).toUpperCase())}';
  }

  List<Widget> _orderBody() {
    final o = order!;
    final store = o['stores'] as Map<String, dynamic>?;
    final driver = o['users'] as Map<String, dynamic>?;
    final storeName = (store?['name'] ?? '').toString();
    final storeAddress = (store?['address'] ?? '').toString();
    final driverName = (driver?['name'] ?? '').toString();
    final status = o['status'] as String? ?? 'created';
    final subtotal = ((o['subtotal'] as num?) ?? 0).toDouble();
    final taxAmount = ((o['tax_amount'] as num?) ?? 0).toDouble();
    final discount = ((o['discount'] as num?) ?? 0).toDouble();
    final discountStatus = o['discount_status'] as String? ?? 'none';
    final total = ((o['total'] as num?) ?? 0).toDouble();
    final paymentStatus = o['payment_status'] as String? ?? 'unpaid';
    final paidAmount = ((o['paid_amount'] as num?) ?? 0).toDouble();
    final date = _fmtDate(o['created_at'] as String?);
    final lines = (o['order_lines'] as List<dynamic>? ?? [])
        .map((l) => ReceiptLine.fromOrderLine(l as Map<String, dynamic>))
        .toList();
    final showDiscount = discount > 0 &&
        (discountStatus == 'approved' || discountStatus == 'pending');
    final cancelled = status == 'cancelled';

    return [
      ..._masthead('فاتورة تسليم', reference: _orderRef(o)),
      if (cancelled)
        Padding(
          padding: EdgeInsets.only(bottom: Dots.px(8)),
          child: Text(
            l10n.statusCancelled,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: Dots.px(30), fontWeight: FontWeight.w700),
          ),
        ),
      if (date.isNotEmpty) _meta(l10n.orderDate, ltr(date)),
      if (storeName.isNotEmpty)
        _meta('المتجر', storeName,
            valueSizeDots: 23, valueWeight: FontWeight.w700),
      if (storeAddress.isNotEmpty)
        _meta(l10n.address, storeAddress, valueWeight: FontWeight.w500),
      if (driverName.isNotEmpty) _meta(l10n.driver, driverName),
      SizedBox(height: Dots.px(14)),
      ThermalGrid(
        columnDots: const [236, 84, 96, 120],
        headers: const ['الصنف', 'الكمية', 'السعر', 'الإجمالي'],
        aligns: const [
          TextAlign.start,
          TextAlign.center,
          TextAlign.center,
          TextAlign.end,
        ],
        rows: [
          for (final line in lines)
            [
              ThermalCell.text(line.name,
                  sub: line.perPackageLabel,
                  mainSizeDots: 23,
                  mainWeight: FontWeight.w600),
              ThermalCell(
                main: _qtySpans(line.qtyMain),
                sub: line.qtySub == null ? null : _qtySpans(line.qtySub!),
                align: TextAlign.center,
              ),
              ThermalCell.text(line.priceMain,
                  sub: line.priceSub, align: TextAlign.center),
              ThermalCell.text(line.totalText,
                  align: TextAlign.end, mainWeight: FontWeight.w700),
            ],
        ],
        footer: [
          (label: l10n.subtotal, value: _amt(subtotal)),
          if (taxAmount > 0) (label: l10n.tax, value: _amt(taxAmount)),
          if (showDiscount) (label: l10n.discount, value: '−${_amt(discount)}'),
        ],
      ),
      TotalBar(label: 'الإجمالي', value: '${_amt(total)} ${l10n.currencyUnit}'),
      if (!cancelled) ...[
        Stamp(
          label: 'حالة الدفع',
          value: switch (paymentStatus) {
            'paid' => 'مدفوع',
            'partial' => 'مدفوع جزئياً',
            _ => 'غير مدفوع',
          },
        ),
        if (paymentStatus == 'partial') ...[
          ThermalKv(label: 'المدفوع', value: _amt(paidAmount)),
          DueBox(
              label: 'المتبقي',
              value: _amt((total - paidAmount).clamp(0.0, total))),
        ],
      ],
      if (packageBalance != null) ...[
        const ThermalRule(kind: ThermalRuleKind.hair),
        _meta('العبوات المتبقية لدى المتجر',
            '${ltr(packageBalance!)} ${l10n.packageUnit}'),
      ],
      SizedBox(height: Dots.px(22)),
      Row(
        children: [
          const Expanded(child: SignatureLine(label: 'توقيع المستلم')),
          SizedBox(width: Dots.px(22)),
          const Expanded(child: SignatureLine(label: 'توقيع السائق')),
        ],
      ),
      ..._footer(),
    ];
  }

  // --- load manifest (Task 7) ---

  List<Widget> _loadBody() => const [];

  // --- return / shift close (Task 7) ---

  List<Widget> _returnBody() => const [];
}
```

- [x] **Step 6: Run the tests to verify they pass**

```powershell
flutter test test/widget/receipts/receipt_palette_test.dart test/widget/receipts/receipt_capture_test.dart
```

Expected: `All tests passed!` (6 tests). If the capture test fails with a width other than 576, the paper is not at its natural width — check that nothing in the test host constrains it (`Align` does not).

- [x] **Step 7: Analyze and commit**

```powershell
flutter analyze
git add lib/features/receipts/widgets/receipt_paper.dart test/widget/receipts/fixtures.dart test/widget/receipts/receipt_palette_test.dart test/widget/receipts/receipt_capture_test.dart
git commit -m "feat(receipts): ReceiptPaper — 288px delivery invoice with boxed grid, palette and capture tests"
```

---

### Task 7: Load manifest and return bodies on `ReceiptPaper`

**Files:**
- Modify: `lib/features/receipts/widgets/receipt_paper.dart` (replace the two `=> const []` stubs)
- Modify: `test/widget/receipts/receipt_palette_test.dart` (add two cases)

**Interfaces:**
- Consumes: `ThermalGrid`, `ThermalCell`, `_masthead`, `_meta` from Task 6.
- Produces: `ReceiptPaper` renders all three `ReceiptDocType`s.

Load manifest: masthead `إيصال التحميل`; driver, loaded-by, date; 2-column grid `الصنف` 416 / `الكمية` 120 with a footer row `إجمالي المحمّل`. Return: masthead `إيصال إغلاق الوردية`; driver, date; 4-column grid `الصنف` 236 / `محمّل` 100 / `مباع` 100 / `مرتجع` 100; totals row appended as the last body row in bold (the grid footer only has two cells, so the three totals go in a body row).

- [x] **Step 1: Add the failing tests**

Append inside `main()` of `test/widget/receipts/receipt_palette_test.dart`:

```dart
  testWidgets('load manifest declares only black and white and totals the load',
      (tester) async {
    tester.view.physicalSize = const Size(600, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(host(ReceiptPaper(
      docType: ReceiptDocType.load,
      l10n: l10nAr,
      config: sampleConfig,
      loadData: sampleLoad(),
    )));
    await expectOnlyInk(tester);
    expect(find.text(l10nAr.loadReceipt), findsOneWidget);
    expect(find.text(l10nAr.totalLoaded, findRichText: true), findsOneWidget);
    expect(find.text('\u206664\u2069', findRichText: true), findsOneWidget); // 40 + 24
  });

  testWidgets('return document declares only black and white and totals columns',
      (tester) async {
    tester.view.physicalSize = const Size(600, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(host(ReceiptPaper(
      docType: ReceiptDocType.returns,
      l10n: l10nAr,
      config: sampleConfig,
      returnData: sampleReturn(),
    )));
    await expectOnlyInk(tester);
    expect(find.text(l10nAr.shiftCloseReceipt), findsOneWidget);
    expect(find.text(l10nAr.loaded, findRichText: true), findsOneWidget);
    expect(find.text(l10nAr.sold, findRichText: true), findsOneWidget);
    expect(find.text(l10nAr.returned, findRichText: true), findsOneWidget);
    expect(find.text('\u206657\u2069', findRichText: true), findsOneWidget); // sold 33 + 24
    expect(find.text('\u20667\u2069', findRichText: true), findsNWidgets(2)); // row + total returned
  });
```

- [x] **Step 2: Run to verify the new tests fail**

```powershell
flutter test test/widget/receipts/receipt_palette_test.dart
```

Expected: the two new tests fail on `findsOneWidget` for the document titles (the bodies are empty); the earlier five still pass.

- [x] **Step 3: Implement both bodies**

Replace the two stubs at the bottom of `receipt_paper.dart`:

```dart
  // --- load manifest ---

  List<Widget> _loadBody() {
    final d = loadData!;
    final driverName = d['driver_name'] as String? ?? '';
    final loadedByName = d['loaded_by_name'] as String? ?? '';
    final date = _fmtDate(d['opened_at'] as String?);
    final items = (d['items'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    final totalQty = items.fold<int>(
        0, (sum, i) => sum + ((i['quantity_loaded'] as num?)?.toInt() ?? 0));

    return [
      ..._masthead(l10n.loadReceipt),
      if (driverName.isNotEmpty)
        _meta(l10n.driver, driverName,
            valueSizeDots: 23, valueWeight: FontWeight.w700),
      if (loadedByName.isNotEmpty) _meta(l10n.loadedBy, loadedByName),
      if (date.isNotEmpty) _meta(l10n.orderDate, ltr(date)),
      SizedBox(height: Dots.px(14)),
      ThermalGrid(
        columnDots: const [416, 120],
        headers: [l10n.products, 'الكمية'],
        aligns: const [TextAlign.start, TextAlign.end],
        rows: [
          for (final m in items)
            [
              ThermalCell.text(m['product_name'] as String? ?? '',
                  mainSizeDots: 23, mainWeight: FontWeight.w600),
              ThermalCell.text(
                  ltr((m['quantity_loaded'] as num?)?.toInt() ?? 0),
                  align: TextAlign.end,
                  mainWeight: FontWeight.w700),
            ],
        ],
        footer: [(label: l10n.totalLoaded, value: ltr(totalQty))],
      ),
      ..._footer(),
    ];
  }

  // --- return / shift close ---

  List<Widget> _returnBody() {
    final d = returnData!;
    final driverName = d['driver_name'] as String? ?? '';
    final date = _fmtDate(d['closed_at'] as String?);
    final items = (d['items'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();

    int sum(String key) => items.fold<int>(
        0, (s, m) => s + ((m[key] as num?)?.toInt() ?? 0));
    final totalLoaded = sum('quantity_loaded');
    final totalSold = sum('quantity_sold');
    final totalReturned = sum('quantity_returned');

    List<Widget> row(String name, int a, int b, int c, {bool bold = false}) {
      final w = bold ? FontWeight.w700 : FontWeight.w400;
      return [
        ThermalCell.text(name,
            mainSizeDots: bold ? 21 : 23,
            mainWeight: bold ? FontWeight.w700 : FontWeight.w600),
        ThermalCell.text(ltr(a), align: TextAlign.center, mainWeight: w),
        ThermalCell.text(ltr(b), align: TextAlign.center, mainWeight: w),
        ThermalCell.text(ltr(c), align: TextAlign.center, mainWeight: w),
      ];
    }

    return [
      ..._masthead(l10n.shiftCloseReceipt),
      if (driverName.isNotEmpty)
        _meta(l10n.driver, driverName,
            valueSizeDots: 23, valueWeight: FontWeight.w700),
      if (date.isNotEmpty) _meta(l10n.orderDate, ltr(date)),
      SizedBox(height: Dots.px(14)),
      ThermalGrid(
        columnDots: const [236, 100, 100, 100],
        headers: [l10n.products, l10n.loaded, l10n.sold, l10n.returned],
        aligns: const [
          TextAlign.start,
          TextAlign.center,
          TextAlign.center,
          TextAlign.center,
        ],
        rows: [
          for (final m in items)
            row(
              m['product_name'] as String? ?? '',
              (m['quantity_loaded'] as num?)?.toInt() ?? 0,
              (m['quantity_sold'] as num?)?.toInt() ?? 0,
              (m['quantity_returned'] as num?)?.toInt() ?? 0,
            ),
          row(l10n.total, totalLoaded, totalSold, totalReturned, bold: true),
        ],
      ),
      ..._footer(),
    ];
  }
}
```

- [x] **Step 4: Run the receipt tests**

```powershell
flutter test test/widget/receipts
```

Expected: `All tests passed!` (all receipt widget tests, including the 7 palette tests).

- [x] **Step 5: Check the file length, analyze, commit**

```powershell
(Get-Content lib/features/receipts/widgets/receipt_paper.dart | Measure-Object -Line).Lines
flutter analyze
git add lib/features/receipts/widgets/receipt_paper.dart test/widget/receipts/receipt_palette_test.dart
git commit -m "feat(receipts): load manifest and shift-close bodies on ReceiptPaper"
```

Expected line count under 500.

---

### Task 8: Wire `ReceiptScreen` to the new paper and delete the old one

**Files:**
- Modify: `lib/features/receipts/screens/receipt_screen.dart` (lines 1–33 imports/enum, 360–385 the preview block, 600–1003 the old `_ReceiptPaper`, `_DashedDivider`, `_DashPainter`)

**Interfaces:**
- Consumes: `ReceiptPaper`, `ReceiptDocType` (Task 6), `receiptConfigProvider` (Task 5), `PrintService.printFromWidget` default 2.0 (Task 1).
- Produces: `ReceiptScreen` unchanged in its public constructors; `ReceiptDocType` is still importable from `receipt_screen.dart` via a re-export.

- [x] **Step 1: Find every external use of `ReceiptDocType`**

```powershell
Select-String -Path lib\**\*.dart -Pattern "ReceiptDocType" | Where-Object { $_.Path -notmatch "receipts" }
```

Expected: no matches, or matches that only go through `ReceiptScreen.order/load/returns`. Either way the re-export below keeps them compiling.

- [x] **Step 2: Replace the enum and imports at the top of the screen**

Delete these lines from `receipt_screen.dart`:

```dart
import 'package:tawzii/core/theme/app_colors.dart';
import 'package:tawzii/core/ui/money_text.dart';
```

and

```dart
/// The three document types the unified receipt screen can render.
enum ReceiptDocType { order, load, returns }
```

Add after the existing imports:

```dart
import 'package:tawzii/features/receipts/providers/receipt_config_provider.dart';
import 'package:tawzii/features/receipts/models/receipt_config.dart';
import 'package:tawzii/features/receipts/widgets/receipt_paper.dart';

export 'package:tawzii/features/receipts/widgets/receipt_paper.dart' show ReceiptDocType;
```

Also delete the `import 'package:intl/intl.dart';` line — after this task nothing in the screen uses `DateFormat`. Keep `app_theme.dart` (used by `_DocTypeIndicator`).

- [x] **Step 3: Replace the preview block in `_buildScaffold`**

Replace:

```dart
          // 58mm thermal preview — always white paper, ink text (both themes).
          Center(
            child: RepaintBoundary(
              key: _receiptKey,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 300),
                child: _ReceiptPaper(
                  docType: widget.docType,
                  order: order,
                  loadData: widget.loadData,
                  returnData: widget.returnData,
                  packageBalance: _packageBalance,
                  l10n: l10n,
                ),
              ),
            ),
          ),
```

with:

```dart
          // 80 mm thermal paper at its natural 288 px (= 576 dots at 2.0).
          // The RepaintBoundary is what gets captured; it sits inside the
          // FittedBox so a narrow phone scales the preview without touching
          // the printed bitmap.
          Center(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final paper = RepaintBoundary(
                  key: _receiptKey,
                  child: ReceiptPaper(
                    docType: widget.docType,
                    order: order,
                    loadData: widget.loadData,
                    returnData: widget.returnData,
                    packageBalance: _packageBalance,
                    config: ref.watch(receiptConfigProvider).valueOrNull ??
                        ReceiptConfig.empty,
                    l10n: l10n,
                  ),
                );
                if (constraints.maxWidth >= ReceiptPaper.width) return paper;
                return FittedBox(fit: BoxFit.fitWidth, child: paper);
              },
            ),
          ),
```

- [x] **Step 4: Delete the old paper**

Delete everything from the comment `/// The white 58mm paper. Colors are intentionally FIXED to light-paper values` through the end of the file (the `_ReceiptPaper`, `_DashedDivider` and `_DashPainter` classes). The file must end after the closing brace of `_DocTypeIndicator`.

- [x] **Step 5: Analyze, check the line count, run everything**

```powershell
flutter analyze
(Get-Content lib/features/receipts/screens/receipt_screen.dart | Measure-Object -Line).Lines
flutter test
```

Expected: `No issues found!`; line count under 500 (about 600 lines were removed from a 1003-line file, so roughly 400); `All tests passed!`.

If `flutter analyze` reports an unused import, remove it. If it reports `ReceiptDocType` unresolved in another file, that file must import `receipt_screen.dart` (the re-export) or `receipt_paper.dart`.

- [ ] **Step 6: Print one real receipt**

Build and install the debug app on the phone paired with the XP-P323B, open any order receipt, tap print. Check on paper:

- every rule is visible (outer frame, header rule, inner grid rules, the two section rules)
- the total bar is solid black with white text
- a mixed line shows `+n ق` in the quantity cell and `n/ق` under the package price
- nothing is cut off at the right edge (the frame's right rule prints)

If the frame's right rule is missing, the printer's left margin is not zero: send `GS L 0 0` (`[0x1D, 0x4C, 0x00, 0x00]`) right after the `ESC @` initialise in `printFromWidget` and print again.

- [x] **Step 7: Commit**

```powershell
git add lib/features/receipts/screens/receipt_screen.dart
git commit -m "feat(receipts): render ReceiptPaper at 576 dots in ReceiptScreen; drop grey dashed paper"
```

---

## Self-review

**Spec coverage.** §1.1/1.2 (grey ink) → Tasks 3, 4, 6 with the palette test as the guard. §1.3 (resample) → Task 1 (box filter, 2.0 default) and Task 6/8 (288 px paper, capture test asserts 576). §1.4 (stale width) → Task 8 replaces the 300-px preview and the "58mm" comment. §4.1 (fixed width, noScaling, FittedBox fallback) → Tasks 6 and 8. §4.2 → Task 1. §4.3 primitives → Task 3 (rules, kv, bar, stamp, due box, signature) and Task 4 (grid); the dashed 9-on-7 rule is not built because template A uses none. §4.4 file split → Tasks 6–8. §4.5 config keys → Task 5. §5 layout and §5.1 grid rules → Task 6 (order) and Task 7 (manifest, return). §6 debug assertion → Task 1 Step 5. §7 tests → Tasks 1, 6, 7 (`esc_pos_raster_test`, `receipt_palette_test`, `receipt_capture_test`); existing `line_item_test` and `package_stock_test` are run by `flutter test` in every task.

**Placeholder scan.** Every code step shows full code; every run step has a command and an expected result. The only environment-dependent step is Task 8 Step 6 (a physical print), which has a concrete checklist.

**Type consistency.** `ThermalCell.text(String, {sub, align, mainSizeDots, mainWeight})` is used identically in Tasks 4, 6, 7. `GridFooterRow` is a `({String label, String value})` record everywhere. `ReceiptLine` getters used in Task 6 (`name`, `perPackageLabel`, `qtyMain`, `qtySub`, `priceMain`, `priceSub`, `totalText`) are all defined in Task 2. `ReceiptConfig.empty`, `phoneKey`, `footerKey` match between Tasks 5 and 6/8. `PrintService.captureWidget` is an existing static and is used unchanged by the capture test. `l10n` keys used (`appTitle`, `orderDate`, `address`, `driver`, `subtotal`, `tax`, `discount`, `currencyUnit`, `packageUnit`, `statusCancelled`, `loadReceipt`, `loadedBy`, `products`, `totalLoaded`, `shiftCloseReceipt`, `loaded`, `sold`, `returned`, `total`) all exist in `lib/core/l10n/app_ar.arb`.
