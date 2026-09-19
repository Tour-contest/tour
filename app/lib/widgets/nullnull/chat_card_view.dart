import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:nullnull/api/attractions_api.dart';
import 'package:nullnull/app_log.dart';
import 'package:nullnull/app_router.dart';
import 'package:nullnull/data/demo_script.dart';
import 'package:nullnull/l10n/app_localizations.dart';
import 'package:nullnull/screens/attraction_detail_screen.dart';
import 'package:nullnull/theme/app_colors.dart';
import 'package:nullnull/theme/app_text_styles.dart';
import 'package:nullnull/widgets/map_app_sheet.dart';
import 'package:nullnull/widgets/nullnull/alternatives_section.dart';
import 'package:nullnull/widgets/nullnull/card_container.dart';
import 'package:nullnull/widgets/nullnull/congestion_badge.dart';
import 'package:nullnull/widgets/nullnull/crowd_bar_chart.dart';
import 'package:nullnull/widgets/nullnull/no_data_card.dart';
import 'package:nullnull/widgets/nullnull/region_donut_chart.dart';

/// [ChatCardBlock.type]을 보고 알맞은 카드 위젯으로 분기한다. **[API 문서로
/// 확인함]** `card.payload.status`가 `no_data`이거나 `has_data:false`면 카드
/// 대신 "지역 전체 현황 보기" 같은 후속 질문 버튼([NoDataCard], 탭하면 그
/// 문구를 그대로 다음 채팅 메시지로 보낸다 — [onActionTap])을 그린다. 단
/// `payload.has_crowd_data`가 `false`면(그 지역 자체에 집중률 데이터가 없어
/// 버튼을 눌러도 같은 결과가 옴) 버튼 없이 한 줄 안내만 보여준다. 아직
/// 지원하지 않는 카드 타입은 조용히 아무것도 그리지 않는다(로그만 남김) —
/// 새 카드 타입이 추가돼도 앱이 깨지지 않도록. `type: "crowd"`는 `payload.items`
/// 유무로 두 모양을 겸한다: 지역 전체 혼잡도([CrowdCardData], `summary`/`samples`)와
/// 사용자가 관광지명으로 물어봐 매칭된 관광지별 혼잡도 예보([CrowdMatchCardData],
/// `items[].series`/`summary` — `attractions/{content_id}/crowd`와 필드명이
/// 같아 그 모델을 재사용). `type: "area_overview"`(규칙 기반 경로 전용)는
/// `crowd`의 지역 전체 혼잡도 모양과 페이로드가 완전히 같아 `_CrowdCard`를
/// 그대로 재사용한다. `type: "alternatives"`는 `attractions/{content_id}/alternatives`
/// REST 응답과 필드명이 완전히 같아 그 모델([AttractionAlternativesResult])을
/// 그대로 재사용한다. `type: "detail"`(`GET /attractions/{id}` 응답과 같음)은
/// "단건 목록 카드"로 그리라고 돼 있어, 그 응답의 최상위 필드(`AttractionSummary`와
/// 같은 모양)를 항목 1개짜리 [AttractionListCardData]로 감싸 `_AttractionListCard`를
/// 재사용한다. `type: "interest"`(`attractions/{content_id}/interest`와 필드명
/// 동일)는 `trend`가 `flat`이 아닌 항목만 한 줄씩 보여준다. `type: "visitors"`는
/// **[실서버 예시로 확인함]** `areas/{signgu_cd}/visitors` REST 응답(여전히
/// 미확인 가정)과 다른 모양(주 단위가 아니라 일 단위, [VisitorsCardData])이라
/// 별도 모델로 파싱해 사용자 지정 시안대로 제목 → 가장 많았던 날짜(강조 박스)
/// → 최근 3일치 인원 → 근거(`data_through`/`note`) 순서로 그린다(날짜별
/// 전부를 나열하지 않음).
class ChatCardView extends StatelessWidget {
  const ChatCardView({super.key, required this.block, this.onActionTap});

  final ChatCardBlock block;

  /// 후속 질문 버튼([NoDataCard]) 탭 시 호출된다. `chat_screen.dart`의 `_send`가
  /// 연결돼 있어(`streaming_ai_message.dart`의 `_BlockView`를 통해 전달), 버튼
  /// 문구가 그대로 다음 채팅 메시지로 나간다.
  final ValueChanged<String>? onActionTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // `payload.status`가 `no_data`이거나 `has_data:false`면 보여줄 정보가
    // 없다는 뜻이다. `has_crowd_data:false`인 특수 케이스(지역 자체에 집중률이
    // 없어 후속 질문을 눌러도 같은 결과만 반복됨)만 버튼 없이 한 줄 안내로
    // 끝내고, 나머지는 후속 질문 버튼을 보여준다. 판단 기준은
    // `ChatCardBlock.hasData`(`data/demo_script.dart`) 하나로 통일돼 있다.
    if (!block.hasData) {
      if (block.payload['has_crowd_data'] == false) {
        final colors = AppColors.of(context);
        return Text(
          l10n.chatCardNoCrowdDataMessage,
          style: AppTextStyles.body(fontSize: 13, color: colors.ink600),
        );
      }
      return NoDataCard(
        actions: [l10n.chatCardFollowUpAction],
        onActionTap: onActionTap ?? (_) {},
      );
    }
    return switch (block.type) {
      'attraction_list' => _AttractionListCard(
          data: AttractionListCardData.fromJson(block.payload)),
      // `crowd` 타입은 두 모양을 겸한다: 지역 전체 혼잡도(`summary`/`samples`
      // 있음, `CrowdCardData`)와 사용자가 특정 관광지명으로 물어봐 매칭된
      // 관광지별 혼잡도 예보(`items` 배열, `CrowdMatchCardData`) — `items`
      // 키 유무로 구분한다.
      'crowd' => block.payload['items'] is List
          ? _CrowdMatchCard(data: CrowdMatchCardData.fromJson(block.payload))
          : _CrowdCard(data: CrowdCardData.fromJson(block.payload)),
      'area_overview' =>
        _CrowdCard(data: CrowdCardData.fromJson(block.payload)),
      'alternatives' => _AlternativesCard(
          data: AttractionAlternativesResult.fromJson(block.payload)),
      // `GET /attractions/{id}` 응답과 필드명이 같아(최상위가 `AttractionSummary`
      // 모양) `AttractionItem.fromJson`을 그대로 재사용, 항목 1개짜리 목록
      // 카드로 그린다.
      'detail' => _AttractionListCard(
          data: AttractionListCardData(
            category: '',
            signguNm: block.payload['signgu_nm'] as String? ?? '',
            items: [AttractionItem.fromJson(block.payload)],
          ),
        ),
      'interest' =>
        _InterestCard(data: AttractionInterestTrend.fromJson(block.payload)),
      'visitors' =>
        _VisitorsCard(data: VisitorsCardData.fromJson(block.payload)),
      _ => _unsupported(),
    };
  }

  Widget _unsupported() {
    AppLog.logger.w('[ChatCardView] 지원하지 않는 카드 타입: ${block.type}');
    return const SizedBox.shrink();
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
/// 무한정 길어지지 않도록). 사용자 요청으로 보이는 항목 사이사이에도
/// 구분선(`Divider`)을 넣는다 — "더보기" 버튼 위 구분선과는 별개.
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
    // `_CrowdCard`/`_CrowdMatchCard`/`_AlternativesCard`와 동일한 이유로
    // 빈 목록이면 카드 자체를 그리지 않는다 — `hasData`(status/has_data)가
    // `true`(또는 필드 자체가 없어 기본 `true`)이면서 `items`만 빈 배열인
    // 경우, 이 가드가 없으면 제목만 있거나(제목도 없으면 완전히 빈) 배경
    // 박스만 뜬 카드가 그려졌다.
    final items = widget.data.items;
    if (items.isEmpty) return const SizedBox.shrink();
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    final hiddenCount = items.length - _collapsedCount;
    final visibleItems =
        (_expanded || hiddenCount <= 0 ? items : items.take(_collapsedCount))
            .toList();
    // `signgu_nm`/`category`가 둘 다 비어있으면(예: 관광지명 단건 조회처럼
    // 제목이 아예 없는 카드) 제목 자체를 그리지 않는데, 이때도 첫 항목 앞에
    // 무조건 12px 여백을 넣으면 위에 아무것도 없는데 빈 공간만 뜬 채로
    // 시작해 항목이 카드 상단에서 붕 떠 보였다 — 제목이 있을 때만(위에서
    // 떨어뜨릴 대상이 있을 때만) 그 여백을 넣는다.
    final hasTitle =
        widget.data.signguNm.isNotEmpty || widget.data.category.isNotEmpty;
    return CardContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // `signgu_nm`/`category`가 둘 다 비어있으면 제목 자체를 아예 그리지
          // 않는다(사용자 요청). 값이 있는 것만 공백으로 이어붙여 `label` 하나로
          // 넘긴다 — 예전엔 두 필드를 템플릿에 나란히 박아 넣어, 실제 payload에
          // `category`가 없는 경우(대부분의 `attraction_list`/모든 `detail`
          // 카드) `signguNm`만 있어도 "OO  목록"처럼 중간에 빈칸이 두 번 들어가
          // 있었다.
          if (hasTitle)
            Text(
              l10n.chatCardAttractionListTitle(
                [widget.data.signguNm, widget.data.category]
                    .where((part) => part.isNotEmpty)
                    .join(' '),
              ),
              style: AppTextStyles.heading(fontSize: 16, color: colors.ink),
            ),
          for (var i = 0; i < visibleItems.length; i++) ...[
            // 첫 항목 앞은 제목이 있을 때만 12px 여백, 두 번째 항목부터는
            // 사용자 요청으로 항목 사이에 구분선(`Divider`)을 추가함 —
            // "더보기" 버튼 위 구분선(아래 `hiddenCount > 0` 분기)과는
            // 별개로, 접혀서 안 보이는 항목이 있어도 지금 보이는 항목들
            // 사이에는 항상 그림.
            if (i > 0) ...[
              const SizedBox(height: 12),
              Divider(height: 1, color: colors.divider),
            ],
            if (i > 0 || hasTitle) const SizedBox(height: 12),
            _AttractionRow(item: visibleItems[i]),
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
            style: AppTextStyles.heading(
                fontSize: 16, color: colors.chatCardAccent),
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
            style: AppTextStyles.body(
                fontSize: 11.5, color: colors.chatCardAccent),
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

  /// 카드가 너무 길어지지 않도록 섹션별 샘플은 앞에서 몇 개만 보여준다
  /// (실제 데이터는 더 많을 수 있음 — 표시상의 제한일 뿐 데이터 손실은 아님).
  static const _maxSamplesPerSection = 3;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    final crowded = data.samples[Level.busy] ?? const [];
    // "인기 관광지"는 혼잡 샘플(samples.crowded)로 채우되, 비어있으면
    // 보통 샘플(samples.normal)로 대체한다.
    final popular =
        crowded.isNotEmpty ? crowded : (data.samples[Level.normal] ?? const []);
    final quiet = data.samples[Level.quiet] ?? const [];
    // `payload.summary`가 전부 0(빈 값 포함, `every`는 빈 컬렉션에서 true)이거나
    // 보여줄 샘플(인기/한적 둘 다)이 없으면, 안내 문구조차 없이 카드 자체를
    // 응답에서 완전히 숨긴다(서버의 `status`/`has_data`와 별개인 클라이언트
    // 쪽 추가 판단 — 값은 있지만 전부 무의미한 0/빈 배열인 경우를 위함).
    final summaryAllZero = data.counts.values.every((count) => count == 0);
    if (summaryAllZero || (popular.isEmpty && quiet.isEmpty)) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CardContainer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.chatCardCrowdOverviewTitle(data.signguNm),
                style: AppTextStyles.heading(fontSize: 16, color: colors.ink),
              ),
              const SizedBox(height: 10),
              RegionDonutChart(counts: data.counts),
            ],
          ),
        ),
        const SizedBox(height: 10),
        CardContainer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.chatCardCrowdTitle(data.signguNm),
                style: AppTextStyles.heading(fontSize: 16, color: colors.ink),
              ),
              if (popular.isNotEmpty) ...[
                const SizedBox(height: 14),
                _SampleSection(
                  label: l10n.chatCardCrowdPopularLabel,
                  samples: popular.take(_maxSamplesPerSection),
                ),
              ],
              if (quiet.isNotEmpty) ...[
                const SizedBox(height: 14),
                _SampleSection(
                  label: l10n.chatCardCrowdQuietLabel,
                  samples: quiet.take(_maxSamplesPerSection),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _SampleSection extends StatelessWidget {
  const _SampleSection({required this.label, required this.samples});

  final String label;
  final Iterable<CrowdSample> samples;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.body(fontSize: 11.5, color: colors.ink600),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final sample in samples) _SampleChip(sample: sample),
          ],
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
          sample.name,
          style: AppTextStyles.tabularNums(
            AppTextStyles.body(fontSize: 12, color: colors.ink),
          ),
        ),
      ),
    );
  }
}

/// `crowd` 카드의 매칭된 관광지 예보 모양(`items` 배열이 있음 — 사용자가
/// 특정 관광지명으로 물어봐 그 관광지의 일자별 혼잡도 예보를 돌려준 경우).
/// `attractions/{content_id}/crowd`(`attractions_api.dart`의
/// `AttractionCrowdDay`/`AttractionCrowdPeriodSummary`)와 항목별 `series`/
/// `summary` 필드명이 동일해 그 모델을 그대로 재사용한다.
class CrowdMatchCardData {
  const CrowdMatchCardData({required this.signguNm, required this.items});

  factory CrowdMatchCardData.fromJson(Map<String, dynamic> json) {
    return CrowdMatchCardData(
      signguNm: json['signgu_nm'] as String? ?? '',
      items: ((json['items'] as List<dynamic>?) ?? const [])
          .cast<Map<String, dynamic>>()
          .map(CrowdMatchItem.fromJson)
          .toList(),
    );
  }

  final String signguNm;
  final List<CrowdMatchItem> items;
}

class CrowdMatchItem {
  const CrowdMatchItem({
    required this.contentId,
    required this.name,
    required this.days,
    this.summary,
  });

  factory CrowdMatchItem.fromJson(Map<String, dynamic> json) {
    final summaryJson = json['summary'] as Map<String, dynamic>?;
    return CrowdMatchItem(
      contentId: json['content_id']?.toString() ?? '',
      name:
          (json['name'] as String?) ?? (json['matched_title'] as String?) ?? '',
      days: ((json['series'] as List<dynamic>?) ?? const [])
          .cast<Map<String, dynamic>>()
          .map(AttractionCrowdDay.fromJson)
          .toList(),
      summary: summaryJson == null
          ? null
          : AttractionCrowdPeriodSummary.fromJson(summaryJson),
    );
  }

  final String contentId;
  final String name;
  final List<AttractionCrowdDay> days;
  final AttractionCrowdPeriodSummary? summary;
}

class _CrowdMatchCard extends StatelessWidget {
  const _CrowdMatchCard({required this.data});

  final CrowdMatchCardData data;

  @override
  Widget build(BuildContext context) {
    final items = data.items.where((item) => item.days.isNotEmpty).toList();
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < items.length; i++)
          Padding(
            padding: EdgeInsets.only(top: i == 0 ? 0 : 10),
            child: _CrowdMatchItemCard(item: items[i], sigun: data.signguNm),
          ),
      ],
    );
  }
}

class _CrowdMatchItemCard extends StatelessWidget {
  const _CrowdMatchItemCard({required this.item, required this.sigun});

  final CrowdMatchItem item;
  final String? sigun;

  void _open(BuildContext context) {
    if (item.contentId.isEmpty) {
      MapAppSheet.show(context, placeName: item.name);
      return;
    }
    context.pushNamed(
      RouteNames.attractionDetail,
      extra: AttractionDetailArgs(
          contentId: item.contentId, initialTitle: item.name),
    );
  }

  String _formatDate(DateTime? date) =>
      date == null ? '' : '${date.month}월 ${date.day}일';

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    final summary = item.summary;
    return Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 22),
        decoration: BoxDecoration(
          color: colors.crowdChartBackground,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: () => _open(context),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // 장소명 길이 + 접근성 글자 크기 설정에 따라 `sigun`(시군구
                  // 라벨)과 합친 폭이 카드 너비를 넘어 `RenderFlex` 오버플로가
                  // 나던 문제 — `Expanded` + 말줄임으로 장소명 쪽만 줄어들게
                  // 하고 `sigun`은 항상 온전히 보이게 한다.
                  Expanded(
                    child: Text(
                      item.name,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      style:
                          AppTextStyles.heading(fontSize: 16, color: colors.ink)
                              .copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    sigun ?? '',
                    style: AppTextStyles.heading(
                            fontSize: 12, color: colors.ink600)
                        .copyWith(fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 15),
            CrowdBarChart(days: item.days, barColor: colors.chatCardAccent),
            if (summary != null) ...[
              const SizedBox(height: 12),
              Text(
                l10n.attractionDetailCrowdSummary(
                  summary.avg,
                  _formatDate(summary.peakDate),
                  summary.peakRate,
                  _formatDate(summary.minDate),
                  summary.minRate,
                ),
                style: AppTextStyles.body(fontSize: 12, color: colors.ink600),
              ),
            ],
          ],
        ));
  }
}

/// `type: "alternatives"` 카드 — `attractions/{content_id}/alternatives`
/// REST 응답과 필드명이 완전히 같아(`base`/`items`/`signgu_nm`/`source`)
/// [AttractionAlternativesResult]를 그대로 재사용한다. `items`가 비어있으면
/// 보여줄 게 없으므로 카드 자체를 숨긴다(`_CrowdCard`의 빈 데이터 처리와
/// 동일한 방침).
class _AlternativesCard extends StatelessWidget {
  const _AlternativesCard({required this.data});

  final AttractionAlternativesResult data;

  void _open(BuildContext context, String contentId, String title) {
    if (contentId.isEmpty) {
      MapAppSheet.show(context, placeName: title);
      return;
    }
    context.pushNamed(
      RouteNames.attractionDetail,
      extra: AttractionDetailArgs(contentId: contentId, initialTitle: title),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (data.items.isEmpty) return const SizedBox.shrink();
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    final base = data.base;
    return CardContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            base != null
                ? l10n.chatCardAlternativesTitle(base.name)
                : l10n.attractionDetailAlternativesSection,
            style: AppTextStyles.heading(fontSize: 16, color: colors.ink),
          ),
          // if (base != null) ...[
          //   const SizedBox(height: 8),
          //   CongestionBadge(level: base.level, score: base.rate),
          // ],
          const SizedBox(height: 12),
          AlternativesSection(
            items: data.items,
            onTap: (contentId, title) => _open(context, contentId, title),
          ),
        ],
      ),
    );
  }
}

/// `type: "interest"` 카드 — `attractions/{content_id}/interest`와 필드명이
/// 완전히 같아(`AttractionInterestTrend`/`AttractionInterestItem`) 그 모델을
/// 그대로 재사용한다. **[API 문서로 확인함]** `trend`가 `flat`인 항목은 특별히
/// 알릴 게 없어 제외하고, 그 외(`up`/`down` 등) 항목만 한 줄씩 보여준다 —
/// 전부 `flat`이면 카드 자체를 숨긴다.
class _InterestCard extends StatelessWidget {
  const _InterestCard({required this.data});

  final AttractionInterestTrend data;

  (String, Color) _trendLabelAndColor(
      AppLocalizations l10n, AppColors colors, String trend) {
    return switch (trend) {
      'up' => (l10n.attractionDetailInterestTrendUp, colors.busyText),
      'down' => (l10n.attractionDetailInterestTrendDown, colors.quietText),
      _ => (l10n.attractionDetailInterestTrendFlat, colors.ink600),
    };
  }

  @override
  Widget build(BuildContext context) {
    final items = data.items.where((item) => item.trend != 'flat').toList();
    if (items.isEmpty) return const SizedBox.shrink();
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    return CardContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.attractionDetailInterestSection,
            style: AppTextStyles.heading(fontSize: 16, color: colors.ink),
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(height: 6),
            _buildLine(colors, l10n, items[i]),
          ],
        ],
      ),
    );
  }

  Widget _buildLine(
      AppColors colors, AppLocalizations l10n, AttractionInterestItem item) {
    final (trendLabel, trendColor) =
        _trendLabelAndColor(l10n, colors, item.trend);
    final sign = item.changePct > 0 ? '+' : '';
    return Text(
      l10n.chatCardInterestLine(
        item.displayName,
        item.weeks,
        trendLabel,
        '$sign${item.changePct.round()}%',
      ),
      style: AppTextStyles.body(fontSize: 13, color: trendColor),
    );
  }
}

/// `card` 이벤트의 `type: "visitors"` payload. **[실서버 예시로 확인함]**
/// `areas/{signgu_cd}/visitors` REST 응답(`areas_api.dart`의 `AreaVisitorsTrend`
/// — 여전히 미확인 가정 상태)과 같은 모양일 것으로 가정했으나, 실제로는 주
/// 단위가 아니라 **일 단위** 방문자 수이고 방문자 구분(`local`/`outsider`/
/// `foreigner`)도 `byType` 맵이 아니라 최상위 키로 바로 온다 — 그 REST
/// 모델과는 다른 별도 모델로 뺐다.
class VisitorsCardData {
  const VisitorsCardData({
    required this.signguNm,
    required this.items,
    this.dataThrough,
    this.partial = false,
    this.note,
  });

  factory VisitorsCardData.fromJson(Map<String, dynamic> json) {
    return VisitorsCardData(
      signguNm: json['signgu_nm'] as String? ?? '',
      items: ((json['items'] as List<dynamic>?) ?? const [])
          .cast<Map<String, dynamic>>()
          .map(VisitorsDayPoint.fromJson)
          .toList(),
      dataThrough: DateTime.tryParse(json['data_through'] as String? ?? ''),
      partial: json['partial'] as bool? ?? false,
      note: json['note'] as String?,
    );
  }

  final String signguNm;
  final List<VisitorsDayPoint> items;
  final DateTime? dataThrough;

  /// 서버가 기간 일부만 채워 보냈다는 표시. 화면에서 아직 별도로 다루지 않는다.
  final bool partial;

  /// 서버가 데이터 출처/지연에 대해 직접 준 안내 문구(예: "통신 데이터
  /// 기반이며 두 달쯤 지연된 값입니다") — 클라이언트가 문구를 새로 짓지 않고
  /// 그대로 보여준다.
  final String? note;
}

/// [VisitorsCardData]의 일별 방문자 수 한 건.
class VisitorsDayPoint {
  const VisitorsDayPoint({
    required this.date,
    required this.total,
    required this.local,
    required this.outsider,
    required this.foreigner,
  });

  factory VisitorsDayPoint.fromJson(Map<String, dynamic> json) {
    return VisitorsDayPoint(
      date: DateTime.tryParse(json['date'] as String? ?? ''),
      total: ((json['total'] as num?) ?? 0).toInt(),
      local: ((json['local'] as num?) ?? 0).toInt(),
      outsider: ((json['outsider'] as num?) ?? 0).toInt(),
      foreigner: ((json['foreigner'] as num?) ?? 0).toInt(),
    );
  }

  final DateTime? date;
  final int total;
  final int local;
  final int outsider;
  final int foreigner;
}

/// 방문자 추이 요약 카드(사용자 지정 시안). 날짜별로 전부 나열하는 대신
/// ① 가장 많았던 날짜(`_PeakHighlight`, 강조 박스)와 ② 최근 [_recentCount]일
/// (`_VisitorsDayRow`)치만 추려서 보여주고, 맨 아래 근거(`data_through`/
/// `note`)로 마무리한다 — `CardContainer` 하나에 제목 → 최고 방문일 →
/// 최근 며칠 → 근거 순서로 구성.
class _VisitorsCard extends StatelessWidget {
  const _VisitorsCard({required this.data});

  final VisitorsCardData data;

  static const _recentCount = 3;
  static final _countFormat = NumberFormat.decimalPattern();

  String _formatDate(DateTime? date) =>
      date == null ? '' : '${date.month}월 ${date.day}일';

  @override
  Widget build(BuildContext context) {
    final points = data.items.where((point) => point.date != null).toList()
      ..sort((a, b) => a.date!.compareTo(b.date!));
    if (points.isEmpty) return const SizedBox.shrink();
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    final peak = points.reduce((a, b) => b.total > a.total ? b : a);
    // 최근 며칠치는 오래된 날짜 → 최신 날짜 순(작은 흐름을 그대로 읽히도록)으로
    // 보여준다 — 전체 목록 정렬(오름차순)의 꼬리 부분을 그대로 잘라 쓴다.
    final recent = points.length <= _recentCount
        ? points
        : points.sublist(points.length - _recentCount);
    // "근거" — 데이터 기준일(data_through)과 서버가 직접 준 설명(note, 예:
    // "통신 데이터 기반이며 두 달쯤 지연된 값입니다")을 이어붙인다. note는
    // 클라이언트가 문구를 새로 짓지 않고 그대로 보여준다.
    final basis = [
      if (data.dataThrough != null)
        l10n.chatCardVisitorsDataThrough(_formatDate(data.dataThrough)),
      if (data.note != null && data.note!.isNotEmpty) data.note!,
    ].join(' · ');
    return CardContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.chatCardVisitorsTitle(data.signguNm),
            style: AppTextStyles.heading(fontSize: 16, color: colors.ink),
          ),
          const SizedBox(height: 12),
          _PeakHighlight(
            point: peak,
            formatDate: _formatDate,
            countFormat: _countFormat,
          ),
          const SizedBox(height: 14),
          Text(
            l10n.chatCardVisitorsRecentLabel,
            style: AppTextStyles.body(fontSize: 12, color: colors.ink600),
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < recent.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            _VisitorsDayRow(
              point: recent[i],
              formatDate: _formatDate,
              countFormat: _countFormat,
            ),
          ],
          if (basis.isNotEmpty) ...[
            const SizedBox(height: 14),
            Divider(height: 1, color: colors.divider),
            const SizedBox(height: 12),
            Text(
              l10n.chatCardVisitorsBasisLabel,
              style: AppTextStyles.body(fontSize: 12, color: colors.ink600),
            ),
            const SizedBox(height: 2),
            Text(
              basis,
              style: AppTextStyles.body(
                  fontSize: 13, color: colors.ink, height: 1.5),
            ),
          ],
        ],
      ),
    );
  }
}

/// [_VisitorsCard] 상단의 "가장 많았던 날짜" 강조 박스 — `_SampleChip`
/// (`crowd` 카드)과 같은 배경·테두리(`colors.surfaceMuted`/`surfaceMutedBorder`)로
/// 나머지 날짜별 행(배경 없는 일반 텍스트 행)과 시각적으로 구분한다.
class _PeakHighlight extends StatelessWidget {
  const _PeakHighlight({
    required this.point,
    required this.formatDate,
    required this.countFormat,
  });

  final VisitorsDayPoint point;
  final String Function(DateTime?) formatDate;
  final NumberFormat countFormat;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surfaceMuted,
        border: Border.all(color: colors.surfaceMutedBorder),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.chatCardVisitorsPeakLabel,
                  style: AppTextStyles.body(fontSize: 11, color: colors.ink600),
                ),
                const SizedBox(height: 2),
                Text(
                  formatDate(point.date),
                  style: AppTextStyles.heading(fontSize: 14, color: colors.ink),
                ),
              ],
            ),
          ),
          Text(
            l10n.chatCardVisitorsDayCount(countFormat.format(point.total)),
            style: AppTextStyles.heading(
                fontSize: 18, color: colors.chatCardAccent),
          ),
        ],
      ),
    );
  }
}

/// [_VisitorsCard]의 날짜 한 줄 — 날짜는 왼쪽, 인원 수는 오른쪽.
class _VisitorsDayRow extends StatelessWidget {
  const _VisitorsDayRow({
    required this.point,
    required this.formatDate,
    required this.countFormat,
  });

  final VisitorsDayPoint point;
  final String Function(DateTime?) formatDate;
  final NumberFormat countFormat;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Row(
      children: [
        Expanded(
          child: Text(
            formatDate(point.date),
            style: AppTextStyles.body(fontSize: 13, color: colors.ink),
          ),
        ),
        Text(
          l10n.chatCardVisitorsDayCount(countFormat.format(point.total)),
          style: AppTextStyles.tabularNums(
              AppTextStyles.body(fontSize: 13, color: colors.ink)),
        ),
      ],
    );
  }
}
