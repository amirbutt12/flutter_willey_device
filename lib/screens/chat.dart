import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'dart:ui' as ui;
import 'dart:async';
import 'dart:convert';
import '../utils/snackbar.dart';
import '../utils/extra.dart';
import 'package:intl/intl.dart'; // Import for date formatting

import 'shared_mixin.dart';
import 'dart:io'; // For platform check

class ChatScreen extends StatefulWidget with SharedMixin {
  final BluetoothDevice device;

  ChatScreen({super.key, required this.device});

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with SharedMixin {
  List<Map<String, dynamic>> messages = [];
  final bool _isDiscoveringServices = false;
  final bool _isConnecting = false;
  final bool _isDisconnecting = false;

  BluetoothCharacteristic? _characteristic;
  BluetoothConnectionState _connectionState =
      BluetoothConnectionState.disconnected;
  List<BluetoothService> _services = [];
  late StreamSubscription<BluetoothConnectionState>
      _connectionStateSubscription;
  late StreamSubscription<List<int>> _characteristicSubscription;

  static const String characteristicUuid =
      "beb5483e-36e1-4688-b7f5-ea07361b26a8";

  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isSending = false;
  @override
  Future<void> onDiscoverServicesPressed() async {
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

  void _startReceivingFromCharacteristic() {
    if (_characteristic != null) {
      _characteristicSubscription = _characteristic!.value.listen((value) {
        String receivedData = utf8.decode(value);
        print("Received data: $receivedData");
        if (receivedData.contains("sender")) {
          _processReceivedData(receivedData);
        }
      });
      _characteristic!.setNotifyValue(true);
    }
  }

  // Function to send JSON data
// Function to send JSON data to Bluetooth device
  Future<void> _sendJsonData(Map<String, dynamic> jsonData) async {
    if (_characteristic != null &&
        _connectionState == BluetoothConnectionState.connected) {
      print("Sending JSON chat $jsonData");
      // Encode the JSON object into a string and then into bytes
      String jsonString = json.encode(jsonData);
      List<int> dataToSend = utf8.encode(jsonString);

      // Write the data to the Bluetooth characteristic
      await _characteristic!.write(dataToSend, withoutResponse: false);

      // Print confirmation of the sent data
      print("Sent JSON data: $jsonString");
    } else {
      print("Bluetooth is not connected or characteristic is null");
    }
  }

  void _processReceivedData(String data) {
    // Assume you have stored the correct crew name and password in SharedPreferences or hardcoded values

    try {
      // Parse the received data as a JSON object
      Map<String, dynamic> jsonData = json.decode(data);

      // Extract the current time and format it as "HH:MM:SS AM/PM"
      String currentTime = DateFormat('hh:mm:ss a').format(DateTime.now());

      // Check if the message was not sent by the current user
      if (jsonData['isSentByMe'] == false) {
        // Extract crewName and crewPass from the JSON if available
        String receivedCrewName =
            jsonData.containsKey('crewName') && jsonData['crewName'] != null
                ? jsonData['crewName']
                : 'Unknown';
        String receivedCrewPass =
            jsonData.containsKey('crewPass') && jsonData['crewPass'] != null
                ? jsonData['crewPass']
                : 'Unknown';

        // Compare received crew name and password with stored values
        if (receivedCrewName != crewName || receivedCrewPass != crewPass) {
          // If they don't match, print an error message
          print(
              "Crew Name or Password doesn't match! Received crewName: $receivedCrewName, crewPass: $receivedCrewPass");
        } else {
          // If they match, add the decoded message to the messages list
          setState(() {
            messages.add({
              'id': jsonData['id'],
              'sender': jsonData['sender'],
              'message': jsonData['message'],
              'time': currentTime,
              'isSentByMe': jsonData['isSentByMe'],
              'crewName': receivedCrewName, // Include crewName
              'crewPass': receivedCrewPass, // Include crewPass
            });
          });

          // Scroll the UI to the bottom after a new message is added
          _scrollToBottom();

          // Print message details for debugging
          print(
              'Message from ${jsonData['sender']}: ${jsonData['message']} at ${jsonData['time']}');
          print('Crew Name: $receivedCrewName, Crew Pass: $receivedCrewPass');
        }
      }
    } catch (e) {
      // Print error if there is an issue decoding the JSON
      print("Error decoding JSON: $e");
    }
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

  @override
  void initState() {
    super.initState();
    loadPreferencesCred();

    // Listen to the device's connection state
    _connectionStateSubscription =
        widget.device.connectionState.listen((state) async {
      _connectionState = state;
      setState(() {}); // Update UI based on connection state

      if (state == BluetoothConnectionState.connected) {
        // Check if platform is Android before requesting MTU
        if (Platform.isAndroid) {
          try {
            await widget.device.requestMtu(512);
            print('MTU successfully requested on Android');
          } catch (e) {
            print('Failed to request MTU: $e');
          }
        } else {
          print('MTU request not needed on iOS');
        }

        // Discover services and start receiving data
        await onDiscoverServicesPressed();
        _startReceivingFromCharacteristic();
      }
    });
  }

  // Function to simulate sending a message
// Function to simulate sending a message
  void _sendMessage() {
    // Call the mixin function to load preferences
    loadPreferencesCred().then((_) {
      // Optionally use setState to update UI when preferences are loaded
      setState(() {
        print("Loaded deviceName: $deviceName and userName: $userName");
      });
    });

    if (_messageController.text.isNotEmpty) {
      // Create the new message JSON object
      String currentTime = DateFormat('hh:mm:ss a')
          .format(DateTime.now()); // Format as "HH:MM:SS AM/PM"

      Map<String, dynamic> newMessage = {
        "command": "chat", // This line indicates the command type
        "id": messages.length + 1,
        "sender": userName,
        "message": _messageController.text,
        "time": currentTime,
        "isSentByMe": true,
        "crewName": crewName,
        "crewPass": crewPass
      };

      setState(() {
        _isSending = true;

        // Add the new message to the messages list
        messages.add(newMessage);

        // Clear the text field
        _messageController.clear();
        _sendJsonData(newMessage);
        _isSending = false;
      });

      // Automatically scroll to the bottom after sending the message
      _scrollToBottom();

      // Send the message JSON to the Bluetooth device
    }
  }

  void _scrollToBottom() {
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  Widget _buildMessage(Map<String, dynamic> message) {
    bool isSentByMe = message['isSentByMe'];

    return Align(
      alignment: isSentByMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isSentByMe ? Colors.green[300] : Colors.grey[300],
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(10),
            topRight: const Radius.circular(10),
            bottomLeft: isSentByMe ? const Radius.circular(10) : Radius.zero,
            bottomRight: isSentByMe ? Radius.zero : const Radius.circular(10),
          ),
        ),
        child: Column(
          crossAxisAlignment:
              isSentByMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              message['sender'],
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              message['message'],
              style: const TextStyle(fontSize: 16, color: Colors.black),
            ),
            const SizedBox(height: 2),
            Text(
              message['time'],
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildSpinner(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(14.0),
      child: AspectRatio(
        aspectRatio: 1.0,
        child: CircularProgressIndicator(
          backgroundColor: Colors.black12,
          color: Colors.black26,
        ),
      ),
    );
  }

  bool get isConnected {
    return _connectionState == BluetoothConnectionState.connected;
  }

  Future onConnectPressed() async {
    try {
      await widget.device.connectAndUpdateStream();
      Snackbar.show(ABC.c, "Connect: Success", success: true);
    } catch (e) {
      if (e is FlutterBluePlusException &&
          e.code == FbpErrorCode.connectionCanceled.index) {
        // ignore connections canceled by the user
      } else {
        Snackbar.show(ABC.c, prettyException("Connect Error:", e),
            success: false);
      }
    }
  }

  Future onDisconnectPressed() async {
    try {
      await widget.device.disconnectAndUpdateStream();
      Snackbar.show(ABC.c, "Disconnect: Success", success: true);
    } catch (e) {
      Snackbar.show(ABC.c, prettyException("Disconnect Error:", e),
          success: false);
    }
  }

  Future onCancelPressed() async {
    try {
      await widget.device.disconnectAndUpdateStream(queue: false);
      Snackbar.show(ABC.c, "Cancel: Success", success: true);
    } catch (e) {
      Snackbar.show(ABC.c, prettyException("Cancel Error:", e), success: false);
    }
  }

  Widget buildConnectButton(BuildContext context) {
    return Row(children: [
      if (_isConnecting || _isDisconnecting) buildSpinner(context),
      Icon(
        isConnected ? Icons.circle : Icons.circle_outlined,
        color: isConnected
            ? Colors.green
            : Colors.red, // Green for online, Red for offline
        size: 16, // Adjust the size of the icon
      ),
      const SizedBox(width: 8), // Space between the icon and button text
      TextButton(
        onPressed: _isConnecting
            ? onCancelPressed
            : (isConnected ? onDisconnectPressed : onConnectPressed),
        child: Text(
          _isConnecting ? "CANCEL" : (isConnected ? "DISCONNECT" : "CONNECT"),
          style: Theme.of(context).primaryTextTheme.labelLarge?.copyWith(
                color: Colors.white,
              ),
        ),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.device.platformName,
          style: const TextStyle(
            fontSize: 14.0, // Smaller text size
            color: Colors.white,
          ),
        ),
        actions: [
          buildConnectButton(context),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              itemCount: messages.length,
              itemBuilder: (context, index) {
                return _buildMessage(messages[index]);
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _isSending ? null : _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
