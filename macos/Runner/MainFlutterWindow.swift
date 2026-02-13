import Cocoa
import FlutterMacOS
import Vision

class MainFlutterWindow: NSWindow {
  private let ocrChannelName = "recipe_app/ocr"
  private let deepLinkChannelName = "recipe_app/deep_link"
  private var deepLinkChannel: FlutterMethodChannel?

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    setupOcrChannel(flutterViewController: flutterViewController)
    setupDeepLinkChannel(flutterViewController: flutterViewController)

    super.awakeFromNib()
  }

  private func setupOcrChannel(flutterViewController: FlutterViewController) {
    let channel = FlutterMethodChannel(
      name: ocrChannelName,
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )

    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else {
        result(FlutterError(code: "unavailable", message: "Window unavailable", details: nil))
        return
      }

      if call.method != "recognizeText" {
        result(FlutterMethodNotImplemented)
        return
      }

      guard let args = call.arguments as? [String: Any],
            let path = args["path"] as? String, !path.isEmpty else {
        result(FlutterError(code: "bad_args", message: "Missing image path", details: nil))
        return
      }

      self.recognizeText(atPath: path, result: result)
    }
  }

  private func setupDeepLinkChannel(flutterViewController: FlutterViewController) {
    let channel = FlutterMethodChannel(
      name: deepLinkChannelName,
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    deepLinkChannel = channel

    DeepLinkRelay.shared.onIncomingUrl = { [weak self] value in
      self?.deepLinkChannel?.invokeMethod("onIncomingUrl", arguments: value)
    }

    channel.setMethodCallHandler { call, result in
      if call.method == "getPendingUrls" {
        result(DeepLinkRelay.shared.takePending())
        return
      }
      result(FlutterMethodNotImplemented)
    }
  }

  private func recognizeText(atPath path: String, result: @escaping FlutterResult) {
    if #available(macOS 10.15, *) {
      let imageURL = URL(fileURLWithPath: path)
      guard FileManager.default.fileExists(atPath: imageURL.path) else {
        result(FlutterError(code: "missing_file", message: "Image file not found", details: path))
        return
      }

      DispatchQueue.global(qos: .userInitiated).async {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true

        let handler = VNImageRequestHandler(url: imageURL, options: [:])

        do {
          try handler.perform([request])
          let observations = request.results ?? []
          let lines = observations.compactMap { observation in
            observation.topCandidates(1).first?.string
          }
          let joined = lines.joined(separator: "\n")
          DispatchQueue.main.async {
            result(joined)
          }
        } catch {
          DispatchQueue.main.async {
            result(
              FlutterError(
                code: "ocr_failed",
                message: "Vision OCR failed",
                details: error.localizedDescription
              )
            )
          }
        }
      }
    } else {
      result(
        FlutterError(
          code: "unsupported_macos",
          message: "OCR requires macOS 10.15+",
          details: nil
        )
      )
    }
  }
}
