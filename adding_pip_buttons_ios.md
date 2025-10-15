# iOS 画中画 (PiP) 添加媒体控制按钮

## 问题

> 我用这种方式实现了画中画模式后，当我展示了画中画，点击画中画的视图的时候，直接退出了画中画，我期望能展示几个操作按钮，该如何实现？

## 解决方案

这个问题很典型。你遇到的情况——点击画中画窗口就直接退出——是因为你使用了 `AVPictureInPictureController.ContentSource` 的 `activeVideoCallSourceView` 初始化方式。这种模式是为视频通话应用设计的，其默认交互就是单击返回主应用。

为了实现你期望的媒体控制按钮（如播放/暂停、快进/快退），你需要让系统认为它正在处理一个媒体播放任务。这需要进行以下几个关键步骤的修改：

1.  **创建一个“虚拟”的 `AVPlayerLayer`**：即使你没有真正的视频要播放，你也需要创建一个 `AVPlayer` 和一个 `AVPlayerLayer`。这个播放器层将作为画中画控制器的数据源，告诉系统“这是一个媒体会话”，从而启用媒体控件。
2.  **更改 `ContentSource`**：使用 `sampleBufferDisplayLayer` 来初始化 `AVPictureInPictureController.ContentSource`，并传入你创建的虚拟播放器层。
3.  **启用线性播放控件**：设置 `pipController.requiresLinearPlayback = true`。这是让播放/暂停和时间轴控件显示出来的关键。
4.  **实现 `AVPictureInPictureControllerDelegate` 的相关方法**：为了让这些按钮能够工作，你需要实现委托方法来响应用户的操作，例如：
    *   `pictureInPictureController(_:setPlaying:)`：当用户点击播放/暂停按钮时调用。
    *   `pictureInPictureControllerIsPlaybackPaused(_:)`：系统通过此方法查询当前是否处于暂停状态。
    *   `pictureInPictureController(_:skipByInterval:completionHandler:)`：当用户点击快进/快退按钮时调用。

---

### 修改后的 `PipTextAction` 代码

下面是修改后的 `PipTextAction` 类的完整代码。你可以直接替换掉你文件中原有的 `PipTextAction` 类。

```swift
@available(iOS 15.0, *)
private class PipTextAction: NSObject, AVPictureInPictureControllerDelegate {
    static let shared = PipTextAction()
    static var onStopPip: (() -> Void)?

    private var pipController: AVPictureInPictureController?
    private var pipVC: AVPictureInPictureVideoCallViewController?
    private var hostingController: UIHostingController<PipTextView>?
    private var model: PipTextModel?
    private var storedConfig: [String: Any] = [:]

    // --- 新增 ---
    // 创建一个虚拟的 AVPlayerLayer，用于欺骗系统以显示媒体控件
    private var playerLayer: AVPlayerLayer?
    // ----------------

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

        // --- 新增 ---
        // 初始化虚拟播放器和图层
        let player = AVPlayer()
        let playerLayer = AVPlayerLayer(player: player)
        self.playerLayer = playerLayer
        // 必须将 playerLayer 添加到视图层级中
        rootView.layer.addSublayer(playerLayer)
        // ----------------

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

        // --- 修改 ---
        // 使用 sampleBufferDisplayLayer 初始化 ContentSource
        let source = AVPictureInPictureController.ContentSource(
            sampleBufferDisplayLayer: playerLayer,
            contentViewController: videoCallVC
        )
        // ----------------

        let controller = AVPictureInPictureController(contentSource: source)
        controller.delegate = self

        // --- 新增 ---
        // 启用线性播放控件（播放/暂停按钮和时间轴）
        controller.requiresLinearPlayback = true
        // ----------------

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
        cleanup() // 在这里调用 cleanup
    }

    private func cleanup() {
        hostingController?.view.removeFromSuperview()
        hostingController = nil
        pipVC = nil
        pipController = nil
        model = nil
        // --- 新增 ---
        // 清理虚拟播放器图层
        playerLayer?.removeFromSuperlayer()
        playerLayer = nil
        // ----------------
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

    // --- 新增：实现委托方法以控制媒体按钮 ---

    // 当用户点击播放/暂停按钮时，此方法被调用
    func pictureInPictureController(_ controller: AVPictureInPictureController, setPlaying playing: Bool) {
        // 我们将播放/暂停映射到文本的滚动/停止
        controlScroll(isScrolling: playing, speed: nil)
    }

    // 系统通过此方法查询当前是否暂停
    func pictureInPictureControllerIsPlaybackPaused(_ controller: AVPictureInPictureController) -> Bool {
        // 返回滚动状态的相反值
        return !(model?.isScrolling ?? true)
    }

    // 当用户点击快进/快退按钮时，此方法被调用
    func pictureInPictureController(
        _ controller: AVPictureInPictureController,
        skipByInterval interval: CMTime,
        completionHandler: @escaping () -> Void
    ) {
        // 在这里你可以实现自己的逻辑，例如加速或减速滚动
        // interval.seconds > 0 表示快进, < 0 表示快退
        if let currentSpeed = model?.scrollSpeed {
            let newSpeed = currentSpeed + (interval.seconds > 0 ? 5.0 : -5.0)
            model?.scrollSpeed = max(5.0, newSpeed) // 确保速度不小于5
        }
        completionHandler()
    }
    // -----------------------------------------
}
```
