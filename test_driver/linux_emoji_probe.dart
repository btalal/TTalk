// A separate CI-only entry point. Never packaged as the application.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:ttalk/ui/emoji_symbol.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final boundaryKey = GlobalKey();
  runApp(
    MaterialApp(
      theme: ThemeData(fontFamily: 'Inter'),
      home: Scaffold(
        body: Center(
          child: RepaintBoundary(
            key: boundaryKey,
            child: const ColoredBox(
              color: Colors.white,
              child: SizedBox.square(
                dimension: 160,
                child: Center(child: EmojiSymbol('🐱', fontSize: 96)),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  try {
    await Future<void>.delayed(const Duration(seconds: 1));
    await WidgetsBinding.instance.endOfFrame;
    final boundary =
        boundaryKey.currentContext!.findRenderObject()!
            as RenderRepaintBoundary;
    final image = await boundary.toImage();
    final pixels = (await image.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    ))!;
    var colored = 0;
    for (var i = 0; i < pixels.lengthInBytes; i += 4) {
      final r = pixels.getUint8(i);
      final g = pixels.getUint8(i + 1);
      final b = pixels.getUint8(i + 2);
      final max = r > g ? (r > b ? r : b) : (g > b ? g : b);
      final min = r < g ? (r < b ? r : b) : (g < b ? g : b);
      if (pixels.getUint8(i + 3) > 200 && max - min > 60) colored++;
    }
    final path = Platform.environment['TTALK_PROBE_OUTPUT'];
    if (path != null) {
      await File('$path/emoji-color.png').writeAsBytes(
        (await image.toByteData(format: ui.ImageByteFormat.png))!.buffer
            .asUint8List(),
      );
      await File('$path/emoji-color-check.txt')
          .writeAsString('Noto Color Emoji: $colored colored pixels\n');
    }
    image.dispose();
    if (colored < 400) {
      throw StateError('Emoji rendered without sufficient color: $colored');
    }
    stdout.writeln('Color emoji verified: $colored colored pixels');
    exit(0);
  } catch (error) {
    stderr.writeln('Color emoji verification failed: $error');
    exit(1);
  }
}
