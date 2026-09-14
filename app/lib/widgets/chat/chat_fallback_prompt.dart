import 'package:flutter/material.dart';

import 'package:nullnull/theme/app_colors.dart';
import 'package:nullnull/theme/app_text_styles.dart';
import 'package:nullnull/widgets/nullnull/mascot.dart';

/// 채팅 SSE가 버퍼(문장/카드)를 하나도 못 채운 채 에러로 끝났을 때(레이트리밋
/// 제외)의 대체 흐름 상태. `chat_screen.dart`의 `_AiChatEntry.fallbackState`가
/// 갖는 값과 1:1로 대응한다.
///
/// - [offered]: 실패 직후. "다른 방식으로 찾아보기" 버튼을 보여준다.
/// - [searching]: 버튼을 탭해 `AttractionsApi`/`AreasApi`로 best-effort 조회
///   중. 버튼 자리를 작은 스피너로 바꾼다.
/// - [exhausted]: 그마저 못 찾음(`not_found`/`ambiguous` — 선택 UI가 없어
///   v1에선 실패로 처리). 더 이상 액션이 없는 막다른 상태.
///
/// 찾은 경우(성공)는 이 위젯이 다루지 않는다 — `_AiChatEntry.blocks`를 채워
/// 기존 `StreamingAiMessage`/`ChatCardView` 경로로 그대로 렌더링한다.
enum ChatFallbackState { offered, searching, exhausted }

/// `NoDataCard`(정상 처리됐지만 보여줄 데이터가 없을 때)와 같은 시각 언어
/// (마스코트 + 버튼)를 쓰되, 원인이 다르므로(SSE 자체가 실패) 문구를 구분한다.
class ChatFallbackPrompt extends StatelessWidget {
  const ChatFallbackPrompt({
    super.key,
    required this.state,
    required this.offeredMessage,
    required this.exhaustedMessage,
    required this.actionLabel,
    required this.onSearch,
  });

  final ChatFallbackState state;
  final String offeredMessage;
  final String exhaustedMessage;
  final String actionLabel;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Mascot(size: 48),
          const SizedBox(height: 12),
          Text(
            state == ChatFallbackState.exhausted
                ? exhaustedMessage
                : offeredMessage,
            style: AppTextStyles.body(fontSize: 13.5, color: colors.ink),
          ),
          if (state != ChatFallbackState.exhausted) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed:
                    state == ChatFallbackState.searching ? null : onSearch,
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: colors.surfaceMutedBorder),
                  backgroundColor: colors.surfaceMuted,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  overlayColor: colors.accentTint08,
                ),
                child: state == ChatFallbackState.searching
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: colors.accent),
                      )
                    : Text(
                        actionLabel,
                        style: AppTextStyles.body(
                            fontSize: 13.5, color: colors.ink),
                      ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
