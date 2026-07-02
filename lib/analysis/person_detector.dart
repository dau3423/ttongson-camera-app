import 'dart:ui' show Size;

import 'package:camera/camera.dart';
import 'package:google_ml_kit/google_ml_kit.dart';

import '../models/person_box.dart';

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
    final imgW = image.width.toDouble();
    final imgH = image.height.toDouble();

    // 원시 얼굴 박스(정규화, 확장 없음) — 잘림 감지용.
    final faceBox = PersonBox(
      left: (f.left / imgW).clamp(0.0, 1.0),
      top: (f.top / imgH).clamp(0.0, 1.0),
      width: (f.width / imgW).clamp(0.0, 1.0),
      height: (f.height / imgH).clamp(0.0, 1.0),
    );

    // 얼굴 박스를 인물 근사로 확장(위 0.5×h, 아래 3×h) — 구도/여백/줌용.
    final top = (f.top - f.height * 0.5).clamp(0.0, imgH);
    final bottom = (f.bottom + f.height * 3.0).clamp(0.0, imgH);
    final personBox = PersonBox(
      left: (f.left / imgW).clamp(0.0, 1.0),
      top: (top / imgH).clamp(0.0, 1.0),
      width: (f.width / imgW).clamp(0.0, 1.0),
      height: ((bottom - top) / imgH).clamp(0.0, 1.0),
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
