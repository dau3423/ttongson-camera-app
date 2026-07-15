// lib/camera/camera_service.dart
import 'dart:io' show Platform;
import 'package:camera/camera.dart';
import 'package:gallery_saver_plus/gallery_saver.dart';

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
