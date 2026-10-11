import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:nullnull/theme/app_colors.dart';
import 'package:nullnull/theme/app_text_styles.dart';

/// 원형 프로필 아바타. [imageUrl]이 있으면 `CachedNetworkImage`로 내려받아
/// 원형으로 잘라 보여주고(한 번 받은 이미지는 캐시돼 재요청하지 않음), 없거나
/// 로딩 중/실패 시에는 [initial](보통 닉네임 첫 글자)로 대체한다.
/// `settings_screen.dart`의 "내 정보"와 `chat_screen.dart` 앱바의 프로필 버튼이
/// 공용으로 쓴다 — 전자는 [borderColor]로 테두리를 그리고, 후자는 기존 앱바
/// 아이콘처럼 테두리 없이 쓴다.
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    required this.size,
    required this.initial,
    this.imageUrl,
    this.borderColor,
    this.initialStyle,
    this.pinTextScale = false,
  });

  final double size;
  final String initial;
  final String? imageUrl;
  final Color? borderColor;
  final TextStyle? initialStyle;

  /// `true`면 [initial] 글자에 접근성 글자 크기 설정(`AppTextScaleController`)이
  /// 적용되지 않는다 — `chat_screen.dart`의 `_ProfileAvatarButton`처럼 헤더의
  /// 고정 크기 아이콘 슬롯 안에 들어가는 경우, 글자가 커지면 원형 아바타를
  /// 벗어날 수 있어 사용자 요청으로 추가함. `settings_screen.dart`의 "내 정보"
  /// 아바타는 기본값(`false`)을 그대로 써서 영향받지 않는다.
  final bool pinTextScale;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final fallback = Center(
      child: Text(
        initial,
        textScaler: pinTextScale ? TextScaler.noScaling : null,
        style: initialStyle ??
            AppTextStyles.heading(color: colors.accentBright, fontSize: 14),
      ),
    );
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: borderColor == null ? null : Border.all(color: borderColor!),
      ),
      child: imageUrl == null
          ? fallback
          : ClipOval(
              child: CachedNetworkImage(
                imageUrl: imageUrl!,
                width: size,
                height: size,
                fit: BoxFit.cover,
                placeholder: (_, __) => fallback,
                errorWidget: (_, __, ___) => fallback,
              ),
            ),
    );
  }
}
