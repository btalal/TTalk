import 'package:flutter/material.dart';

/// Flat illustrated avatars: 20 people and 20 groups, drawn in code so they
/// stay sharp at every size and add nothing to the package.
class AvatarArt extends StatelessWidget {
  const AvatarArt({
    super.key,
    required this.index,
    this.group = false,
    this.size = 40,
  });

  final int index;
  final bool group;
  final double size;

  static const count = 20;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(painter: _AvatarPainter(index % count, group)),
  );
}

class _Person {
  const _Person(this.skin, this.hair, this.style, this.shirt, this.glasses);
  final Color skin, hair, shirt;
  final int style;
  final bool glasses;
}

const _backgrounds = <Color>[
  Color(0xFF6C5CE7), Color(0xFF00A884), Color(0xFF0984E3), Color(0xFFE17055),
  Color(0xFFF5B83D), Color(0xFFD6457F), Color(0xFF00A8A8), Color(0xFF8E7CF8),
  Color(0xFF2EAD6B), Color(0xFFF08A6C), Color(0xFF4C8DF6), Color(0xFFE35D6A),
  Color(0xFF3FB8C9), Color(0xFFE9A23B), Color(0xFFC2417A), Color(0xFF5865F2),
  Color(0xFF16A085), Color(0xFFF06D3F), Color(0xFF7F8CFF), Color(0xFFB85CE6),
];

const _people = <_Person>[
  _Person(Color(0xFFF5D0B5), Color(0xFF2B1D14), 0, Color(0xFFFFFFFF), false),
  _Person(Color(0xFFE8B895), Color(0xFF5B3A1E), 1, Color(0xFF1F2937), false),
  _Person(Color(0xFFC98E6B), Color(0xFF1A1410), 3, Color(0xFFFDE68A), false),
  _Person(Color(0xFFF1C9A5), Color(0xFFE8C15A), 2, Color(0xFF1E3A8A), true),
  _Person(Color(0xFFA0694A), Color(0xFF1A1410), 4, Color(0xFFF9FAFB), false),
  _Person(Color(0xFFF5D0B5), Color(0xFF9C3D2E), 1, Color(0xFFFFFFFF), false),
  _Person(Color(0xFF7A4B32), Color(0xFF1A1410), 3, Color(0xFFF59E0B), false),
  _Person(Color(0xFFE8B895), Color(0xFF2B1D14), 4, Color(0xFF111827), true),
  _Person(Color(0xFFF1C9A5), Color(0xFFC9822E), 0, Color(0xFFFFFFFF), false),
  _Person(Color(0xFFC98E6B), Color(0xFF2B1D14), 2, Color(0xFF1F2937), false),
  _Person(Color(0xFFF5D0B5), Color(0xFF6B7280), 0, Color(0xFFFDE68A), true),
  _Person(Color(0xFFA0694A), Color(0xFF2B1D14), 1, Color(0xFFFFFFFF), false),
  _Person(Color(0xFFE8B895), Color(0xFFE8C15A), 3, Color(0xFF312E81), false),
  _Person(Color(0xFF7A4B32), Color(0xFF1A1410), 0, Color(0xFFFFFFFF), true),
  _Person(Color(0xFFF1C9A5), Color(0xFF5B3A1E), 4, Color(0xFFFFFFFF), false),
  _Person(Color(0xFFC98E6B), Color(0xFF9C3D2E), 2, Color(0xFFFDE68A), false),
  _Person(Color(0xFFF5D0B5), Color(0xFF1A1410), 1, Color(0xFF111827), true),
  _Person(Color(0xFFA0694A), Color(0xFFC9822E), 3, Color(0xFFFFFFFF), false),
  _Person(Color(0xFFE8B895), Color(0xFFE5E7EB), 0, Color(0xFF1E3A8A), true),
  _Person(Color(0xFF7A4B32), Color(0xFF5B3A1E), 2, Color(0xFFFFFFFF), false),
];

const _ink = Color(0xFF1F1A2E);

class _AvatarPainter extends CustomPainter {
  _AvatarPainter(this.index, this.group);
  final int index;
  final bool group;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 100, size.height / 100);
    canvas.clipPath(
      Path()..addOval(const Rect.fromLTWH(0, 0, 100, 100)),
    );
    final background = group
        ? _backgrounds[(index * 3 + 5) % AvatarArt.count]
        : _backgrounds[index];
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 100, 100),
      Paint()..color = background,
    );
    canvas.drawCircle(
      const Offset(86, 14),
      30,
      Paint()..color = const Color(0x1FFFFFFF),
    );
    if (group) {
      _member(canvas, _people[(index + 7) % 20], -1, 16, .6);
      _member(canvas, _people[(index + 13) % 20], 41, 16, .6);
      _member(canvas, _people[index], 14, 26, .72);
    } else {
      _member(canvas, _people[index], 0, 2, 1);
    }
    canvas.restore();
  }

  void _member(Canvas canvas, _Person p, double dx, double dy, double scale) {
    canvas.save();
    canvas.translate(dx, dy);
    canvas.scale(scale);
    final skin = Paint()..color = p.skin;
    canvas.drawPath(
      Path()
        ..moveTo(16, 104)
        ..cubicTo(16, 80, 31, 70, 50, 70)
        ..cubicTo(69, 70, 84, 80, 84, 104)
        ..close(),
      Paint()..color = p.shirt,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(44, 56, 12, 16),
        const Radius.circular(5),
      ),
      skin,
    );
    canvas.drawCircle(const Offset(33, 47), 3.5, skin);
    canvas.drawCircle(const Offset(67, 47), 3.5, skin);
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(50, 45), width: 34, height: 38),
      skin,
    );
    canvas.drawPath(_hair(p.style), Paint()..color = p.hair);
    final ink = Paint()..color = _ink;
    canvas.drawCircle(const Offset(43, 46), 2, ink);
    canvas.drawCircle(const Offset(57, 46), 2, ink);
    final stroke = Paint()
      ..color = _ink
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2;
    canvas.drawPath(
      Path()
        ..moveTo(44, 54)
        ..quadraticBezierTo(50, 59, 56, 54),
      stroke,
    );
    if (p.glasses) {
      final frame = Paint()
        ..color = _ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6;
      canvas.drawCircle(const Offset(43, 46), 5.5, frame);
      canvas.drawCircle(const Offset(57, 46), 5.5, frame);
      canvas.drawLine(const Offset(48.5, 46), const Offset(51.5, 46), frame);
    }
    canvas.restore();
  }

  static Path _short() => Path()
    ..moveTo(33, 46)
    ..cubicTo(30, 27, 41, 21, 51, 21)
    ..cubicTo(62, 21, 71, 29, 67, 46)
    ..cubicTo(64, 37, 58, 32, 50, 32)
    ..cubicTo(42, 32, 36, 37, 33, 46)
    ..close();

  static Path _hair(int style) {
    switch (style) {
      case 1:
        return Path()
          ..moveTo(31, 48)
          ..cubicTo(28, 25, 41, 19, 51, 19)
          ..cubicTo(63, 19, 73, 27, 69, 49)
          ..lineTo(71, 70)
          ..cubicTo(65, 66, 66, 54, 66, 45)
          ..cubicTo(62, 35, 56, 31, 50, 31)
          ..cubicTo(43, 31, 36, 36, 34, 45)
          ..cubicTo(34, 54, 35, 66, 29, 70)
          ..close();
      case 2:
        return _short()
          ..addOval(Rect.fromCircle(center: const Offset(50, 20), radius: 8));
      case 3:
        final curls = Path();
        for (final (x, y, r) in const [
          (36.0, 37.0, 7.0),
          (41.0, 29.0, 8.0),
          (50.0, 25.0, 9.0),
          (59.0, 29.0, 8.0),
          (64.0, 37.0, 7.0),
        ]) {
          curls.addOval(Rect.fromCircle(center: Offset(x, y), radius: r));
        }
        return curls;
      case 4:
        return Path()
          ..moveTo(33, 46)
          ..cubicTo(31, 26, 44, 20, 54, 22)
          ..cubicTo(64, 23, 70, 31, 67, 46)
          ..cubicTo(66, 40, 63, 35, 58, 33)
          ..cubicTo(50, 36, 41, 36, 35, 41)
          ..close();
      default:
        return _short();
    }
  }

  @override
  bool shouldRepaint(_AvatarPainter old) =>
      old.index != index || old.group != group;
}
