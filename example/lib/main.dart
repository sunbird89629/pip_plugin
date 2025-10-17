import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pip_plugin/pip_configuration.dart';
import 'package:pip_plugin/pip_plugin.dart';
import 'package:pip_plugin/text_pip_widget.dart';
import 'package:pip_plugin_example/teleprompter_text.dart';

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
  bool _pipStarted = false;
  bool _isSupported = false;
  late final StreamSubscription<bool> _pipStatusSub;

  double _currentSpeedValue = 1.0;
  final int baseSpeed = 30;
  final double fontSize = 30;

  final voiceScript =
      "Hey everyone, this air conditioner can completely cool down your house, your room, or even your car! If your car doesn’t have air conditioning, I highly recommend you get this now. It’s super easy to use—just add water, press two buttons, and it starts cooling down quickly. You can use it in your room, outdoors, in the car, or on the go. Plus, it’s really convenient to carry and can run continuously for two days. It drains quickly with just one charge. So, I suggest you grab one now!Hey everyone, this air conditioner can completely cool down your house, your room, or even your car! If your car doesn’t have air conditioning, I highly recommend you get this now. It’s super easy to use—just add water, press two buttons, and it starts cooling down quickly. You can use it in your room, outdoors, in the car, or on the go. Plus, it’s really convenient to carry and can run continuously for two days. It drains quickly with just one charge. So, I suggest you grab one now!";

  @override
  void initState() {
    super.initState();
    _initPlugin().then(
      (_) {
        _pipStatusSub = _plugin.pipActiveStream.listen(
          (isActive) {
            if (!isActive && _pipStarted) {
              _plugin.controlScroll(isScrolling: false);
              setState(() {
                _pipStarted = false;
              });
              _showSnackBar('PiP closed — timer stopped.');
            }
          },
        );
      },
    );
  }

  Future<void> _initPlugin() async {
    final supported = await _plugin.isPipSupported();
    setState(() => _isSupported = supported);
    if (supported) {
      await _plugin.setupPip(
        configuration: PipConfiguration.initial.copyWith(textSize: fontSize),
      );
    }
  }

  Future<void> _startPip() async {
    await _plugin.updateText(voiceScript);
    await _plugin.update(
      speed: _currentSpeedValue * baseSpeed,
      textSize: fontSize,
    );
    final started = await _plugin.startPip();
    if (started) {
      setState(() => _pipStarted = true);
      _plugin.controlScroll(isScrolling: true);
    } else {
      _showSnackBar('Failed to start PiP');
    }
  }

  Future<void> _stopPip() async {
    await _plugin.controlScroll(isScrolling: false);
    await _plugin.stopPip();
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
    _pipStatusSub.cancel();
    super.dispose();
  }

  final items = <Item>[
    const Item(label: "0.75x", speed: 0.75),
    const Item(label: "1.0x", speed: 1.0),
    const Item(label: "1.25x", speed: 1.25),
    const Item(label: "1.5x", speed: 1.5),
    const Item(label: "1.75x", speed: 1.75),
    // const Item(label: "2.0x", speed: 2.0),
  ];

  @override
  Widget build(BuildContext context) {
    return TextPipWidget(
      child: Scaffold(
        appBar: AppBar(title: const Text('PiP Timer')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                height: 300,
                margin: const EdgeInsets.only(left: 16, right: 16),
                child: TeleprompterText(
                  text: voiceScript,
                  speed: _currentSpeedValue * baseSpeed,
                  fontSize: fontSize,
                ),
              ),
              const SizedBox(height: 30),
              Container(
                margin: const EdgeInsets.only(left: 16, right: 16),
                alignment: Alignment.centerLeft,
                child: const Text(
                  "Speed",
                  style: TextStyle(fontSize: 30),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: List.generate(
                  items.length,
                  (index) => Row(
                    children: [
                      Radio(
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        value: items[index].speed,
                        groupValue: _currentSpeedValue,
                        onChanged: (value) => setState(
                          () {
                            _currentSpeedValue = value ?? 1.0;
                          },
                        ),
                      ),
                      Text(items[index].label),
                    ],
                  ),
                ),
              ),
              if (_isSupported)
                ElevatedButton(
                  onPressed: _pipStarted ? _stopPip : _startPip,
                  child: Text(
                    _pipStarted
                        ? 'Dismiss Floating Window'
                        : 'Launch Floating Window',
                  ),
                )
              else
                const Text(
                  'PiP not supported on this platform',
                  style: TextStyle(color: Colors.red),
                ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

class Item {
  const Item({
    required this.label,
    required this.speed,
  });
  final String label;
  final double speed;
}
