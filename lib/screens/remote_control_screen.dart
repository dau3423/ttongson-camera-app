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

  // I1: 셔터 in-flight 추적 — 전송 후 결과 수신 전까지 버튼 비활성화.
  int? _pendingShutterSeq;

  // I1: 로컬 카운트다운 타이머 및 현재 표시 숫자.
  Timer? _countdownTimer;
  int? _countdownValue;

  // I2: 수신 워치독 — 마지막 수신 시각 추적.
  DateTime _lastRxAt = DateTime.fromMillisecondsSinceEpoch(0);
  Timer? _watchdogTimer;

  // I3: 재접속 딜레이 타이머 필드로 관리.
  Timer? _reconnectTimer;

  @override
  void dispose() {
    _zoomDebounce?.cancel();
    _countdownTimer?.cancel();
    _watchdogTimer?.cancel();
    _reconnectTimer?.cancel();
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

  Future<void> _connect(
    PairingPayload payload, {
    bool viaReconnect = false,
  }) async {
    setState(() => _phase = _Phase.connecting);
    try {
      final welcome = await _client.connect(payload);
      if (!mounted) return;
      await _msgSub?.cancel();
      await _frameSub?.cancel();
      _reconnect.reset();
      _lastRxAt = DateTime.now();
      _msgSub = _client.messages.listen(_onMessage);
      _frameSub = _client.frames.listen((f) {
        if (!mounted) return;
        _lastRxAt = DateTime.now(); // I2: 프레임 수신 시각 갱신
        setState(() => _frame = Uint8List.fromList(f));
      });
      _client.onDisconnected = _onDisconnected;
      _startWatchdog(); // I2: 연결 직후 워치독 시작
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
      // I3(c): viaReconnect이고 정책이 소진되지 않았으면 재접속 경로로 처리.
      // _onDisconnected 대신 _scheduleReconnect을 직접 호출해 connecting 상태 가드를 우회.
      if (viaReconnect) {
        _scheduleReconnect();
      } else {
        _fail('연결하지 못했어요. 두 폰이 같은 Wi-Fi(또는 핫스팟)에 있는지 확인해 주세요.');
      }
    }
  }

  // I2: 수신 워치독 — 5초 침묵이면 연결 끊김으로 처리.
  void _startWatchdog() {
    _watchdogTimer?.cancel();
    _watchdogTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_phase != _Phase.connected) return;
      if (DateTime.now().difference(_lastRxAt).inSeconds > 5) {
        _client.close();
        _onDisconnected();
      }
    });
  }

  // I3: 재접속 스케줄링 로직 분리 — _onDisconnected와 _connect catch 양쪽에서 호출.
  void _scheduleReconnect() {
    if (!mounted) return;
    _watchdogTimer?.cancel();
    _cancelCountdown();
    setState(() {
      _pendingShutterSeq = null; // I1: 셔터 in-flight 초기화
    });
    final delay = _reconnect.next();
    final payload = _payload;
    if (delay == null || payload == null) {
      _fail('연결이 끊겼어요.');
      return;
    }
    setState(() => _phase = _Phase.connecting);
    // I3(a): 기존 재접속 타이머 취소 후 새로 예약.
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, () {
      if (mounted) _connect(payload, viaReconnect: true);
    });
  }

  void _onDisconnected() {
    // I3(b): 이미 connecting 상태면 중복 진입 방지.
    if (_phase == _Phase.connecting) return;
    if (!mounted) return;
    _scheduleReconnect();
  }

  void _fail(String message) {
    if (!mounted) return;
    _watchdogTimer?.cancel();
    setState(() => _phase = _Phase.failed);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _onMessage(RemoteMessage m) {
    if (!mounted) return;
    _lastRxAt = DateTime.now(); // I2: 메시지 수신 시각 갱신
    switch (m) {
      case StateMessage():
        setState(() {
          _hints = m.hints;
          _zoom = m.zoom;
        });
      case ResultMessage():
        // I1: 셔터 결과 수신 — seq 일치 시 in-flight 해제 + 카운트다운 정리.
        if (_pendingShutterSeq == m.seq) {
          _cancelCountdown();
          setState(() => _pendingShutterSeq = null);
        }
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

  // I1: 카운트다운 취소 헬퍼.
  void _cancelCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
    if (mounted) setState(() => _countdownValue = null);
  }

  void _sendShutter() {
    final seq = ++_seq;
    _client.send(ShutterMessage(seq: seq, timerSeconds: _timerSeconds));
    setState(() => _pendingShutterSeq = seq);

    // I1(b): timerSeconds > 0이면 로컬 카운트다운 오버레이 표시.
    if (_timerSeconds > 0) {
      _countdownTimer?.cancel();
      setState(() => _countdownValue = _timerSeconds);
      var remaining = _timerSeconds;
      _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
        remaining--;
        if (!mounted || remaining <= 0) {
          t.cancel();
          _countdownTimer = null;
          if (mounted) setState(() => _countdownValue = null);
        } else {
          setState(() => _countdownValue = remaining);
        }
      });
    }
  }

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
        _Phase.scanning => _scanner(),
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

  /// QR 스캔 단계 UI. 스캔 프레임·안내 문구로 촬영 화면과 혼동되지 않게 한다.
  Widget _scanner() {
    const frameSize = 260.0;
    return Stack(
      fit: StackFit.expand,
      children: [
        MobileScanner(onDetect: _onScanned),
        // 스캔 프레임 밖을 어둡게 눌러 카메라 화면이 아님을 드러낸다.
        ColorFiltered(
          colorFilter: const ColorFilter.mode(Colors.black54, BlendMode.srcOut),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Container(
                decoration: const BoxDecoration(
                  color: Colors.black,
                  backgroundBlendMode: BlendMode.dstOut,
                ),
              ),
              Center(
                child: Container(
                  width: frameSize,
                  height: frameSize,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
              ),
            ],
          ),
        ),
        Center(
          child: Container(
            width: frameSize,
            height: frameSize,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white, width: 3),
              borderRadius: BorderRadius.circular(24),
            ),
          ),
        ),
        Positioned(
          top: 48,
          left: 24,
          right: 24,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  '촬영 폰에 표시된 QR 코드를 스캔하세요',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '촬영 폰: 카메라 화면 상단 리모컨 아이콘 → 이 폰으로 촬영하기',
                style: TextStyle(color: Colors.white70, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _controls() {
    final welcome = _welcome!;
    final shutterEnabled = _pendingShutterSeq == null; // I1: in-flight이면 비활성
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
                  // I1(b): 로컬 카운트다운 오버레이 (큰 숫자, 가운데).
                  if (_countdownValue != null)
                    Center(
                      child: Text(
                        '$_countdownValue',
                        style: const TextStyle(
                          fontSize: 96,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          shadows: [
                            Shadow(blurRadius: 24, color: Colors.black),
                          ],
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
              // I1: shutterEnabled가 false면 비활성(onTap null).
              GestureDetector(
                onTap: shutterEnabled ? _sendShutter : null,
                child: Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: shutterEnabled ? Colors.white : Colors.white38,
                      width: 4,
                    ),
                    color: shutterEnabled ? Colors.white24 : Colors.white10,
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
