import 'package:cloud_functions/cloud_functions.dart';
import '../analysis/guide_metrics.dart';
import '../models/shooting_mode.dart';
import 'advice_image.dart';
import 'composition_advice.dart';

class CloudAdviceException implements Exception {
  final String message;
  CloudAdviceException(this.message);
  @override
  String toString() => 'CloudAdviceException: $message';
}

/// 현재 프레임을 클라우드 함수로 보내 구도 추천을 받는다. 판단 없음(전송·파싱만).
class CloudAdvisor {
  final FirebaseFunctions _functions;
  CloudAdvisor({FirebaseFunctions? functions})
    : _functions = functions ?? FirebaseFunctions.instance;

  Future<CompositionAdvice> suggest(
    String jpegPath,
    GuideMetrics metrics,
    String deviceId,
    ShootingMode mode,
  ) async {
    try {
      final downsized = await encodeDownsizedJpeg(jpegPath);
      final base64 = await fileToBase64(downsized);
      final callable = _functions.httpsCallable(
        'advise',
        // Sonnet 4.6 비전+구조화 출력은 보통 5초를 넘긴다. 서버 타임아웃(30s)보다
        // 짧게 20초로 둔다. (너무 짧으면 서버는 성공하는데 앱만 폴백됨)
        options: HttpsCallableOptions(timeout: const Duration(seconds: 20)),
      );
      final result = await callable.call<Map<String, dynamic>>({
        'imageBase64': base64,
        'mediaType': 'image/jpeg',
        'deviceId': deviceId,
        'mode': mode.wire,
        'metrics': _metricsPayload(metrics),
      });
      return CompositionAdvice.fromJson(Map<String, dynamic>.from(result.data));
    } on FirebaseFunctionsException catch (e) {
      throw CloudAdviceException(e.message ?? '구도 추천 실패');
    } catch (e) {
      throw CloudAdviceException('구도 추천 실패: $e');
    }
  }

  Map<String, dynamic> _metricsPayload(GuideMetrics m) {
    final person = m.person;
    return {
      'tiltDeg': double.parse(m.tilt.rollDegrees.toStringAsFixed(1)),
      'hasPerson': person != null,
      if (person != null)
        'personCenterX': double.parse(person.centerX.toStringAsFixed(2)),
      if (person != null)
        'personCenterY': double.parse(person.centerY.toStringAsFixed(2)),
    };
  }
}
