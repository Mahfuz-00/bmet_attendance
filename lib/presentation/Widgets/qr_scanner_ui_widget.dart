import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';
import '../../Common/Config/Theme/app_colors.dart';

class QRScannerUI extends StatefulWidget {
  final bool isProcessing;
  final Function(String) onQRScanned;
  final VoidCallback onLogout;
  /// Called by the child to give the parent a resume-camera callback.
  /// Parent receives a `VoidCallback` it can call to resume the camera.
  final ValueChanged<VoidCallback> onScannerCreated;

  const QRScannerUI({
    Key? key,
    required this.isProcessing,
    required this.onQRScanned,
    required this.onLogout,
    required this.onScannerCreated,
  }) : super(key: key);

  @override
  _QRScannerUIState createState() => _QRScannerUIState();
}

class _QRScannerUIState extends State<QRScannerUI> {
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  QRViewController? controller;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller?.resumeCamera();
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final cutOutSize = size.width * 0.8;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const Text('Scan QR Code'),
          actions: [
            IconButton(
              onPressed: () {
                controller?.toggleFlash();
                setState(() {});
              },
              icon: FutureBuilder<bool?>(
                future: controller?.getFlashStatus(),
                builder: (context, snapshot) {
                  return Icon(snapshot.data == true ? Icons.flash_on : Icons.flash_off);
                },
              ),
            ),
            IconButton(
              onPressed: widget.onLogout,
              icon: const Icon(Icons.logout),
            ),
          ],
        ),
        body: Stack(
          children: [
            QRView(
              key: qrKey,
              onQRViewCreated: _onQRViewCreated,
              overlay: QrScannerOverlayShape(
                borderColor: AppColors.accent,
                borderRadius: 12,
                borderLength: 40,
                borderWidth: 8,
                cutOutSize: cutOutSize,
                overlayColor: Colors.black.withOpacity(0.6),
              ),
            ),
            if (widget.isProcessing)
              const Center(child: CircularProgressIndicator(color: AppColors.accent)),
          ],
        ),
      ),
    );
  }

  void _onQRViewCreated(QRViewController controller) {
    this.controller = controller;

    // Register a resume callback with the parent. Parent can call this to resume the camera.
    widget.onScannerCreated(() async {
      try {
        await this.controller?.resumeCamera();
      } catch (e) {
        // optional: log
        print('QRScannerUI: resumeCamera error: $e');
      }
    });

    controller.scannedDataStream.listen((scanData) async {
      await controller.pauseCamera();
      try {
        widget.onQRScanned(scanData.code!);
      } catch (e) {
        print('QRScannerUI: Stream error: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('QR Scanner error: $e')),
        );
        await controller.resumeCamera();
      }
    }, onError: (error) {
      print('QRScannerUI: Stream error: $error');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('QR Scanner error: $error')),
      );
      controller.resumeCamera();
    });
    controller.getCameraInfo().then((cameraInfo) {
      print('QRScannerUI: Camera info: $cameraInfo');
    });
    controller.getFlashStatus().then((flashStatus) {
      print('QRScannerUI: Flash status: $flashStatus');
    });
  }

  void resumeScanner() async {
    await controller?.resumeCamera();
  }


  @override
  void dispose() {
    controller?.pauseCamera();
    controller?.dispose();
    super.dispose();
  }
}