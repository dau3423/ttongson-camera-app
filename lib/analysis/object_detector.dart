import 'dart:ui' show Size;

import 'package:camera/camera.dart';
import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';

import 'person_detector.dart';
import 'box_normalize.dart';

/// ML Kit Object Detection 기반 사물 감지. 가장 큰 사물 박스 하나를 정규화 PersonBox로 반환.
///
/// stream 모드는 "가장 두드러진 중앙 물체가 안정될 때까지" 박스를 잘 내보내지 않아
/// 사물 인식이 잘 안 되는 원인이 된다. 프레임을 이미 스로틀(_processing)하므로
/// 프레임마다 전체 검출을 하는 single 모드가 인식률이 더 좋다.
class MlKitObjectDetector implements PersonDetector {
  final ObjectDetector _detector = ObjectDetector(
    options: ObjectDetectorOptions(
      classifyObjects: false,
      multipleObjects: true,
      mode: DetectionMode.single,
    ),
  );

  @override
  Future<Detection?> detect(CameraImage image, int rotationDegrees) async {
    final input = _toInputImage(image, rotationDegrees);
    if (input == null) return null;
    final objects = await _detector.processImage(input);
    if (objects.isEmpty) return null;

    // 면적이 가장 큰 사물 선택.
    objects.sort(
      (a, b) => (b.boundingBox.width * b.boundingBox.height).compareTo(
        a.boundingBox.width * a.boundingBox.height,
      ),
    );
    final o = objects.first.boundingBox;
    // 회전 보정: ML Kit은 세운 좌표계의 박스를 반환하므로 세운 크기로 정규화.
    final box = normalizeBox(
      o.left,
      o.top,
      o.width,
      o.height,
      image.width,
      image.height,
      rotationDegrees,
    );
    // 사물엔 얼굴 개념이 없어 face/person 모두 같은 박스(사물 모드는 face 미사용).
    return Detection(face: box, person: box);
  }

  InputImage? _toInputImage(CameraImage image, int rotationDegrees) {
    final rotation =
        InputImageRotationValue.fromRawValue(rotationDegrees) ??
        InputImageRotation.rotation0deg;
    final format =
        InputImageFormatValue.fromRawValue(image.format.raw as int) ??
        InputImageFormat.nv21;
    final plane = image.planes.first;
    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  @override
  void dispose() => _detector.close();
}
