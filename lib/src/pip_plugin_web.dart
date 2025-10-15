import 'dart:js_interop';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:pip_plugin/pip_configuration.dart';
import 'package:pip_plugin/src/contracts/base_pip_plugin.dart';
import 'package:pip_plugin/src/contracts/pip_plugin_platform_interface.dart';
import 'package:web/web.dart' as web;

class PipPluginWeb extends BasePipPlugin {
  web.HTMLVideoElement? _video;
  web.HTMLCanvasElement? _canvas;
  late PipConfiguration _configuration;

  @override
  PipConfiguration get configuration => _configuration;

  static void registerWith(Registrar registrar) {
    PipPluginPlatform.instance = PipPluginWeb();
  }

  String _colorToCssRgba(Color color) =>
      'rgba(${color.red}, ${color.green}, ${color.blue}, ${color.alpha / 255})';

  @override
  Future<bool> isPipSupported() async {
    try {
      final enabled = web.document.pictureInPictureEnabled;
      return enabled;
    } catch (e, st) {
      debugPrint('PipPluginWeb.isPipSupported error: $e\n$st');
      return false;
    }
  }

  @override
  Future<bool> performSetup(
      String? windowTitle, PipConfiguration? configuration) async {
    try {
      _configuration = configuration ?? PipConfiguration.initial;
      _initializeCanvasAndVideo();
      markInitialized();
      return true;
    } catch (e, st) {
      debugPrint('PipPluginWeb.performSetup error: $e\n$st');
      return false;
    }
  }

  void _initializeCanvasAndVideo() {
    try {
      final size = _getSizeFromRatio();
      _video = web.HTMLVideoElement()
        ..style.position = 'absolute'
        ..style.left = '-9999px'
        ..autoplay = true
        ..muted = true;
      _canvas = web.HTMLCanvasElement()
        ..width = size.width.toInt()
        ..height = size.height.toInt()
        ..style.position = 'absolute'
        ..style.left = '-9999px';

      web.document.body!.appendChild(_video!);
      web.document.body!.appendChild(_canvas!);

      _video!.srcObject = _canvas!.captureStream(30);
      _video!.addEventListener(
          'leavepictureinpicture',
          (web.Event event) {
            handlePipExited();
          }.toJS);
      _updateCanvas();
    } catch (e, st) {
      debugPrint('PipPluginWeb._initializeCanvasAndVideo error: $e\n$st');
      rethrow;
    }
  }

  @override
  Future<bool> startPip() async {
    checkInitialized();
    if (_video == null) {
      debugPrint('PipPluginWeb.startPip called before initialization');
      return false;
    }

    try {
      await _video!.play().toDart;
      final currentPiP = web.document.pictureInPictureElement;
      if (currentPiP != _video) {
        await _video!.requestPictureInPicture().toDart;
      }
      handlePipEntered();
      return true;
    } catch (e, st) {
      debugPrint('PipPluginWeb.startPip error: $e\n$st');
      return false;
    }
  }

  @override
  Future<bool> stopPip() async {
    checkInitialized();
    try {
      await web.document.exitPictureInPicture().toDart;
      handlePipExited();
      return true;
    } catch (e, st) {
      debugPrint('PipPluginWeb.stopPip error: $e\n$st');
      return false;
    }
  }

  @override
  Future<bool> update(PipConfiguration configuration) async {
    checkInitialized();
    _configuration = configuration;
    try {
      _updateCanvas();
      return true;
    } catch (e, st) {
      debugPrint('PipPluginWeb.update error: $e\n$st');
      return false;
    }
  }

  @override
  Future<bool> updateText(String text) async {
    checkInitialized();
    try {
      _updateCanvas(text: text);
      return true;
    } catch (e, st) {
      debugPrint('PipPluginWeb.updateText error: $e\n$st');
      return false;
    }
  }

  void _updateCanvas({String text = ''}) {
    final ctx = _canvas?.getContext('2d') as web.CanvasRenderingContext2D?;
    if (ctx == null) {
      throw StateError('Canvas not initialized');
    }
    ctx
      ..clearRect(0, 0, _canvas!.width, _canvas!.height)
      ..fillStyle = _colorToCssRgba(_configuration.backgroundColor).toJS
      ..fillRect(0, 0, _canvas!.width, _canvas!.height)
      ..font = '${_configuration.textSize}px Arial'
      ..fillStyle = _colorToCssRgba(_configuration.textColor).toJS
      ..textAlign = _getTextAlign()
      ..fillText(text, _canvas!.width / 2, _canvas!.height / 2);
  }

  String _getTextAlign() => switch (_configuration.textAlign) {
        TextAlign.left => 'left',
        TextAlign.right => 'right',
        _ => 'center',
      };

  Size _getSizeFromRatio() {
    const height = 180.0;
    return Size(
        height * _configuration.ratio.$1 / _configuration.ratio.$2, height);
  }

  @override
  void dispose() {
    super.dispose();
    try {
      _video?.remove();
      _canvas?.remove();
    } catch (e, st) {
      debugPrint('PipPluginWeb.dispose remove error: $e\n$st');
    }
    _video = null;
    _canvas = null;
  }

  @override
  Future<void> controlScroll({required bool isScrolling, double? speed}) {
    // TODO: implement controlScroll
    throw UnimplementedError();
  }
}
