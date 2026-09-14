import 'package:flutter/material.dart';

import 'package:nullnull/api/attractions_api.dart';
import 'package:nullnull/theme/app_colors.dart';
import 'package:nullnull/theme/app_text_styles.dart';

/// [AttractionCrowdDay] 목록을 막대 그래프로 그린다. 막대 색은 `colors.accentBright`로
/// 통일한다(등급별 색상 구분 없음). 막대 폭은 가용 너비를 [days] 개수로 나눠
/// 채우되(`LayoutBuilder`), 날짜 수가 많아 폭이 [_minBarSlotWidth] 아래로
/// 내려가는 경우(예: 28일)에만 그 최소 폭을 유지하고 가로 스크롤로 훑어보게
/// 한다. `attraction_detail_screen.dart`의 혼잡도 섹션과 `chat_card_view.dart`의
/// 매칭된 관광지 혼잡도 카드가 공유한다.
class CrowdBarChart extends StatelessWidget {
  const CrowdBarChart({super.key, required this.days});

  final List<AttractionCrowdDay> days;

  static const _barAreaHeight = 200.0;
  static const _gridValues = [0, 30, 50, 70, 90];
  static const _axisWidth = 24.0;
  static const _minBarSlotWidth = 28.0;

  /// 막대 자체의 고정 폭. 막대가 차지하는 슬롯(`barSlotWidth`, 아래
  /// `LayoutBuilder`)은 가용 너비에 맞춰 늘어나 간격을 벌리지만, 막대
  /// 그림 자체는 이 값으로 고정해 슬롯 안에서 가운데 정렬한다.
  static const _barWidth = 15.0;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: _barAreaHeight,
          width: _axisWidth,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              for (final value in _gridValues)
                Positioned(
                  bottom: _barAreaHeight * (value / 100) - 6,
                  left: 0,
                  child: Text(
                    value == 90 ? '90+' : '$value',
                    style: AppTextStyles.tabularNums(AppTextStyles.body(
                        fontSize: 9.5, color: colors.ink600)),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final barSlotWidth = days.isEmpty
                  ? _minBarSlotWidth
                  : (constraints.maxWidth / days.length)
                      .clamp(_minBarSlotWidth, double.infinity);
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: SizedBox(
                  width: barSlotWidth * days.length,
                  child: Column(
                    children: [
                      SizedBox(
                        height: _barAreaHeight,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            for (final value in _gridValues)
                              Positioned(
                                bottom: _barAreaHeight * (value / 100),
                                left: 0,
                                right: 0,
                                child: Container(
                                    height: 1, color: colors.inputBarBorder),
                              ),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                for (final day in days)
                                  SizedBox(
                                    width: barSlotWidth,
                                    child: Align(
                                      alignment: Alignment.bottomCenter,
                                      child: FractionallySizedBox(
                                        heightFactor:
                                            (day.rate.clamp(0, 100) / 100)
                                                .clamp(0.02, 1.0),
                                        child: Container(
                                          width: _barWidth,
                                          decoration: BoxDecoration(
                                            color: colors.accentBright,
                                            borderRadius:
                                                const BorderRadius.vertical(
                                                    top:
                                                        Radius.circular(3)),
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
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          for (final day in days)
                            SizedBox(
                              width: barSlotWidth,
                              child: Text(
                                day.weekday,
                                textAlign: TextAlign.center,
                                style: AppTextStyles.body(
                                    fontSize: 9.5, color: colors.ink600),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
