# Gemini Code Assistant Context

## Project Overview

This project is a Flutter plugin named `pip_plugin` that provides Picture-in-Picture (PiP) functionality for displaying text overlays. It is designed to be cross-platform, with support for Android, iOS, web, macOS, and Windows.

The plugin exposes a Dart API through the `PipPlugin` class, which allows developers to:

*   Setup and configure the PiP window (title, colors, text size, aspect ratio).
*   Start and stop PiP mode.
*   Update the text content and appearance of the PiP window dynamically.
*   Check for PiP support on the current platform.
*   Listen to a stream of PiP active status changes.

The plugin follows a platform interface architecture, with a common Dart interface and separate platform-specific implementations.

## Building and Running

This is a Flutter plugin, so it's meant to be consumed by a Flutter application. To use this plugin, add it to your `pubspec.yaml` and run `flutter pub get`.

To run the example application:

```bash
cd example
flutter run
```

## Development Conventions

*   **Platform Interface:** The plugin uses a platform interface (`PipPluginPlatform`) to abstract the platform-specific implementations. This is a standard Flutter plugin development pattern.
*   **Method Channels:** For iOS, macOS, and Windows, the plugin uses method channels to communicate between the Dart code and the native platform code.
*   **Federated Plugin:** The plugin is structured as a federated plugin, with separate packages for each platform implementation.
*   **Android Implementation:** The Android implementation uses the `simple_pip_mode` package to handle PiP functionality.
*   **Web Implementation:** The web implementation uses the `dart:js_interop` and `package:web` libraries to interact with the browser's Picture-in-Picture API.
*   **iOS/macOS Implementation:** The iOS and macOS implementations are written in Swift and use the native `AVPictureInPictureController` and `NSWindow` APIs, respectively.
*   **Windows Implementation:** The Windows implementation is written in C++ and uses the native Windows API to create and manage the PiP window.
