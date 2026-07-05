import 'dart:ui' show Size;

import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import '../models/person_box.dart';
import 'box_normalize.dart';

/// 감지 결과: 원시 얼굴 박스(face)와 상반신 근사 박스(person)를 함께 보유.
class Detection {
  final PersonBox face;
  final PersonBox person;
  const Detection({required this.face, required this.person});
}

/// 프레임에서 인물 경계 상자(정규화)를 추출하는 인터페이스.
abstract class PersonDetector {
  Future<Detection?> detect(CameraImage image, int rotationDegrees);
  void dispose();
}

/// ML Kit Face Detection 기반 인물 감지 구현.
class MlKitPersonDetector implements PersonDetector {
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(performanceMode: FaceDetectorMode.fast),
  );

  @override
  Future<Detection?> detect(CameraImage image, int rotationDegrees) async {
    final input = _toInputImage(image, rotationDegrees);
    if (input == null) return null;
    final faces = await _faceDetector.processImage(input);
    if (faces.isEmpty) return null;

    // 가장 큰 얼굴 선택 후, 얼굴 상단 위로 확장해 상반신 근사.
    faces.sort(
      (a, b) => (b.boundingBox.width * b.boundingBox.height).compareTo(
        a.boundingBox.width * a.boundingBox.height,
      ),
    );
    final f = faces.first.boundingBox;
    // 회전 보정: ML Kit은 세운 좌표계의 박스를 반환하므로 세운 크기로 정규화.
    final s = uprightSize(image.width, image.height, rotationDegrees);

    // 원시 얼굴 박스(확장 없음) — 잘림 감지용.
    final faceBox = normalizeBox(
      f.left,
      f.top,
      f.width,
      f.height,
      image.width,
      image.height,
      rotationDegrees,
    );

    // 얼굴 박스를 인물 근사로 확장(위 0.5×h, 아래 3×h) — 구도/여백/줌용.
    // 확장·클램프는 세운 이미지 높이(s.h) 기준.
    final top = (f.top - f.height * 0.5).clamp(0.0, s.h);
    final bottom = (f.bottom + f.height * 3.0).clamp(0.0, s.h);
    final personBox = normalizeBox(
      f.left,
      top,
      f.width,
      bottom - top,
      image.width,
      image.height,
      rotationDegrees,
    );

    return Detection(face: faceBox, person: personBox);
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
  void dispose() => _faceDetector.close();
}
