import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let result = super.application(application, didFinishLaunchingWithOptions: launchOptions)
    // Register the notification-settings channel here, where the FlutterViewController
    // and its engine are already attached to the window by super.application.
    if let controller = window?.rootViewController as? FlutterViewController {
      registerNotificationSettingsChannel(messenger: controller.binaryMessenger)
    }
    return result
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }

  // Registers the notification-settings MethodChannel so Flutter can open the
  // OS app-notification settings panel (FR-23, FR-25).
  // Uses UIApplication.openSettingsURLString which opens Settings.app at the
  // app-specific notification settings page on iOS 8+.
  private func registerNotificationSettingsChannel(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "metra/notification_settings",
      binaryMessenger: messenger
    )
    channel.setMethodCallHandler { (call, result) in
      guard call.method == "open" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard let url = URL(string: UIApplication.openSettingsURLString) else {
        result(FlutterError(
          code: "INVALID_URL",
          message: "openSettingsURLString is invalid",
          details: nil,
        ))
        return
      }
      UIApplication.shared.open(url, options: [:], completionHandler: nil)
      result(nil)
    }
  }
}
