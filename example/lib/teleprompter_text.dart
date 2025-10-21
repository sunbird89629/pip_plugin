import 'dart:async';

import 'package:flutter/material.dart';

class TeleprompterText extends StatefulWidget {
  final String text;
  final double speed;
  final double fontSize;

  const TeleprompterText({
    super.key,
    required this.text,
    required this.speed,
    required this.fontSize,
  });

  @override
  State<TeleprompterText> createState() => _TeleprompterTextState();
}

class _TeleprompterTextState extends State<TeleprompterText> {
  final ScrollController _controller = ScrollController();
  Timer? _timer;
  double _offset = 0;
  bool _isPlaying = true;

  void _togglePlay() {
    setState(() => _isPlaying = !_isPlaying);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _start();
    });
  }

  void _start() {
    _timer = Timer.periodic(const Duration(milliseconds: 16), (_) {
      if (!_isPlaying) return;
      final maxScroll = _controller.position.maxScrollExtent;
      final delta = (widget.speed / 60);
      _offset += delta;
      if (_offset < 0) _offset = maxScroll;
      if (_offset > maxScroll) _offset = 0;
      _controller.jumpTo(_offset);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _togglePlay,
      child: Stack(
        children: [
          SingleChildScrollView(
            controller: _controller,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                widget.text,
                style: TextStyle(fontSize: widget.fontSize, height: 1.2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
