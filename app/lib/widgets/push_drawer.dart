import 'package:flutter/material.dart';

import 'package:nullnull/theme/app_colors.dart';

/// `assets/images/drawer_screen.png` 시안처럼, 열렸을 때 기본 [Drawer]와
/// 달리 화면 위에 겹쳐 뜨는 대신 본문 전체를 오른쪽으로 밀어내고 그 뒤에
/// 드러나는 방식의 드로어. [drawer]는 왼쪽에 깔려 있고, [child]는 열렸을 때
/// 오른쪽에 [peekWidth]만큼만 보이도록 밀려나며 모서리가 둥글게 말린다 —
/// 즉 드로어 폭은 기기 너비에 상관없이 `(가용 너비 - peekWidth)`로 계산된다.
/// 열려 있는 동안 그 [peekWidth] 영역(밀려난 본문이 보이는 부분)을 탭하거나
/// 좌우로 드래그하면 일반적인 드로어처럼 닫힌다 — 탭은 즉시 닫히고, 드래그는
/// 손가락을 따라 실시간으로 따라오다가 손을 떼는 순간의 위치/속도로 열림·
/// 닫힘 중 더 가까운(또는 튕긴 방향의) 상태로 스냅한다.
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

  /// 드래그로 직접 조작 중인 동안에는 손가락과 1:1로 움직여야 자연스러워
  /// [_controller.value]를 그대로 쓰고, `open()`/`close()`가 트는 프로그램
  /// 애니메이션(탭으로 닫기, 드래그 종료 후 스냅) 동안에는 `easeOutCubic`으로
  /// 감속한다 — `build()`의 `t` 계산 참고.
  bool _dragging = false;

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

  void _onDragStart(DragStartDetails details) => _dragging = true;

  /// 드래그 중 손가락을 따라 [_controller.value]를 실시간으로 갱신한다.
  /// `primaryDelta`가 음수(왼쪽으로 드래그, 닫는 방향)면 값이 줄고, 양수면
  /// 늘어난다 — `AnimationController.value` setter가 자체적으로
  /// notifyListeners를 호출해 `AnimatedBuilder`가 매 프레임 다시 그린다.
  void _onDragUpdate(DragUpdateDetails details, double drawerWidth) {
    if (drawerWidth <= 0) return;
    _controller.value =
        (_controller.value + details.primaryDelta! / drawerWidth)
            .clamp(0.0, 1.0);
  }

  /// 표준 [Drawer]의 닫힘 제스처와 같은 감각: 빠르게 튕기듯 스와이프하면
  /// (`primaryVelocity`) 방향에 따라 곧바로 스냅하고, 느리게 놓으면 절반
  /// (`0.5`)을 기준으로 더 가까운 상태로 스냅한다.
  static const double _flingVelocityThreshold = 365;

  void _onDragEnd(DragEndDetails details) {
    _dragging = false;
    final velocity = details.primaryVelocity ?? 0;
    if (velocity < -_flingVelocityThreshold) {
      close();
    } else if (velocity > _flingVelocityThreshold) {
      open();
    } else if (_controller.value > 0.5) {
      open();
    } else {
      close();
    }
  }

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
                  final t = _dragging
                      ? _controller.value
                      : Curves.easeOutCubic.transform(_controller.value);
                  final radius = 20 * t;
                  return Transform.translate(
                    offset: Offset(drawerWidth * t, 0),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(radius),
                      child: GestureDetector(
                        onTap: _open ? close : null,
                        onHorizontalDragStart: _open ? _onDragStart : null,
                        onHorizontalDragUpdate: _open
                            ? (details) => _onDragUpdate(details, drawerWidth)
                            : null,
                        onHorizontalDragEnd: _open ? _onDragEnd : null,
                        behavior: HitTestBehavior.opaque,
                        child: child,
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
