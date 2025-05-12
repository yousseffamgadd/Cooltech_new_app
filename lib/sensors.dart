import 'package:flutter/material.dart';
import 'dart:convert';
import 'qrscreen.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';
import 'package:flutter_screenutil/flutter_screenutil.dart'; 


class SensorManagementScreen extends StatefulWidget {
  final String token; // Receive token from token screen
  const SensorManagementScreen({super.key, required this.token});

  @override
  State<SensorManagementScreen> createState() => _SensorManagementScreenState();
}

class _SensorManagementScreenState extends State<SensorManagementScreen> {
  late String accessToken;
  List<Map<String, dynamic>> sensors = [];
  bool isLoading = true;
  Map<String, dynamic> thingsBoardData = {};
  bool closeloading=false;
  final Connectivity _connectivity = Connectivity();
  bool _isOnline = false;
  late StreamSubscription<ConnectivityResult> _connectivitySubscription;
  ConnectivityResult? _previousResult;

  @override
  
  void initState() {
    super.initState();
    accessToken = widget.token;
    _loadSensors();
    _checkConnectivity();
    _listenForConnectivityChanges();

    // Ensure syncing happens after widget is built
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (_isOnline) {
      _syncPendingData();
    }
  });
    
  }

Future<void> _checkConnectivity() async {
  final connectivityResult = await _connectivity.checkConnectivity();
  setState(() {
    _isOnline = connectivityResult != ConnectivityResult.none;
    _previousResult =connectivityResult;
  });

  // Trigger sync after setting online status
  if (_isOnline) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncPendingData();
    });
  }
}

// Listen for changes in connectivity
  void _listenForConnectivityChanges() {
  _connectivitySubscription = _connectivity.onConnectivityChanged.listen((ConnectivityResult result) {
    final isNowOnline = result != ConnectivityResult.none;
    final wasOffline = _previousResult == ConnectivityResult.none;
    
    // Update previous result BEFORE checking condition
    _previousResult = result;
    // Now only sync if transitioning from offline to online
    if (wasOffline && isNowOnline) {
      print('✅ Internet reconnected, syncing...');
      _syncPendingData();
    }


    // Store the latest state for next change
    _previousResult = result;

    setState(() {
      _isOnline =isNowOnline;
    });
  });
}
  // Cancel the subscription to avoid memory leaks
  @override
  void dispose() {
    _connectivitySubscription.cancel();
    super.dispose();
  }


// Sync pending data if the device is online
  Future<void> _syncPendingData() async {
    print('syncing');
  final prefs = await SharedPreferences.getInstance();
  print('Saved: ${prefs.getString('pending_attributes')}');

  final pendingData = prefs.getString('pending_attributes_$accessToken');

  if (pendingData != null) {
    final data = jsonDecode(pendingData);
    print('Pending data found: $data'); 
    try {
      await _sendAttributes(
        payload: data,
        successMessage: 'Synced pending data!',
        onDone: (msg) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(msg)),
          );
        },
      );
      await prefs.remove('pending_attributes_$accessToken');
    } catch (e) {
      print('Sync failed: $e');
    }
  }
}

  // Load sensors dynamically based on ThingsBoard data
Future<void> _loadSensors() async {
  setState(() {
    isLoading = true;
  });

  final url = Uri.parse('https://demo.thingsboard.io/api/v1/$accessToken/attributes');

  try {
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);
      final clientAttributes = data['client'];

      // **Check if clientAttributes is null or empty**
      if (clientAttributes == null || clientAttributes.isEmpty) {
        setState(() {
          isLoading = false;
        });
        return;
      }

      sensors.clear();
      final Map<String, Map<String, dynamic>> tempSensors = {};

      clientAttributes.forEach((key, value) {
        if (value != 'nan') {
          final match = RegExp(r'([A-Za-z]+\d*)(Mac|Timer)').firstMatch(key);

          if (match != null) {
            final sensorName = match.group(1)!; // e.g., Temp1 or Door1
            final attributeType = match.group(2)!; // MAC or Timer

            tempSensors.putIfAbsent(sensorName, () => {});

            if (attributeType == 'Mac') {
              tempSensors[sensorName]!['mac'] = value;
              tempSensors[sensorName]!['key'] = key;
            } else if (attributeType == 'Timer') {
              tempSensors[sensorName]!['interval'] = int.tryParse(value.toString());
              tempSensors[sensorName]!['keyInt'] = key;
            }
          }
        }
      });

      tempSensors.forEach((sensorName, attributes) {
        if (attributes.containsKey('mac') && attributes.containsKey('interval')) {
          // Determine type based on prefix
          String type;
          if (sensorName.startsWith('SHT')) {
            type = 'Temperature';
          } else if (sensorName.startsWith('Door')) {
            type = 'Door';
           } 
           else {
            type = 'Unknown';
          }

          sensors.add({
            "type": type,
            "mac": attributes['mac'],
            "interval": attributes['interval'],
            "key": attributes['key'],
            "keyInt": attributes['keyInt'],
          });
        }
      });

      setState(() {
        thingsBoardData = clientAttributes;
        isLoading = false;
      });
    } else {
      throw Exception('Failed to load data');
    }
  } catch (e) {
    setState(() {
      isLoading = false;
    });
    print('Error: $e');
  }
}

//   void _showThingsBoardData(BuildContext context) {
//   showDialog(
//     context: context,
//     builder: (ctx) {
//       return AlertDialog(
//         title: const Text('ThingsBoard Data'),
//         content: SingleChildScrollView(
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Text("ThingsBoard Data:"),
//               Text(thingsBoardData.toString()),
//             ],
//           ),
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(ctx),
//             child: const Text('Close'),
//           ),
//         ],
//       );
//     },
//   );
// }

Future<String?> _navigateToScanner(BuildContext context) async {
  final result = await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => const QRScanScreen(scanType: QRScanType.macAddress),
    ),
  );

  if (result != null && result['mac'] != null) {
    return result['mac']; 
  }

  return null; // Return null if scan cancelled or failed
}



  @override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: PreferredSize(
      preferredSize: Size.fromHeight(40.h), 
      child: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back, size: 22.sp), 
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Sensor Management', style: TextStyle(fontSize: 17.sp)),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, size: 24.h),
            onPressed: () {
              setState(() => _loadSensors());
            },
          ),
          // IconButton(
          //   icon: Icon(Icons.info_outline, size: 24.h),
          //   onPressed: () => _showThingsBoardData(context),
          // ),
        ],
      ),
    ),
    body: Stack(
      children: [
        Positioned.fill(
          child: Opacity(
            opacity: 1,
            child: Image.asset(
              'images/background.png',
              fit: BoxFit.cover,
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.all(8.w),
          child: Column(
            children: [
              SizedBox(height: 5.h,),
              _buildAddButton(),
              SizedBox(height: 5.h),
              isLoading ? _buildLoader() : _buildSensorList(),
            ],
          ),
        ),
      ],
    ),
  );
}


  Widget _buildAddButton() {
  return Padding(
    padding: EdgeInsets.symmetric(horizontal: 10.w),
    child: ElevatedButton.icon(
      icon: Icon(
        Icons.add,
        size: 20.h,
        color: Color.fromARGB(255, 42, 62, 173),
      ),
      label: Text(
        'Add New Sensor',
        style: TextStyle(
          color: Color.fromARGB(255, 42, 62, 173),
          fontSize: 12.sp,
        ),
      ),
      style: ElevatedButton.styleFrom(
        padding: EdgeInsets.symmetric(vertical: 7.sp , horizontal: 8.sp),
        backgroundColor: Colors.white, 
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.r),
        ),
      ),
      onPressed: () => _showAddDialog(context),
    ),
  );
}


  Widget _buildLoader() {
  return Expanded(
    child: Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: Colors.white),
          SizedBox(height: 16.h),
          Text('Loading sensors...',
              style: TextStyle(color: Colors.white, fontSize: 16.sp)),
        ],
      ),
    ),
  );
}

  Widget _buildSensorList() {
    return Expanded(
      child:
          sensors.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                itemCount: sensors.length,
                itemBuilder: (ctx, i) => _buildSensorCard(i),
              ),
    );
  }

  Widget _buildEmptyState() {
  return Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.sensors, size: 64.sp, color: Colors.white),
        SizedBox(height: 16.h),
        Text(
          'No sensors configured',
          style: TextStyle(
            color: Colors.white,
            fontSize: 17.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          'Add Your First Sensor',
          style: TextStyle(
            color: Colors.white,
            fontSize: 15.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    ),
  );
}

  Widget _buildSensorCard(int index) {
  final sensor = sensors[index];
  return Card(
    margin: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 8.h),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12.r),
    ),
    child: Padding(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h), // adjustable internal padding
      child: Row(
        children: [
          Icon(
            sensor["type"] == "Temperature" ? Icons.thermostat : Icons.door_front_door,
            color: Colors.blue,
            size: 28.sp,
          ),
          SizedBox(width: 12.w), // spacing between icon and text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "${sensor["type"]} Sensor",
                  style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w500),
                ),
                SizedBox(height: 2.h),
                Text("Key: ${sensor["key"].substring(0, 4)}", style: TextStyle(fontSize: 13.sp)),
                Text("MAC: ${sensor["mac"]}", style: TextStyle(fontSize: 13.sp)),
                Text("Interval: ${sensor["interval"]} min", style: TextStyle(fontSize: 13.sp)),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, size: 22.sp),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10.r),
            ),
            itemBuilder: (context) => [
              PopupMenuItem<String>(
                value: 'edit',
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 4.h),
                  child: Text('Edit Interval', style: TextStyle(fontSize: 14.sp)),
                ),
              ),
              PopupMenuItem<String>(
                value: 'replace',
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 4.h),
                  child: Text('Replace MAC', style: TextStyle(fontSize: 14.sp)),
                ),
              ),
              PopupMenuItem<String>(
                value: 'delete',
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 4.h),
                  child: Text('Delete', style: TextStyle(color: Colors.red, fontSize: 14.sp)),
                ),
              ),
            ],
            onSelected: (value) {
              if (value == 'edit') {
                _showIntervalDialog(context, index);
              } else if (value == 'replace') {
                _showReplaceMacDialog(context, index);
              } else if (value == 'delete') {
                _showDeleteDialog(context, index);
              }
            },
          ),
        ],
      ),
    ),
  );
}

  

  Widget buildDialogContent({
  required bool isLoading,
  required String? resultMessage,
  required Widget formFields,
}) {
  return Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (isLoading && closeloading == false)
         Padding(
          padding: EdgeInsets.only(top: 20.h),
          child: CircularProgressIndicator(color: Color.fromARGB(255, 42, 62, 173),),
        ),
      if (resultMessage != null) ...[
        SizedBox(height: 20.h),
        Icon(
          resultMessage.endsWith('Successfully') ? Icons.check_circle : Icons.error,
          color: resultMessage.endsWith('Successfully') ? Colors.green : Colors.red,
          size: 50.sp,
        ),
        SizedBox(height: 10.h),
        Text(
          resultMessage,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16.sp,
            color: resultMessage.endsWith('Successfully') ? Colors.green : Colors.red,
          ),
        ),
      ],
      if (resultMessage == null) formFields,
    ],
  );
}

List<Widget> buildDialogActions({
  required BuildContext context,
  required VoidCallback onConfirm,
  required bool showConfirmButton,
}) {
  return [
    if (showConfirmButton)
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          TextButton(
            onPressed: onConfirm,
            child: Text(
              'Confirm',
              style: TextStyle(color: Color.fromARGB(255, 42, 62, 173), fontSize: 17.sp),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.red, fontSize: 17.sp),
            ),
          ),
        ],
      ),
    if (!showConfirmButton)
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text('OK', style: TextStyle(fontSize: 16.sp , color:Color.fromARGB(255, 42, 62, 173), )),
      ),
  ];
}
  bool macExists(String newMac) {
  return sensors.any((sensor) => sensor['mac'] == newMac);
}

  Widget buildMacAddressInput({
  required List<TextEditingController> controllers,
  required List<FocusNode> focusNodes,
  required void Function(String fullMac) onMacChanged,
  required BuildContext dialogContext,
  bool enableQrScan = false,
}) {
  return Column(
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
  for (int i = 0; i < 6; i++) ...[
    Container(
      width: 31.w, // responsive width
      child: TextField(
        controller: controllers[i],
        cursorColor: const Color.fromARGB(255, 42, 62, 173),
        focusNode: focusNodes[i],
        maxLength: 2,
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 14.sp),
        decoration: InputDecoration(
          counterText: '',
          contentPadding: EdgeInsets.symmetric(vertical: 7.h),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(
              color: Color.fromARGB(255, 42, 62, 173), // Border color when focused
            ),
            borderRadius: BorderRadius.circular(10.r), // Keep consistent border radius
          ),
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(
              color: Colors.grey, // Default border color
            ),
            borderRadius: BorderRadius.circular(10.r), // Keep consistent border radius
          ),
        ),
        onChanged: (value) {
          if (value.length == 2 && i < 5) {
            focusNodes[i + 1].requestFocus();
          } else if (value.isEmpty && i > 0) {
            focusNodes[i - 1].requestFocus();
          }
          final mac = controllers.map((c) => c.text).join(":").toLowerCase();
          onMacChanged(mac);
        },
      ),
    ),
    if (i < 5)
      Padding(
        padding: EdgeInsets.symmetric(horizontal: 2.w),
        child: Text(":", style: TextStyle(fontSize: 16.sp)),
      ),
  ],
],

      ),
      if (enableQrScan)
        Padding(
          padding: EdgeInsets.only(top: 12.h),
          child: IconButton(
            icon: Icon(Icons.qr_code, size: 30.sp),
            onPressed: () async {
              String? scannedMac = await _navigateToScanner(dialogContext);
              if (scannedMac != null) {
                final parts = scannedMac.split(":");
                for (int i = 0; i < 6; i++) {
                  controllers[i].text = parts[i];
                }
                final mac = controllers.map((c) => c.text).join(":").toLowerCase();
                onMacChanged(mac);
              }
            },
          ),
        ),
    ],
  );
}

  
  void _showReplaceMacDialog(BuildContext context, int index) {
  List<TextEditingController> macControllers = List.generate(6, (_) => TextEditingController());
  List<FocusNode> macFocusNodes = List.generate(6, (_) => FocusNode());
  String? resultMessage;
  String newMac = "";
  final String key = sensors[index]["key"];
  bool isReplacing = false;

  showDialog(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (context, setState) {
          return Center(
            child: SingleChildScrollView(
              child: AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                title: resultMessage == null
                    ? Text('Replace MAC Address', style: TextStyle(fontSize: 20.sp))
                    : null,
                content: buildDialogContent(
                  isLoading: isReplacing,
                  resultMessage: resultMessage,
                  formFields: buildMacAddressInput(
                    controllers: macControllers,
                    focusNodes: macFocusNodes,
                    dialogContext: ctx,
                    onMacChanged: (val) => newMac = val,
                    enableQrScan: true,
                  ),
                ),
                actions: buildDialogActions(
                  context: ctx,
                  onConfirm: () async {
                    if (newMac.replaceAll(":", "").length == 12) {
                      if (macExists(newMac)) {
                        setState(() {
                          resultMessage = 'This sensor is already added';
                        });
                        return;
                      }
                      setState(() {
                        isReplacing = true;
                        resultMessage = null;
                      });
                      await _sendAttributes(
                        payload: {key: newMac},
                        onDone: (String message) {
                          setState(() {
                            isReplacing = false;
                            resultMessage = message;
                          });
                        },
                        successMessage: 'MAC address updated Successfully',
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Not Completed MAC Address !!!')),
                      );
                    }
                  },
                  showConfirmButton: resultMessage == null,
                ),
              ),
            ),
          );
        },
      );
    },
  );
}


  void _showAddDialog(BuildContext context) async {
  String? type;
  int interval = 30;
  String mac = "";
  String? resultmess;
  bool isAdding = false;
  // List of all types
  final List<String> allTypes = ['Temperature', 'Door'];

  final List<TextEditingController> macControllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> macFocusNodes =
      List.generate(6, (_) => FocusNode());

  showDialog(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (context, setStateDialog) {
          return Center(
            child: SingleChildScrollView(
              child: AlertDialog(
                title: resultmess == null
                    ? Text('Add Sensor', style: TextStyle(fontSize: 20.sp))
                    : null,
                content: buildDialogContent(
                  isLoading: isAdding,
                  resultMessage: resultmess,
                  formFields: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                    SizedBox(height: 4.h),
                      Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(horizontal: 10.w),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: Text(
                              'Select Sensor Type',
                              style: TextStyle(fontSize: 15.sp , fontWeight: FontWeight.bold),
                            ),
                          ),
                          SizedBox(height: 4.h),
                          ...allTypes.map((t) {
                              return RadioListTile<String>(
                                title: Text(
                                  t,
                                  style: TextStyle(fontSize: 14.sp),
                                ),
                                value: t,
                                groupValue: type,
                                onChanged: (val) {
                                  setStateDialog(() {
                                    type = val;
                                  });
                                },
                                dense: true,
                                contentPadding: EdgeInsets.symmetric(horizontal: 4.w),
                                visualDensity: VisualDensity.compact,
                                activeColor: Color.fromARGB(255, 42, 62, 173), // Dot color
                                controlAffinity: ListTileControlAffinity.leading,
                              );
                            }),

                        ],
                      ),
                    ),
                      SizedBox(height: 5.h),
                      Center(
                        child: Text(
                              'Enter MAC Addrress',
                              style: TextStyle(fontSize: 15.sp , fontWeight: FontWeight.bold),
                            ),
                      ),
                      SizedBox(height: 4.h),
                      // MAC Address Input
                      buildMacAddressInput(
                        controllers: macControllers,
                        focusNodes: macFocusNodes,
                        dialogContext: context,
                        enableQrScan: true,
                        onMacChanged: (newMac) {
                          mac = newMac;
                        },
                      ),

                      SizedBox(height: 16.h),
                      
                      Center(
                        child: Text(
                              'Update Interval (minutes)',
                              style: TextStyle(fontSize: 15.sp , fontWeight: FontWeight.bold),
                            ),
                      ),
                      // Interval Slider
                      _buildIntervalSlider(
                        interval: interval,
                        context: context,
                        onChanged: (val) =>
                            setStateDialog(() => interval = val),
                      ),

                      // Validation messages
                      if (type == "Temperature" &&
                          sensors
                                  .where((s) => s["type"] == "Temperature")
                                  .length >=
                              4)
                        Text(
                          'Maximum of 4 temperature sensors allowed',
                          style: TextStyle(color: Colors.red, fontSize: 12.sp),
                        ),
                      if (type == "Door" &&
                          sensors.any((s) => s["type"] == "Door"))
                        Text(
                          'Only 1 door sensor allowed',
                          style: TextStyle(color: Colors.red, fontSize: 12.sp),
                        ),
                    ],
                  ),
                ),
                actions: buildDialogActions(
                  context: ctx,
                  onConfirm: () async {
                    if (type == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Missing Sensor Type !!'),
                        ),
                      );
                      return;
                    }

                    if (mac.replaceAll(":", "").length != 12) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Not Completed MAC Address !!'),
                        ),
                      );
                      return;
                    }

                    if (macExists(mac)) {
                      setStateDialog(() {
                        resultmess = 'This sensor is already added';
                      });
                      return;
                    }

                    setStateDialog(() {
                      isAdding = true;
                      closeloading = false;
                      resultmess = null;
                    });

                    await _addSensor(
                      context,
                      type: type!,
                      mac: mac,
                      interval: interval,
                      onDone: (String resultMessage) {
                        setStateDialog(() {
                          isAdding = false;
                          resultmess = resultMessage;
                        });
                      },
                    );
                  },
                  showConfirmButton: resultmess == null,
                ),
              ),
            ),
          );
        },
      );
    },
  );
}



  Future<void> _addSensor(BuildContext context, {
  required String type,
  required String mac,
  required int interval,
  required Function(String) onDone,
}) async {
  // Validation
  if (type == "Temperature" &&
      sensors.where((s) => s["type"] == "Temperature").length >= 4) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Maximum of 4 temperature sensors allowed')),
    );
    closeloading = true;
    return;
  }

  if (type == "Door" &&
      sensors.any((s) => s["type"] == "Door")) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Only 1 door sensor allowed')),
    );
    closeloading = true;
    return;
  }

  // Generate key
  final key = type == "Door"
      ? "Door"
      : () {
          for (int i = 1; i <= 4; i++) {
            final tempKey = 'SHT$i';
            final exists = sensors.any((sensor) => (sensor['key'] as String).startsWith(tempKey));
            if (!exists) return tempKey;
          }
        }();

  final payload = {
    '${key}Mac': mac,
    '${key}Timer': interval,
  };

  await _sendAttributes(
    payload: payload,
    onDone: onDone,
    successMessage: 'Sensor Added Successfully',
  );
}



  void _showIntervalDialog(BuildContext context, int index) {
  int interval = 30;
  final String keyInt = sensors[index]["keyInt"];
  String? resultMessage;
  bool isSaving = false;

  showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setStateDialog) {
        return Center(
          child: SingleChildScrollView(
            child: AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
              title: resultMessage == null
                  ? Text(
                      'Update Interval (minutes)',
                      style: TextStyle(fontSize: 20.sp),
                    )
                  : null,
              contentPadding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
              content: buildDialogContent(
                isLoading: isSaving,
                resultMessage: resultMessage,
                formFields: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(height: 2.h),
                    _buildIntervalSlider(
              interval: interval,
              context: context,
              onChanged: (val) => setStateDialog(() => interval = val),),
                  ],
                ),
              ),
              actionsPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
              actions: buildDialogActions(
                context: ctx,
                onConfirm: () async {
                  setStateDialog(() {
                    isSaving = true;
                    resultMessage = null;
                  });

                  await _sendAttributes(
                    payload: {keyInt: interval},
                    onDone: (String resultMess) {
                      setStateDialog(() {
                        isSaving = false;
                        resultMessage = resultMess;
                      });
                    },
                    successMessage: 'Interval updated Successfully',
                  );
                },
                showConfirmButton: !isSaving && resultMessage == null,
              ),
            ),
          ),
        );
      },
    ),
  );
}

Widget _buildIntervalSlider({
  required int interval,
  required void Function(int) onChanged,
  required BuildContext context,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      SliderTheme(
        data: SliderTheme.of(context).copyWith(
          trackHeight: 3.h, // Responsive track height
          thumbShape: RoundSliderThumbShape(
            enabledThumbRadius: 10.r, // Responsive thumb size
          ),
          overlayShape: RoundSliderOverlayShape(
            overlayRadius: 18.r, // Responsive overlay size
          ),
          activeTrackColor: const Color.fromARGB(255, 42, 62, 173),
          inactiveTrackColor: const Color.fromARGB(255, 136, 162, 207),
          thumbColor: const Color.fromARGB(255, 42, 62, 173),
          overlayColor: const Color.fromARGB(255, 42, 62, 173).withAlpha(32),
        ),
        child: Container(
          width: 280.w, // Responsive width for slider container
          child: Slider(
            value: interval.toDouble(),
            min: 1,
            max: 60,
            divisions: 59,
            onChanged: (v) => onChanged(v.toInt()),
          ),
        ),
      ),
      SizedBox(height: 6.h),
      Center(
        child: Text(
          '$interval minutes',
          style: TextStyle(fontSize: 13.sp),
        ),
      ),
    ],
  );
}



  void _showDeleteDialog(BuildContext context, int index) {
  final String key = sensors[index]["key"];
  final String keyInt = sensors[index]["keyInt"]; 

  showDialog(
    context: context,
    builder: (ctx) {
      String? deleteResultMessage;
      bool isDeleting = false;

      return StatefulBuilder(
        builder: (context, setStateDialog) {
          return Center(
            child: SingleChildScrollView(
              child: AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                title: deleteResultMessage == null
                    ? Text(
                        'Are you sure you want to delete this sensor?',
                        style: TextStyle(fontSize: 20.sp), 
                      )
                    : null,
                contentPadding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h), 
                content: buildDialogContent(
                  isLoading: isDeleting,
                  resultMessage: deleteResultMessage,
                  formFields: const SizedBox.shrink(), // no form fields needed for delete
                ),
                actionsPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h), 
                actions: buildDialogActions(
                  context: ctx,
                  onConfirm: () async {
                    setStateDialog(() {
                      isDeleting = true;
                      deleteResultMessage = null;
                    });
              
                    await _sendAttributes(
                      payload: { key: 'nan', keyInt: 'nan' }, // Sending 'nan' to delete the sensor
                      onDone: (String resultMessage) {
                        setStateDialog(() {
                          isDeleting = false;
                          deleteResultMessage = resultMessage;
                        });
                      },
                      successMessage: 'Sensor deleted Successfully',
                    );
                  },
                  showConfirmButton: !isDeleting && deleteResultMessage == null,
                ),
              ),
            ),
          );
        },
      );
    },
  );
}


/// Sends a POST with [payload] to ThingsBoard, reloads sensors,  
/// and calls [onDone] with either [successMessage] or the error.
Future<void> _sendAttributes({
  required Map<String, dynamic> payload,
  required void Function(String result) onDone,
  required String successMessage,
}) async {
  final uri = Uri.parse('https://demo.thingsboard.io/api/v1/$accessToken/attributes');
  try {
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );

    if (response.statusCode == 200) {
      await _loadSensors();
      onDone(successMessage);  // <- Use custom message 
    } else {
      final errorMsg = _handleError(response.statusCode, response.reasonPhrase);
      onDone(errorMsg);
    }
  } catch (e) {
      if (e is SocketException) {
    onDone('You are currently offline. Your changes have been saved and will automatically sync once you’re back online');
    //////////
    final prefs = await SharedPreferences.getInstance();
   await prefs.setString('pending_attributes_$accessToken', jsonEncode(payload));
    ////////////////
  } else {
      onDone('Exception: $e');
  }
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

}