import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:tawzii/features/printing/services/esc_pos_raster.dart';

/// Service for Bluetooth thermal printer operations.
///
/// Uses image-based printing to support Arabic RTL text:
/// Flutter renders the receipt widget → captured as bitmap → printed as image.
class PrintService {
  PrintService._();
  static final instance = PrintService._();

  bool _connected = false;
  String? _connectedName;
  String? _lastMacAddress;
  String? _lastName;

  bool get isConnected => _connected;
  String? get connectedPrinterName => _connectedName;

  /// Rows (dots) sent to the printer by the last successful print, after
  /// trailing white rows were trimmed. Divide by [kDotsPerMm] for length.
  int? lastPrintedRows;

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
    if (result) {
      _lastMacAddress = macAddress;
      _lastName = name;
    }
    return result;
  }

  /// Attempt to reconnect to the last known printer.
  Future<bool> tryReconnect() async {
    if (_lastMacAddress == null) return false;
    debugPrint('Attempting printer auto-reconnect to $_lastName');
    return connect(_lastMacAddress!, name: _lastName);
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
  Future<bool> printFromWidget(GlobalKey receiptKey, {double pixelRatio = 2.0}) async {
    if (!_connected) {
      // Attempt auto-reconnect to last known printer
      final reconnected = await tryReconnect();
      if (!reconnected) return false;
    }

    try {
      // Capture widget as image
      final imageBytes = await captureWidget(receiptKey, pixelRatio: pixelRatio);
      if (imageBytes == null) return false;

      // Convert PNG to ESC/POS raster bands (trailing white rows trimmed).
      final raster = await _pngToEscPos(imageBytes);
      if (raster == null || raster.bytes.isEmpty) return false;
      lastPrintedRows = raster.rows;

      // One write for the whole job. The Android plugin prefixes every
      // writeBytes call with a line feed, so separate init / image / feed
      // writes would each move the paper a little.
      final job = <int>[
        0x1B, 0x40, // ESC @  initialise
        ...raster.bytes, // GS v 0 bands
        0x1B, 0x64, 0x03, // ESC d 3  feed to the tear bar
      ];
      return await PrintBluetoothThermal.writeBytes(job);
    } catch (e) {
      debugPrint('Print failed: $e');
      return false;
    }
  }

  /// Convert PNG bytes to ESC/POS raster bitmap commands.
  ///
  /// Decodes the PNG to RGBA and hands it to [encodeEscPosRaster]. The
  /// receipt paper is 288 logical px captured at 2.0, so the decoded width
  /// should already be [kPrintWidthDots]; anything else means the paper
  /// width and the capture ratio were changed independently.
  Future<EscPosRaster?> _pngToEscPos(Uint8List pngBytes) async {
    // Decode + width check live OUTSIDE the try below: an AssertionError here
    // is a build-time bug (the capture is not 576 dots wide), and keeping it
    // out of this method's try lets its own message reach the log verbatim
    // (via printFromWidget's catch) instead of being flattened into an empty
    // byte list.
    final codec = await ui.instantiateImageCodec(pngBytes);
    final frame = await codec.getNextFrame();
    final image = frame.image;
    assert(
      image.width == kPrintWidthDots,
      'Receipt capture is ${image.width} dots wide; expected $kPrintWidthDots. '
      'ReceiptPaper.width × pixelRatio must equal $kPrintWidthDots.',
    );
    try {
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (byteData == null) return null;
      return encodeEscPosRaster(
        width: image.width,
        height: image.height,
        rgba: byteData.buffer.asUint8List(),
      );
    } catch (e) {
      debugPrint('PNG to ESC/POS conversion failed: $e');
      return null;
    }
  }
}
