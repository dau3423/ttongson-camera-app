// lib/screens/remote_control_screen.dart
// 리모컨: QR 스캔 → 연결 → 프리뷰·컨트롤. 판단 없음: 표시·명령 전송만.
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../remote/protocol/pairing_payload.dart';
import '../remote/protocol/remote_message.dart';
import '../remote/protocol/remote_session.dart';
import '../remote/transport/remote_client.dart';

enum _Phase { scanning, connecting, connected, failed }

class RemoteControlScreen extends StatefulWidget {
  const RemoteControlScreen({super.key});

  @override
  State<RemoteControlScreen> createState() => _RemoteControlScreenState();
}

class _RemoteControlScreenState extends State<RemoteControlScreen> {
  final RemoteClient _client = RemoteClient();
  final ReconnectPolicy _reconnect = ReconnectPolicy();

  _Phase _phase = _Phase.scanning;
  PairingPayload? _payload;
  WelcomeMessage? _welcome;
  Uint8List? _frame;
  List<String> _hints = const [];
  double _zoom = 1.0;
  int _timerSeconds = 0;
  int _seq = 0;
  StreamSubscription<RemoteMessage>? _msgSub;
  StreamSubscription<List<int>>? _frameSub;
  Timer? _zoomDebounce;

  @override
  void dispose() {
    _zoomDebounce?.cancel();
    _msgSub?.cancel();
    _frameSub?.cancel();
    _client.close();
    super.dispose();
  }

  Future<void> _onScanned(BarcodeCapture capture) async {
    if (_phase != _Phase.scanning) return;
    for (final code in capture.barcodes) {
      final payload = PairingPayload.decode(code.rawValue ?? '');
      if (payload != null) {
        _payload = payload;
        await _connect(payload);
        return;
      }
    }
  }

  Future<void> _connect(PairingPayload payload) async {
    setState(() => _phase = _Phase.connecting);
    try {
      final welcome = await _client.connect(payload);
      if (!mounted) return;
      await _msgSub?.cancel();
      await _frameSub?.cancel();
      _reconnect.reset();
      _msgSub = _client.messages.listen(_onMessage);
      _frameSub = _client.frames.listen((f) {
        if (!mounted) return;
        setState(() => _frame = Uint8List.fromList(f));
      });
      _client.onDisconnected = _onDisconnected;
      setState(() {
        _welcome = welcome;
        _zoom = welcome.zoom;
        _phase = _Phase.connected;
      });
    } on RemoteRejectedException catch (e) {
      _fail(switch (e.reason) {
        'bad-token' => 'QR이 만료됐어요. 촬영 폰에서 QR을 다시 띄워 스캔해 주세요.',
        'busy' => '이미 다른 리모컨이 연결돼 있어요.',
        'version' => '연결이 거부됐어요. 두 폰의 앱을 최신으로 업데이트해 주세요.',
        _ => '연결이 거부됐어요. 두 폰의 앱을 최신으로 업데이트해 주세요.',
      });
    } catch (_) {
      _fail('연결하지 못했어요. 두 폰이 같은 Wi-Fi(또는 핫스팟)에 있는지 확인해 주세요.');
    }
  }

  void _onDisconnected() {
    if (!mounted) return;
    final delay = _reconnect.next();
    final payload = _payload;
    if (delay == null || payload == null) {
      _fail('연결이 끊겼어요.');
      return;
    }
    setState(() => _phase = _Phase.connecting);
    Timer(delay, () {
      if (mounted) _connect(payload);
    });
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() => _phase = _Phase.failed);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _onMessage(RemoteMessage m) {
    if (!mounted) return;
    switch (m) {
      case StateMessage():
        setState(() {
          _hints = m.hints;
          _zoom = m.zoom;
        });
      case ResultMessage():
        if (m.thumbBase64 != null) {
          final thumb = base64Decode(m.thumbBase64!);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              duration: const Duration(seconds: 2),
              content: Row(
                children: [
                  Image.memory(thumb, height: 56),
                  const SizedBox(width: 12),
                  const Text('찰칵! 촬영 폰에 저장했어요'),
                ],
              ),
            ),
          );
        } else if (!m.ok) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(m.error ?? '명령이 실패했어요')));
        }
      default:
        break;
    }
  }

  void _sendShutter() =>
      _client.send(ShutterMessage(seq: ++_seq, timerSeconds: _timerSeconds));

  void _sendSwitchCamera() => _client.send(SwitchCameraMessage(seq: ++_seq));

  void _onZoomChanged(double v) {
    setState(() => _zoom = v);
    _zoomDebounce?.cancel();
    _zoomDebounce = Timer(const Duration(milliseconds: 100), () {
      _client.send(ZoomMessage(seq: ++_seq, zoom: v));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: const Text('리모컨')),
      body: switch (_phase) {
        _Phase.scanning => MobileScanner(onDetect: _onScanned),
        _Phase.connecting => const Center(child: CircularProgressIndicator()),
        _Phase.failed => Center(
          child: ElevatedButton(
            onPressed: () => setState(() => _phase = _Phase.scanning),
            child: const Text('QR 다시 스캔'),
          ),
        ),
        _Phase.connected => _controls(),
      },
    );
  }

  Widget _controls() {
    final welcome = _welcome!;
    return Column(
      children: [
        Expanded(
          child: Center(
            child: AspectRatio(
              aspectRatio: welcome.previewAspectRatio,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (_frame != null)
                    Image.memory(
                      _frame!,
                      gaplessPlayback: true,
                      fit: BoxFit.cover,
                    )
                  else
                    const Center(child: CircularProgressIndicator()),
                  Positioned(
                    top: 12,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          _hints.isEmpty ? '좋아요' : _hints.first,
                          style: TextStyle(
                            color: _hints.isEmpty
                                ? Colors.greenAccent
                                : Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              const Icon(Icons.zoom_out, color: Colors.white54),
              Expanded(
                child: Slider(
                  min: welcome.minZoom,
                  max: welcome.maxZoom,
                  value: _zoom.clamp(welcome.minZoom, welcome.maxZoom),
                  onChanged: _onZoomChanged,
                ),
              ),
              const Icon(Icons.zoom_in, color: Colors.white54),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 32, top: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _timerButton(),
              GestureDetector(
                onTap: _sendShutter,
                child: Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 4),
                    color: Colors.white24,
                  ),
                ),
              ),
              IconButton(
                iconSize: 32,
                color: Colors.white,
                icon: const Icon(Icons.cameraswitch),
                onPressed: _sendSwitchCamera,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _timerButton() {
    const options = [0, 3, 5, 10];
    return TextButton(
      onPressed: () {
        final next =
            options[(options.indexOf(_timerSeconds) + 1) % options.length];
        setState(() => _timerSeconds = next);
      },
      child: Text(
        _timerSeconds == 0 ? '타이머\n끔' : '타이머\n$_timerSeconds초',
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white),
      ),
    );
  }
}
