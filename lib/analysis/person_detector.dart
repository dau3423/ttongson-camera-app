import 'dart:ui' show Size;

import 'package:camera/camera.dart';
import 'package:google_ml_kit/google_ml_kit.dart';

import '../models/person_box.dart';

/// 프레임에서 인물 경계 상자(정규화)를 추출하는 인터페이스.
abstract class PersonDetector {
  Future<PersonBox?> detect(CameraImage image, int rotationDegrees);
  void dispose();
}

/// ML Kit Face Detection 기반 인물 감지 구현.
class MlKitPersonDetector implements PersonDetector {
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(performanceMode: FaceDetectorMode.fast),
  );

  @override
  Future<PersonBox?> detect(CameraImage image, int rotationDegrees) async {
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

    // 얼굴 박스를 인물 근사로 확장(위 0.5×h, 아래 3×h).
    final top = (f.top - f.height * 0.5).clamp(0.0, imgH);
    final bottom = (f.bottom + f.height * 3.0).clamp(0.0, imgH);
    return PersonBox(
      left: (f.left / imgW).clamp(0.0, 1.0),
      top: (top / imgH).clamp(0.0, 1.0),
      width: (f.width / imgW).clamp(0.0, 1.0),
      height: ((bottom - top) / imgH).clamp(0.0, 1.0),
    );
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
