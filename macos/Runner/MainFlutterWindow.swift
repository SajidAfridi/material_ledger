import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  private var applicationAttentionChannel: FlutterMethodChannel?

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    let registrar = flutterViewController.registrar(
      forPlugin: "YorksApplicationAttention")
    applicationAttentionChannel = FlutterMethodChannel(
      name: "com.yorks.app/application_attention",
      binaryMessenger: registrar.messenger)
    applicationAttentionChannel?.setMethodCallHandler { [weak self] call, result in
      guard call.method == "setAttention" else {
        result(FlutterMethodNotImplemented)
        return
      }
      let arguments = call.arguments as? [String: Any]
      let unreadCount = max(0, arguments?["unreadCount"] as? Int ?? 0)
      let attentionRaised = arguments?["attentionRaised"] as? Bool ?? false
      let badgeLabel = unreadCount > 99 ? "99+" : "\(unreadCount)"
      self?.title = unreadCount > 0
        ? "(\(badgeLabel)) Yorks AC. & Ref."
        : "Yorks AC. & Ref."
      NSApplication.shared.dockTile.badgeLabel = unreadCount > 0 ? badgeLabel : nil
      NSApplication.shared.dockTile.display()
      if attentionRaised && !NSApplication.shared.isActive {
        NSApplication.shared.requestUserAttention(.informationalRequest)
      }
      result(nil)
    }

    super.awakeFromNib()
  }
}
