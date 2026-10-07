import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../ui/ui.dart';
import '../runtime/app_controller.dart';

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  final _scanner = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
  );
  var _handled = false;

  @override
  void dispose() {
    _scanner.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_handled) return;
    final raw = capture.barcodes
        .map((barcode) => barcode.rawValue)
        .whereType<String>()
        .firstOrNull;
    if (raw == null || raw.isEmpty) return;
    _handled = true;
    await _scanner.stop();
    await widget.controller.handleQrPayload(raw);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _scanner,
            onDetect: _onDetect,
            errorBuilder: (context, error) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: AppAlert(
                  title: 'Камера недоступна',
                  description: error.errorDetails?.message ?? error.toString(),
                  variant: AppAlertVariant.destructive,
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      AppButton(
                        key: const Key('close-qr-scanner'),
                        size: AppButtonSize.small,
                        variant: AppButtonVariant.secondary,
                        leading: const Icon(Icons.close),
                        onPressed: widget.controller.closeQrScanner,
                        child: const Text('Закрыть'),
                      ),
                      const Spacer(),
                      AppButton(
                        size: AppButtonSize.icon,
                        variant: AppButtonVariant.secondary,
                        onPressed: _scanner.toggleTorch,
                        child: const Icon(Icons.flashlight_on_outlined),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Container(
                  width: 250,
                  height: 250,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white, width: 3),
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                const SizedBox(height: 26),
                const Text(
                  'Наведите камеру на QR-код any2app',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 34),
                  child: Text(
                    'QR может содержать ссылку, встроенную конфигурацию '
                    'и начальные данные.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ),
                const Spacer(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
