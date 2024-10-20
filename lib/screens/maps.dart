import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'dart:async';
import 'dart:convert';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../widgets/service_tile.dart';
import '../widgets/characteristic_tile.dart';
import '../widgets/descriptor_tile.dart';
import '../utils/snackbar.dart';
import '../utils/extra.dart';
import 'shared_mixin.dart';
import 'dart:io'; // For platform check

class MapScreen extends StatefulWidget with SharedMixin {
  @override
  final BluetoothDevice device;

  MapScreen({super.key, required this.device});

  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with SharedMixin {
  final bool _isDiscoveringServices = false;
  final bool _isConnecting = false;
  final bool _isDisconnecting = false;
  // List to hold marker positions
  List<LatLng> markerPositions = [];

  BluetoothCharacteristic? _characteristic;
  BluetoothConnectionState _connectionState =
      BluetoothConnectionState.disconnected;
  List<BluetoothService> _services = [];
  late StreamSubscription<BluetoothConnectionState>
      _connectionStateSubscription;
  late StreamSubscription<List<int>> _characteristicSubscription;

  static const String characteristicUuid =
      "beb5483e-36e1-4688-b7f5-ea07361b26a8";

  final Completer<GoogleMapController> _controller = Completer();
  Set<Marker> _markers = {};
  final double _zoomLevel = 50.0;

  final Map<String, Marker> _deviceMarkers = {}; // Store markers by device name
  MapType _currentMapType =
      MapType.normal; // Add this line to track current map type

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
        print("Received data Map: $receivedData");
        _processReceivedData(receivedData);
      });
      _characteristic!.setNotifyValue(true);
    }
  }

  void _processReceivedData(String data) {
    try {
      // Parse the received data as a JSON object
      Map<String, dynamic> jsonData = json.decode(data);

      // Check if the command is present and handle it
      if (jsonData.containsKey('command')) {
        String command = jsonData['command']; // Accessing 'command'

        // Extract other values, checking for their existence and type
        String deviceName =
            jsonData.containsKey('name') ? jsonData['name'] : 'Unknown Device';
        double latitude = jsonData.containsKey('latitude')
            ? jsonData['latitude']?.toDouble() ?? 0.0
            : 0.0;
        double longitude = jsonData.containsKey('longitude')
            ? jsonData['longitude']?.toDouble() ?? 0.0
            : 0.0;
        double heading = jsonData.containsKey('heading')
            ? jsonData['heading']?.toDouble() ?? 0.0
            : 0.0;

        // Check crew name and password before updating marker
        String receivedCrewName =
            jsonData.containsKey('crewName') ? jsonData['crewName'] : '';
        String receivedCrewPass =
            jsonData.containsKey('crewPass') ? jsonData['crewPass'] : '';

        // Validate crew credentials
        if (command == 'navigate' &&
            receivedCrewName == crewName &&
            receivedCrewPass == crewPass) {
          _updateMarker(deviceName, latitude, longitude, heading);
        } else {
          // Print message if credentials do not match
          print("Invalid crew credentials. Marker not added.");
        }
      }
    } catch (e) {
      print("Error decoding JSON MAP: $e");
    }
  }

  void _adjustCameraPosition() async {
    loadPreferencesCred();
    if (markerPositions.isNotEmpty) {
      // Calculate bounds
      double south = markerPositions
          .map((pos) => pos.latitude)
          .reduce((a, b) => a < b ? a : b);
      double north = markerPositions
          .map((pos) => pos.latitude)
          .reduce((a, b) => a > b ? a : b);
      double west = markerPositions
          .map((pos) => pos.longitude)
          .reduce((a, b) => a < b ? a : b);
      double east = markerPositions
          .map((pos) => pos.longitude)
          .reduce((a, b) => a > b ? a : b);

      // Create bounds
      LatLngBounds bounds = LatLngBounds(
        southwest: LatLng(south, west),
        northeast: LatLng(north, east),
      );

      // Move the camera to include the bounds
      final GoogleMapController controller = await _controller.future;
      controller.animateCamera(
          CameraUpdate.newLatLngBounds(bounds, 50)); // Add padding if needed
    }
  }

  // Function to create or update a marker for a device
  void _updateMarker(String deviceName, double latitude, double longitude,
      double heading) async {
    final BitmapDescriptor customIcon = await _getBitmapFromIcon(
      Icons.navigation,
      Colors.blue,
      210.0,
    );

    Marker updatedMarker = Marker(
      markerId: MarkerId(deviceName),
      position: LatLng(latitude, longitude),
      icon: customIcon,
      rotation: heading,
      infoWindow: InfoWindow(title: deviceName),
      onTap: () {
        _goToLocation(latitude, longitude);
      },
    );

    setState(() {
      _deviceMarkers[deviceName] = updatedMarker;
      _markers = _deviceMarkers.values.toSet(); // Update the markers set
      markerPositions
          .add(LatLng(latitude, longitude)); // Add position to the list
      //  _adjustCameraPosition(); // Adjust camera position after adding the marker
    });
  }

  Future<BitmapDescriptor> _getBitmapFromIcon(
      IconData iconData, Color color, double size) async {
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    final paint = Paint()..color = color;

    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    textPainter.text = TextSpan(
      text: String.fromCharCode(iconData.codePoint),
      style: TextStyle(
        fontSize: size * 0.6, // Icon size depending on zoom
        fontFamily: iconData.fontFamily,
        color: Colors.blue, // Icon color
      ),
    );
    textPainter.layout();
    textPainter.paint(
        canvas,
        Offset(
            (size - textPainter.width) / 2, (size - textPainter.height) / 2));

    final img = await pictureRecorder
        .endRecording()
        .toImage(size.toInt(), size.toInt());
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.fromBytes(data!.buffer.asUint8List());
  }

  Future<void> _goToLocation(double latitude, double longitude) async {
    final GoogleMapController controller = await _controller.future;
    controller.animateCamera(
        CameraUpdate.newLatLngZoom(LatLng(latitude, longitude), 55));
  }

  Future onCancelPressed() async {
    try {
      await widget.device.disconnectAndUpdateStream(queue: false);
      Snackbar.show(ABC.c, "Cancel: Success", success: true);
    } catch (e) {
      Snackbar.show(ABC.c, prettyException("Cancel Error:", e), success: false);
    }
  }

  bool get isConnected {
    return _connectionState == BluetoothConnectionState.connected;
  }

  @override
  void dispose() {
    _connectionStateSubscription.cancel();
    _characteristicSubscription.cancel();
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Map Screen'),
        actions: [
          PopupMenuButton<MapType>(
            icon: const Icon(Icons.map),
            onSelected: (MapType selectedMapType) {
              setState(() {
                _currentMapType = selectedMapType; // Update the map type
              });
            },
            itemBuilder: (BuildContext context) {
              return [
                const PopupMenuItem(
                  value: MapType.normal,
                  child: Text('Normal'),
                ),
                const PopupMenuItem(
                  value: MapType.satellite,
                  child: Text('Satellite'),
                ),
                const PopupMenuItem(
                  value: MapType.terrain,
                  child: Text('Terrain'),
                ),
                const PopupMenuItem(
                  value: MapType.hybrid,
                  child: Text('Hybrid'),
                ),
              ];
            },
          ),
        ],
      ),
      body: isConnected
          ? Stack(
              children: [
                GoogleMap(
                  mapType: _currentMapType, // Set the map type
                  onMapCreated: (GoogleMapController controller) {
                    _controller.complete(controller);
                  },
                  markers: _markers,
                  initialCameraPosition: const CameraPosition(
                    target: LatLng(0, 0),
                    zoom: 21,
                  ),
                ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: FloatingActionButton(
                    onPressed: _adjustCameraPosition,
                    backgroundColor: Colors.transparent,
                    elevation: 0, // To remove any shadow
                    child: const Icon(
                      Icons.zoom_in_rounded,
                      color: Colors.blue,
                      size: 48, // Increase the icon size
                    ),
                  ),
                )
              ],
            )
          : buildSpinner(context),
    );
  }
}
