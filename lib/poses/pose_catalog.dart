import 'package:flutter/services.dart' show rootBundle;
import 'pose.dart';

/// assets/poses/poses.json 을 로드해 Pose 리스트로. 실패 시 빈 리스트.
class PoseCatalog {
  static Future<List<Pose>> load() async {
    try {
      final json = await rootBundle.loadString('assets/poses/poses.json');
      return parsePoses(json);
    } catch (_) {
      return const [];
    }
  }
}
