import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'pose.dart';

/// 하단 시트: 카테고리 탭 + 가로 썸네일. 포즈 탭 시 onSelect(pose)+닫힘,
/// '끄기' 시 onSelect(null)+닫힘, 'AI 추천' 시 onAiRecommend()+닫힘.
Future<void> showPosePicker(
  BuildContext context, {
  required List<Pose> poses,
  required void Function(Pose?) onSelect,
  required VoidCallback onAiRecommend,
}) {
  final grouped = groupByCategory(poses);
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surfaceCard,
    builder: (ctx) => DefaultTabController(
      length: PoseCategory.values.length,
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                TextButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    onSelect(null);
                  },
                  icon: const Icon(Icons.visibility_off, size: 18),
                  label: const Text('끄기'),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    onAiRecommend();
                  },
                  icon: const Icon(Icons.auto_awesome, size: 18),
                  label: const Text('AI 추천'),
                ),
              ],
            ),
            const TabBar(
              isScrollable: true,
              tabs: [
                Tab(text: '셀카'),
                Tab(text: '전신'),
                Tab(text: '커플'),
                Tab(text: '우정'),
              ],
            ),
            SizedBox(
              height: 140,
              child: TabBarView(
                children: [
                  for (final c in PoseCategory.values)
                    _PoseRow(
                      poses: grouped[c] ?? const [],
                      onTap: (p) {
                        Navigator.pop(ctx);
                        onSelect(p);
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _PoseRow extends StatelessWidget {
  final List<Pose> poses;
  final void Function(Pose) onTap;
  const _PoseRow({required this.poses, required this.onTap});

  @override
  Widget build(BuildContext context) {
    if (poses.isEmpty) {
      return const Center(child: Text('포즈 준비 중'));
    }
    return ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.all(12),
      children: [
        for (final p in poses)
          GestureDetector(
            onTap: () => onTap(p),
            child: Container(
              width: 84,
              margin: const EdgeInsets.only(right: 10),
              child: Column(
                children: [
                  Expanded(
                    child: Container(
                      color: Colors.black26,
                      alignment: Alignment.center,
                      child: Image.asset(
                        p.asset,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(
                              Icons.accessibility_new,
                              color: Colors.white54,
                            ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    p.label,
                    style: const TextStyle(fontSize: 12),
                    maxLines: 1,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
