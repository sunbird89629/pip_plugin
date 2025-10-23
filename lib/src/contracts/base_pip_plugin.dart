import 'dart:async';

import 'package:pip_plugin/pip_configuration.dart';
import 'package:pip_plugin/src/contracts/pip_plugin_platform_interface.dart';
import 'package:simple_pip_mode/actions/pip_action.dart';

abstract class BasePipPlugin extends PipPluginPlatform {
  final StreamController<bool> _pipStatusController =
      StreamController<bool>.broadcast();

  final StreamController<PipAction> _pipActionController =
      StreamController<PipAction>.broadcast();

  bool _isInitialized = false;
  @override
  bool get isInitialized => _isInitialized;

  void handlePipEntered() => _pipStatusController.add(true);

  void handlePipExited() => _pipStatusController.add(false);

  void handlePipAction(PipAction action) => _pipActionController.add(action);

  @override
  Stream<bool> get pipActiveStream => _pipStatusController.stream;
  @override
  Stream<PipAction> get pipActionStream => _pipActionController.stream;

  void markInitialized() {
    _isInitialized = true;
  }

  void checkInitialized() {
    if (!_isInitialized) {
      throw Exception('PipPlugin not initialized. Call setupPip() first.');
    }
  }

  @override
  Future<bool> setupPip({
    String? windowTitle,
    PipConfiguration? configuration,
  }) async {
    return performSetup(windowTitle, configuration);
  }

  Future<bool> performSetup(
      String? windowTitle, PipConfiguration? configuration);

  @override
  void dispose() {
    stopPip().ignore();
    _pipStatusController.add(false);
    _isInitialized = false;
  }
}
