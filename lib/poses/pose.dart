// lib/poses/pose.dart
// 순수 Dart — 포즈 카탈로그 모델과 poses.json 파싱.
import 'dart:convert';

enum PoseCategory { selfie, fullbody, couple, friends }

extension PoseCategoryInfo on PoseCategory {
  String get label => switch (this) {
    PoseCategory.selfie => '셀카',
    PoseCategory.fullbody => '전신',
    PoseCategory.couple => '커플',
    PoseCategory.friends => '우정',
  };
  String get wire => name; // 'selfie','fullbody','couple','friends'
}

PoseCategory? poseCategoryFromWire(String wire) {
  for (final c in PoseCategory.values) {
    if (c.wire == wire) return c;
  }
  return null;
}

class Pose {
  final String id;
  final PoseCategory category;
  final String label;
  final String asset;
  const Pose({
    required this.id,
    required this.category,
    required this.label,
    required this.asset,
  });
}

/// poses.json(배열)을 Pose 리스트로. 이상 항목은 건너뛴다(비차단).
List<Pose> parsePoses(String jsonString) {
  final dynamic raw;
  try {
    raw = jsonDecode(jsonString);
  } catch (_) {
    return const [];
  }
  if (raw is! List) return const [];
  final out = <Pose>[];
  for (final item in raw) {
    if (item is! Map) continue;
    final id = item['id'];
    final cat = item['category'];
    final label = item['label'];
    final asset = item['asset'];
    if (id is! String ||
        cat is! String ||
        label is! String ||
        asset is! String) {
      continue;
    }
    final category = poseCategoryFromWire(cat);
    if (category == null) continue;
    out.add(Pose(id: id, category: category, label: label, asset: asset));
  }
  return out;
}

Map<PoseCategory, List<Pose>> groupByCategory(List<Pose> poses) {
  final map = <PoseCategory, List<Pose>>{
    for (final c in PoseCategory.values) c: [],
  };
  for (final p in poses) {
    map[p.category]!.add(p);
  }
  return map;
}
