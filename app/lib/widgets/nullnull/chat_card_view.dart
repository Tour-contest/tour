import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:nullnull/app_log.dart';
import 'package:nullnull/app_router.dart';
import 'package:nullnull/data/demo_script.dart';
import 'package:nullnull/l10n/app_localizations.dart';
import 'package:nullnull/screens/attraction_detail_screen.dart';
import 'package:nullnull/theme/app_colors.dart';
import 'package:nullnull/theme/app_text_styles.dart';
import 'package:nullnull/widgets/map_app_sheet.dart';
import 'package:nullnull/widgets/nullnull/card_container.dart';
import 'package:nullnull/widgets/nullnull/region_donut_chart.dart';

/// [ChatCardBlock.type]을 보고 알맞은 카드 위젯으로 분기한다. `docs/API_SPEC.md`의
/// `card.payload.status`가 `no_data`이거나 `has_data:false`면 카드 대신 안내
/// 문구를 그린다(실제 후속 질문 버튼 스키마는 아직 예시가 없어 문구만 보여줌).
/// 아직 지원하지 않는 카드 타입은 조용히 아무것도 그리지 않는다(로그만 남김) —
/// 새 카드 타입이 추가돼도 앱이 깨지지 않도록.
class ChatCardView extends StatelessWidget {
  const ChatCardView({super.key, required this.block});

  final ChatCardBlock block;

  bool get _hasData =>
      block.payload['status'] != 'no_data' &&
      block.payload['has_data'] != false;

  @override
  Widget build(BuildContext context) {
    if (!_hasData) {
      return const _NoDataMessage();
    }
    return switch (block.type) {
      'attraction_list' => _AttractionListCard(
          data: AttractionListCardData.fromJson(block.payload)),
      'crowd' => _CrowdCard(data: CrowdCardData.fromJson(block.payload)),
      _ => _unsupported(),
    };
  }

  Widget _unsupported() {
    AppLog.logger.w('[ChatCardView] 지원하지 않는 카드 타입: ${block.type}');
    return const SizedBox.shrink();
  }
}

class _NoDataMessage extends StatelessWidget {
  const _NoDataMessage();

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    return CardContainer(
      child: Text(
        l10n.chatCardNoDataMessage,
        style: AppTextStyles.body(color: colors.ink600),
      ),
    );
  }
}

/// `card` 이벤트의 `type: "attraction_list"` 페이로드.
class AttractionListCardData {
  const AttractionListCardData({
    required this.category,
    required this.signguNm,
    required this.items,
  });

  factory AttractionListCardData.fromJson(Map<String, dynamic> json) {
    return AttractionListCardData(
      category: json['category'] as String? ?? '',
      signguNm: json['signgu_nm'] as String? ?? '',
      items: ((json['items'] as List<dynamic>?) ?? const [])
          .cast<Map<String, dynamic>>()
          .map(AttractionItem.fromJson)
          .toList(),
    );
  }

  final String category;
  final String signguNm;
  final List<AttractionItem> items;
}

class AttractionItem {
  const AttractionItem({
    required this.contentId,
    required this.title,
    required this.address,
  });

  factory AttractionItem.fromJson(Map<String, dynamic> json) {
    final addr1 = json['addr1'] as String? ?? '';
    final addr2 = json['addr2'] as String?;
    return AttractionItem(
      contentId: json['content_id']?.toString() ?? '',
      title: json['title'] as String? ?? '',
      address: addr2 != null && addr2.isNotEmpty ? '$addr1 $addr2' : addr1,
    );
  }

  final String contentId;
  final String title;
  final String address;
}

/// 목록 카드. 혼잡도 정보가 없는 카드라(응답 문장에서도 안내됨) 배지 없이
/// 이름·주소만 보여주고, 각 항목은 이름으로 지도 검색만 연결한다(좌표는 있지만
/// `MapLauncherService`가 아직 이름 검색 스킴만 지원 — `## 아키텍처` 참고).
/// 항목이 [_collapsedCount]개보다 많으면 처음엔 그만큼만 보여주고
/// "더보기"/"접기" 버튼(`_ShowMoreButton`)으로 펼치고 줄일 수 있다(응답 카드가
/// 무한정 길어지지 않도록).
class _AttractionListCard extends StatefulWidget {
  const _AttractionListCard({required this.data});

  final AttractionListCardData data;

  @override
  State<_AttractionListCard> createState() => _AttractionListCardState();
}

class _AttractionListCardState extends State<_AttractionListCard> {
  static const _collapsedCount = 3;

  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    final items = widget.data.items;
    final hiddenCount = items.length - _collapsedCount;
    final visibleItems =
        _expanded || hiddenCount <= 0 ? items : items.take(_collapsedCount);
    return CardContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.chatCardAttractionListTitle(
                widget.data.signguNm, widget.data.category),
            style: AppTextStyles.heading(fontSize: 14, color: colors.ink),
          ),
          for (final item in visibleItems) ...[
            const SizedBox(height: 12),
            _AttractionRow(item: item),
          ],
          if (hiddenCount > 0) ...[
            const SizedBox(height: 14),
            Divider(height: 1, color: colors.divider),
            const SizedBox(height: 12),
            _ShowMoreButton(
              expanded: _expanded,
              hiddenCount: hiddenCount,
              onTap: () => setState(() => _expanded = !_expanded),
            ),
          ],
        ],
      ),
    );
  }
}

/// 항목 탭 시 `content_id`가 있으면 `AttractionDetailScreen`으로 이동한다.
/// 실서버가 `content_id`를 비워 보내는 것 같은 예외적인 경우에만(스펙상으로는
/// 항상 옴) 기존처럼 이름으로 지도를 여는 `MapAppSheet`로 대체한다.
class _AttractionRow extends StatelessWidget {
  const _AttractionRow({required this.item});

  final AttractionItem item;

  void _open(BuildContext context) {
    if (item.contentId.isEmpty) {
      MapAppSheet.show(context, placeName: item.title);
      return;
    }
    context.pushNamed(
      RouteNames.attractionDetail,
      extra: AttractionDetailArgs(
          contentId: item.contentId, initialTitle: item.title),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    return InkWell(
      onTap: () => _open(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.title,
            style:
                AppTextStyles.heading(fontSize: 14, color: colors.accentBright),
          ),
          if (item.address.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              item.address,
              style: AppTextStyles.body(fontSize: 12, color: colors.ink600),
            ),
          ],
          const SizedBox(height: 4),
          Text(
            l10n.attractionListItemDetailCta,
            style:
                AppTextStyles.body(fontSize: 11.5, color: colors.accentBright),
          ),
        ],
      ),
    );
  }
}

/// "더보기"/"접기" 버튼. 개별 항목의 순수 텍스트 링크(`_AttractionRow`의
/// "지도에서 보기 ↗")와 혼동되지 않도록, `_SampleChip`(`crowd` 카드)과 같은
/// 배경·테두리(`colors.surfaceMuted`/`surfaceMutedBorder`)를 준 별도 버튼
/// 영역으로 분리했다.
class _ShowMoreButton extends StatelessWidget {
  const _ShowMoreButton({
    required this.expanded,
    required this.hiddenCount,
    required this.onTap,
  });

  final bool expanded;
  final int hiddenCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: colors.surfaceMuted,
          border: Border.all(color: colors.surfaceMutedBorder),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            expanded
                ? l10n.chatCardShowLess
                : l10n.chatCardShowMore(hiddenCount),
            style: AppTextStyles.body(fontSize: 12.5, color: colors.ink),
          ),
        ),
      ),
    );
  }
}

/// `card` 이벤트의 `type: "crowd"` 페이로드. **[실서버로 확인함]** `summary`/
/// `samples`의 키가 애초 가정했던 한글 라벨(`혼잡`/`보통`/`한적`)이 아니라
/// 영문 키(`crowded`/`normal`/`quiet`)로 온다 — 이 파일이 그동안 한글만
/// 비교하고 있어 영문 키는 전부 매치에 실패해 기본값(`Level.normal`)으로만
/// 떨어졌고, 세 버킷이 전부 `Level.normal` 하나로 뭉개져 왔다(예: `crowded`
/// 카운트/샘플이 실제로는 `Level.busy`가 아니라 `Level.normal`에 들어가고,
/// 뒤이어 처리되는 `normal`/`quiet` 키가 같은 `Level.normal` 자리를 덮어써
/// 마지막 키만 남는 식). `_levelFor`가 이제 영문 키를 우선 확인하고, 한글
/// 라벨도 그대로 인식하도록(다른 소비처가 여전히 한글을 쓸 수 있어 방어적으로
/// 겸용) 고쳤다.
class CrowdCardData {
  const CrowdCardData({
    required this.signguNm,
    required this.counts,
    required this.samples,
  });

  factory CrowdCardData.fromJson(Map<String, dynamic> json) {
    final summary = json['summary'] as Map<String, dynamic>? ?? const {};
    final samplesJson = json['samples'] as Map<String, dynamic>? ?? const {};
    final counts = <Level, int>{};
    summary.forEach((key, value) {
      counts[_levelFor(key)] = (value as num?)?.toInt() ?? 0;
    });
    final samples = <Level, List<CrowdSample>>{};
    samplesJson.forEach((key, value) {
      samples[_levelFor(key)] = ((value as List<dynamic>?) ?? const [])
          .cast<Map<String, dynamic>>()
          .map(CrowdSample.fromJson)
          .toList();
    });
    return CrowdCardData(
      signguNm: json['signgu_nm'] as String? ?? '',
      counts: counts,
      samples: samples,
    );
  }

  static Level _levelFor(String key) => switch (key) {
        '혼잡' || 'crowded' || 'busy' => Level.busy,
        '한적' || 'quiet' => Level.quiet,
        _ => Level.normal,
      };

  final String signguNm;
  final Map<Level, int> counts;
  final Map<Level, List<CrowdSample>> samples;
}

class CrowdSample {
  const CrowdSample({required this.name, required this.rate, this.contentId});

  factory CrowdSample.fromJson(Map<String, dynamic> json) {
    return CrowdSample(
      name: json['name'] as String? ?? '',
      rate: ((json['rate'] as num?) ?? 0).round(),
      contentId: json['content_id']?.toString(),
    );
  }

  final String name;
  final int rate;
  final String? contentId;
}

class _CrowdCard extends StatelessWidget {
  const _CrowdCard({required this.data});

  final CrowdCardData data;

  /// 카드가 너무 길어지지 않도록 레벨별 샘플은 앞에서 몇 개만 보여준다
  /// (실제 데이터는 더 많을 수 있음 — 표시상의 제한일 뿐 데이터 손실은 아님).
  static const _maxSamplesPerLevel = 5;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CardContainer(child: RegionDonutChart(counts: data.counts)),
        const SizedBox(height: 10),
        CardContainer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.chatCardCrowdTitle(data.signguNm),
                style: AppTextStyles.heading(fontSize: 14, color: colors.ink),
              ),
              for (final level in [Level.busy, Level.normal, Level.quiet])
                if ((data.samples[level] ?? const []).isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _SampleRow(
                    label: switch (level) {
                      Level.busy => l10n.congestionLevelBusy,
                      Level.normal => l10n.congestionLevelNormal,
                      Level.quiet => l10n.congestionLevelQuiet,
                    },
                    samples: data.samples[level]!.take(_maxSamplesPerLevel),
                  ),
                ],
            ],
          ),
        ),
      ],
    );
  }
}

class _SampleRow extends StatelessWidget {
  const _SampleRow({required this.label, required this.samples});

  final String label;
  final Iterable<CrowdSample> samples;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 42,
          child: Text(
            label,
            style: AppTextStyles.body(fontSize: 11.5, color: colors.ink600),
          ),
        ),
        Expanded(
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final sample in samples) _SampleChip(sample: sample),
            ],
          ),
        ),
      ],
    );
  }
}

/// 탭 시 `content_id`가 있으면 `AttractionDetailScreen`으로 이동한다
/// (`_AttractionRow`와 동일한 패턴). 없는 예외적인 경우에만 이름으로 지도를
/// 여는 `MapAppSheet`로 대체한다.
class _SampleChip extends StatelessWidget {
  const _SampleChip({required this.sample});

  final CrowdSample sample;

  void _open(BuildContext context) {
    final contentId = sample.contentId;
    if (contentId == null || contentId.isEmpty) {
      MapAppSheet.show(context, placeName: sample.name);
      return;
    }
    context.pushNamed(
      RouteNames.attractionDetail,
      extra:
          AttractionDetailArgs(contentId: contentId, initialTitle: sample.name),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: () => _open(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: colors.surfaceMuted,
          border: Border.all(color: colors.surfaceMutedBorder),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          '${sample.name} ${sample.rate}',
          style: AppTextStyles.tabularNums(
            AppTextStyles.body(fontSize: 12, color: colors.ink),
          ),
        ),
      ),
    );
  }
}
