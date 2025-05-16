import Flutter
import UIKit
import AVKit
import SwiftUI

public class PipPlugin: NSObject, FlutterPlugin {
    private var channel: FlutterMethodChannel?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "pip_plugin", binaryMessenger: registrar.messenger())
        let instance = PipPlugin()
        instance.channel = channel
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        if #available(iOS 15.0, *) {
            PipHandler.handle(call: call, result: result, channel: channel)
        } else {
            result(FlutterError(code: "UNSUPPORTED_VERSION", message: "iOS 15.0 or higher required", details: nil))
        }
    }
}

@available(iOS 15.0, *)
private class PipHandler {
    static func handle(call: FlutterMethodCall, result: @escaping FlutterResult, channel: FlutterMethodChannel?) {
        switch call.method {
        case "setupPip":
            guard let args = call.arguments as? [String: Any] else {
                result(false)
                return
            }

            let bgColor = args["backgroundColor"] as? [Int]
            let ratio = args["ratio"] as? [Int]
            let textColor = args["textColor"] as? [Int]
            let textSize = args["textSize"] as? Double
            let textAlign = args["textAlign"] as? String

            PipTextAction.shared.setupPip(
                backgroundColor: bgColor,
                textColor: textColor,
                textSize: textSize,
                textAlign: textAlign,
                sizeRatio: ratio
            )

            PipTextAction.onStopPip = {
                channel?.invokeMethod("pipStopped", arguments: nil)
            }

            result(true)

        case "startPip":
            let didStart = PipTextAction.shared.startPip()
            result(didStart)

        case "stopPip":
            PipTextAction.shared.hidePip()
            result(true)

        case "updateText":
            guard let args = call.arguments as? [String: Any],
                  let text = args["text"] as? String else {
                result(false)
                return
            }
            PipTextAction.shared.updateText(text)
            result(true)

        case "updatePip":
            guard let args = call.arguments as? [String: Any] else {
                result(false)
                return
            }
            PipTextAction.shared.updateConfiguration(args)
            result(true)

        case "isPipSupported":
            result(AVPictureInPictureController.isPictureInPictureSupported())

        default:
            result(FlutterMethodNotImplemented)
        }
    }
}

@available(iOS 15.0, *)
private class PipTextAction: NSObject, AVPictureInPictureControllerDelegate {
    static let shared = PipTextAction()
    static var onStopPip: (() -> Void)?

    private var pipController: AVPictureInPictureController?
    private var pipVC: AVPictureInPictureVideoCallViewController?
    private var hostingController: UIHostingController<PipTextView>?
    private var model: PipTextModel?
    private var storedConfig: [String: Any] = [:]

    func setupPip(
        backgroundColor: [Int]?,
        textColor: [Int]?,
        textSize: Double?,
        textAlign: String?,
        sizeRatio: [Int]?
    ) {
        cleanup()

        guard AVPictureInPictureController.isPictureInPictureSupported(),
              let rootView = UIApplication.shared.windows.first?.rootViewController?.view else { return }

        storedConfig = [
            "text": storedConfig["text"] ?? "",
            "backgroundColor": backgroundColor ?? [],
            "textColor": textColor ?? [],
            "textSize": textSize ?? 16.0,
            "textAlign": textAlign ?? "center",
            "ratio": sizeRatio ?? []
        ]

        let videoCallVC = AVPictureInPictureVideoCallViewController()
        self.pipVC = videoCallVC

        let m = PipTextModel(text: storedConfig["text"] as? String ?? "")
        self.model = m

        if let bg = backgroundColor, bg.count >= 4 {
            m.background = Color(
                red: Double(bg[0]) / 255.0,
                green: Double(bg[1]) / 255.0,
                blue: Double(bg[2]) / 255.0,
                opacity: Double(bg[3]) / 255.0
            )
        }

        if let tc = textColor, tc.count >= 4 {
            m.color = Color(
                red: Double(tc[0]) / 255.0,
                green: Double(tc[1]) / 255.0,
                blue: Double(tc[2]) / 255.0,
                opacity: Double(tc[3]) / 255.0
            )
        }

        if let size = textSize {
            m.fontSize = size
        }

        if let align = textAlign {
            switch align.lowercased() {
            case "left": m.alignment = .leading
            case "right": m.alignment = .trailing
            default: m.alignment = .center
            }
        }

        let host = UIHostingController(rootView: PipTextView(model: m))
        self.hostingController = host

        videoCallVC.addChild(host)
        host.didMove(toParent: videoCallVC)
        addConstrainedSubview(host.view, to: videoCallVC.view)

        let contentSize = calculateContentSize(ratio: sizeRatio, defaultSize: rootView.frame.size)
        videoCallVC.preferredContentSize = contentSize

        let source = AVPictureInPictureController.ContentSource(
            activeVideoCallSourceView: rootView,
            contentViewController: videoCallVC
        )
        let controller = AVPictureInPictureController(contentSource: source)
        controller.delegate = self
        self.pipController = controller
    }

    func startPip() -> Bool {
         guard AVPictureInPictureController.isPictureInPictureSupported() else { return false }

    if pipController == nil {
    setupPip(
      backgroundColor: storedConfig["backgroundColor"] as? [Int],
      textColor:       storedConfig["textColor"]       as? [Int],
      textSize:        storedConfig["textSize"]        as? Double,
      textAlign:       storedConfig["textAlign"]       as? String,
      sizeRatio:       storedConfig["ratio"]           as? [Int]
    )

    DispatchQueue.main.async { [weak self] in
      guard let ctrl = self?.pipController,
            !ctrl.isPictureInPictureActive
      else { return }
      ctrl.startPictureInPicture()
    }

    return true
  }

  guard let ctrl = pipController,
        !ctrl.isPictureInPictureActive
  else {
    return pipController?.isPictureInPictureActive ?? false
  }

  ctrl.startPictureInPicture()
  return true
    }

    func hidePip() {
        pipController?.stopPictureInPicture()
    }

    func updateText(_ text: String) {
        model?.text = text
        storedConfig["text"] = text
    }

    func updateConfiguration(_ args: [String: Any]) {
        if let bg = args["backgroundColor"] as? [Int], bg.count >= 4 {
            model?.background = Color(
                red: Double(bg[0]) / 255.0,
                green: Double(bg[1]) / 255.0,
                blue: Double(bg[2]) / 255.0,
                opacity: Double(bg[3]) / 255.0
            )
        }

        if let tc = args["textColor"] as? [Int], tc.count >= 4 {
            model?.color = Color(
                red: Double(tc[0]) / 255.0,
                green: Double(tc[1]) / 255.0,
                blue: Double(tc[2]) / 255.0,
                opacity: Double(tc[3]) / 255.0
            )
        }

        if let size = args["textSize"] as? Double {
            model?.fontSize = size
        }

        if let align = args["textAlign"] as? String {
            switch align.lowercased() {
            case "left": model?.alignment = .leading
            case "right": model?.alignment = .trailing
            default: model?.alignment = .center
            }
        }

        if let ratio = args["ratio"] as? [Int],
           let vc = pipVC,
           let rootView = UIApplication.shared.windows.first?.rootViewController?.view {
            vc.preferredContentSize = calculateContentSize(ratio: ratio, defaultSize: rootView.frame.size)
        }

        storedConfig.merge(args) { _, new in new }
    }

    func pictureInPictureControllerDidStopPictureInPicture(_ controller: AVPictureInPictureController) {
        Self.onStopPip?()
        pipController = nil
    }

    private func cleanup() {
        hostingController?.view.removeFromSuperview()
        hostingController = nil
        pipVC = nil
        pipController = nil
        model = nil
    }

    private func calculateContentSize(ratio: [Int]?, defaultSize: CGSize) -> CGSize {
        guard let r = ratio, r.count == 2 else { return defaultSize }
        return CGSize(width: CGFloat(r[0]), height: CGFloat(r[1]))
    }

    private func addConstrainedSubview(_ subview: UIView, to view: UIView) {
        view.addSubview(subview)
        subview.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            subview.topAnchor.constraint(equalTo: view.topAnchor),
            subview.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            subview.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            subview.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
}

@available(iOS 15.0, *)
private class PipTextModel: ObservableObject {
    @Published var text: String
    @Published var color: Color = .white
    @Published var background: Color = .black
    @Published var fontSize: Double = 16.0
    @Published var alignment: TextAlignment = .center

    init(text: String) {
        self.text = text
    }
}

@available(iOS 15.0, *)
private struct PipTextView: View {
    @ObservedObject var model: PipTextModel

    private var frameAlignment: Alignment {
        switch model.alignment {
        case .leading:  return .leading
        case .trailing: return .trailing
        default:        return .center
        }
    }

    var body: some View {
        Text(model.text)
            .foregroundColor(model.color)
            .font(.system(size: model.fontSize))
            .multilineTextAlignment(model.alignment)
            .frame(
                maxWidth:  .infinity,
                maxHeight: .infinity,
                alignment: frameAlignment
            )
            .background(model.background)
    }
}
