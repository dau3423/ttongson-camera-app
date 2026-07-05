import 'package:flutter/material.dart';
import '../models/shooting_mode.dart';

/// 하단 촬영 모드 선택 휠. 렌더 + 콜백만(판단 없음).
class ModeSelector extends StatelessWidget {
  final ShootingMode current;
  final ValueChanged<ShootingMode> onChanged;
  const ModeSelector({
    super.key,
    required this.current,
    required this.onChanged,
  });

  static const _modes = ShootingMode.values;

  void _shift(int delta) {
    final i = _modes.indexOf(current);
    final next = i + delta;
    if (next >= 0 && next < _modes.length) onChanged(_modes[next]);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // 좌로 밀면 다음, 우로 밀면 이전 모드.
      onHorizontalDragEnd: (d) {
        final v = d.primaryVelocity ?? 0;
        if (v < 0) _shift(1);
        if (v > 0) _shift(-1);
      },
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (final m in _modes)
            GestureDetector(
              onTap: () {
                if (m != current) onChanged(m);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                child: Text(
                  m.label,
                  style: TextStyle(
                    color: m == current ? Colors.amber : Colors.white70,
                    fontSize: m == current ? 18 : 15,
                    fontWeight: m == current
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
