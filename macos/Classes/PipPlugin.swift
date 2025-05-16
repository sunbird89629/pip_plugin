import Cocoa
import FlutterMacOS

public class PipPlugin: NSObject, FlutterPlugin, NSWindowDelegate {
  private var channel: FlutterMethodChannel?
  private var pipWindow: NSWindow?
  private var pipLabel: NSTextField?

  private struct PipConfiguration {
    var title: String = "PiP Window"
    var text: String = ""
    var backgroundColor: NSColor = .white
    var textColor: NSColor = .black
    var textSize: CGFloat = 48.0
    var textAlign: NSTextAlignment = .center
    var size: (width: CGFloat, height: CGFloat) = (320, 180)
  }

  private var storedConfig: PipConfiguration?

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "pip_plugin",
      binaryMessenger: registrar.messenger
    )
    let instance = PipPlugin()
    instance.channel = channel
    registrar.addMethodCallDelegate(instance, channel: channel)

    if let mainWindow = registrar.view?.window {
      NotificationCenter.default.addObserver(
        instance,
        selector: #selector(instance.mainWindowWillClose(_:)),
        name: NSWindow.willCloseNotification,
        object: mainWindow
      )
    }
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "isPipSupported":
      result(true)

    case "setupPip":
      guard let args = call.arguments as? [String: Any] else {
        result(false); return
      }

      let windowTitle = args["windowTitle"] as? String ?? "PiP Window"

      var backgroundColor = NSColor.white
      if let bg = args["backgroundColor"] as? [Int], bg.count == 4 {
        backgroundColor = NSColor(
          red: CGFloat(bg[0])/255.0,
          green: CGFloat(bg[1])/255.0,
          blue: CGFloat(bg[2])/255.0,
          alpha: CGFloat(bg[3])/255.0
        )
      }

      var textColor = NSColor.black
      if let tc = args["textColor"] as? [Int], tc.count == 4 {
        textColor = NSColor(
          red: CGFloat(tc[0])/255.0,
          green: CGFloat(tc[1])/255.0,
          blue: CGFloat(tc[2])/255.0,
          alpha: CGFloat(tc[3])/255.0
        )
      }

      let textSize = (args["textSize"] as? Double).map { CGFloat($0) } ?? 48.0

      var textAlign: NSTextAlignment = .center
      if let alignName = args["textAlign"] as? String {
        switch alignName.lowercased() {
        case "left": textAlign = .left
        case "right": textAlign = .right
        default: textAlign = .center
        }
      }

      var pipSize: (width: CGFloat, height: CGFloat) = (320,180)
      if let ratio = args["ratio"] as? [Int], ratio.count == 2 {
        pipSize = (180 * CGFloat(ratio[0]) / CGFloat(ratio[1]), 180)
      }

      createPiPWindow(
        title: windowTitle,
        text: "",
        backgroundColor: backgroundColor,
        textColor: textColor,
        textSize: textSize,
        textAlign: textAlign,
        size: pipSize
      )

      storedConfig = PipConfiguration(
        title: windowTitle,
        text: "",
        backgroundColor: backgroundColor,
        textColor: textColor,
        textSize: textSize,
        textAlign: textAlign,
        size: pipSize
      )

      result(true)

    case "startPip":
      guard let config = storedConfig else {
        result(false)
        return
      }
      showPiPWindow(with: config)
      result(true)

    case "stopPip":
      pipWindow?.orderOut(nil)
      channel?.invokeMethod("pipStopped", arguments: nil)
      result(true)

    case "updateText":
      if let args = call.arguments as? [String: Any],
         let newText = args["text"] as? String {
        updatePiPText(newText)
        result(true)
      } else {
        result(false)
      }

    case "updatePip":
      guard let args = call.arguments as? [String: Any] else {
        result(false); return
      }
      let success = updatePipConfiguration(with: args)
      result(success)

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func createPiPWindow(
    title: String,
    text: String,
    backgroundColor: NSColor,
    textColor: NSColor,
    textSize: CGFloat,
    textAlign: NSTextAlignment,
    size: (width: CGFloat, height: CGFloat)
  ) {
    guard pipWindow == nil, let screenFrame = NSScreen.main?.frame else { return }

    let origin = NSPoint(
      x: screenFrame.maxX - size.width - 20,
      y: screenFrame.minY + 20
    )
    let rect = NSRect(origin: origin, size: NSSize(width: size.width, height: size.height))

    let window = NSWindow(
      contentRect: rect,
      styleMask: [.titled, .closable, .resizable],
      backing: .buffered,
      defer: false
    )
    window.delegate = self
    window.level = .floating
    window.backgroundColor = backgroundColor
    window.title = title
    window.isReleasedWhenClosed = false

    NotificationCenter.default.addObserver(
      self,
      selector: #selector(pipWindowWillClose(_:)),
      name: NSWindow.willCloseNotification,
      object: window
    )

    let label = NSTextField(labelWithString: text)
    label.alignment = textAlign
    label.font = NSFont.boldSystemFont(ofSize: textSize)
    label.textColor = textColor
    label.backgroundColor = backgroundColor
    label.isBezeled = false
    label.isEditable = false
    label.frame = NSRect(
      x: 0,
      y: (size.height - textSize * 1.2) / 2,
      width: size.width,
      height: textSize * 1.2
    )

    window.contentView?.addSubview(label)

    pipWindow = window
    pipLabel = label
  }

  private func showPiPWindow(with config: PipConfiguration) {
    if pipWindow == nil {
      createPiPWindow(
        title: config.title,
        text: config.text,
        backgroundColor: config.backgroundColor,
        textColor: config.textColor,
        textSize: config.textSize,
        textAlign: config.textAlign,
        size: config.size
      )
    }
    pipLabel?.stringValue = config.text
    pipWindow?.makeKeyAndOrderFront(nil)
  }

  private func updatePiPText(_ text: String) {
    DispatchQueue.main.async {
      self.pipLabel?.stringValue = text
    }
  }

  private func updatePipConfiguration(with args: [String: Any]) -> Bool {
    guard let window = pipWindow,
          let label = pipLabel
    else { return false }

    if let newTitle = args["windowTitle"] as? String {
      window.title = newTitle
      storedConfig?.title = newTitle
    }

    if let bg = args["backgroundColor"] as? [Int], bg.count == 4 {
      let c = NSColor(
        red: CGFloat(bg[0])/255.0,
        green: CGFloat(bg[1])/255.0,
        blue: CGFloat(bg[2])/255.0,
        alpha: CGFloat(bg[3])/255.0
      )
      window.backgroundColor = c
      label.backgroundColor = c
      storedConfig?.backgroundColor = c
    }

    if let tc = args["textColor"] as? [Int], tc.count == 4 {
      let c = NSColor(
        red: CGFloat(tc[0])/255.0,
        green: CGFloat(tc[1])/255.0,
        blue: CGFloat(tc[2])/255.0,
        alpha: CGFloat(tc[3])/255.0
      )
      label.textColor = c
      storedConfig?.textColor = c
    }

    if let ts = args["textSize"] as? Double {
      let newSize = CGFloat(ts)
      label.font = NSFont.boldSystemFont(ofSize: newSize)
      var f = label.frame
      f.size.height = newSize * 1.2
      f.origin.y = (window.frame.height - f.size.height) / 2
      label.frame = f
      storedConfig?.textSize = newSize
    }

    if let alignName = args["textAlign"] as? String {
      switch alignName.lowercased() {
      case "left": label.alignment = .left
      case "right": label.alignment = .right
      default: label.alignment = .center
      }
      storedConfig?.textAlign = label.alignment
    }

    if let ratio = args["ratio"] as? [Int], ratio.count == 2 {
      let newSize = NSSize(width: 180 * CGFloat(ratio[0]) / CGFloat(ratio[1]), height: 180)
      var frame = window.frame
      frame.origin.x = NSScreen.main!.frame.maxX - newSize.width - 20
      frame.size = newSize
      window.setFrame(frame, display: true, animate: true)

      var lf = label.frame
      lf.size.width = newSize.width
      lf.origin.y = (newSize.height - lf.size.height) / 2
      label.frame = lf

      storedConfig?.size = (newSize.width, newSize.height)
    }
    layoutPiPLabel()
    return true
  }

  @objc private func pipWindowWillClose(_ note: Notification) {
    guard (note.object as? NSWindow) === pipWindow else { return }
    pipWindow?.orderOut(nil) // Hide only
    channel?.invokeMethod("pipStopped", arguments: nil)
  }

  @objc private func mainWindowWillClose(_ notification: Notification) {
    closePiPWindow()
  }

  private func closePiPWindow() {
    pipWindow?.orderOut(nil)
  }

  deinit {
    NotificationCenter.default.removeObserver(self)
  }

  public func windowDidResize(_ notification: Notification) {
    layoutPiPLabel()
}

public func windowDidEndZoom(_ notification: Notification) {
    layoutPiPLabel()
}


private func layoutPiPLabel() {
    guard let window = pipWindow, let label = pipLabel else { return }

    let contentFrame = window.contentView?.frame ?? .zero
    let textSize = label.font?.pointSize ?? 48
    let labelHeight = textSize * 1.2
    let labelWidth = contentFrame.width

    var labelX: CGFloat = 0
    switch label.alignment {
    case .left:
        labelX = 10
    case .right:
        labelX = max(0, labelWidth - label.intrinsicContentSize.width - 10)
    case .center, .justified, .natural:
        labelX = (labelWidth - label.intrinsicContentSize.width) / 2
    @unknown default:
        labelX = 0
    }

    label.frame = NSRect(
        x: labelX,
        y: (contentFrame.height - labelHeight) / 2,
        width: min(label.intrinsicContentSize.width, labelWidth - 20),
        height: labelHeight
    )
}

}
