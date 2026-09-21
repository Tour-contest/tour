import 'package:flutter/material.dart';

import 'package:nullnull/data/demo_script.dart';
import 'package:nullnull/l10n/app_localizations.dart';
import 'package:nullnull/theme/app_colors.dart';
import 'package:nullnull/theme/app_text_styles.dart';

class ForecastBarChart extends StatelessWidget {
  const ForecastBarChart({super.key, required this.forecast});

  final Forecast forecast;

  static const _barAreaHeight = 108.0;
  static const _gridValues = [0, 30, 50, 70, 90];
  static const _axisWidth = 24.0;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    final peak = forecast.peak;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _AxisLabels(colors: colors),
            Expanded(
              child: SizedBox(
                height: _barAreaHeight,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _GridLines(colors: colors),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        for (final day in forecast.days)
                          Expanded(
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 3),
                              child: Align(
                                alignment: Alignment.bottomCenter,
                                child: FractionallySizedBox(
                                  heightFactor: (day.score.clamp(0, 100) / 100)
                                      .clamp(0.02, 1.0),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: identical(day, peak)
                                          ? colors.accent
                                          : colors.surfaceMuted,
                                      borderRadius: const BorderRadius.vertical(
                                          top: Radius.circular(3)),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            const SizedBox(width: _axisWidth),
            for (final day in forecast.days)
              Expanded(
                child: Text(
                  day.weekdayLabel,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.body(
                    fontSize: 10.5,
                    color: identical(day, peak) ? colors.ink : colors.ink600,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerLeft,
          child: _Tooltip(text: _peakTooltip(l10n, peak), colors: colors),
        ),
      ],
    );
  }

  String _peakTooltip(AppLocalizations l10n, DailyScore day) {
    final levelLabel = switch (day.level) {
      Level.quiet => l10n.congestionLevelQuiet,
      Level.normal => l10n.congestionLevelNormal,
      Level.busy => day.score >= 75
          ? l10n.congestionLevelVeryBusy
          : l10n.congestionLevelBusy,
    };
    return l10n.forecastTooltip(day.weekdayLabel, day.score, levelLabel);
  }
}

class _AxisLabels extends StatelessWidget {
  const _AxisLabels({required this.colors});

  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: ForecastBarChart._barAreaHeight,
      width: ForecastBarChart._axisWidth,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (final value in ForecastBarChart._gridValues)
            Positioned(
              bottom: ForecastBarChart._barAreaHeight * (value / 100) - 6,
              left: 0,
              child: Text(
                value == 90 ? '90+' : '$value',
                style: AppTextStyles.tabularNums(
                    AppTextStyles.body(fontSize: 9.5, color: colors.ink600)),
              ),
            ),
        ],
      ),
    );
  }
}

class _GridLines extends StatelessWidget {
  const _GridLines({required this.colors});

  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        for (final value in ForecastBarChart._gridValues)
          Positioned(
            bottom: ForecastBarChart._barAreaHeight * (value / 100),
            left: 0,
            right: 0,
            child: Container(height: 1, color: colors.divider),
          ),
      ],
    );
  }
}

class _Tooltip extends StatelessWidget {
  const _Tooltip({required this.text, required this.colors});

  final String text;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: colors.accent,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: AppTextStyles.body(fontSize: 11, color: colors.paper),
      ),
    );
  }
}
