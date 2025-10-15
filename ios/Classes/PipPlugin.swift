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
            let rootView = UIApplication.shared.windows.first?
                .rootViewController?.view
        else { return }

        storedConfig = [
            "text": storedConfig["text"] ?? "",
            "backgroundColor": backgroundColor ?? [],
            "textColor": textColor ?? [],
            "textSize": textSize ?? 16.0,
            "textAlign": textAlign ?? "center",
            "ratio": sizeRatio ?? [],
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
            setupPip(
                backgroundColor: storedConfig["backgroundColor"] as? [Int],
                textColor: storedConfig["textColor"] as? [Int],
                textSize: storedConfig["textSize"] as? Double,
                textAlign: storedConfig["textAlign"] as? String,
                sizeRatio: storedConfig["ratio"] as? [Int]
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
            let rootView = UIApplication.shared.windows.first?
                .rootViewController?.view
        {
            vc.preferredContentSize = calculateContentSize(
                ratio: ratio,
                defaultSize: rootView.frame.size
            )
        }

        storedConfig.merge(args) { _, new in new }
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
        pipController = nil
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
private class PipTextModel: ObservableObject {
    @Published var text: String
    @Published var color: Color = .white
    @Published var background: Color = .black
    @Published var fontSize: Double = 16.0

    @Published var alignment: TextAlignment = .center

    @Published var isScrolling: Bool = false
    @Published var scrollSpeed: Double = 10.0

    init(text: String) {
        self.text = text
    }
}

@available(iOS 15.0, *)
private struct PipTextView: View {
    @ObservedObject var model: PipTextModel

    @State private var scrollOffset: CGFloat = 0
    private let timer = Timer.publish(every: 1.0 / 60.0, on: .main, in: .common)
        .autoconnect()

    var body: some View {
        //        ScrollViewReader { scrollViewProxy in
        //            ScrollView(.vertical, showsIndicators: false) {
        //                GeometryReader { geometry in
        //                    let totalHeight = geometry.size.height
        //
        //                    Text(model.text)
        //                        .foregroundColor(model.color)
        //                        .font(.system(size: model.fontSize))
        //                        .multilineTextAlignment(model.alignment)
        //                        .frame(minHeight: 400)
        //                        .lineLimit(10)
        //                        .id("teleprompter_text")
        //                        .onReceive(timer) { _ in
        ////                            guard model.isScrolling else { return }
        //
        ////                            let increment = model.scrollSpeed / 60.0
        //                            let increment = 1.0
        //                            let newOffset = scrollOffset + increment
        //
        //                            scrollOffset = newOffset
        //                            withAnimation(.linear(duration: 0.01)) {
        ////                                scrollViewProxy.scrollTo("teleprompter_text", anchor: .top)
        ////                                scrollViewProxy.scrollTo(<#T##id: Hashable##Hashable#>)
        ////                                scrollViewProxy.scrollTo(<#T##id: Hashable##Hashable#>)
        //                            }
        //
        ////                            if newOffset < totalHeight {
        ////                                scrollOffset = newOffset
        ////                                withAnimation(.linear(duration: 0.01)) {
        ////                                    scrollViewProxy.scrollTo("teleprompter_text", anchor: .top)
        ////                                }
        ////                            } else {
        ////                                model.isScrolling = false
        ////                            }
        //                        }
        //                }
        //            }
        //            .onChange(of: model.isScrolling) { isScrolling in
        //                if !isScrolling {
        //                    scrollOffset = 0
        //                    withAnimation {
        //                        scrollViewProxy.scrollTo("teleprompter_text", anchor: .top)
        //                    }
        //                }
        //            }
        //        }
        //        .background(model.background)
        AutoScrollTextView(content: model.text)
            .fixedSize()
    }
}

@available(iOS 15.0, *)
struct AutoScrollTextView: View {
    var content: String
    let interval: TimeInterval = 0.02

    @State private var offset: CGFloat = 0
    @State private var timer: AnyCancellable?

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 8) {
                Text(content).font(.system(size: 16)).fixedSize(
                    horizontal: true,
                    vertical: true
                )
            }
            .offset(y: -offset)
        }.background(Color.red)
            .fixedSize()
            .onAppear {
                //            let totalHeight = CGFloat(lines.count) * 24
                timer = Timer.publish(every: interval, on: .main, in: .common)
                    .autoconnect()
                    .sink { _ in
                        offset += 0.5
                        //                    if offset > totalHeight {
                        //                        offset = 0
                        //                    }
                    }
            }
            .onDisappear {
                timer?.cancel()
            }
    }
}

@available(iOS 15.0, *)
#Preview {
    AutoScrollTextView(
        content:
            "Hey everyone, this air conditioner \ncan completely cool down your house,\n your room, or even your car!\nIf your car doesn’t have air conditi\noning, I highly recommend you get this now. It’s super eas\ny to use—just add water, press two buttons, and it \nstarts cooling down quickly. \nYou can use it in your room, outdoors, in the car, or on the \ngo. Plus, it’s really convenient \nto carry and can run continuously for two days. \nIt drains quickly with just one charge. \nSo, I suggest you grab one now!Hey everyone, \nthis air conditioner can completely cool \ndown your house, your room, or even your car! If your car \ndoesn’t have air conditioning, \nI highly recommend you get this now. \nIt’s super easy to use—just add water, \npress two buttons, and it starts cooling down \nquickly. You can use it in your room, outdoors, \nin the car, or on the go. Plus, it’s really\n convenient to carry and can run\n continuously for two days. It drains quickly with \njust one charge. So, I suggest you grab one now!"
    )
    .frame(height: 60)
}
