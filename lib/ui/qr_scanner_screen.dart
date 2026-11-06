import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});
  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  final _controller = MobileScannerController();
  bool _returned = false;
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Scanner une invitation')),
    body: Column(
      children: [
        const Padding(
          padding: EdgeInsets.all(20),
          child: Text(
            'La caméra sert uniquement à lire un QR code TTalk. Vérifie l’identité de ton contact après l’appairage.',
          ),
        ),
        Expanded(
          child: MobileScanner(
            controller: _controller,
            errorBuilder: (context, error) => const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  "Caméra indisponible ou accès refusé. Reviens en arrière et colle le lien d’invitation à la place.",
                ),
              ),
            ),
            onDetect: (capture) {
              if (_returned) return;
              for (final code in capture.barcodes) {
                final value = code.rawValue;
                if (value != null && value.startsWith('ttalk://pair?')) {
                  _returned = true;
                  Navigator.of(context).pop(value);
                  return;
                }
              }
            },
          ),
        ),
      ],
    ),
  );
}
