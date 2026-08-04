// lib/camera/camera_service.dart
import 'dart:io' show Platform, File;
import 'dart:isolate';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:gallery_saver_plus/gallery_saver.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

/// 카메라 프리뷰/프레임 스트림/촬영·저장을 캡슐화한다.
class CameraService {
  CameraController? _controller;
  bool _streaming = false;
  List<CameraDescription> _cameras = const [];
  CameraLensDirection _lens = CameraLensDirection.back;

  double _minZoom = 1.0;
  double _maxZoom = 1.0;
  double _currentZoom = 1.0;

  CameraLensDirection get lensDirection => _lens;
  bool get isInitialized => _controller?.value.isInitialized ?? false;
  bool get isFront => _lens == CameraLensDirection.front;
  bool get canSwitch =>
      _cameras.any((c) => c.lensDirection == CameraLensDirection.front) &&
      _cameras.any((c) => c.lensDirection == CameraLensDirection.back);

  CameraController get controller {
    final c = _controller;
    if (c == null) {
      throw StateError('CameraService.initialize()를 먼저 호출하세요');
    }
    return c;
  }

  int get sensorOrientation => _controller?.description.sensorOrientation ?? 0;

  double get minZoom => _minZoom;
  double get maxZoom => _maxZoom;
  double get currentZoom => _currentZoom;

  Future<void> initialize() async {
    _cameras = await availableCameras();
    await _open(CameraLensDirection.back);
  }

  /// 지정한 렌즈 방향의 카메라를 열어 컨트롤러를 준비한다.
  Future<void> _open(CameraLensDirection lens) async {
    final desc = _cameras.firstWhere(
      (c) => c.lensDirection == lens,
      orElse: () => _cameras.first,
    );
    final ctrl = CameraController(
      desc,
      ResolutionPreset.high,
      enableAudio: false,
      // ML Kit이 처리 가능한 포맷으로 프레임을 받는다.
      // Android는 NV21(기본 YUV_420_888은 ML Kit이 거부), iOS는 BGRA8888.
      imageFormatGroup: Platform.isAndroid
          ? ImageFormatGroup.nv21
          : ImageFormatGroup.bgra8888,
    );
    await ctrl.initialize();
    _minZoom = await ctrl.getMinZoomLevel();
    _maxZoom = await ctrl.getMaxZoomLevel();
    _currentZoom = _minZoom;
    _controller = ctrl;
    _lens = desc.lensDirection;
  }

  /// 전/후면 카메라를 전환한다. 반대 렌즈가 없으면 false.
  /// 스트리밍 중이었다면 [onFrame]으로 재개한다.
  Future<bool> switchCamera(void Function(CameraImage) onFrame) async {
    final target = _lens == CameraLensDirection.back
        ? CameraLensDirection.front
        : CameraLensDirection.back;
    if (!_cameras.any((c) => c.lensDirection == target)) return false;
    final previous = _lens;
    final wasStreaming = _streaming;
    await stopStream();
    await _controller?.dispose();
    _controller = null;
    try {
      await _open(target);
    } catch (e) {
      // 대상 렌즈 열기 실패 시 원래 렌즈로 복구해 컨트롤러를 유효하게 유지.
      await _open(previous);
      if (wasStreaming) startStream(onFrame);
      rethrow;
    }
    if (wasStreaming) startStream(onFrame);
    return true;
  }

  /// 줌 배율을 지원 범위로 클램프해 적용하고, 실제 적용된 배율을 반환한다.
  Future<double> setZoom(double zoom) async {
    final clamped = zoom.clamp(_minZoom, _maxZoom);
    await controller.setZoomLevel(clamped);
    _currentZoom = clamped;
    return clamped;
  }

  void startStream(void Function(CameraImage) onFrame) {
    if (_streaming) return;
    _streaming = true;
    controller.startImageStream(onFrame);
  }

  Future<void> stopStream() async {
    if (!_streaming) return;
    _streaming = false;
    await controller.stopImageStream();
  }

  /// 프리뷰 정지(화면에 보이지 않을 때 호출해 발열·전력을 줄인다). 안전/가역.
  Future<void> pausePreview() async {
    final c = _controller;
    if (c != null && c.value.isInitialized && !c.value.isPreviewPaused) {
      await c.pausePreview();
    }
  }

  Future<void> resumePreview() async {
    final c = _controller;
    if (c != null && c.value.isInitialized && c.value.isPreviewPaused) {
      await c.resumePreview();
    }
  }

  /// 촬영 후 사진첩(갤러리)에 저장한다. 저장 성공 여부를 반환.
  /// 프리뷰가 센서 전체 프레임을 그대로(contain) 보여주므로, 저장 사진도
  /// 크롭 없이 그대로 저장하면 프리뷰와 일치한다(WYSIWYG).
  Future<bool> captureAndSave() async {
    final path = await capturePhoto();
    return saveToGallery(path);
  }

  /// 사진을 촬영해 임시 파일 경로를 반환(갤러리 저장 안 함). 후처리(배경흐림 등)용.
  /// 스트림은 중단하며, 재개는 호출측 책임.
  /// 전면(셀카)은 프리뷰가 거울처럼 좌우 반전돼 보이는데 플러그인 촬영본은
  /// 반전되지 않아 프리뷰와 어긋난다. WYSIWYG를 위해 좌우로 뒤집어 맞춘다.
  Future<String> capturePhoto() async {
    if (_streaming) await stopStream();
    final file = await controller.takePicture();
    if (isFront) return _mirrorHorizontal(file.path);
    return file.path;
  }

  /// 이미지를 좌우 반전한 새 JPEG 임시 파일 경로를 반환한다(픽셀 처리는 아이솔레이트).
  /// 디코드 실패 시 원본 경로를 그대로 반환한다.
  Future<String> _mirrorHorizontal(String path) async {
    final bytes = await File(path).readAsBytes();
    final jpeg = await Isolate.run<Uint8List?>(() {
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return null;
      // EXIF 방향을 반영한 뒤 좌우 반전(방향 태그와 반전이 겹치지 않게).
      final baked = img.bakeOrientation(decoded);
      final mirrored = img.flipHorizontal(baked);
      return img.encodeJpg(mirrored, quality: 95);
    });
    if (jpeg == null) return path;
    final dir = await getTemporaryDirectory();
    final out = File(
      '${dir.path}/selfie_${DateTime.now().microsecondsSinceEpoch}.jpg',
    );
    await out.writeAsBytes(jpeg);
    return out.path;
  }

  /// 주어진 경로의 이미지를 사진첩에 저장. 성공 여부 반환.
  Future<bool> saveToGallery(String path) async {
    final saved = await GallerySaver.saveImage(path);
    return saved ?? false;
  }

  /// 구도 추천용으로 현재 프레임을 촬영해 임시 파일 경로를 반환한다.
  /// 갤러리에 저장하지 않는다. 호출 후 스트림 재개는 호출측 책임.
  Future<String> captureFrameForAdvice() async {
    if (_streaming) await stopStream();
    final file = await controller.takePicture();
    return file.path;
  }

  Future<void> dispose() async {
    await stopStream();
    await _controller?.dispose();
    _controller = null;
  }
}
