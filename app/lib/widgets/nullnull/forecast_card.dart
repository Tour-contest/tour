import 'package:flutter/material.dart';

import 'package:nullnull/data/demo_script.dart';
import 'package:nullnull/theme/app_colors.dart';
import 'package:nullnull/theme/app_text_styles.dart';
import 'package:nullnull/widgets/nullnull/card_container.dart';
import 'package:nullnull/widgets/nullnull/forecast_bar_chart.dart';

class ForecastCard extends StatelessWidget {
  const ForecastCard({super.key, required this.forecast});

  final Forecast forecast;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return CardContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            forecast.spot.name,
            style: AppTextStyles.heading(fontSize: 16, color: colors.ink),
          ),
          const SizedBox(height: 2),
          Text(
            forecast.spot.location,
            style: AppTextStyles.body(fontSize: 12, color: colors.ink600),
          ),
          const SizedBox(height: 16),
          ForecastBarChart(forecast: forecast),
        ],
      ),
    );
  }
}
