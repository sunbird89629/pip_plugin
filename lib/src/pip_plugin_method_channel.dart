import 'dart:async';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pip_plugin/pip_configuration.dart';
import 'package:pip_plugin/src/contracts/base_pip_plugin.dart';

class LoggedMethodChannel extends MethodChannel {
  const LoggedMethodChannel(super.name);

  @override
  Future<T?> invokeMethod<T>(String method, [arguments]) {
    log("LoggedMethodChannel:invokeMethod->method:$method,arguments:$arguments");
    return super.invokeMethod(method, arguments);
  }
}

class MethodChannelPipPlugin extends BasePipPlugin {
  final MethodChannel methodChannel = const LoggedMethodChannel('pip_plugin');
  late PipConfiguration _configuration;

  @override
  PipConfiguration get configuration => _configuration;

  List<int> _colorToIntList(Color color) =>
      [color.red, color.green, color.blue, color.alpha];

  @override
  Future<bool> performSetup(
      String? windowTitle, PipConfiguration? configuration) async {
    try {
      _configuration = configuration ?? PipConfiguration.initial;
      final args = {
        'windowTitle': windowTitle,
        'ratio': [_configuration.ratio.$1, _configuration.ratio.$2],
        'backgroundColor': _colorToIntList(_configuration.backgroundColor),
        'textColor': _colorToIntList(_configuration.textColor),
        'textSize': _configuration.textSize,
        'textAlign': _configuration.textAlign.name,
      };
      final result = await methodChannel.invokeMethod<bool>('setupPip', args);
      methodChannel.setMethodCallHandler(_handleMethodCall);
      markInitialized();
      return result ?? false;
    } catch (e, st) {
      debugPrint('MethodChannelPipPlugin.performSetup error: $e\n$st');
      return false;
    }
  }

  Future<void> _handleMethodCall(MethodCall call) async {
    if (call.method == 'pipStopped') {
      handlePipExited();
    }
  }

  @override
  Future<bool> startPip() async {
    checkInitialized();
    try {
      final started =
          await methodChannel.invokeMethod<bool>('startPip') ?? false;
      if (started) handlePipEntered();
      return started;
    } catch (e, st) {
      debugPrint('MethodChannelPipPlugin.startPip error: $e\n$st');
      return false;
    }
  }

  @override
  Future<bool> stopPip() async {
    checkInitialized();
    try {
      final stopped =
          await methodChannel.invokeMethod<bool>('stopPip') ?? false;
      if (stopped) handlePipExited();
      return stopped;
    } catch (e, st) {
      debugPrint('MethodChannelPipPlugin.stopPip error: $e\n$st');
      return false;
    }
  }

  @override
  Future<bool> isPipSupported() async {
    try {
      return await methodChannel.invokeMethod<bool>('isPipSupported') ?? false;
    } catch (e, st) {
      debugPrint('MethodChannelPipPlugin.isPipSupported error: $e\n$st');
      return false;
    }
  }

  @override
  Future<bool> update(PipConfiguration configuration) async {
    checkInitialized();
    try {
      final args = {
        'backgroundColor': _colorToIntList(configuration.backgroundColor),
        'textColor': _colorToIntList(configuration.textColor),
        'textSize': configuration.textSize,
        'ratio': [configuration.ratio.$1, configuration.ratio.$2],
        'textAlign': configuration.textAlign.name,
        'speed': configuration.speed,
      };
      final success =
          await methodChannel.invokeMethod<bool>('updatePip', args) ?? false;
      if (success) _configuration = configuration;
      return success;
    } catch (e, st) {
      debugPrint('MethodChannelPipPlugin.update error: $e\n$st');
      return false;
    }
  }

  @override
  Future<bool> updateText(String text) async {
    checkInitialized();
    try {
      return await methodChannel
              .invokeMethod<bool>('updateText', {'text': text}) ??
          false;
    } catch (e, st) {
      debugPrint('MethodChannelPipPlugin.updateText error: $e\n$st');
      return false;
    }
  }

  @override
  Future<void> controlScroll({
    required bool isScrolling,
    double? speed,
  }) async {
    checkInitialized();
    try {
      await methodChannel.invokeMethod<bool>('controlScroll', {
        'isScrolling': isScrolling,
        'speed': speed,
      });
    } catch (e, st) {
      debugPrint('MethodChannelPipPlugin.controlScroll error: $e\n$st');
    }
  }

  @override
  void dispose() {
    super.dispose();
    _configuration = PipConfiguration.initial;
  }
}
