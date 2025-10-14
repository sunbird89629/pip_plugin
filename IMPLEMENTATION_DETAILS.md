# Pip-Plugin 实现原理分析

本文档深入分析 `pip_plugin` 在 Android 和 iOS 平台上的具体实现机制。

---

### Android 平台实现原理

Android 平台的实现相对巧妙，它主要依赖一个现成的第三方 Flutter 插件 `simple_pip_mode` 来处理底层的画中画逻辑。

1.  **核心依赖**:
    *   它没有自己从头编写 Android 原生的画中画代码，而是在 `pubspec.yaml` 中添加了 `simple_pip_mode: ^1.1.0` 这个依赖。这个库专门用于简化 Android 上的画中画集成。

2.  **Dart 层实现 (`lib/src/pip_plugin_android.dart`)**:
    *   这个文件里的 `PipPluginAndroid` 类是对 `simple_pip_mode` 插件功能的进一步封装。
    *   当调用 `startPip()` 时，它实际上是调用了 `simple_pip_mode` 提供的 `enterPipMode()` 方法。
    *   它使用 `ValueNotifier` (例如 `_configuration` 和 `text`) 来在 Dart 层管理画中画窗口的状态和显示的文本。

3.  **原生层集成 (用户配置)**:
    *   要在 Android 上使用画中画，用户必须在 `AndroidManifest.xml` 中为 `<activity>` 添加 `android:supportsPictureInPicture="true"` 属性来声明支持画中画。
    *   同时，需要处理画中画模式变化的生命周期回调。`simple_pip_mode` 提供了两种便捷方式（如 `README.md` 中所述）：
        *   **继承 `PipCallbackHelperActivityWrapper`**: 这是最简单的方式，让应用的 `MainActivity` 直接继承这个类，它内部已经处理好了所有回调。
        *   **手动调用 `PipCallbackHelper`**: 如果不想继承，也可以在 `MainActivity` 中手动创建 `PipCallbackHelper` 实例，并在 `onPictureInPictureModeChanged` 等生命周期方法中调用它的相应方法。

4.  **UI 渲染 (`text_pip_widget.dart`)**:
    *   在 Android 上，画中画窗口其实是主 Activity 的一个缩略版。为了只在画中画模式下显示特定文本，这个插件提供了一个 `TextPipWidget`。
    *   它的原理是：通过 `simple_pip_mode` 提供的 `SimplePipBuilder` 来判断当前是否处于画中画模式。如果是，就渲染一个只包含文本的简单视图；如果不是，就渲染 `child`，也就是正常的应用界面。

**小结**: Android 的实现是一个“组合”策略，通过依赖 `simple_pip_mode` 插件，极大地简化了原生代码的编写和维护，将复杂的 Android PiP 生命周期管理交给了这个专门的库。

---

### iOS 平台实现原理

iOS 的实现则完全是自己编写的原生 Swift 代码，通过 `MethodChannel` 与 Dart 进行通信。它利用了苹果官方从 iOS 15 开始提供的 `AVKit` 框架。

1.  **核心技术**:
    *   **`AVPictureInPictureController`**: 这是 Apple 官方提供的用于管理画中画窗口的控制器。
    *   **`SwiftUI`**: 为了在画中画窗口里显示自定义的文本和样式，它使用 SwiftUI 来创建一个视图 (`PipTextView`)。

2.  **通信方式**:
    *   它在 `PipPlugin.swift` 中注册了一个名为 `pip_plugin` 的 `FlutterMethodChannel`。Dart 代码通过这个通道调用 Swift 方法（如 `startPip`, `updateText`），Swift 代码也通过这个通道向 Dart 发送事件（如 `pipStopped`）。

3.  **原生层实现 (`ios/Classes/PipPlugin.swift`)**:
    *   **设置 (`setupPip`)**: 当 Dart 调用 `setupPip` 时，Swift 代码会创建一个 `AVPictureInPictureController`。最关键的一步是设置它的 `contentSource` (内容源)。
    *   **自定义内容**: 为了显示文本而不是视频，它创建了一个 `AVPictureInPictureVideoCallViewController`，这是一个专门用于视频通话场景的视图控制器，但可以巧妙地用来承载自定义的 UI。
    *   **渲染视图**: 它将一个用 SwiftUI 编写的 `PipTextView` 视图通过 `UIHostingController` 包装起来，然后作为子视图添加到了 `AVPictureInPictureVideoCallViewController` 中。这个 `PipTextView` 负责根据 Dart 传来的参数（文本内容、颜色、字号等）来渲染界面。
    *   **启动 (`startPip`)**: 调用 `pipController.startPictureInPicture()` 来启动画中画模式。
    *   **更新 (`updateText`, `updatePip`)**: 当需要更新文本或样式时，Dart 层通过方法通道调用 Swift，Swift 代码直接更新 `PipTextModel`（一个 `ObservableObject`），由于 SwiftUI 的数据绑定特性，`PipTextView` 会自动刷新，从而更新画中画窗口中的内容。
    *   **停止 (`stopPip`)**: 当用户手动关闭画中画窗口时，`AVPictureInPictureControllerDelegate` 的 `pictureInPictureControllerDidStopPictureInPicture` 代理方法会被触发，然后它通过 `channel.invokeMethod("pipStopped", ...)` 通知 Dart 层画中画已停止。

**小结**: iOS 的实现更加“原生”，它直接利用了苹果的 `AVKit` 和 `SwiftUI` 框架。通过将 SwiftUI 视图嵌入到视频通话画中画控制器中，实现了一个非常原生且高效的自定义画中画窗口。
