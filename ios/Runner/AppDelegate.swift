import AudioToolbox
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
    let applicationAttentionChannel = FlutterMethodChannel(
      name: "com.yorks.app/application_attention",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    applicationAttentionChannel.setMethodCallHandler { call, result in
      if call.method == "playNotificationAlert" {
        DispatchQueue.main.async {
          AudioServicesPlayAlertSound(SystemSoundID(1007))
          result(nil)
        }
        return
      }
      guard call.method == "setAttention" else {
        result(FlutterMethodNotImplemented)
        return
      }
      let arguments = call.arguments as? [String: Any]
      let unreadCount = max(0, arguments?["unreadCount"] as? Int ?? 0)
      DispatchQueue.main.async {
        UIApplication.shared.applicationIconBadgeNumber = unreadCount
        result(nil)
      }
    }
  }
}
