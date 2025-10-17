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

    private func currentRootView() -> UIView? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }?
            .rootViewController?.view
    }

    func setupPip(
        backgroundColor: [Int]?,
        textColor: [Int]?,
        textSize: Double?,
        textAlign: String?,
        sizeRatio: [Int]?
    ) {
        cleanup()

        guard AVPictureInPictureController.isPictureInPictureSupported(),
              let rootView = currentRootView()
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

        let m = PipTextModel(
            text: storedConfig["text"] as? String ?? "",
            actionHandler: self
        )
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
        if let size = textSize { m.fontSize = size }
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
        
        
        if let speed = args["speed"] as? Double{
            model?.scrollSpeed = speed
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
private class PipTextModel: ObservableObject {
    @Published var text: String
    @Published var color: Color = .white
    @Published var background: Color = .black
    @Published var fontSize: Double = 16.0
    @Published var alignment: TextAlignment = .center
    @Published var isScrolling: Bool = false
    @Published var scrollSpeed: Double = 10.0

    private weak var actionHandler: PipTextAction?

    init(text: String, actionHandler: PipTextAction?) {
        self.text = text
        self.actionHandler = actionHandler
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
private struct PipTextView: View {
    @ObservedObject var model: PipTextModel

    var body: some View {
        ZStack {
            let fontSize = model.fontSize
            let uiColor = UIColor(model.color)
            
            AutoScrollUILabelView(
                text: model.text,
                font: UIFont.systemFont(ofSize: CGFloat(fontSize)),
                textColor: uiColor,
                isScrolling: $model.isScrolling,
                speed: $model.scrollSpeed
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
//            AutoScrollTextView(
//                content: model.text,
//                isScrolling: $model.isScrolling,
//                scrollSpeed: $model.scrollSpeed,
//                fontSize: $model.fontSize,
//                textColor: $model.color
//            )
//            .background(model.background)

//            VStack {
//                Spacer()
//
//                HStack(spacing: 30) {
//                    Button(action: { model.decreaseSpeed() }) {
//                        Image(systemName: "backward.fill")
//                            .font(.title2)
//                    }
//                    .tint(.white)
//
//                    Button(action: { model.toggleScrolling() }) {
//                        Image(
//                            systemName: model.isScrolling
//                                ? "pause.fill" : "play.fill"
//                        )
//                        .font(.largeTitle)
//                    }
//                    .tint(.white)
//
//                    Button(action: { model.increaseSpeed() }) {
//                        Image(systemName: "forward.fill")
//                            .font(.title2)
//                    }
//                    .tint(.white)
//                }
//
//                Spacer()
//
//                HStack {
//                    Spacer()
//                    Button(action: { model.closePip() }) {
//                        Image(systemName: "xmark")
//                            .font(.system(size: 12, weight: .bold))
//                            .foregroundColor(.black)
//                            .padding(8)
//                            .background(.white.opacity(0.8))
//                            .clipShape(Circle())
//                    }
//                    .padding()
//                }
//            }
//            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .clipped()
    }
}

@available(iOS 15.0, *)
struct AutoScrollTextView: View {
    let content: String
    @Binding var isScrolling: Bool
    @Binding var scrollSpeed: Double
    @Binding var fontSize: Double
    @Binding var textColor: Color

    @State private var scrollOffset: CGFloat = 0
    @State private var contentHeight: CGFloat = 0

    private let timer = Timer.publish(every: 1.0 / 60.0, on: .main, in: .common)
        .autoconnect()

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            Text(content)
                .font(.system(size: fontSize))
                .foregroundColor(textColor)
                .padding()
                .background(
                    GeometryReader { geometry in
                        Color.clear.preference(
                            key: ContentHeightPreferenceKey.self,
                            value: geometry.size.height
                        )
                    }
                )
                .offset(y: scrollOffset)
        }
        .onPreferenceChange(ContentHeightPreferenceKey.self) { height in
            self.contentHeight = height
        }
        .onReceive(timer) { _ in
            guard isScrolling else { return }

            let increment = scrollSpeed / 60.0
            var newOffset = scrollOffset - increment

            if abs(newOffset) > contentHeight {
                newOffset = 0
            }
            scrollOffset = newOffset
        }
        .onChange(of: isScrolling) { isScrolling in
            if !isScrolling {
                // scrollOffset = 0
            }
        }
    }
}

@available(iOS 15.0, *)
private struct ContentHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

@available(iOS 15.0, *)
struct PipCounterView: View {
    @State private var count = 0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 16) {
                Text("👆 可交互计数器")
                    .foregroundColor(.white)
                    .font(.headline)

                Text("\(count)")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(.yellow)

                Button(action: {
                    count += 1
                }) {
                    Text("+1")
                        .font(.title2)
                        .bold()
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }

//                Button(action: {
//                    if let pip = PipInteractiveManager.shared.pipController,
//                       pip.isPictureInPictureActive {
//                        pip.stopPictureInPicture()
//                    }
//                }) {
//                    Image(systemName: "xmark.circle.fill")
//                        .font(.title)
//                        .foregroundColor(.white.opacity(0.8))
//                }
//                .padding(.top, 20)
            }
            .padding()
        }
    }
}

@available(iOS 15.0, *)
struct AutoScrollUILabelView: UIViewRepresentable {
    let text: String
    var font: UIFont
    var textColor: UIColor
    @Binding var isScrolling: Bool
    @Binding var speed: Double

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.showsVerticalScrollIndicator = false
        scrollView.isScrollEnabled = false // we drive programmatically
        let label = UILabel()
        label.numberOfLines = 0
        label.font = font
        label.textColor = textColor
        label.text = text
        label.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 8),
            label.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -8),
            label.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 8),
            label.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -8),
            label.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -16)
        ])

        context.coordinator.setup(scrollView: scrollView, label: label)
        return scrollView
    }

    func updateUIView(_ uiView: UIScrollView, context: Context) {
        context.coordinator.update(text: text, font: font, color: textColor)
        context.coordinator.updateScrolling(isScrolling: isScrolling, speed: speed)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator {
        private weak var scrollView: UIScrollView?
        private weak var label: UILabel?
        private var displayLink: CADisplayLink?
        private var lastTime: CFTimeInterval = 0
        private var speedPerSec: Double = 30 // default

        func setup(scrollView: UIScrollView, label: UILabel) {
            self.scrollView = scrollView
            self.label = label
        }

        func update(text: String, font: UIFont, color: UIColor) {
            label?.text = text
            label?.font = font
            label?.textColor = color
            // Ensure layout then update contentSize
            label?.setNeedsLayout()
            label?.layoutIfNeeded()
        }

        func updateScrolling(isScrolling: Bool, speed: Double) {
            speedPerSec = speed
            if isScrolling { start() } else { stop() }
        }

        private func start() {
            stop()
            lastTime = CACurrentMediaTime()
            displayLink = CADisplayLink(target: self, selector: #selector(tick))
            displayLink?.add(to: .main, forMode: .common)
        }

        private func stop() {
            displayLink?.invalidate()
            displayLink = nil
        }

        @objc private func tick() {
            guard let sv = scrollView else { return }
            guard let label = label else { return }
            let now = CACurrentMediaTime()
            let dt = now - lastTime
            lastTime = now
            let delta = CGFloat(speedPerSec * dt)
            var newOffset = sv.contentOffset.y + delta
            let maxOffset = max(0, sv.contentSize.height - sv.bounds.height)
            if newOffset > maxOffset {
                newOffset = 0
            }
            sv.setContentOffset(CGPoint(x: 0, y: newOffset), animated: false)
        }
    }
}
