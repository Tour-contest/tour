import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:nullnull/data/demo_script.dart';
import 'package:nullnull/l10n/app_localizations.dart';
import 'package:nullnull/theme/app_colors.dart';
import 'package:nullnull/theme/app_text_styles.dart';

class RegionDonutChart extends StatelessWidget {
  const RegionDonutChart({super.key, required this.counts});

  final Map<Level, int> counts;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    final total = counts.values.fold(0, (sum, v) => sum + v);

    return Row(
      children: [
        SizedBox(
          width: 92,
          height: 92,
          child: CustomPaint(
            painter: _DonutPainter(counts: counts, colors: colors),
            child: Center(
              child: Text(
                '$total',
                style: AppTextStyles.heading(fontSize: 22, color: colors.ink),
              ),
            ),
          ),
        ),
        const SizedBox(width: 18),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _LegendRow(
                dot: colors.quietChart,
                label: l10n.congestionLevelQuiet,
                count: counts[Level.quiet] ?? 0,
                colors: colors,
              ),
              const SizedBox(height: 8),
              _LegendRow(
                dot: colors.normalChart,
                label: l10n.congestionLevelNormal,
                count: counts[Level.normal] ?? 0,
                colors: colors,
              ),
              const SizedBox(height: 8),
              _LegendRow(
                dot: colors.busyChart,
                label: l10n.congestionLevelBusy,
                count: counts[Level.busy] ?? 0,
                colors: colors,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter({required this.counts, required this.colors});

  final Map<Level, int> counts;
  final AppColors colors;

  static const _strokeWidth = 14.0;

  @override
  void paint(Canvas canvas, Size size) {
    final total = counts.values.fold(0, (sum, v) => sum + v);
    if (total == 0) return;
    final rect = Rect.fromLTWH(_strokeWidth / 2, _strokeWidth / 2,
        size.width - _strokeWidth, size.height - _strokeWidth);
    var start = -math.pi / 2;
    for (final entry in [
      (counts[Level.quiet] ?? 0, colors.quietChart),
      (counts[Level.normal] ?? 0, colors.normalChart),
      (counts[Level.busy] ?? 0, colors.busyChart),
    ]) {
      final (count, color) = entry;
      if (count == 0) continue;
      final sweep = 2 * math.pi * (count / total);
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = _strokeWidth
        ..strokeCap = StrokeCap.butt;
      canvas.drawArc(rect, start, sweep, false, paint);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) =>
      oldDelegate.counts != counts;
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({
    required this.dot,
    required this.label,
    required this.count,
    required this.colors,
  });

  final Color dot;
  final String label;
  final int count;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(label,
              style: AppTextStyles.body(fontSize: 13, color: colors.ink)),
        ),
        Text(
          '$count',
          style: AppTextStyles.tabularNums(
              AppTextStyles.heading(fontSize: 14, color: colors.ink)),
        ),
      ],
    );
  }
}
