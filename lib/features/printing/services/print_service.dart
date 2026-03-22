import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

/// Service for Bluetooth thermal printer operations.
///
/// Uses image-based printing to support Arabic RTL text:
/// Flutter renders the receipt widget → captured as bitmap → printed as image.
class PrintService {
  PrintService._();
  static final instance = PrintService._();

  bool _connected = false;
  String? _connectedName;

  bool get isConnected => _connected;
  String? get connectedPrinterName => _connectedName;

  /// Get list of paired Bluetooth devices.
  Future<List<BluetoothInfo>> getPairedDevices() async {
    return await PrintBluetoothThermal.pairedBluetooths;
  }

  /// Connect to a Bluetooth printer by MAC address.
  Future<bool> connect(String macAddress, {String? name}) async {
    final result = await PrintBluetoothThermal.connect(
        macPrinterAddress: macAddress);
    _connected = result;
    _connectedName = result ? name : null;
    return result;
  }

  /// Disconnect from the current printer.
  Future<void> disconnect() async {
    await PrintBluetoothThermal.disconnect;
    _connected = false;
    _connectedName = null;
  }

  /// Check current connection status.
  Future<bool> checkConnection() async {
    _connected = await PrintBluetoothThermal.connectionStatus;
    if (!_connected) _connectedName = null;
    return _connected;
  }

  /// Capture a widget rendered via GlobalKey as image bytes.
  static Future<Uint8List?> captureWidget(GlobalKey key,
      {double pixelRatio = 2.0}) async {
    try {
      final boundary =
          key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;

      final image = await boundary.toImage(pixelRatio: pixelRatio);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint('Widget capture failed: $e');
      return null;
    }
  }

  /// Print receipt by capturing a rendered widget as image.
  ///
  /// 1. Captures widget via RepaintBoundary key as PNG
  /// 2. Sends raw image bytes to printer via ESC/POS commands
  ///
  /// Arabic text works perfectly because Flutter renders it.
  Future<bool> printFromWidget(GlobalKey receiptKey) async {
    if (!_connected) return false;

    try {
      // Capture widget as image
      final imageBytes = await captureWidget(receiptKey, pixelRatio: 2.0);
      if (imageBytes == null) return false;

      // Initialize printer
      await PrintBluetoothThermal.writeBytes([0x1B, 0x40]);

      // Print image using the package's byte writing
      // Convert PNG to ESC/POS raster format
      final escPosBytes = await _pngToEscPos(imageBytes);
      if (escPosBytes.isEmpty) return false;

      final result = await PrintBluetoothThermal.writeBytes(escPosBytes);

      // Feed paper
      await PrintBluetoothThermal.writeBytes([0x1B, 0x64, 0x04]); // Feed 4 lines

      return result;
    } catch (e) {
      debugPrint('Print failed: $e');
      return false;
    }
  }

  /// Convert PNG bytes to ESC/POS raster bitmap commands.
  ///
  /// Decodes the PNG, converts to monochrome, generates GS v 0 commands.
  Future<List<int>> _pngToEscPos(Uint8List pngBytes) async {
    try {
      // Decode PNG to raw RGBA pixels using Flutter's image codec
      final codec = await ui.instantiateImageCodec(pngBytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;

      final width = image.width;
      final height = image.height;

      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (byteData == null) return [];

      final pixels = byteData.buffer.asUint8List();

      // Target print width: 384 pixels (48mm printable on 58mm paper at 203dpi)
      const printWidth = 384;
      final scale = printWidth / width;
      final printHeight = (height * scale).toInt();

      // Convert to monochrome bitmap (1 bit per pixel)
      // Width in bytes (8 pixels per byte)
      final widthBytes = (printWidth + 7) ~/ 8;

      final List<int> commands = [];

      // GS v 0 — Print raster bit image
      // Format: GS v 0 m xL xH yL yH d1...dk
      commands.addAll([0x1D, 0x76, 0x30, 0x00]); // GS v 0 normal
      commands.addAll([
        widthBytes & 0xFF,
        (widthBytes >> 8) & 0xFF,
      ]); // xL xH
      commands.addAll([
        printHeight & 0xFF,
        (printHeight >> 8) & 0xFF,
      ]); // yL yH

      // Generate monochrome pixel data
      for (int y = 0; y < printHeight; y++) {
        for (int xByte = 0; xByte < widthBytes; xByte++) {
          int byte = 0;
          for (int bit = 0; bit < 8; bit++) {
            final px = xByte * 8 + bit;
            if (px >= printWidth) continue;

            // Map scaled coordinates back to source image
            final srcX = (px / scale).toInt().clamp(0, width - 1);
            final srcY = (y / scale).toInt().clamp(0, height - 1);
            final idx = (srcY * width + srcX) * 4;

            // RGBA → grayscale → threshold
            final r = pixels[idx];
            final g = pixels[idx + 1];
            final b = pixels[idx + 2];
            final gray = (0.299 * r + 0.587 * g + 0.114 * b).toInt();

            // Dark pixels = 1 (print), light pixels = 0 (no print)
            if (gray < 128) {
              byte |= (0x80 >> bit);
            }
          }
          commands.add(byte);
        }
      }

      return commands;
    } catch (e) {
      debugPrint('PNG to ESC/POS conversion failed: $e');
      return [];
    }
  }
}
