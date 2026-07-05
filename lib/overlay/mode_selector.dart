import 'package:flutter/material.dart';
import '../models/shooting_mode.dart';

/// 하단 촬영 모드 선택기. **선택된 모드는 항상 가운데**, 양옆에 이웃 모드.
/// 좌우 드래그(스와이프)로 이동하며 **슬라이딩 애니메이션**으로 전환된다.
/// 옆 라벨·화살표 탭으로도 선택. 렌더+콜백만(판단 없음).
class ModeSelector extends StatefulWidget {
  final ShootingMode current;
  final ValueChanged<ShootingMode> onChanged;
  const ModeSelector({
    super.key,
    required this.current,
    required this.onChanged,
  });

  @override
  State<ModeSelector> createState() => _ModeSelectorState();
}

class _ModeSelectorState extends State<ModeSelector> {
  static const _modes = ShootingMode.values;
  static const _slotWidth = 96.0;

  /// 마지막 이동 방향(1=다음/좌로 밀기, -1=이전/우로 밀기) — 슬라이드 방향용.
  int _dir = 1;

  /// 현재 기준 [offset]칸 떨어진 모드(순환).
  ShootingMode _at(int offset) {
    final n = _modes.length;
    final i = (_modes.indexOf(widget.current) + offset) % n;
    return _modes[(i + n) % n];
  }

  void _select(ShootingMode m, int dir) {
    if (m == widget.current) return;
    _dir = dir;
    widget.onChanged(m);
  }

  @override
  Widget build(BuildContext context) {
    final prev = _at(-1);
    final next = _at(1);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      // 좌로 밀면 다음, 우로 밀면 이전 모드가 가운데로.
      onHorizontalDragEnd: (d) {
        final v = d.primaryVelocity ?? 0;
        if (v < -80) _select(next, 1);
        if (v > 80) _select(prev, -1);
      },
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 260),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        transitionBuilder: (child, animation) {
          // 들어오는 항목은 이동 방향에서, 나가는 항목은 반대쪽으로 슬라이드.
          final outgoing = animation.status == AnimationStatus.reverse;
          final beginX = (outgoing ? -_dir : _dir) * 0.6;
          return SlideTransition(
            position: Tween<Offset>(
              begin: Offset(beginX, 0),
              end: Offset.zero,
            ).animate(animation),
            child: FadeTransition(opacity: animation, child: child),
          );
        },
        child: Row(
          key: ValueKey(widget.current),
          mainAxisSize: MainAxisSize.min,
          children: [
            _chevron(Icons.chevron_left, () => _select(prev, -1)),
            _slot(prev, selected: false),
            _slot(widget.current, selected: true),
            _slot(next, selected: false),
            _chevron(Icons.chevron_right, () => _select(next, 1)),
          ],
        ),
      ),
    );
  }

  Widget _chevron(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Icon(icon, color: Colors.white54, size: 22),
    );
  }

  Widget _slot(ShootingMode m, {required bool selected}) {
    return GestureDetector(
      onTap: () => _select(
        m,
        _modes.indexOf(m) > _modes.indexOf(widget.current) ? 1 : -1,
      ),
      child: SizedBox(
        width: _slotWidth,
        child: Text(
          m.label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: selected ? Colors.amber : Colors.white54,
            fontSize: selected ? 20 : 15,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
