import 'dart:io';

import 'package:pip_plugin/pip_configuration.dart';
import 'package:pip_plugin/src/pip_plugin_android.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:simple_pip_mode/actions/pip_action.dart';

import '../pip_plugin_method_channel.dart';

abstract class PipPluginPlatform extends PlatformInterface {
  /// Constructs a PipPluginPlatform.
  PipPluginPlatform() : super(token: _token);

  static final Object _token = Object();

  static PipPluginPlatform _instance =
      Platform.isAndroid ? PipPluginAndroid() : MethodChannelPipPlugin();

  /// The default instance of [PipPluginPlatform] to use.
  ///
  /// Defaults to [MethodChannelPipPlugin].
  static PipPluginPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [PipPluginPlatform] when
  /// they register themselves.
  static set instance(PipPluginPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<bool> setupPip({
    String? windowTitle,
    PipConfiguration? configuration,
  });

  Future<bool> startPip();
  Future<bool> stopPip();
  Future<bool> isPipSupported();

  Future<bool> update(PipConfiguration configuration);
  Future<bool> updateText(String text);

  Future<void> controlScroll({
    required bool isScrolling,
    double? speed,
  });

  Stream<bool> get pipActiveStream;

  Stream<PipAction> get pipActionStream;

  PipConfiguration get configuration;
  bool get isInitialized;

  void dispose();
}
