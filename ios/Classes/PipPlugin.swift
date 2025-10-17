import AVKit
import Combine
import Flutter
import SwiftUI
import UIKit

public class PipPlugin: NSObject, FlutterPlugin {
    private var channel: FlutterMethodChannel?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "pip_plugin",
            binaryMessenger: registrar.messenger()
        )
        let instance = PipPlugin()
        instance.channel = channel
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(
        _ call: FlutterMethodCall,
        result: @escaping FlutterResult
    ) {
        if #available(iOS 15.0, *) {
            PipHandler.handle(call: call, result: result, channel: channel)
        } else {
            result(
                FlutterError(
                    code: "UNSUPPORTED_VERSION",
                    message: "iOS 15.0 or higher required",
                    details: nil
                )
            )
        }
    }
}

@available(iOS 15.0, *)
private class PipHandler {
    static func handle(
        call: FlutterMethodCall,
        result: @escaping FlutterResult,
        channel: FlutterMethodChannel?
    ) {
        switch call.method {
        case "setupPip":
            guard let args = call.arguments as? [String: Any] else {
                result(false)
                return
            }

            let ratio = args["ratio"] as? [Int]
            let textSize = args["textSize"] as? Double

            PipTextAction.shared.setupPip(
                textSize: textSize,
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
                let text = args["text"] as? String
            else {
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

        case "controlScroll":
            guard let args = call.arguments as? [String: Any],
                let isScrolling = args["isScrolling"] as? Bool
            else {
                result(false)
                return
            }
            let speed = args["speed"] as? Double
            PipTextAction.shared.controlScroll(
                isScrolling: isScrolling,
                speed: speed
            )
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
    private var hostingController: UIHostingController<CustomView>?
    private var model: CustomViewModel?

    private func currentRootView() -> UIView? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }?
            .rootViewController?.view
    }

    func setupPip(
        textSize: Double?,
        sizeRatio: [Int]?
    ) {
        cleanup()

        guard AVPictureInPictureController.isPictureInPictureSupported(),
              let rootView = currentRootView()
        else { return }

        let videoCallVC = AVPictureInPictureVideoCallViewController()
        self.pipVC = videoCallVC

        let m = CustomViewModel(
            text: "init text",
            actionHandler: self,
            fontSize:textSize ?? 30.0,
        )
        self.model = m

        let host = UIHostingController(rootView: CustomView(model: m))
        self.hostingController = host

        videoCallVC.addChild(host)
        host.didMove(toParent: videoCallVC)
        addConstrainedSubview(host.view, to: videoCallVC.view)

        let contentSize = calculateContentSize(
            ratio: sizeRatio,
            defaultSize: rootView.frame.size
        )
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
        guard AVPictureInPictureController.isPictureInPictureSupported() else {
            return false
        }

        if pipController == nil {
//            setupPip(
//                backgroundColor: storedConfig["backgroundColor"] as? [Int],
//                textColor: storedConfig["textColor"] as? [Int],
//                textSize: storedConfig["textSize"] as? Double,
//                textAlign: storedConfig["textAlign"] as? String,
//                sizeRatio: storedConfig["ratio"] as? [Int]
//            )

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
//        storedConfig["text"] = text
    }

    func updateConfiguration(_ args: [String: Any]) {
//        if let bg = args["backgroundColor"] as? [Int], bg.count >= 4 {
//            model?.backgroundColor = Color(
//                red: Double(bg[0]) / 255.0,
//                green: Double(bg[1]) / 255.0,
//                blue: Double(bg[2]) / 255.0,
//                opacity: Double(bg[3]) / 255.0
//            )
//        }

//        if let tc = args["textColor"] as? [Int], tc.count >= 4 {
//            model?.fontColor = Color(
//                red: Double(tc[0]) / 255.0,
//                green: Double(tc[1]) / 255.0,
//                blue: Double(tc[2]) / 255.0,
//                opacity: Double(tc[3]) / 255.0
//            )
//        }
//        if let size = args["textSize"] as? Double {
//            model?.fontSize = size
//        }

//        if let align = args["textAlign"] as? String {
//            switch align.lowercased() {
//            case "left": model?.alignment = .leading
//            case "right": model?.alignment = .trailing
//            default: model?.alignment = .center
//            }
//        }

        if let ratio = args["ratio"] as? [Int],
            let vc = pipVC,
            let rootView = UIApplication.shared.windows.first?
                .rootViewController?.view
        {
            vc.preferredContentSize = calculateContentSize(
                ratio: ratio,
                defaultSize: rootView.frame.size
            )
        }
        
        
        if let speed = args["speed"] as? Double{
            model?.scrollSpeed = speed
        }
//        storedConfig.merge(args) { _, new in new }
    }

    func controlScroll(isScrolling: Bool, speed: Double?) {
        model?.isScrolling = isScrolling
        if let newSpeed = speed {
            model?.scrollSpeed = newSpeed
        }
    }

    func pictureInPictureControllerDidStopPictureInPicture(
        _ controller: AVPictureInPictureController
    ) {
        Self.onStopPip?()
        cleanup()
    }

    private func cleanup() {
        hostingController?.view.removeFromSuperview()
        hostingController = nil
        pipVC = nil
        pipController = nil
        model = nil
    }

    private func calculateContentSize(ratio: [Int]?, defaultSize: CGSize)
        -> CGSize
    {
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
            subview.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }
}

@available(iOS 15.0, *)
private class CustomViewModel: ObservableObject {
    let fontColor: Color = .white
    let backgroundColor: Color = .black
    let fontSize: Double
    let alignment: TextAlignment = .center
    
    @Published var text: String
    @Published var isScrolling: Bool = false
    @Published var scrollSpeed: Double = 10.0
    

    private weak var actionHandler: PipTextAction?

    init(text: String, actionHandler: PipTextAction?,fontSize:Double) {
        self.text = text
        self.actionHandler = actionHandler
        self.fontSize=fontSize
    }

    func toggleScrolling() {
        isScrolling.toggle()
    }

    func increaseSpeed() {
        scrollSpeed += 5.0
    }

    func decreaseSpeed() {
        scrollSpeed = max(5.0, scrollSpeed - 5.0)
    }

    func closePip() {
        actionHandler?.hidePip()
    }
}

@available(iOS 15.0, *)
private struct CustomView: View {
    @ObservedObject var model: CustomViewModel

    var body: some View {
        ZStack {
            let fontSize = model.fontSize
            let uiColor = UIColor(model.fontColor)
            
            AutoScrollUILabelView(
                text: model.text,
                font: UIFont.systemFont(ofSize: CGFloat(fontSize)),
                textColor: uiColor,
                isScrolling: $model.isScrolling,
                scrollSpeed: $model.scrollSpeed
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .clipped()
        .background(model.backgroundColor)
    }
}
