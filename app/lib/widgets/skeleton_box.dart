import 'package:flutter/material.dart';

import 'package:nullnull/theme/app_colors.dart';

/// TODO 추후 이미지 교체
/// 네트워크 이미지 로딩 전/실패 시 보여주는 스켈레톤 placeholder.
/// 골드 톤 그라디언트가 은은하게 좌우로 스윕하며 "로딩 중"임을 표시한다.
class SkeletonBox extends StatefulWidget {
  const SkeletonBox({super.key, this.child});

  final Widget? child;

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        return Container(
          decoration: BoxDecoration(
            color: colors.accentTint08,
            gradient: LinearGradient(
              begin: Alignment(-1.6 + t * 3.2, 0),
              end: Alignment(-0.6 + t * 3.2, 0),
              colors: [
                colors.accentTint08,
                colors.accentTint14,
                colors.accentTint08
              ],
            ),
          ),
          alignment: Alignment.center,
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
