import 'package:flutter/material.dart';

import 'package:nullnull/data/demo_script.dart';
import 'package:nullnull/l10n/app_localizations.dart';
import 'package:nullnull/theme/app_colors.dart';
import 'package:nullnull/theme/app_text_styles.dart';
import 'package:nullnull/widgets/nullnull/card_container.dart';
import 'package:nullnull/widgets/nullnull/region_donut_chart.dart';

class RegionCard extends StatelessWidget {
  const RegionCard({super.key, required this.status});

  final RegionStatus status;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CardContainer(
          child: RegionDonutChart(counts: status.counts),
        ),
        const SizedBox(height: 10),
        CardContainer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.regionCardTitle(status.region),
                style: AppTextStyles.heading(fontSize: 14, color: colors.ink),
              ),
              const SizedBox(height: 14),
              _ChipRow(
                label: l10n.regionPopularLabel,
                spots: status.popular,
              ),
              const SizedBox(height: 12),
              _ChipRow(
                label: l10n.regionQuietLabel,
                spots: status.quiet,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ChipRow extends StatelessWidget {
  const _ChipRow({required this.label, required this.spots});

  final String label;
  final List<PlaceRecommendation> spots;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Row(
      children: [
        SizedBox(
          width: 74,
          child: Text(
            label,
            style: AppTextStyles.body(fontSize: 11.5, color: colors.ink600),
          ),
        ),
        Expanded(
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [for (final spot in spots) _SpotChip(spot: spot)],
          ),
        ),
      ],
    );
  }
}

class _SpotChip extends StatelessWidget {
  const _SpotChip({required this.spot});

  final PlaceRecommendation spot;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: colors.surfaceMuted,
        border: Border.all(color: colors.surfaceMutedBorder),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        spot.name,
        style: AppTextStyles.body(fontSize: 12, color: colors.ink),
      ),
    );
  }
}
