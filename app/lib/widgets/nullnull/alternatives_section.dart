import 'package:flutter/material.dart';

import 'package:nullnull/api/attractions_api.dart';
import 'package:nullnull/l10n/app_localizations.dart';
import 'package:nullnull/theme/app_colors.dart';
import 'package:nullnull/theme/app_text_styles.dart';
import 'package:nullnull/widgets/nullnull/congestion_badge.dart';

/// [AttractionAlternative] 목록을 가로 스크롤 카드로 그린다. `attractions/{content_id}/alternatives`
/// REST 응답과 `chat/stream`의 `type: "alternatives"` 카드 payload가 필드명이
/// 완전히 같아(`AttractionAlternativesResult`) `attraction_detail_screen.dart`의
/// "함께 찾는 곳" 섹션과 `chat_card_view.dart`의 대안지 카드가 이 위젯을 공유한다
/// (원래 `attraction_detail_screen.dart` 전용 프라이빗 위젯이었던 것을 승격).
/// 서버가 보낸 순서를 재정렬하지 않고(`docs/API_SPEC.md`의 "구현 주의") 앞에서부터
/// 최대 [_maxItems]개까지만 보여준다(사용자 요청) — 랭킹 라벨(`{n}위`)도 이
/// 순서를 그대로 따른다.
class AlternativesSection extends StatelessWidget {
  const AlternativesSection({super.key, required this.items, this.onTap});

  final List<AttractionAlternative> items;

  /// 카드 탭 시 `(contentId, title)`로 호출된다. `null`이면 탭해도 아무
  /// 반응이 없다.
  final void Function(String contentId, String title)? onTap;

  static const _maxItems = 3;

  /// 카드 폭을 가용 너비의 이 비율로 고정한다(`LayoutBuilder`). 항목이
  /// 2개 이상이면 두 배(1.24)가 항상 100%를 넘어 다음 카드가 화면 오른쪽
  /// 끝에서 일부만 보이도록(peek) 강제된다 — 카드가 화면 폭에 딱 맞게
  /// 꽉 차 보여서 가로로 더 넘길 수 있다는 게 잘 안 보인다는 사용자 피드백
  /// 반영.
  static const _cardWidthFactor = 0.62;

  @override
  Widget build(BuildContext context) {
    final visible =
        items.length > _maxItems ? items.sublist(0, _maxItems) : items;
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = constraints.maxWidth * _cardWidthFactor;
        // 예전엔 `SizedBox(height: 176)` + `ListView.separated`로 고정
        // 높이를 줬는데, 카드 내용(이름/사유/배지 등)은 접근성 글자 크기
        // 설정에 따라 커지는 반면 이 높이는 고정이라 글자가 커지면 카드
        // 안에서 세로로 오버플로가 났다. `ListView`는 가로 스크롤 시 세로
        // (cross axis) 폭을 부모가 준 만큼 고정으로 요구해 콘텐츠에 맞춰
        // 스스로 커질 수 없으므로(항목이 최대 3개뿐이라 성능상 문제도 없어)
        // `Row` + `SingleChildScrollView`로 바꾸고 `IntrinsicHeight`로
        // 감싸 가장 긴 카드의 실제 콘텐츠 높이에 맞춰 전체가 함께
        // 늘어나도록 했다.
        return IntrinsicHeight(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < visible.length; i++) ...[
                  if (i > 0) const SizedBox(width: 10),
                  AlternativeCard(
                    item: visible[i],
                    rank: i + 1,
                    width: cardWidth,
                    onTap: onTap == null
                        ? null
                        : () => onTap!(visible[i].contentId, visible[i].name),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class AlternativeCard extends StatelessWidget {
  const AlternativeCard({
    super.key,
    required this.item,
    required this.rank,
    this.width = 150,
    this.onTap,
  });

  final AttractionAlternative item;

  /// 1부터 시작하는 순위(`AlternativesSection`이 보여주는 순서 기준).
  final int rank;

  /// 카드 폭. `AlternativesSection`이 가용 너비 기반으로 계산해 넘긴다(다음
  /// 카드가 살짝 잘려 보이도록) — 단독으로 쓰일 때를 위해 고정값 기본값도 둔다.
  final double width;

  final VoidCallback? onTap;

  String _formatOneDecimal(double value) => value.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    final reason = item.reason;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: width,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colors.graphite,
          border: Border.all(color: colors.inputBarBorder, width: 1.5),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    l10n.alternativeRankLabel(rank),
                    style: AppTextStyles.heading(
                      fontSize: 13,
                      color: colors.voiceListeningHint,
                      height: 1.0,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                CongestionBadge(level: item.level, score: item.rate),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              item.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.heading(
                fontSize: 16,
                color: colors.ink,
                height: 1.5,
              ),
            ),
            if (reason != null) ...[
              const SizedBox(height: 5),
              SizedBox(
                width: double.infinity,
                child: Text(
                  l10n.alternativeReasonLabel(
                    _formatOneDecimal(reason.lowerBy),
                    _formatOneDecimal(reason.distanceKm),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.heading(
                    fontSize: 11,
                    color: colors.voiceListeningHint,
                    height: 1.0,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 30),
            Text(
              l10n.alternativeDetailLinkLabel,
              style:
                  AppTextStyles.body(fontSize: 11, color: colors.alternativeReasonText),
            ),
          ],
        ),
      ),
    );
  }
}
