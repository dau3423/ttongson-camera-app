import 'package:flutter/material.dart';
import '../models/shooting_mode.dart';

/// 하단 촬영 모드 선택기. **선택된 모드는 항상 가운데**, 양옆에 이웃 모드를 둔다.
/// 좌우 드래그(스와이프)로 이동하고, 옆 라벨 탭으로도 선택. 렌더+콜백만(판단 없음).
class ModeSelector extends StatelessWidget {
  final ShootingMode current;
  final ValueChanged<ShootingMode> onChanged;
  const ModeSelector({
    super.key,
    required this.current,
    required this.onChanged,
  });

  static const _modes = ShootingMode.values;
  static const _slotWidth = 96.0;

  /// 현재 기준 [offset]칸 떨어진 모드(순환). -1=이전, +1=다음.
  ShootingMode _at(int offset) {
    final n = _modes.length;
    final i = (_modes.indexOf(current) + offset) % n;
    return _modes[(i + n) % n];
  }

  void _select(ShootingMode m) {
    if (m != current) onChanged(m);
  }

  @override
  Widget build(BuildContext context) {
    final prev = _at(-1);
    final next = _at(1);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      // 좌로 밀면 다음 모드가, 우로 밀면 이전 모드가 가운데로 온다.
      onHorizontalDragEnd: (d) {
        final v = d.primaryVelocity ?? 0;
        if (v < -80) _select(next);
        if (v > 80) _select(prev);
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _slot(prev, selected: false),
          _slot(current, selected: true),
          _slot(next, selected: false),
        ],
      ),
    );
  }

  Widget _slot(ShootingMode m, {required bool selected}) {
    return GestureDetector(
      onTap: () => _select(m),
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
