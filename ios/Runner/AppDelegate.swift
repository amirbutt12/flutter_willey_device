import Flutter
import UIKit
import GoogleMaps
@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
       GMSServices.provideAPIKey("AIzaSyDgUnA2RM0XyXi36766JX-YBhkOWbdk3a4")
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

 


}
