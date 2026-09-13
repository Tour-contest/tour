import 'package:flutter/material.dart';

import 'package:nullnull/app_log.dart';
import 'package:nullnull/data/demo_script.dart';
import 'package:nullnull/l10n/app_localizations.dart';
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
    required this.title,
    required this.address,
  });

  factory AttractionItem.fromJson(Map<String, dynamic> json) {
    final addr1 = json['addr1'] as String? ?? '';
    final addr2 = json['addr2'] as String?;
    return AttractionItem(
      title: json['title'] as String? ?? '',
      address: addr2 != null && addr2.isNotEmpty ? '$addr1 $addr2' : addr1,
    );
  }

  final String title;
  final String address;
}

/// 목록 카드. 혼잡도 정보가 없는 카드라(응답 문장에서도 안내됨) 배지 없이
/// 이름·주소만 보여주고, 각 항목은 이름으로 지도 검색만 연결한다(좌표는 있지만
/// `MapLauncherService`가 아직 이름 검색 스킴만 지원 — `## 아키텍처` 참고).
class _AttractionListCard extends StatelessWidget {
  const _AttractionListCard({required this.data});

  final AttractionListCardData data;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    return CardContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.chatCardAttractionListTitle(data.signguNm, data.category),
            style: AppTextStyles.heading(fontSize: 14, color: colors.ink),
          ),
          for (final item in data.items) ...[
            const SizedBox(height: 12),
            _AttractionRow(item: item),
          ],
        ],
      ),
    );
  }
}

class _AttractionRow extends StatelessWidget {
  const _AttractionRow({required this.item});

  final AttractionItem item;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    return InkWell(
      onTap: () => MapAppSheet.show(context, placeName: item.title),
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
            l10n.nulnulOpenInMap,
            style:
                AppTextStyles.body(fontSize: 11.5, color: colors.accentBright),
          ),
        ],
      ),
    );
  }
}

/// `card` 이벤트의 `type: "crowd"` 페이로드. `summary`/`samples`의 키(`혼잡`/`보통`/
/// `한적`)를 [Level]로 매핑한다.
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

  static Level _levelFor(String koreanLabel) => switch (koreanLabel) {
        '혼잡' => Level.busy,
        '한적' => Level.quiet,
        _ => Level.normal,
      };

  final String signguNm;
  final Map<Level, int> counts;
  final Map<Level, List<CrowdSample>> samples;
}

class CrowdSample {
  const CrowdSample({required this.name, required this.rate});

  factory CrowdSample.fromJson(Map<String, dynamic> json) {
    return CrowdSample(
      name: json['name'] as String? ?? '',
      rate: ((json['rate'] as num?) ?? 0).round(),
    );
  }

  final String name;
  final int rate;
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

class _SampleChip extends StatelessWidget {
  const _SampleChip({required this.sample});

  final CrowdSample sample;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: () => MapAppSheet.show(context, placeName: sample.name),
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
