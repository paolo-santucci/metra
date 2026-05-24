import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    // Register the notification-settings channel via the implicit engine's binary
    // messenger. Under iOS-13+ UIApplicationSceneManifest (scene lifecycle),
    // window is nil at didFinishLaunchingWithOptions time — this callback fires
    // when the FlutterViewController for the first scene is initialised, at which
    // point engineBridge.binaryMessenger is valid (FR-23, FR-25).
    registerNotificationSettingsChannel(messenger: engineBridge.binaryMessenger)
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
