// lib/camera/camera_service.dart
import 'package:camera/camera.dart';
import 'package:gallery_saver_plus/gallery_saver.dart';

/// 카메라 프리뷰/프레임 스트림/촬영·저장을 캡슐화한다.
class CameraService {
  CameraController? _controller;
  bool _streaming = false;

  CameraController get controller {
    final c = _controller;
    if (c == null) {
      throw StateError('CameraService.initialize()를 먼저 호출하세요');
    }
    return c;
  }

  int get sensorOrientation => _controller?.description.sensorOrientation ?? 0;

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
    _controller = ctrl;
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

  /// 촬영 후 갤러리에 저장하고 파일 경로를 반환.
  Future<String> captureAndSave() async {
    final wasStreaming = _streaming;
    if (wasStreaming) await stopStream();
    final file = await controller.takePicture();
    await GallerySaver.saveImage(file.path);
    return file.path;
  }

  Future<void> dispose() async {
    await stopStream();
    await _controller?.dispose();
    _controller = null;
  }
}
