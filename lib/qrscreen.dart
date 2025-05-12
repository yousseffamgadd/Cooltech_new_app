import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart'; 

enum QRScanType { accessToken, macAddress }

class QRScanScreen extends StatefulWidget {
  final QRScanType scanType;

  const QRScanScreen({super.key, required this.scanType});

  @override
  State<QRScanScreen> createState() => _QRScanScreenState();
}

class _QRScanScreenState extends State<QRScanScreen> {
  late MobileScannerController cameraController;
  bool isFlashOn = false;
  bool isFrontCamera = false;
  bool isScanComplete = false;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    cameraController = MobileScannerController();
  }

  void _processScannedData(String? data) {
    if (data == null || data.isEmpty || isScanComplete) return;

    print('Scanned Data: $data'); 

    setState(() {
      isScanComplete = true;
      errorMessage = ''; // Clear previous error message for a fresh scan
    });

    if (widget.scanType == QRScanType.macAddress) {
      // Find the MAC part in the string till the comma
      final macMatch = RegExp(r'MAC:([^,]+)').firstMatch(data);
      if (macMatch == null) {
        setState(() {
          errorMessage = 'MAC address not found';
          isScanComplete = false; // Allow retry
        });
        Future.delayed(const Duration(seconds: 2), () {
          if (!mounted) return;
          setState(() {
            errorMessage = '';
          });
        });
        return; 
      }

      String macRaw = macMatch.group(1)!; 
      // Validate: exactly 12 characters
      final isValidMac = RegExp(r'^[a-fA-F0-9]{12}$').hasMatch(macRaw);

      if (!isValidMac) {
        setState(() {
          errorMessage = 'Invalid MAC address format.';
          isScanComplete = false; // Allow retry
        });
        Future.delayed(const Duration(seconds: 2), () {
          if (!mounted) return;
          setState(() {
            errorMessage = '';
          });
        });
        return; 
      }

      // Clean up the MAC address
      String cleaned = macRaw.replaceAll(RegExp(r'[^a-fA-F0-9]'), '').toLowerCase();

      // Insert colons every 2 characters
      StringBuffer formattedMac = StringBuffer();
      for (int i = 0; i < cleaned.length; i += 2) {
        if (i != 0) formattedMac.write(':');
        formattedMac.write(cleaned.substring(i, i + 2));
      }

      // Display success message
      setState(() {
        errorMessage = 'Scanned Successfully';
      });

      Future.delayed(const Duration(seconds: 2), () {
        if (!mounted) return;
        Navigator.pop(context, {'mac': formattedMac.toString()});
      });
    } else {
      // Access token case
      setState(() {
        errorMessage = 'Scanned Successfully';
      });

      Future.delayed(const Duration(seconds: 2), () {
        if (!mounted) return;
        Navigator.pop(context, {'access_token': data});
      });
    }
  }

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }

  @override
Widget build(BuildContext context) {
  return Scaffold(
    backgroundColor: Colors.black,
    appBar: PreferredSize(
      preferredSize: Size.fromHeight(40.h),
      child: AppBar(
        title: Text('Scan QR Code', style: TextStyle(fontSize: 17.sp, color: Colors.white)),
        backgroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
            icon: Icon(Icons.arrow_back, color: Colors.white , size: 22.sp), 
            onPressed: () => Navigator.pop(context),
          ),
        actions: [
          IconButton(
            color: Colors.white,
            icon: Icon(isFlashOn ? Icons.flash_on : Icons.flash_off , size: 22.sp,),
            onPressed: () {
              setState(() => isFlashOn = !isFlashOn);
              cameraController.toggleTorch();
            },
          ),
          IconButton(
            color: Colors.white,
            icon: Icon(isFrontCamera ? Icons.camera_front : Icons.camera_rear , size: 22.sp,),
            onPressed: () {
              setState(() => isFrontCamera = !isFrontCamera);
              cameraController.switchCamera();
            },
            
          ),
        ],
      ),
    ),
    body: Stack(
      fit: StackFit.expand,
      children: [
        // Camera preview fills the entire screen
        Positioned.fill(
          child: MobileScanner(
            controller: cameraController,
            onDetect: (capture) {
              for (final barcode in capture.barcodes) {
                _processScannedData(barcode.rawValue);
              }
            },
          ),
        ),

        // Overlay on top of camera preview
        _buildScannerOverlay(context),

        // Error message display
        if (errorMessage != null && errorMessage!.isNotEmpty)
          Positioned(
            bottom: MediaQuery.of(context).size.height * 0.1,  // 10% from the bottom of the screen
            left: 20.w,  
            right: 20.w,  
            child: Container(
              padding: EdgeInsets.symmetric(
                vertical: 12.h,  
                horizontal: 16.w, 
              ),
              decoration: BoxDecoration(
                color: errorMessage!.endsWith('Successfully')
                    ? Colors.green.withOpacity(0.8)
                    : Colors.red.withOpacity(0.8),
                borderRadius: BorderRadius.circular(10.r),  
              ),
              child: Text(
                errorMessage!,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14.sp,  
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    ),
  );
}


  Widget _buildScannerOverlay(BuildContext context) {
  return Container(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [
          Colors.black.withOpacity(0.5),
          Colors.transparent,
          Colors.transparent,
          Colors.black.withOpacity(0.5),
        ],
        stops: const [0, 0.25, 0.75, 1],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ),
    ),
    child: Center( // Center the whole content
      child: Container(
        width: MediaQuery.of(context).size.width * 0.7, // Set box width to 70% of screen width
        height: MediaQuery.of(context).size.width * 0.7, // Set box height to 70% of screen width (square shape)
        decoration: BoxDecoration(
          border: Border.all(
            color: Colors.white.withOpacity(0.5), // White border with transparency
            width: 2,
          ),
          borderRadius: BorderRadius.circular(20), 
        ),
        child: Stack(
          children: [
           
          ],
        ),
      ),
    ),
  );
}

}
