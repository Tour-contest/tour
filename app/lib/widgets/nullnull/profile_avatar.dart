import 'package:flutter/material.dart';

import 'package:nullnull/theme/app_colors.dart';
import 'package:nullnull/theme/app_text_styles.dart';

/// 원형 프로필 아바타. [imageUrl]이 있으면 네트워크 이미지를 원형으로 잘라
/// 보여주고, 없거나 로딩에 실패하면 [initial](보통 닉네임 첫 글자)로 대체한다.
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
  });

  final double size;
  final String initial;
  final String? imageUrl;
  final Color? borderColor;
  final TextStyle? initialStyle;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final fallback = Center(
      child: Text(
        initial,
        style:
            initialStyle ?? AppTextStyles.heading(color: colors.accentBright),
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
              child: Image.network(
                imageUrl!,
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => fallback,
              ),
            ),
    );
  }
}
