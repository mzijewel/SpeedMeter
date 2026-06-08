import 'dart:math';
import 'package:flutter/material.dart';

class SpeedometerGauge extends StatelessWidget {
  final double speedKmh;
  final double maxDisplaySpeed;

  const SpeedometerGauge({
    super.key,
    required this.speedKmh,
    this.maxDisplaySpeed = 160.0,
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.0,
      child: CustomPaint(
        painter: _SpeedometerPainter(
          speedKmh: speedKmh,
          maxSpeed: maxDisplaySpeed,
        ),
      ),
    );
  }
}

class _SpeedometerPainter extends CustomPainter {
  final double speedKmh;
  final double maxSpeed;

  static const double _startAngleDeg = 150.0;
  static const double _sweepAngleDeg = 240.0;
  static const double _startAngle = _startAngleDeg * pi / 180.0;
  static const double _sweepAngle = _sweepAngleDeg * pi / 180.0;

  const _SpeedometerPainter({required this.speedKmh, required this.maxSpeed});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final arcRadius = radius * 0.78;

    _drawBackground(canvas, center, radius);
    _drawTrackArc(canvas, center, arcRadius);
    _drawSpeedArc(canvas, center, arcRadius);
    _drawTicks(canvas, center, arcRadius);
    _drawNeedle(canvas, center, arcRadius);
    _drawCenterCap(canvas, center);
  }

  void _drawBackground(Canvas canvas, Offset center, double radius) {
    canvas.drawCircle(
      center,
      radius,
      Paint()..color = const Color(0xFF0D0D1A),
    );
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = const Color(0xFF2D2D44)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  void _drawTrackArc(Canvas canvas, Offset center, double arcRadius) {
    final paint = Paint()
      ..color = const Color(0xFF2D2D44)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;

    final rect = Rect.fromCircle(center: center, radius: arcRadius);
    canvas.drawArc(rect, _startAngle, _sweepAngle, false, paint);
  }

  void _drawSpeedArc(Canvas canvas, Offset center, double arcRadius) {
    final fraction = (speedKmh / maxSpeed).clamp(0.0, 1.0);
    if (fraction == 0) return;

    final paint = Paint()
      ..color = _speedColor(fraction)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;

    final rect = Rect.fromCircle(center: center, radius: arcRadius);
    canvas.drawArc(rect, _startAngle, _sweepAngle * fraction, false, paint);
  }

  Color _speedColor(double fraction) {
    if (fraction < 0.5) {
      return Color.lerp(
            const Color(0xFF00E676), const Color(0xFFFFEB3B), fraction * 2)!;
    } else if (fraction < 0.75) {
      return Color.lerp(const Color(0xFFFFEB3B), const Color(0xFFFF6D00),
          (fraction - 0.5) * 4)!;
    } else {
      return Color.lerp(const Color(0xFFFF6D00), const Color(0xFFD50000),
          (fraction - 0.75) * 4)!;
    }
  }

  void _drawTicks(Canvas canvas, Offset center, double arcRadius) {
    final majorPaint = Paint()
      ..color = const Color(0xFF9E9E9E)
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;
    final minorPaint = Paint()
      ..color = const Color(0xFF555566)
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round;

    const int majorCount = 8;
    const int minorPerMajor = 4;
    const int totalMinor = majorCount * minorPerMajor;

    for (int i = 0; i <= totalMinor; i++) {
      final bool isMajor = i % minorPerMajor == 0;
      final double fraction = i / totalMinor;
      final double angle = _startAngle + fraction * _sweepAngle;

      final double outerR = arcRadius - 6;
      final double innerR = isMajor ? arcRadius - 20 : arcRadius - 13;

      final Offset outer = center + Offset(cos(angle), sin(angle)) * outerR;
      final Offset inner = center + Offset(cos(angle), sin(angle)) * innerR;

      canvas.drawLine(outer, inner, isMajor ? majorPaint : minorPaint);

      if (isMajor) {
        final int speedLabel = (i ~/ minorPerMajor) * 20;
        final double labelR = arcRadius - 32;
        final Offset labelPos =
            center + Offset(cos(angle), sin(angle)) * labelR;
        _drawText(canvas, '$speedLabel', labelPos);
      }
    }
  }

  void _drawText(Canvas canvas, String text, Offset position) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: Color(0xFF9E9E9E),
          fontSize: 10,
          fontWeight: FontWeight.w400,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    tp.layout();
    tp.paint(
        canvas, position - Offset(tp.width / 2, tp.height / 2));
  }

  void _drawNeedle(Canvas canvas, Offset center, double arcRadius) {
    final fraction = (speedKmh / maxSpeed).clamp(0.0, 1.0);
    final double angle = _startAngle + fraction * _sweepAngle;

    final Offset tip =
        center + Offset(cos(angle), sin(angle)) * (arcRadius - 18);

    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(center, tip, paint);
  }

  void _drawCenterCap(Canvas canvas, Offset center) {
    canvas.drawCircle(center, 8, Paint()..color = const Color(0xFF2D2D44));
    canvas.drawCircle(center, 5, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_SpeedometerPainter old) => old.speedKmh != speedKmh;
}
