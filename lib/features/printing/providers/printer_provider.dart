import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/print_service.dart';

final printServiceProvider = Provider<PrintService>((ref) {
  return PrintService.instance;
});

final printerConnectedProvider = StateProvider<bool>((ref) {
  return PrintService.instance.isConnected;
});

final connectedPrinterNameProvider = StateProvider<String?>((ref) {
  return PrintService.instance.connectedPrinterName;
});
