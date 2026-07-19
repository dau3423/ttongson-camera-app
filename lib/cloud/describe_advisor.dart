// lib/cloud/describe_advisor.dart
import 'package:cloud_functions/cloud_functions.dart';
import 'advice_image.dart';

class DescribeException implements Exception {
  final String message;
  DescribeException(this.message);
  @override
  String toString() => 'DescribeException: $message';
}

class PhotoDescription {
  final String name;
  final List<String> tags;
  const PhotoDescription({required this.name, required this.tags});
}

/// 서버 결과 맵 → PhotoDescription (방어적).
PhotoDescription photoDescriptionFromResult(Map<String, dynamic> data) {
  final name = data['name'];
  final rawTags = data['tags'];
  final tags = rawTags is List
      ? rawTags.whereType<String>().toList()
      : <String>[];
  return PhotoDescription(name: name is String ? name : '', tags: tags);
}

/// 사진을 서버로 보내 이름·태그를 받는다. 판단 없음(전송·파싱만).
class DescribeAdvisor {
  final FirebaseFunctions _functions;
  DescribeAdvisor({FirebaseFunctions? functions})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: 'asia-northeast3');

  Future<PhotoDescription> describe({
    required String jpegPath,
    required String deviceId,
  }) async {
    try {
      final downsized = await encodeDownsizedJpeg(jpegPath);
      final base64 = await fileToBase64(downsized);
      final callable = _functions.httpsCallable(
        'describe',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 20)),
      );
      final result = await callable.call<Map<String, dynamic>>({
        'imageBase64': base64,
        'mediaType': 'image/jpeg',
        'deviceId': deviceId,
      });
      return photoDescriptionFromResult(Map<String, dynamic>.from(result.data));
    } on FirebaseFunctionsException catch (e) {
      throw DescribeException(e.message ?? '이름 생성 실패');
    } catch (e) {
      throw DescribeException('이름 생성 실패: $e');
    }
  }
}
