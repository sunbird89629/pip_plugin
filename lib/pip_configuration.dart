import 'package:flutter/material.dart';

class PipConfiguration {
  final Color backgroundColor;
  final Color textColor;
  final double textSize;
  final TextAlign textAlign;
  final (int, int) ratio;
  final double speed;

  PipConfiguration({
    required this.backgroundColor,
    required this.ratio,
    required this.textAlign,
    required this.textColor,
    required this.textSize,
    required this.speed,
  });

  static PipConfiguration get initial => PipConfiguration(
        backgroundColor: Colors.black,
        textColor: Colors.white,
        textSize: 32.0,
        textAlign: TextAlign.center,
        ratio: (16, 9),
        speed: 1.0,
      );

  PipConfiguration copyWith({
    Color? backgroundColor,
    Color? textColor,
    double? textSize,
    TextAlign? textAlign,
    (int, int)? ratio,
    double? speed,
  }) {
    return PipConfiguration(
      backgroundColor: backgroundColor ?? this.backgroundColor,
      textColor: textColor ?? this.textColor,
      textSize: textSize ?? this.textSize,
      textAlign: textAlign ?? this.textAlign,
      ratio: ratio ?? this.ratio,
      speed: speed ?? this.speed,
    );
  }
}
