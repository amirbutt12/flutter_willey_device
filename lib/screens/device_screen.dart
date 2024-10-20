import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../widgets/service_tile.dart';
import '../widgets/characteristic_tile.dart';
import '../widgets/descriptor_tile.dart';
import '../utils/snackbar.dart';
import '../utils/extra.dart';
import 'dart:math';

bool _isForward = true; // Track current direction, true for forward
int counter = 0;

class DeviceScreen extends StatefulWidget {
  final BluetoothDevice device;

  const DeviceScreen({super.key, required this.device});

  @override
  State<DeviceScreen> createState() => _DeviceScreenState();
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
  String? _previousJsonData; // Variable to store previous JSON data

  int? _rssi;
  int? _mtuSize;
  BluetoothConnectionState _connectionState =
      BluetoothConnectionState.disconnected;
  List<BluetoothService> _services = [];
  bool _isDiscoveringServices = false;
  bool _isConnecting = false;
  bool _isDisconnecting = false;

  late StreamSubscription<BluetoothConnectionState>
      _connectionStateSubscription;
  late StreamSubscription<bool> _isConnectingSubscription;
  late StreamSubscription<bool> _isDisconnectingSubscription;
  late StreamSubscription<int> _mtuSubscription;
  Timer? _timer;
  final int _counter = 0;
  BluetoothCharacteristic? _characteristic;

  static const String characteristicUuid =
      "beb5483e-36e1-4688-b7f5-ea07361b26a8";

  @override
  void initState() {
    super.initState();

    _connectionStateSubscription =
        widget.device.connectionState.listen((state) async {
      _connectionState = state;
      if (state == BluetoothConnectionState.connected) {
        _services = []; // must rediscover services
        await widget.device.requestMtu(512, predelay: 0);
        await onDiscoverServicesPressed();
        _startWritingToCharacteristic();
      }
      if (state == BluetoothConnectionState.connected && _rssi == null) {
        _rssi = await widget.device.readRssi();
      }
      if (mounted) {
        setState(() {});
      }
    });

    _mtuSubscription = widget.device.mtu.listen((value) {
      _mtuSize = value;
      if (mounted) {
        setState(() {});
      }
    });

    _isConnectingSubscription = widget.device.isConnecting.listen((value) {
      _isConnecting = value;
      if (mounted) {
        setState(() {});
      }
    });

    _isDisconnectingSubscription =
        widget.device.isDisconnecting.listen((value) {
      _isDisconnecting = value;
      if (mounted) {
        setState(() {});
      }
    });
  }

  List<int> _getBytesFromJson(String jsonString) {
    return utf8.encode(jsonString);
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
    Map<String, dynamic> data = {
      'ac': _acceleration,
      'ro': _rotationAngle,
      'dr': _isForward
    };
    return jsonEncode(data);
  }

  // // Method to send JSON data via Bluetooth
  // void _sendJsonData() {
  //   String jsonData = _createJsonData();
  //   List<int> bytes = utf8.encode(jsonData);
  //   // _characteristic.write(bytes, withoutResponse: true);
  // }

  // // Method to start sending data every 100ms
  // void _startSendingData() {
  //   _sendDataTimer = Timer.periodic(Duration(milliseconds: 50), (timer) {
  //     _sendJsonData();
  //   });
  // }

  @override
  void dispose() {
    _connectionStateSubscription.cancel();
    _mtuSubscription.cancel();
    _isConnectingSubscription.cancel();
    _isDisconnectingSubscription.cancel();
    _timer?.cancel();
    super.dispose();
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

  Future onCancelPressed() async {
    try {
      await widget.device.disconnectAndUpdateStream(queue: false);
      Snackbar.show(ABC.c, "Cancel: Success", success: true);
    } catch (e) {
      Snackbar.show(ABC.c, prettyException("Cancel Error:", e), success: false);
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

  Future onDiscoverServicesPressed() async {
    if (mounted) {
      setState(() {
        _isDiscoveringServices = true;
      });
    }
    try {
      _services = await widget.device.discoverServices();
      Snackbar.show(ABC.c, "Discover Services: Success", success: true);
      _findCharacteristic();
    } catch (e) {
      Snackbar.show(ABC.c, prettyException("Discover Services Error:", e),
          success: false);
    }
    if (mounted) {
      setState(() {
        _isDiscoveringServices = false;
      });
    }
  }

  void _findCharacteristic() {
    for (BluetoothService service in _services) {
      for (BluetoothCharacteristic characteristic in service.characteristics) {
        if (characteristic.uuid.toString() == characteristicUuid) {
          print("Found Match Services ");
          print(characteristic.uuid.toString());
          _characteristic = characteristic;
          _startWritingToCharacteristic();
          break;
        }
      }
    }
  }

  void _startWritingToCharacteristic() {
    _timer = Timer.periodic(const Duration(milliseconds: 200), (timer) async {
      if (_characteristic != null) {
        try {
          String jsonString = _createJsonData();

          if (jsonString != _previousJsonData) {
            _characteristic!.write(_getBytesFromJson(jsonString),
                withoutResponse:
                    _characteristic!.properties.writeWithoutResponse);
            _previousJsonData = jsonString; // Update previous JSON data
            print("sending data $jsonString");
          }

          ///  Snackbar.show(ABC.c, "Write: Success", success: true);
          // if (_characteristic!.properties.read) {
          // //  await _characteristic!.read();
          // }
        } catch (e) {
          Snackbar.show(ABC.c, prettyException("Write Error:", e),
              success: false);
        }
      }
    });
  }

  void _stopWritingToCharacteristic() {
    _timer?.cancel();
  }

  Future onRequestMtuPressed() async {
    try {
      await widget.device.requestMtu(223, predelay: 0);
      Snackbar.show(ABC.c, "Request Mtu: Success", success: true);
    } catch (e) {
      Snackbar.show(ABC.c, prettyException("Change Mtu Error:", e),
          success: false);
    }
  }

  List<Widget> _buildServiceTiles(BuildContext context, BluetoothDevice d) {
    return _services
        .map(
          (s) => ServiceTile(
            service: s,
            characteristicTiles: s.characteristics
                .map((c) => _buildCharacteristicTile(c))
                .toList(),
          ),
        )
        .toList();
  }

  CharacteristicTile _buildCharacteristicTile(BluetoothCharacteristic c) {
    return CharacteristicTile(
      characteristic: c,
      descriptorTiles:
          c.descriptors.map((d) => DescriptorTile(descriptor: d)).toList(),
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

  Widget buildRemoteId(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Text('${widget.device.remoteId}'),
    );
  }

  Widget buildRssiTile(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        isConnected
            ? const Icon(Icons.bluetooth_connected)
            : const Icon(Icons.bluetooth_disabled),
        Text(((isConnected && _rssi != null) ? '${_rssi!} dBm' : ''),
            style: Theme.of(context).textTheme.bodySmall)
      ],
    );
  }

  Widget buildGetServices(BuildContext context) {
    return IndexedStack(
      index: (_isDiscoveringServices) ? 1 : 0,
      children: <Widget>[
        TextButton(
          onPressed: onDiscoverServicesPressed,
          child: const Text("Get Services"),
        ),
        const IconButton(
          icon: SizedBox(
            width: 18.0,
            height: 18.0,
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation(Colors.grey),
            ),
          ),
          onPressed: null,
        )
      ],
    );
  }

  Widget buildMtuTile(BuildContext context) {
    return ListTile(
        title: const Text('MTU Size'),
        subtitle: Text('$_mtuSize bytes'),
        trailing: IconButton(
          icon: const Icon(Icons.edit),
          onPressed: onRequestMtuPressed,
        ));
  }

  Widget buildConnectButton(BuildContext context) {
    return Row(children: [
      if (_isConnecting || _isDisconnecting) buildSpinner(context),
      TextButton(
          onPressed: _isConnecting
              ? onCancelPressed
              : (isConnected ? onDisconnectPressed : onConnectPressed),
          child: Text(
            _isConnecting ? "CANCEL" : (isConnected ? "DISCONNECT" : "CONNECT"),
            style: Theme.of(context)
                .primaryTextTheme
                .labelLarge
                ?.copyWith(color: Colors.white),
          ))
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldMessenger(
      key: Snackbar.snackBarKeyC,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.device.platformName),
          actions: [buildConnectButton(context)],
        ),

        /* 
        body: SingleChildScrollView(
          child: Column(
            children: <Widget>[
              buildRemoteId(context),
              ListTile(
                leading: buildRssiTile(context),
                title: Text(
                    'Device is ${_connectionState.toString().split('.')[1]}.'),
                trailing: buildGetServices(context),
              ),
              buildMtuTile(context),
              ..._buildServiceTiles(context, widget.device),
            ],
          ),
        ),

*/
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
      ),
    );
  }
}
