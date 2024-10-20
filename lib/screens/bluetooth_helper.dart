import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'dart:convert';
import 'dart:async';

// Helper class for Bluetooth functions
class BluetoothHelper {
  BluetoothCharacteristic? _characteristic;
  BluetoothConnectionState _connectionState =
      BluetoothConnectionState.disconnected;
  StreamSubscription<List<int>>? _characteristicSubscription;

  static const String characteristicUuid =
      "beb5483e-36e1-4688-b7f5-ea07361b26a8";

  // Discover services and characteristics
  Future<void> discoverServices(BluetoothDevice device) async {
    try {
      List<BluetoothService> services = await device.discoverServices();
      for (var service in services) {
        for (var characteristic in service.characteristics) {
          if (characteristic.uuid.toString() == characteristicUuid) {
            _characteristic = characteristic;
            print("Characteristic found");
            return;
          }
        }
      }
      print("Characteristic not found");
    } catch (e) {
      print("Error discovering services: $e");
    }
  }

  // Start receiving data from characteristic
  void startReceivingFromCharacteristic(Function(String) processReceivedData) {
    if (_characteristic != null) {
      _characteristicSubscription = _characteristic!.value.listen((value) {
        String receivedData = utf8.decode(value);
        print("Received data: $receivedData");
        processReceivedData(receivedData);
      });
      _characteristic!.setNotifyValue(true);
    } else {
      print("No characteristic found to receive data from");
    }
  }

  // Stop receiving data from characteristic
  void stopReceivingFromCharacteristic() {
    if (_characteristicSubscription != null) {
      _characteristicSubscription!.cancel();
      _characteristicSubscription = null;
      print("Stopped receiving from characteristic");
    }
  }

  // Send JSON data to Bluetooth device
  Future<void> sendJsonData(Map<String, dynamic> jsonData) async {
    if (_characteristic != null &&
        _connectionState == BluetoothConnectionState.connected) {
      try {
        String jsonString = json.encode(jsonData);
        List<int> dataToSend = utf8.encode(jsonString);
        await _characteristic!.write(dataToSend, withoutResponse: false);
        print("Sent JSON data: $jsonString");
      } catch (e) {
        print("Failed to send JSON data: $e");
      }
    } else {
      print("Bluetooth is not connected or characteristic is null");
    }
  }

  // Connect to the Bluetooth device
  Future<void> connectDevice(BluetoothDevice device) async {
    try {
      await device.connect();
      _connectionState = BluetoothConnectionState.connected;
      print("Connected to device");
    } catch (e) {
      print("Connection failed: $e");
    }
  }

  // Disconnect from the Bluetooth device
  Future<void> disconnectDevice(BluetoothDevice device) async {
    try {
      await device.disconnect();
      _connectionState = BluetoothConnectionState.disconnected;
      stopReceivingFromCharacteristic(); // Clean up characteristic subscription
      print("Disconnected from device");
    } catch (e) {
      print("Disconnection failed: $e");
    }
  }

  // Cancel ongoing connection
  Future<void> cancelConnection(BluetoothDevice device) async {
    try {
      await device.disconnect();
      _connectionState = BluetoothConnectionState.disconnected;
      stopReceivingFromCharacteristic(); // Clean up characteristic subscription
      print("Canceled connection");
    } catch (e) {
      print("Cancel connection failed: $e");
    }
  }
}
