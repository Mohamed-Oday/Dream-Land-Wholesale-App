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

    // The paper must hug its content even when the host offers more height
    // (here 4000 px): anything taller is printed as blank paper.
    final paperHeight = tester.getSize(find.byType(ReceiptPaper)).height;
    expect(paperHeight, lessThan(2000));
    expect(image!.height, (paperHeight * 2).round());

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
