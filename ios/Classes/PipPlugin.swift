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

        // 注意：这里将 self 作为参数传入，以便 Model 可以回调
        let m = PipTextModel(text: storedConfig["text"] as? String ?? "", actionHandler: self)
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

        // 使用原始的、正确的 ContentSource
        let source = AVPictureInPictureController.ContentSource(
            activeVideoCallSourceView: rootView,
            contentViewController: videoCallVC
        )
        let controller = AVPictureInPictureController(contentSource: source)
        controller.delegate = self
        self.pipController = controller
    }

    // ... startPip, hidePip, updateText, updateConfiguration ...
    // (这些方法保持不变)
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

// --- 修改 PipTextModel ---
@available(iOS 15.0, *)
private class PipTextModel: ObservableObject {
    @Published var text: String
    @Published var color: Color = .white
    @Published var background: Color = .black
    @Published var fontSize: Double = 16.0
    @Published var alignment: TextAlignment = .center
    @Published var isScrolling: Bool = false
    @Published var scrollSpeed: Double = 10.0

    // 新增：添加一个对 action handler 的弱引用，用于关闭 PiP
    private weak var actionHandler: PipTextAction?

    init(text: String, actionHandler: PipTextAction?) {
        self.text = text
        self.actionHandler = actionHandler
    }

    // 新增：控制逻辑方法
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

// --- 修改 PipTextView ---
@available(iOS 15.0, *)
private struct PipTextView: View {
    @ObservedObject var model: PipTextModel
    // 新增：状态来控制按钮的显示/隐藏
    @State private var showControls = false

    var body: some View {
        ZStack {
            // 文本视图作为背景
            AutoScrollTextView(
                content: model.text,
                isScrolling: $model.isScrolling,
                scrollSpeed: $model.scrollSpeed,
                fontSize: $model.fontSize,
                textColor: $model.color
            )

            // 控制按钮层
            if showControls {
                Color.black.opacity(0.4) // 半透明遮罩
                VStack {
                    Spacer()
                    HStack(spacing: 20) {
                        // 减速按钮
                        Button(action: { model.decreaseSpeed() }) {
                            Image(systemName: "backward.fill")
                                .font(.title2)
                        }

                        // 播放/暂停按钮
                        Button(action: { model.toggleScrolling() }) {
                            Image(systemName: model.isScrolling ? "pause.fill" : "play.fill")
                                .font(.title)
                        }

                        // 加速按钮
                        Button(action: { model.increaseSpeed() }) {
                            Image(systemName: "forward.fill")
                                .font(.title2)
                        }
                    }
                    Spacer()
                    // 关闭按钮
                    Button(action: { model.closePip() }) {
                         Image(systemName: "xmark")
                            .font(.subheadline)
                            .padding(8)
                            .background(Color.gray.opacity(0.7))
                            .clipShape(Circle())
                    }
                    .padding(.bottom, 10)
                }
                .foregroundColor(.white)
            }
        }
        .background(model.background)
        .onTapGesture {
            // 点击视图时，切换控制按钮的显示状态
            withAnimation {
                showControls.toggle()
            }
        }
        .clipped() // 防止子视图超出边界
    }
}


// --- 修改 AutoScrollTextView ---
@available(iOS 15.0, *)
struct AutoScrollTextView: View {
    let content: String
    @Binding var isScrolling: Bool
    @Binding var scrollSpeed: Double
    @Binding var fontSize: Double
    @Binding var textColor: Color

    @State private var scrollOffset: CGFloat = 0
    @State private var contentHeight: CGFloat = 0

    private let timer = Timer.publish(every: 1.0 / 60.0, on: .main, in: .common).autoconnect()

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            Text(content)
                .font(.system(size: fontSize))
                .foregroundColor(textColor)
                .padding()
                .background(
                    GeometryReader { geometry in
                        Color.clear.preference(key: ContentHeightPreferenceKey.self, value: geometry.size.height)
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
            
            // 当文本完全滚出视图时，从头开始
            if abs(newOffset) > contentHeight {
                newOffset = 0
            }
            scrollOffset = newOffset
        }
        .onChange(of: isScrolling) { isScrolling in
            // 如果不是滚动状态，可以重置位置
            if !isScrolling {
                // scrollOffset = 0 // 可选：如果希望暂停时回到顶部，取消此行注释
            }
        }
    }
}

// 用于获取内容高度的辅助工具
@available(iOS 15.0, *)
private struct ContentHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

//@available(iOS 15.0, *)
//#Preview {
//    AutoScrollTextView(
//        content:
//            "Hey everyone, this air conditioner 
//can completely cool down your house,
// your room, or even your car!
//If your car doesn’t have air conditi
//oning, I highly recommend you get this now. It’s super eas
//y to use—just add water, press two buttons, and it 
//starts cooling down quickly. 
//You can use it in your room, outdoors, in the car, or on the 
//go. Plus, it’s really convenient 
//to carry and can run continuously for two days. 
//It drains quickly with just one charge. 
//So, I suggest you grab one now!Hey everyone, 
//this air conditioner can completely cool 
//down your house, your room, or even your car! If your car 
//doesn’t have air conditioning, 
//I highly recommend you get this now. 
//It’s super easy to use—just add water, 
//press two buttons, and it starts cooling down 
//quickly. You can use it in your room, outdoors, 
//in the car, or on the go. Plus, it’s really
// convenient to carry and can run
// continuously for two days. It drains quickly with 
//just one charge. So, I suggest you grab one now!", isScrolling: .constant(true), scrollSpeed: .constant(10.0), fontSize: .constant(16.0), textColor: .constant(.white)
//    )
//    .frame(height: 60)
//    .background(Color.black)
//}
