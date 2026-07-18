// lib/cloud/mood_advisor.dart
import 'package:cloud_functions/cloud_functions.dart';
import '../analysis/mood_adjust.dart';
import 'advice_image.dart';

class MoodAdviceException implements Exception {
  final String message;
  MoodAdviceException(this.message);
  @override
  String toString() => 'MoodAdviceException: $message';
}

/// 서버 결과 맵 → MoodParams (범위 클램프는 MoodParams.fromJson이 담당).
MoodParams moodParamsFromResult(Map<String, dynamic> data) =>
    MoodParams.fromJson(data);

/// 촬영 사진 1장당 하나 생성. 무드별 결과를 캐시해 재호출을 막는다.
class MoodAdvisor {
  final FirebaseFunctions _functions;
  final Map<String, MoodParams> _cache = {};

  MoodAdvisor({FirebaseFunctions? functions})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: 'asia-northeast3');

  Future<MoodParams> enhance({
    required String jpegPath,
    required String moodWire,
    required String deviceId,
  }) async {
    final cached = _cache[moodWire];
    if (cached != null) return cached;
    try {
      final downsized = await encodeDownsizedJpeg(jpegPath);
      final base64 = await fileToBase64(downsized);
      final callable = _functions.httpsCallable(
        'enhance',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 20)),
      );
      final result = await callable.call<Map<String, dynamic>>({
        'imageBase64': base64,
        'mediaType': 'image/jpeg',
        'deviceId': deviceId,
        'mood': moodWire,
      });
      final params = moodParamsFromResult(
        Map<String, dynamic>.from(result.data),
      );
      _cache[moodWire] = params;
      return params;
    } on FirebaseFunctionsException catch (e) {
      throw MoodAdviceException(e.message ?? '보정값 생성 실패');
    } catch (e) {
      throw MoodAdviceException('보정값 생성 실패: $e');
    }
  }
}
