import 'dart:io';

import 'package:flutter/material.dart';

/// Prefer the distro's actual color font over monochrome symbol fallback on Linux.
class EmojiSymbol extends StatelessWidget {
  const EmojiSymbol(this.symbol, {super.key, required this.fontSize});

  final String symbol;
  final double fontSize;

  @override
  Widget build(BuildContext context) => Text(
    symbol,
    style: TextStyle(
      fontSize: fontSize,
      fontFamily: Platform.isLinux ? 'Noto Color Emoji' : null,
      fontFamilyFallback: Platform.isLinux ? const ['Inter'] : null,
    ),
  );
}
