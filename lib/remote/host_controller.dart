// lib/remote/host_controller.dart
// 카메라 화면과 RemoteServer를 잇는다. 판단 없음: 인코딩·전달만.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:camera/camera.dart';

import '../cloud/advice_image.dart';
import 'frame_encoder.dart';
import 'protocol/remote_message.dart';
import 'transport/remote_server.dart';

class HostController {
  HostController({
    required this.server,
    required this.onShutter,
    required this.onZoom,
    required this.onSwitchCamera,
  }) {
    server.onCommand = _handleCommand;
  }

  final RemoteServer server;

  /// 타이머 카운트다운 → 촬영 → 갤러리 저장까지 마친 뒤 사진 파일 경로 반환.
  /// 실패 시 null.
  final Future<String?> Function(int timerSeconds) onShutter;

  /// 줌 적용 후 실제 배율 반환.
  final Future<double> Function(double zoom) onZoom;

  /// 전/후면 전환. 성공 여부 반환.
  final Future<bool> Function() onSwitchCamera;

  bool _encoding = false;
  DateTime _lastFrameAt = DateTime.fromMillisecondsSinceEpoch(0);

  /// 프리뷰 프레임 전송. 인코딩 중이거나 80ms 이내 재호출이면 스킵(스로틀).
  void pushCameraImage(
    CameraImage image, {
    required int rotationDegrees,
    required bool mirror,
  }) {
    if (!server.hasClient || _encoding) return;
    final now = DateTime.now();
    if (now.difference(_lastFrameAt).inMilliseconds < 80) return;
    _lastFrameAt = now;
    _encoding = true;

    final isBgra = image.format.group == ImageFormatGroup.bgra8888;
    final width = image.width;
    final height = image.height;
    final bytes = Uint8List.fromList(image.planes[0].bytes);
    final bytesPerRow = image.planes[0].bytesPerRow;

    Isolate.run<Uint8List>(() {
          final im = isBgra
              ? imageFromBgra8888(
                  width: width,
                  height: height,
                  bytes: bytes,
                  bytesPerRow: bytesPerRow,
                )
              : imageFromNv21(width: width, height: height, nv21: bytes);
          return encodePreviewJpeg(
            im,
            rotationDegrees: rotationDegrees,
            mirror: mirror,
          );
        })
        .then((jpeg) {
          server.sendFrame(jpeg);
        })
        .catchError((_) {})
        .whenComplete(() {
          _encoding = false;
        });
  }

  void pushState(StateMessage state) => server.sendMessage(state);

  Future<void> _handleCommand(RemoteMessage m) async {
    switch (m) {
      case ShutterMessage():
        String? path;
        try {
          path = await onShutter(m.timerSeconds);
        } catch (_) {
          path = null;
        }
        if (path == null) {
          server.sendMessage(
            ResultMessage(seq: m.seq, ok: false, error: '촬영 실패'),
          );
          return;
        }
        server.sendMessage(
          ResultMessage(
            seq: m.seq,
            ok: true,
            thumbBase64: await _thumbBase64(path),
          ),
        );
      case ZoomMessage():
        try {
          await onZoom(m.zoom);
          server.sendMessage(ResultMessage(seq: m.seq, ok: true));
        } catch (_) {
          server.sendMessage(
            ResultMessage(seq: m.seq, ok: false, error: '줌 실패'),
          );
        }
      case SwitchCameraMessage():
        try {
          final ok = await onSwitchCamera();
          server.sendMessage(ResultMessage(seq: m.seq, ok: ok));
        } catch (_) {
          server.sendMessage(
            ResultMessage(seq: m.seq, ok: false, error: '전환 실패'),
          );
        }
      default:
        break;
    }
  }

  Future<String?> _thumbBase64(String path) async {
    try {
      final thumbPath = await encodeDownsizedJpeg(
        path,
        maxLongEdge: 320,
        quality: 60,
      );
      return base64Encode(await File(thumbPath).readAsBytes());
    } catch (_) {
      return null;
    }
  }

  Future<void> dispose() async {
    server.onCommand = null;
    await server.stop();
  }
}
