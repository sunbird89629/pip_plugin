import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pip_plugin/pip_configuration.dart';
import 'package:pip_plugin/src/contracts/base_pip_plugin.dart';
import 'package:simple_pip_mode/simple_pip.dart';

class PipPluginAndroid extends BasePipPlugin {
  late ValueNotifier<PipConfiguration> _configuration;
  late ValueNotifier<String> text;

  late SimplePip pip;

  ValueNotifier<PipConfiguration> get configurationNotifier => _configuration;

  @override
  PipConfiguration get configuration => _configuration.value;

  @override
  Future<bool> isPipSupported() async {
    try {
      return SimplePip.isPipAvailable;
    } catch (e, st) {
      debugPrint('PipPluginAndroid.isPipSupported error: $e\n$st');
      return false;
    }
  }

  @override
  Future<bool> performSetup(
      String? windowTitle, PipConfiguration? configuration) async {
    try {
      _configuration = ValueNotifier(configuration ?? PipConfiguration.initial);
      text = ValueNotifier('');
      pip = SimplePip(
        onPipEntered: handlePipEntered,
        onPipExited: handlePipExited,
      );
      markInitialized();
      return true;
    } catch (e, st) {
      debugPrint('PipPluginAndroid.performSetup error: $e\n$st');
      return false;
    }
  }

  @override
  Future<bool> startPip() async {
    checkInitialized();
    try {
      final ratio =
          (_configuration.value.ratio.$1, _configuration.value.ratio.$2);
      return await pip.enterPipMode(aspectRatio: ratio);
    } catch (e, st) {
      debugPrint('PipPluginAndroid.startPip error: $e\n$st');
      return false;
    }
  }

  @override
  Future<bool> stopPip() async {
    checkInitialized();
    // no-op: stopping PiP isn’t needed on Android
    return false;
  }

  @override
  Future<bool> update(PipConfiguration configuration) async {
    checkInitialized();
    try {
      _configuration.value = configuration;
      return true;
    } catch (e, st) {
      debugPrint('PipPluginAndroid.update error: $e\n$st');
      return false;
    }
  }

  @override
  Future<bool> updateText(String text) async {
    checkInitialized();
    try {
      this.text.value = text;
      return true;
    } catch (e, st) {
      debugPrint('PipPluginAndroid.updateText error: $e\n$st');
      return false;
    }
  }

  @override
  void dispose() {
    super.dispose();
    try {
      _configuration.dispose();
      text.dispose();
    } catch (e, st) {
      debugPrint('PipPluginAndroid.dispose error: $e\n$st');
    }
  }
}
