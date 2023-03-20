import UIKit
import Flutter
import flutter_background_service_ios

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let controller = window.rootViewController as! FlutterViewController
    let backgroundChannel = FlutterMethodChannel(name: "flutter_background_service", binaryMessenger: controller.binaryMessenger)
    flutter_background_service.register(with: backgroundChannel)

    let backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "Background task") {
        // End the background task if it hasn't finished by the time the app enters foreground again
        UIApplication.shared.endBackgroundTask(backgroundTask)
    }
    flutter_background_service.start()


    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

}
