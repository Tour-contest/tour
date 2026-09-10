import 'package:flutter/material.dart';

import 'package:nullnull/theme/app_colors.dart';

/// `assets/images/drawer_screen.png` 시안처럼, 열렸을 때 기본 [Drawer]와
/// 달리 화면 위에 겹쳐 뜨는 대신 본문 전체를 오른쪽으로 밀어내고 그 뒤에
/// 드러나는 방식의 드로어. [drawer]는 왼쪽에 깔려 있고, [child]는 열렸을 때
/// 오른쪽에 [peekWidth]만큼만 보이도록 밀려나며 모서리가 둥글게 말린다 —
/// 즉 드로어 폭은 기기 너비에 상관없이 `(가용 너비 - peekWidth)`로 계산된다.
///
/// [Scaffold]의 내장 drawer(오버레이 + 스크림 + 엣지 스와이프)와 달리 뒤로가기로
/// 자동으로 닫히지 않으므로, 상위 화면에서 [GlobalKey<PushDrawerState>]를 들고
/// 있다가 `PopScope`의 뒤로가기 처리에서 [PushDrawerState.isOpen]일 때
/// [PushDrawerState.close]를 먼저 호출해야 한다.
class PushDrawer extends StatefulWidget {
  const PushDrawer({
    super.key,
    required this.drawer,
    required this.child,
    this.peekWidth = 80,
  });

  final Widget drawer;
  final Widget child;

  /// 드로어가 열렸을 때 오른쪽에 남겨둘 본문 폭. 기기 너비와 무관하게
  /// 고정값이며, 드로어 자체의 폭은 `가용 너비 - peekWidth`가 된다.
  final double peekWidth;

  @override
  State<PushDrawer> createState() => PushDrawerState();
}

class PushDrawerState extends State<PushDrawer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 240),
  );
  bool _open = false;

  bool get isOpen => _open;

  void open() {
    _open = true;
    _controller.forward();
  }

  void close() {
    _open = false;
    _controller.reverse();
  }

  void toggle() => _open ? close() : open();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return ColoredBox(
      color: colors.drawerBackground,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final drawerWidth = (constraints.maxWidth - widget.peekWidth).clamp(
            0.0,
            constraints.maxWidth,
          );
          return Stack(
            children: [
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: drawerWidth,
                child: widget.drawer,
              ),
              AnimatedBuilder(
                animation: _controller,
                child: widget.child,
                builder: (context, child) {
                  final t = Curves.easeOutCubic.transform(_controller.value);
                  final radius = 20 * t;
                  return Transform.translate(
                    offset: Offset(drawerWidth * t, 0),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(radius),
                        boxShadow: [
                          BoxShadow(
                            color: colors.scrim.withAlpha((153 * t).round()),
                            blurRadius: 24,
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(radius),
                        child: GestureDetector(
                          onTap: _open ? close : null,
                          behavior: HitTestBehavior.opaque,
                          child: child,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}
