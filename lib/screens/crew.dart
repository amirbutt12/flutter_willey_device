import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart'; // Ensure this is in your pubspec.yaml
import 'shared_mixin.dart';
import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart'; // Import SharedPreferences

class CrewScreen extends StatefulWidget {
  final BluetoothDevice device; // Ensure to pass this from the previous screen

  const CrewScreen({super.key, required this.device});

  @override
  _CrewScreenState createState() => _CrewScreenState();
}

class _CrewScreenState extends State<CrewScreen> with SharedMixin {
  final TextEditingController _CrewNameController =
      TextEditingController(); // Text controller for device name
  final TextEditingController _CrewPassController =
      TextEditingController(); // Text controller for user name

  BluetoothCharacteristic? _characteristic;
  BluetoothConnectionState _connectionState =
      BluetoothConnectionState.disconnected;
  List<BluetoothService> _services = [];
  late StreamSubscription<BluetoothConnectionState>
      _connectionStateSubscription;

  static const String characteristicUuid =
      "beb5483e-36e1-4688-b7f5-ea07361b26a8";

  @override
  void initState() {
    super.initState();

    loadPreferencesCred().then((_) {
      // Optionally use setState to update UI when preferences are loaded
      setState(() {
        print("Loaded deviceName: $deviceName and userName: $userName");
      });
    });
    _loadPreferences();
    _connectionStateSubscription =
        widget.device.connectionState.listen((state) async {
      _connectionState = state;
      setState(() {}); // Update UI based on connection state

      if (state == BluetoothConnectionState.connected) {
        try {
          await widget.device.requestMtu(512);
        } catch (e) {
          print("Failed to request MTU: $e");
        }
        await _discoverServices(); // Discover services when connected
      }
    });
  }

  @override
  void dispose() {
    _connectionStateSubscription.cancel();
    _CrewNameController.dispose();
    _CrewPassController.dispose();
    super.dispose();
  }

  Future<void> _discoverServices() async {
    _services = await widget.device.discoverServices();
    for (var service in _services) {
      for (var characteristic in service.characteristics) {
        if (characteristic.uuid.toString() == characteristicUuid) {
          _characteristic = characteristic;
          print("Characteristic found");
          return;
        }
      }
    }
  }

  // Send JSON data to Bluetooth device
  Future<void> _sendJsonData(Map<String, dynamic> jsonData) async {
    if (_characteristic != null &&
        _connectionState == BluetoothConnectionState.connected) {
      print("Sending JSON: $jsonData");
      String jsonString = json.encode(jsonData);
      List<int> dataToSend = utf8.encode(jsonString);

      await _characteristic!.write(dataToSend, withoutResponse: false);
      print("Sent JSON data: $jsonString");
    } else {
      print("Bluetooth is not connected or characteristic is null");
    }
  }

  // Load saved device name and user name from SharedPreferences
  Future<void> _loadPreferences() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? savedcrewName = prefs.getString('crewName');
    String? savedcrewPass = prefs.getString('crewPass');
    setState(() {
      if (savedcrewName != null) _CrewNameController.text = savedcrewName;
      if (savedcrewPass != null) _CrewPassController.text = savedcrewPass;
      crewName = savedcrewName!;
      crewPass = savedcrewPass!;
    });
  }

  // Save device name and user name to SharedPreferences
  Future<void> _savePreferences(String crewName, String crewPass) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('crewName', crewName);
    await prefs.setString('crewPass', crewPass);

    // Show snackbar to confirm saving
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Device and User Name saved successfully!')),
    );
  }

  // Send device name and user name as JSON
  Future<void> _sendNamesAsJson() async {
    crewName = _CrewNameController.text.trim();
    crewPass = _CrewPassController.text.trim();
    if (crewName.isNotEmpty && crewPass.isNotEmpty) {
      Map<String, dynamic> jsonData = {
        "command": "update_crew_name",
        "crew_name": crewName,
        "crew_pass": crewPass,
      };
      await _sendJsonData(jsonData); // Send the names as JSON
      await _savePreferences(crewName, crewPass); // Save to preferences
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.device.name,
          style: const TextStyle(fontSize: 14.0, color: Colors.white),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller:
                  _CrewNameController, // Text controller for device name
              decoration: const InputDecoration(
                labelText: 'Crew Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _CrewPassController, // Text controller for user name
              decoration: const InputDecoration(
                labelText: 'Crew Pass',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            TextButton(
              onPressed: _sendNamesAsJson, // Send device and user name as JSON
              child: const Text('Send Crew as JSON'),
            ),
          ],
        ),
      ),
    );
  }
}
