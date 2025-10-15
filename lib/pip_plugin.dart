import 'dart:ui';

import 'package:pip_plugin/pip_configuration.dart';
import 'src/contracts/pip_plugin_platform_interface.dart';

class PipPlugin {
  bool _isDisposed = false;

  void _ensureNotDisposed() {
    if (_isDisposed) {
      throw StateError('PipPlugin has been disposed and cannot be used.');
    }
  }

  /// On **desktop platforms**, you can optionally set a [windowTitle].
  Future<bool> setupPip({
    String? windowTitle,
    PipConfiguration? configuration,
  }) {
    _ensureNotDisposed();
    return PipPluginPlatform.instance.setupPip(
      configuration: configuration,
      windowTitle: windowTitle,
    );
  }

  /// Starts Picture-in-Picture mode.
  Future<bool> startPip() {
    _ensureNotDisposed();
    return PipPluginPlatform.instance.startPip();
  }

  /// Stops Picture-in-Picture mode.
  /// On Android, this will do nothing as PiP mode is automatically stopped.
  Future<bool> stopPip() {
    _ensureNotDisposed();
    return PipPluginPlatform.instance.stopPip();
  }

  /// Checks if PiP is supported on the current platform.
  Future<bool> isPipSupported() {
    _ensureNotDisposed();
    return PipPluginPlatform.instance.isPipSupported();
  }

  /// Updates the PiP configuration at runtime.
  /// - **[textAlign]**: only `left`, `right`, and `center` are supported.
  /// - **[ratio]**: ignored on Web platforms.
  Future<bool> update({
    Color? backgroundColor,
    Color? textColor,
    double? textSize,
    TextAlign? textAlign,
    (int, int)? ratio,
  }) {
    _ensureNotDisposed();
    final updatedConfig = PipPluginPlatform.instance.configuration.copyWith(
      backgroundColor: backgroundColor,
      textColor: textColor,
      textSize: textSize,
      textAlign: textAlign,
      ratio: ratio,
    );
    return PipPluginPlatform.instance.update(updatedConfig);
  }

  /// Updates the text content in PiP mode.
  Future<bool> updateText(String text) {
    _ensureNotDisposed();
    return PipPluginPlatform.instance.updateText(text);
  }

  /// Controls the automatic scrolling of the text in the PiP window.
  ///
  /// This is currently only supported on iOS.
  Future<void> controlScroll({
    required bool isScrolling,
    double? speed,
  }) {
    _ensureNotDisposed();
    return PipPluginPlatform.instance.controlScroll(
      isScrolling: isScrolling,
      speed: speed,
    );
  }

  /// A stream that emits the active status of PiP mode.
  Stream<bool> get pipActiveStream {
    _ensureNotDisposed();
    return PipPluginPlatform.instance.pipActiveStream;
  }

  bool get isInitialized {
    _ensureNotDisposed();
    return PipPluginPlatform.instance.isInitialized;
  }

  void dispose() {
    if (!_isDisposed) {
      PipPluginPlatform.instance.dispose();
      _isDisposed = true;
    }
  }
}
