import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:nullnull/app_router.dart';
import 'package:nullnull/data/analytics_service.dart';
import 'package:nullnull/data/demo_script.dart';
import 'package:nullnull/l10n/app_localizations.dart';
import 'package:nullnull/theme/app_colors.dart';
import 'package:nullnull/theme/app_text_styles.dart';
import 'package:nullnull/widgets/nullnull/card_container.dart';
import 'package:nullnull/widgets/nullnull/congestion_badge.dart';

class AlternativesSection extends StatelessWidget {
  const AlternativesSection({
    super.key,
    required this.items,
    this.excludedNote,
  });

  final List<Alternative> items;
  final String? excludedNote;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < items.length; i++)
          Padding(
            padding: EdgeInsets.only(bottom: i == items.length - 1 ? 0 : 10),
            child: _AlternativeCard(alternative: items[i]),
          ),
        if (excludedNote != null) ...[
          const SizedBox(height: 10),
          Text(
            excludedNote!,
            style: AppTextStyles.body(
                fontSize: 11, color: colors.ink600, height: 1.5),
          ),
        ],
      ],
    );
  }
}

class _AlternativeCard extends StatelessWidget {
  const _AlternativeCard({required this.alternative});

  final Alternative alternative;

  void _showComingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content:
              Text(AppLocalizations.of(context)!.nulnulOpenInMapComingSoon)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    final spot = alternative.spot;
    return InkWell(
      borderRadius: BorderRadius.circular(15),
      onTap: () {
        unawaited(AnalyticsService.logPlaceDetailView(spot));
        context.pushNamed(RouteNames.place, extra: spot);
      },
      child: CardContainer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.alternativeRankLabel(alternative.rank),
                        style: AppTextStyles.body(
                            fontSize: 10.5,
                            color: colors.ink600,
                            letterSpacing: .3),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        spot.name,
                        style: AppTextStyles.heading(
                            fontSize: 15.5, color: colors.accentBright),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        [
                          if (spot.category != null) spot.category!,
                          if (spot.travelMinutes != null)
                            l10n.alternativeTravelMinutes(spot.travelMinutes!),
                        ].join(' · '),
                        style: AppTextStyles.body(
                            fontSize: 12, color: colors.ink600),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                CongestionBadge(
                    level: alternative.level, score: spot.congestionPercent),
              ],
            ),
            const SizedBox(height: 10),
            InkWell(
              onTap: () => _showComingSoon(context),
              child: Text(
                l10n.nulnulOpenInMap,
                style: AppTextStyles.body(
                    fontSize: 11.5, color: colors.accentBright),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
