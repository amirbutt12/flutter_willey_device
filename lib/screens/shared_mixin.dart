import 'package:shared_preferences/shared_preferences.dart'; // Import SharedPreferences

mixin SharedMixin {
  String deviceName = "";
  String userName = "";
  String crewName = "";
  String crewPass = "";

  // Load saved device name, user name, crew name, and crew pass from SharedPreferences
  Future<void> loadPreferencesCred() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    // Retrieve saved values or set default values if null
    String? savedDeviceName = prefs.getString('device_name');
    String? savedUserName = prefs.getString('user_name');
    String? savedCrewName = prefs.getString('crewName');
    String? savedCrewPass = prefs.getString('crewPass'); // Fixed key

    // Use null-aware operators to provide default values if null
    deviceName = savedDeviceName ?? "null"; // Default to empty string
    userName = savedUserName ?? "null";
    crewName = savedCrewName ?? "null";
    crewPass = savedCrewPass ?? "null";
  }
}
