import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pip_plugin/pip_configuration.dart';
import 'package:pip_plugin/pip_plugin.dart';
import 'package:pip_plugin/text_pip_widget.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'PiP Timer Example',
      home: PipTimerPage(),
    );
  }
}

class PipTimerPage extends StatefulWidget {
  const PipTimerPage({super.key});
  @override
  State<PipTimerPage> createState() => _PipTimerPageState();
}

class _PipTimerPageState extends State<PipTimerPage> {
  final PipPlugin _plugin = PipPlugin();
  final Stopwatch _stopwatch = Stopwatch();
  Timer? _timer;
  final String _time = '00:00';
  bool _pipStarted = false;
  bool _isSupported = false;
  late final StreamSubscription<bool> _pipStatusSub;

  final voiceScript =
      "Hey everyone, this air conditioner \ncan completely cool down your house,\n your room, or even your car!\nIf your car doesn’t have air conditi\noning, I highly recommend you get this now. It’s super eas\ny to use—just add water, press two buttons, and it \nstarts cooling down quickly. \nYou can use it in your room, outdoors, in the car, or on the \ngo. Plus, it’s really convenient \nto carry and can run continuously for two days. \nIt drains quickly with just one charge. \nSo, I suggest you grab one now!Hey everyone, \nthis air conditioner can completely cool \ndown your house, your room, or even your car! If your car \ndoesn’t have air conditioning, \nI highly recommend you get this now. \nIt’s super easy to use—just add water, \npress two buttons, and it starts cooling down \nquickly. You can use it in your room, outdoors, \nin the car, or on the go. Plus, it’s really\n convenient to carry and can run\n continuously for two days. It drains quickly with \njust one charge. So, I suggest you grab one now!";

  @override
  void initState() {
    super.initState();
    _initPlugin().then((_) {
      _pipStatusSub = _plugin.pipActiveStream.listen((isActive) {
        if (!isActive && _pipStarted) {
          _plugin.controlScroll(isScrolling: false);
          _stopTimer();
          setState(() {
            _pipStarted = false;
          });
          _showSnackBar('PiP closed — timer stopped.');
        }
      });
    });
  }

  Future<void> _initPlugin() async {
    final supported = await _plugin.isPipSupported();
    setState(() => _isSupported = supported);
    if (supported) {
      await _plugin.setupPip(
        configuration: PipConfiguration.initial.copyWith(
          textColor: Colors.red,
        ),
      );
    }
  }
  // void _startTimer() {
  //   _stopwatch.start();
  //   _timer = Timer.periodic(const Duration(seconds: 1), (_) {
  //     final elapsed = _stopwatch.elapsed;
  //     setState(() {
  //       _time = '${elapsed.inMinutes.toString().padLeft(2, '0')}:'
  //           '${(elapsed.inSeconds % 60).toString().padLeft(2, '0')}';
  //     });
  //     if (_pipStarted) {
  //       _plugin.updateText('aaaa${_time}bbbb');
  //     }
  //   });
  // }

  void _stopTimer() {
    _stopwatch.stop();
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _startPip() async {
    // await _plugin.updateText(_time);
    await _plugin.updateText(voiceScript);
    final started = await _plugin.startPip();
    if (started) {
      setState(() => _pipStarted = true);
      // _startTimer();
      _plugin.controlScroll(isScrolling: true);
    } else {
      _showSnackBar('Failed to start PiP');
    }
  }

  Future<void> _stopPip() async {
    await _plugin.controlScroll(isScrolling: false);
    await _plugin.stopPip();
    _stopTimer();
    setState(() => _pipStarted = false);
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pipStatusSub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextPipWidget(
      child: Scaffold(
        appBar: AppBar(title: const Text('PiP Timer')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  voiceScript,
                  style: const TextStyle(fontSize: 48),
                ),
              ),
              const SizedBox(height: 32),
              if (_isSupported)
                ElevatedButton(
                  onPressed: _pipStarted ? _stopPip : _startPip,
                  child: Text(_pipStarted ? 'Stop PiP' : 'Start PiP'),
                )
              else
                const Text(
                  'PiP not supported on this platform',
                  style: TextStyle(color: Colors.red),
                ),
              const SizedBox(
                height: 40,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
