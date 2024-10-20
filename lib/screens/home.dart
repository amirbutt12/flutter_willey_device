import 'package:flutter/material.dart';
import 'package:flutter_ble_scratch/screens/crew.dart';
import 'dart:ui' as ui;
import 'dart:ui';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:async';

import 'dart:async';
import 'dart:convert';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../widgets/service_tile.dart';
import '../widgets/characteristic_tile.dart';
import '../widgets/descriptor_tile.dart';
import '../utils/snackbar.dart';
import '../utils/extra.dart';
import 'dart:math';
import 'maps.dart';
import 'chat.dart';
import 'settings.dart';

// void main() {
//   runApp(HomeApp());
// }
class HomeApp extends StatefulWidget {
  final BluetoothDevice device;

  const HomeApp({super.key, required this.device});

  @override
  _HomeAppState createState() => _HomeAppState();
}

class _HomeAppState extends State<HomeApp> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Bottom Navigation',
      theme: ThemeData(
        brightness: Brightness.dark, // Apply dark theme
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Colors.black, // Black background
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Colors.black, // Black bottom navigation bar
          selectedItemColor:
              Colors.blueAccent, // Highlighted color for selected icon
          unselectedItemColor: Colors.white, // White color for unselected icons
        ),
      ),
      home: HomeScreen(
          device: widget.device), // Pass the BluetoothDevice to HomeScreen
    );
  }
}

class HomeScreen extends StatefulWidget {
  @override
  final BluetoothDevice device;

  const HomeScreen({super.key, required this.device});
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  // List of pages for each tab
  late List<Widget> _pages;
  @override
  void initState() {
    super.initState();
    // Initialize pages and pass the BluetoothDevice to MapScreen
    _pages = [
      MapScreen(device: widget.device), // Pass the BluetoothDevice here
      CrewScreen(device: widget.device),
      ChatScreen(
        device: widget.device,
      ),
      DashScreen(),
      SettingsScreen(
        device: widget.device,
      ),
    ];
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.map),
            label: 'Map',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people),
            label: 'Crew',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat),
            label: 'Chat',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dash',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

class DashScreen extends StatelessWidget {
  const DashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Dash Screen',
        style: TextStyle(color: Colors.white),
      ),
    );
  }
}
