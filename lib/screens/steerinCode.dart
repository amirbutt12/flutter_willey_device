import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../widgets/characteristic_tile.dart';

bool _isForward = true; // Track current direction, true for forward

class DeviceScreen extends StatefulWidget {
  final BluetoothDevice device;

  const DeviceScreen({super.key, required this.device});

  @override
  _DeviceScreenState createState() => _DeviceScreenState();
}

class _DeviceScreenState extends State<DeviceScreen> {
  double _rotationAngle = 0.0; // Initial rotation angle set to 0 degrees
  Offset _startPosition = Offset.zero; // Initial position set to (0, 0)
  int _acceleration = 0; // Initial acceleration value (0 to 255)
  final int _accelerationStep = 5; // Acceleration increment step
  bool _isAccelerating = false; // Track whether accelerating or not
  Timer? _accelerationTimer; // Timer for gradual acceleration release
  Timer? _decelerationTimer; // Timer for gradual deceleration release
  Timer? _sendDataTimer; // Timer to send data every 100 ms
  late BluetoothCharacteristic _characteristic;

  @override
  void initState() {
    super.initState();
    _connectToDevice();
    _startSendingData(); // Start sending data every 100ms
  }

  Future<void> _connectToDevice() async {
    try {
      await widget.device.connect();
      List<BluetoothService> services = await widget.device.discoverServices();
      for (var service in services) {
        for (var characteristic in service.characteristics) {
          if (characteristic.uuid.toString() == 'your-characteristic-uuid') {
            _characteristic = characteristic;
          }
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to connect to ${widget.device.name}')),
      );
    }
  }

  void _updateRotation(Offset currentPosition) {
    RenderBox box = context.findRenderObject() as RenderBox;
    Offset center = box.localToGlobal(box.size.center(Offset.zero));
    double dx = currentPosition.dx - _startPosition.dx;
    double maxRotation = 90.0;
    double angle = dx.clamp(-maxRotation, maxRotation);

    setState(() {
      _rotationAngle = angle;
    });
  }

  void _resetRotation() {
    setState(() {
      _rotationAngle = 0.0;
    });
  }

  void _startAcceleration() {
    if (!_isAccelerating) {
      _isAccelerating = true;
      _decelerationTimer?.cancel();
      _accelerationTimer =
          Timer.periodic(const Duration(milliseconds: 50), (timer) {
        setState(() {
          _acceleration = (_acceleration + _accelerationStep).clamp(0, 255);
        });
      });
    }
  }

  void _stopAcceleration() {
    if (_isAccelerating) {
      _isAccelerating = false;
      _accelerationTimer?.cancel();
      _decelerationTimer =
          Timer.periodic(const Duration(milliseconds: 50), (timer) {
        setState(() {
          _acceleration = max(0, _acceleration - (_accelerationStep + 2));
          if (_acceleration == 0) {
            timer.cancel();
          }
        });
      });
    }
  }

  void _toggleAcceleration(bool isAccelerating) {
    if (isAccelerating) {
      _startAcceleration();
    } else {
      _stopAcceleration();
    }
  }

  void _toggleDirection() {
    setState(() {
      _isForward = !_isForward; // Toggle between forward and backward
    });
  }

  // Method to create JSON data
  String _createJsonData() {
    Map<String, dynamic> data = {'acc': _acceleration, 'rot': _rotationAngle};
    return jsonEncode(data);
  }

  // Method to send JSON data via Bluetooth
  void _sendJsonData() {
    String jsonData = _createJsonData();
    List<int> bytes = utf8.encode(jsonData);
    _characteristic.write(bytes, withoutResponse: true);
  }

  // Method to start sending data every 100ms
  void _startSendingData() {
    _sendDataTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      _sendJsonData();
    });
  }

  @override
  void dispose() {
    _accelerationTimer?.cancel();
    _decelerationTimer?.cancel();
    _sendDataTimer?.cancel();
    widget.device.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.device.name ?? widget.device.id.toString()),
        centerTitle: true,
      ),
      body: Row(
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Rotation Value: ${_rotationAngle.toStringAsFixed(1)}°',
                style: const TextStyle(fontSize: 12),
              ),
              Expanded(
                child: Center(
                  child: GestureDetector(
                    onTapDown: (details) {
                      _startPosition = details.globalPosition;
                    },
                    onPanUpdate: (details) {
                      Offset currentPosition = details.globalPosition;
                      _updateRotation(currentPosition);
                    },
                    onPanEnd: (_) {
                      _resetRotation();
                    },
                    onTapUp: (_) {
                      _resetRotation();
                    },
                    onTapCancel: () {
                      _resetRotation();
                    },
                    child: Padding(
                      padding: const EdgeInsets.only(left: 20.0),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Transform.rotate(
                          angle: _rotationAngle * pi / 180,
                          alignment: Alignment.center,
                          child: Image.asset(
                            'assets/images/steering_wheel.png',
                            width: 250,
                            height: 250,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text(
                'Direction',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _toggleDirection,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: const BoxDecoration(
                    color: Colors.blue,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isForward ? Icons.arrow_forward : Icons.arrow_back,
                    color: Colors.white,
                    size: 48,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 204),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Acceleration',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTapDown: (_) {
                  _toggleAcceleration(true);
                },
                onTapUp: (_) {
                  _toggleAcceleration(false);
                },
                onTapCancel: () {
                  _toggleAcceleration(false);
                },
                child: Container(
                  width: 120,
                  height: 180,
                  color: Colors.green,
                  child: Center(
                    child: Text(
                      _acceleration.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 24,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
