import 'package:flutter/material.dart';

import 'package:nullnull/theme/app_colors.dart';

class CardContainer extends StatelessWidget {
  const CardContainer({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: colors.graphite,
        border: Border.all(color: colors.inputBarBorder, width: 1.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
    );
  }
}
