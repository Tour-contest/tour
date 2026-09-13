import 'package:flutter/material.dart';

/// docs/DESIGN.md: "아이콘: Lucide, stroke 1.5px, 13–20px".
/// 외부 아이콘 폰트 의존성 없이 필요한 아이콘만 직접 그린다.
enum AppIconShape {
  menu,
  edit,
  clip,
  arrowUp,
  arrowUpRight,
  copy,
  refresh,
  chevronLeft,
  settings,
  kakao,
  pin,
  phone,
  image,
}

class AppIcon extends StatelessWidget {
  const AppIcon(this.shape,
      {super.key, this.size = 16, this.color, this.strokeWidth = 1.5});

  final AppIconShape shape;
  final double size;
  final Color? color;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _AppIconPainter(
          shape: shape,
          color: color ?? IconTheme.of(context).color ?? Colors.black,
          strokeWidth: strokeWidth,
        ),
      ),
    );
  }
}

class _AppIconPainter extends CustomPainter {
  _AppIconPainter(
      {required this.shape, required this.color, required this.strokeWidth});

  final AppIconShape shape;
  final Color color;
  final double strokeWidth;

  // 모든 path는 24x24 기준 좌표로 그리고 캔버스 크기에 맞춰 스케일한다.
  static const _viewBox = 24.0;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / _viewBox;
    canvas.save();
    canvas.scale(scale, scale);

    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth / scale
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    switch (shape) {
      case AppIconShape.menu:
        canvas.drawLine(const Offset(4, 7), const Offset(20, 7), strokePaint);
        canvas.drawLine(const Offset(4, 12), const Offset(20, 12), strokePaint);
        canvas.drawLine(const Offset(4, 17), const Offset(20, 17), strokePaint);
        break;

      case AppIconShape.edit:
        canvas.drawLine(
            const Offset(4.5, 19.5), const Offset(14.5, 9.5), strokePaint);
        final tip = Path()
          ..moveTo(14.5, 9.5)
          ..lineTo(17, 7)
          ..lineTo(19, 9)
          ..lineTo(16.5, 11.5)
          ..close();
        canvas.drawPath(tip, fillPaint);
        break;

      case AppIconShape.clip:
        final p = Path()
          ..moveTo(14.5, 4.2)
          ..cubicTo(16.6, 4.2, 18.3, 5.9, 18.3, 8)
          ..lineTo(18.3, 14.2)
          ..cubicTo(18.3, 17.4, 15.7, 20, 12.5, 20)
          ..cubicTo(9.3, 20, 6.7, 17.4, 6.7, 14.2)
          ..lineTo(6.7, 7.6)
          ..cubicTo(6.7, 5.6, 8.3, 4, 10.3, 4)
          ..cubicTo(12.3, 4, 13.9, 5.6, 13.9, 7.6)
          ..lineTo(13.9, 14.2)
          ..cubicTo(13.9, 15.1, 13.2, 15.8, 12.3, 15.8)
          ..cubicTo(11.4, 15.8, 10.7, 15.1, 10.7, 14.2)
          ..lineTo(10.7, 8);
        canvas.drawPath(p, strokePaint);
        break;

      case AppIconShape.arrowUp:
        canvas.drawLine(const Offset(12, 19), const Offset(12, 5), strokePaint);
        final head = Path()
          ..moveTo(6, 11)
          ..lineTo(12, 5)
          ..lineTo(18, 11);
        canvas.drawPath(head, strokePaint);
        break;

      case AppIconShape.arrowUpRight:
        canvas.drawLine(const Offset(7, 17), const Offset(17, 7), strokePaint);
        final head = Path()
          ..moveTo(9, 7)
          ..lineTo(17, 7)
          ..lineTo(17, 15);
        canvas.drawPath(head, strokePaint);
        break;

      case AppIconShape.copy:
        final back = RRect.fromRectAndRadius(
          const Rect.fromLTWH(3, 3, 13, 13),
          const Radius.circular(2.5),
        );
        final front = RRect.fromRectAndRadius(
          const Rect.fromLTWH(8, 8, 13, 13),
          const Radius.circular(2.5),
        );
        canvas.drawRRect(back, strokePaint);
        final fillBehind = Paint()..color = const Color(0x00000000);
        canvas.drawRRect(front, fillBehind..style = PaintingStyle.fill);
        canvas.drawRRect(front, strokePaint);
        break;

      case AppIconShape.refresh:
        final rect = Rect.fromCircle(center: const Offset(12, 12), radius: 7.5);
        canvas.drawArc(rect, _deg(-160), _deg(230), false, strokePaint);
        final headTop = Path()
          ..moveTo(19.6, 5.5)
          ..lineTo(19.9, 10.2)
          ..lineTo(15.2, 9.9);
        canvas.drawPath(headTop, strokePaint);

        canvas.drawArc(rect, _deg(20), _deg(230), false, strokePaint);
        final headBottom = Path()
          ..moveTo(4.4, 18.5)
          ..lineTo(4.1, 13.8)
          ..lineTo(8.8, 14.1);
        canvas.drawPath(headBottom, strokePaint);
        break;

      case AppIconShape.chevronLeft:
        final p = Path()
          ..moveTo(15, 6)
          ..lineTo(9, 12)
          ..lineTo(15, 18);
        canvas.drawPath(p, strokePaint);
        break;

      case AppIconShape.settings:
        canvas.drawLine(const Offset(4, 6), const Offset(20, 6), strokePaint);
        canvas.drawCircle(const Offset(9, 6), 2.3, strokePaint);
        canvas.drawLine(const Offset(4, 12), const Offset(20, 12), strokePaint);
        canvas.drawCircle(const Offset(15, 12), 2.3, strokePaint);
        canvas.drawLine(const Offset(4, 18), const Offset(20, 18), strokePaint);
        canvas.drawCircle(const Offset(8, 18), 2.3, strokePaint);
        break;

      case AppIconShape.kakao:
        final bubble = RRect.fromRectAndRadius(
          const Rect.fromLTWH(3.5, 4.5, 17, 12.5),
          const Radius.circular(6),
        );
        canvas.drawRRect(bubble, strokePaint);
        final tail = Path()
          ..moveTo(8.2, 16.6)
          ..lineTo(6.6, 20.3)
          ..lineTo(11.3, 16.6);
        canvas.drawPath(tail, strokePaint);
        break;

      case AppIconShape.pin:
        final drop = Path()
          ..moveTo(12, 21)
          ..cubicTo(12, 21, 18, 14.3, 18, 10)
          ..cubicTo(18, 6.7, 15.3, 4, 12, 4)
          ..cubicTo(8.7, 4, 6, 6.7, 6, 10)
          ..cubicTo(6, 14.3, 12, 21, 12, 21)
          ..close();
        canvas.drawPath(drop, strokePaint);
        canvas.drawCircle(const Offset(12, 10), 2.2, strokePaint);
        break;

      case AppIconShape.phone:
        final receiver = Path()
          ..moveTo(6.8, 4.4)
          ..cubicTo(5.5, 4.4, 4.5, 5.6, 4.7, 6.9)
          ..cubicTo(5.6, 12.4, 10.0, 16.8, 15.5, 17.7)
          ..cubicTo(16.8, 17.9, 18.0, 16.9, 18.0, 15.6)
          ..lineTo(18.0, 14.1)
          ..cubicTo(18.0, 13.4, 17.5, 12.8, 16.8, 12.7)
          ..lineTo(14.7, 12.3)
          ..cubicTo(14.2, 12.2, 13.7, 12.4, 13.4, 12.8)
          ..lineTo(12.8, 13.6)
          ..cubicTo(11.0, 12.6, 9.6, 11.1, 8.7, 9.4)
          ..lineTo(9.5, 8.8)
          ..cubicTo(9.9, 8.5, 10.1, 8.0, 10.0, 7.5)
          ..lineTo(9.6, 5.4)
          ..cubicTo(9.5, 4.7, 8.9, 4.2, 8.2, 4.2)
          ..close();
        canvas.drawPath(receiver, strokePaint);
        break;

      case AppIconShape.image:
        final frame = RRect.fromRectAndRadius(
          const Rect.fromLTWH(3.5, 4.5, 17, 15),
          const Radius.circular(2.5),
        );
        canvas.drawRRect(frame, strokePaint);
        canvas.drawCircle(const Offset(8.5, 9.5), 1.6, strokePaint);
        final mountains = Path()
          ..moveTo(4.5, 16.5)
          ..lineTo(9.5, 11.5)
          ..lineTo(13, 15)
          ..lineTo(15.5, 12.5)
          ..lineTo(19.5, 17);
        canvas.drawPath(mountains, strokePaint);
        break;
    }

    canvas.restore();
  }

  double _deg(double degrees) => degrees * 3.1415926535 / 180;

  @override
  bool shouldRepaint(covariant _AppIconPainter oldDelegate) {
    return oldDelegate.shape != shape ||
        oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
