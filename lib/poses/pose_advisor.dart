// lib/poses/pose_advisor.dart
import 'package:cloud_functions/cloud_functions.dart';
import '../cloud/advice_image.dart';
import 'pose.dart';

class PoseAdviceException implements Exception {
  final String message;
  PoseAdviceException(this.message);
  @override
  String toString() => 'PoseAdviceException: $message';
}

class PoseSuggestion {
  final String poseId;
  final String reason;
  const PoseSuggestion({required this.poseId, required this.reason});
}

/// 서버 결과 맵 → PoseSuggestion (방어적).
PoseSuggestion poseSuggestionFromResult(Map<String, dynamic> data) {
  final id = data['poseId'];
  final reason = data['reason'];
  return PoseSuggestion(
    poseId: id is String ? id : '',
    reason: reason is String ? reason : '',
  );
}

/// 현재 프레임을 서버로 보내 어울리는 포즈 id를 받는다. 판단 없음(전송·파싱만).
class PoseAdvisor {
  final FirebaseFunctions _functions;
  PoseAdvisor({FirebaseFunctions? functions})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: 'asia-northeast3');

  Future<PoseSuggestion> suggest({
    required String jpegPath,
    required List<Pose> candidates,
    required String deviceId,
  }) async {
    try {
      final downsized = await encodeDownsizedJpeg(jpegPath);
      final base64 = await fileToBase64(downsized);
      final callable = _functions.httpsCallable(
        'suggestPose',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 20)),
      );
      final result = await callable.call<Map<String, dynamic>>({
        'imageBase64': base64,
        'mediaType': 'image/jpeg',
        'deviceId': deviceId,
        'candidates': [
          for (final p in candidates)
            {'id': p.id, 'label': p.label, 'category': p.category.wire},
        ],
      });
      return poseSuggestionFromResult(Map<String, dynamic>.from(result.data));
    } on FirebaseFunctionsException catch (e) {
      throw PoseAdviceException(e.message ?? '포즈 추천 실패');
    } catch (e) {
      throw PoseAdviceException('포즈 추천 실패: $e');
    }
  }
}
