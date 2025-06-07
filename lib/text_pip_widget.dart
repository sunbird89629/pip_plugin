import 'package:flutter/material.dart';
import 'package:pip_plugin/src/pip_plugin_android.dart';
import 'package:pip_plugin/src/contracts/pip_plugin_platform_interface.dart';

class TextPipWidget extends StatefulWidget {
  const TextPipWidget({super.key, this.child});
  final Widget? child;

  @override
  State<TextPipWidget> createState() => _TextPipWidgetState();
}

class _TextPipWidgetState extends State<TextPipWidget> {
  final _scrollController = ScrollController();
  final PipPluginAndroid? pipPlugin =
      PipPluginPlatform.instance is PipPluginAndroid
          ? PipPluginPlatform.instance as PipPluginAndroid
          : null;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (pipPlugin == null) {
      return widget.child ?? const SizedBox.shrink();
    }

    return StreamBuilder<bool>(
      stream: pipPlugin!.pipActiveStream,
      builder: (context, snapshot) {
        final isPipActive = snapshot.data ?? false;
        return Stack(
          children: [
            widget.child ?? const SizedBox.shrink(),
            if (isPipActive)
              Positioned.fill(
                child: _PipContent(
                  pipPlugin: pipPlugin!,
                  scrollController: _scrollController,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _PipContent extends StatelessWidget {
  final PipPluginAndroid pipPlugin;
  final ScrollController scrollController;

  const _PipContent({
    required this.pipPlugin,
    required this.scrollController,
  });

  void _scrollToEnd() {
    if (scrollController.hasClients) {
      scrollController.animateTo(
        scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: pipPlugin.configurationNotifier,
      builder: (BuildContext context, value, _) {
        return ValueListenableBuilder(
            valueListenable: pipPlugin.text,
            builder: (ctx, text, _) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _scrollToEnd();
              });
              return Scaffold(
                body: Container(
                  color: value.backgroundColor,
                  width: double.infinity,
                  height: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Align(
                    alignment: getAlignment(value.textAlign),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      controller: scrollController,
                      child: Text(
                        text,
                        textAlign: value.textAlign,
                        style: TextStyle(
                          color: value.textColor,
                          fontSize: value.textSize,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            });
      },
    );
  }

  Alignment getAlignment(TextAlign textAlign) {
    switch (textAlign) {
      case TextAlign.left:
        return Alignment.centerLeft;
      case TextAlign.right:
        return Alignment.centerRight;
      case TextAlign.center:
        return Alignment.center;
      default:
        return Alignment.center;
    }
  }
}
