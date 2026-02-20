import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';

/// Zebra printer service for raw ZPL printing over Bluetooth SPP.
/// The ZPL must already be correctly formatted (portrait 5x10 cm).
class ZebraPrinterService {
  static ZebraPrinterService? _instance;
  factory ZebraPrinterService() =>
      _instance ??= ZebraPrinterService._internal();
  ZebraPrinterService._internal();

  final BlueThermalPrinter _bt = BlueThermalPrinter.instance;

  Completer<void>? _lock;
  bool _busy = false;

  Future<void> _acquire() async {
    while (_busy) {
      await _lock?.future;
      await Future.delayed(const Duration(milliseconds: 5));
    }
    _busy = true;
    _lock = Completer<void>();
  }

  void _release() {
    _busy = false;
    _lock?.complete();
    _lock = null;
  }

  // ---------------- Bluetooth ----------------

  Future<bool> isConnected() async => await _bt.isConnected ?? false;

  Future<List<BluetoothDevice>> getBondedDevices() async =>
      await _bt.getBondedDevices();

  Future<void> connect(BluetoothDevice device) async =>
      await _bt.connect(device);

  Future<void> disconnect() async => await _bt.disconnect();

  // ---------------- Print ----------------

  /// Send raw ZPL to printer (no modification)
  Future<void> printZpl(String zpl) async {
    await _acquire();
    try {
      debugPrint('🖨️ ZPL SENT (portrait 5x10cm)\n$zpl');
      await _bt.write(zpl);
    } finally {
      _release();
    }
  }
}
