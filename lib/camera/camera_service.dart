// lib/camera/camera_service.dart
import 'package:camera/camera.dart';
import 'package:gallery_saver_plus/gallery_saver.dart';

/// 카메라 프리뷰/프레임 스트림/촬영·저장을 캡슐화한다.
class CameraService {
  CameraController? _controller;
  bool _streaming = false;

  double _minZoom = 1.0;
  double _maxZoom = 1.0;
  double _currentZoom = 1.0;

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
    final cameras = await availableCameras();
    final back = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );
    final ctrl = CameraController(
      back,
      ResolutionPreset.high,
      enableAudio: false,
    );
    await ctrl.initialize();
    _minZoom = await ctrl.getMinZoomLevel();
    _maxZoom = await ctrl.getMaxZoomLevel();
    _currentZoom = _minZoom;
    _controller = ctrl;
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

  /// 촬영 후 사진첩(갤러리)에 저장한다. 저장 성공 여부를 반환.
  /// 프리뷰가 센서 전체 프레임을 그대로(contain) 보여주므로, 저장 사진도
  /// 크롭 없이 그대로 저장하면 프리뷰와 일치한다(WYSIWYG).
  Future<bool> captureAndSave() async {
    final wasStreaming = _streaming;
    if (wasStreaming) await stopStream();
    final file = await controller.takePicture();
    final saved = await GallerySaver.saveImage(file.path);
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
