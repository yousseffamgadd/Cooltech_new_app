import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_screenutil/flutter_screenutil.dart'; // For responsiveness
import 'qrscreen.dart';
import 'sensors.dart';
import 'dart:io';
import 'package:encrypt/encrypt.dart' as encrypt ;
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'dart:typed_data';


class TokenQrScreen extends StatefulWidget {
  const TokenQrScreen({super.key});

  @override
  State<TokenQrScreen> createState() => _TokenQrScreenState();
}

class _TokenQrScreenState extends State<TokenQrScreen> {
  bool isProcessing = false;

  Future<void> _startScanning() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const QRScanScreen(scanType: QRScanType.accessToken),
      ),
    );
    print('tokennnnnn');
    if (result != null && result['access_token'] != null) {

      final token = result['access_token'];
      print("yessssssss");
      _processScannedData(token);
    }
  }

  void _processScannedData(String token) async {
    if (isProcessing) return;
    setState(() => isProcessing = true);
    print("hereeee");
    //🔐 Decrypt token before use
    final decryptedToken = SecureTokenEncryptor.decrypt(token);
    print(decryptedToken);
    if (decryptedToken == 'DECRYPTION_FAILED') {
  _showResultDialog(
    'Decryption Error',
    'The token could not be decrypted. Please make sure the QR code is valid.',
    Icons.error,
    Colors.red,
  );
  setState(() => isProcessing = false);
  return;
}

    final url = Uri.parse('https://demo.thingsboard.io/api/v1/$decryptedToken/attributes');

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        await _showResultDialog(
          'Success',
          'Gateway connected successfully',
          Icons.check_circle,
          Colors.green,
        );

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SensorManagementScreen(token: decryptedToken),
          ),
        );
      } else {
        String errorMessage = _handleError(response.statusCode, response.reasonPhrase);
        _showResultDialog('Error', errorMessage, Icons.error, Colors.red);
      }
    } catch (e) {
      if (e is SocketException) {
        _showResultDialog(
          'No Internet Connection',
          'Please check your connection and try again',
          Icons.error,
          Colors.red,
        );
      } else {
        _showResultDialog('Exception', 'An error occurred: $e', Icons.error, Colors.red);
      }
    } finally {
      setState(() => isProcessing = false);
    }
  }

  String _handleError(int statusCode, String? reasonPhrase) {
    switch (statusCode) {
      case 400:
        return 'Bad Request: The request is malformed.';
      case 401:
        return 'Unauthorized: The token provided is invalid or expired.';
      case 403:
        return 'Forbidden: Access is denied.';
      case 404:
        return 'Not Found: Resource could not be found.';
      case 500:
        return 'Server Error: Something went wrong.';
      default:
        return 'Error $statusCode: $reasonPhrase';
    }
  }

  Future<void> _showResultDialog(
  String title,
  String message,
  IconData icon,
  Color color,
) {
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.r),
      ),
      titlePadding: EdgeInsets.fromLTRB(24.w, 20.h, 24.w, 10.h),
      contentPadding: EdgeInsets.fromLTRB(24.w, 0, 24.w, 10.h),
      actionsPadding: EdgeInsets.only(right: 12.w, bottom: 8.h),

      title: Row(
        children: [
          Icon(icon, color: color, size: 24.sp),
          SizedBox(width: 10.w),
          Expanded(
            child: Text(
              title,
              style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: Text(
        message,
        style: TextStyle(fontSize: 16.sp),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'OK',
            style: TextStyle(fontSize: 16.sp , color:Color.fromARGB(255, 42, 62, 173) ),
            
          ),
        ),
      ],
    ),
  );
}

  @override
Widget build(BuildContext context) {
  final screenHeight = MediaQuery.of(context).size.height;

  return Scaffold(
    body: Stack(
      children: [
        /// Background
        Positioned.fill(
          child: Opacity(
            opacity: 1,
            child: Image.asset(
              'images/background.png',
              fit: BoxFit.cover,
            ),
          ),
        ),

        /// Foreground UI
        Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 30.w),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: screenHeight * 0.75, // Same height constraint as login
              ),
              child: Container(
                padding: EdgeInsets.all(22.r),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.87),
                  borderRadius: BorderRadius.circular(16.r),
                  boxShadow: [
                    BoxShadow(
                      blurRadius: 10.r,
                      color: Colors.black12,
                      offset: Offset(0, 4.h),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.qr_code_scanner,
                      size: 80.sp,
                      color: Color.fromARGB(255, 42, 62, 173),
                    ),
                    SizedBox(height: 20.h),
                    Text(
                      'Connect to Gateway',
                      style: TextStyle(
                        fontSize: 24.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 10.h),
                    Text(
                      'Scan the QR code on your gateway device',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16.sp,
                        color: Colors.blueGrey,
                      ),
                    ),
                    SizedBox(height: 40.h),

                    /// Scan Button
                    SizedBox(
                      width: double.infinity,
                      height: 54.h,
                      child: ElevatedButton.icon(
                        onPressed: _startScanning,
                        icon: Padding(
                          padding: EdgeInsets.only(right: 6.w),
                          child: Icon(
                            Icons.qr_code_2,
                            size: 22.sp,
                          ),
                        ),
                        label: Text(
                          'Scan QR Code',
                          style: TextStyle(fontSize: 17.sp),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color.fromARGB(255, 42, 62, 173),
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(
                            horizontal: 20.w,
                            vertical: 12.h,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25.r),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
}



class SecureTokenEncryptor {
  static const String _kEncryptionKey = 'D8A7F3C5B2E6019D4A6C7E8F03B1D294F7E0C3A5B8D6017E2A9D4F8C5E3B7012';
  static const String _kIV = 'F3A1C6B2D8E9074E';

  static String decrypt(String encryptedText) {
  try {
    final key = _validateOrHashKey(_kEncryptionKey);
    final iv = encrypt.IV.fromUtf8(_kIV);

    final encrypter = encrypt.Encrypter(
      encrypt.AES(
        encrypt.Key(Uint8List.fromList(key)),
        mode: encrypt.AESMode.cbc,
      ),
    );

    final encrypted = encrypt.Encrypted.fromBase64(encryptedText);
    return encrypter.decrypt(encrypted, iv: iv);
  } catch (e, stacktrace) {
    debugPrint('🔐 Decryption failed!');
    debugPrint('Error: $e');
    debugPrint('Stacktrace: $stacktrace');
    return 'DECRYPTION_FAILED';
  }
}


  static List<int> _validateOrHashKey(String key) {
    final keyBytes = utf8.encode(key);
    return keyBytes.length == 32 ? keyBytes : sha256.convert(keyBytes).bytes;
  }
}
