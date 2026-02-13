import Cocoa
import FlutterMacOS

final class DeepLinkRelay {
  static let shared = DeepLinkRelay()

  private init() {}

  private var pendingUrls: [String] = []
  var onIncomingUrl: ((String) -> Void)?

  func push(url: URL) {
    let value = url.absoluteString
    pendingUrls.append(value)
    onIncomingUrl?(value)
  }

  func takePending() -> [String] {
    let values = pendingUrls
    pendingUrls.removeAll()
    return values
  }
}

@main
class AppDelegate: FlutterAppDelegate {
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  override func application(_ application: NSApplication, open urls: [URL]) {
    for url in urls {
      DeepLinkRelay.shared.push(url: url)
    }
  }
}
