// lib/screens/camera_screen.dart
import 'dart:async';
import 'dart:math' as math;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import '../camera/camera_service.dart';
import '../analysis/analysis_engine.dart';
import '../analysis/person_detector.dart';
import '../analysis/guide_metrics.dart';
import '../analysis/tilt.dart';
import '../analysis/angle_zoom.dart';
import '../overlay/guide_overlay.dart';
import '../cloud/cloud_advisor.dart';
import '../cloud/composition_advice.dart';
import '../cloud/advice_overlay.dart';
import '../cloud/advice_consent.dart';
import '../cloud/device_id.dart';
import '../cloud/stillness_detector.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});
  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  final _camera = CameraService();
  late final PersonDetector _detector;
  late final AnalysisEngine _engine;
  StreamSubscription<AccelerometerEvent>? _accelSub;

  final CloudAdvisor _advisor = CloudAdvisor();
  final AdviceConsentStore _consent = AdviceConsentStore();
  final DeviceId _deviceId = DeviceId();
  CompositionAdvice? _advice;
  bool _adviceLoading = false;

  final StillnessDetector _stillness = StillnessDetector();
  int _lastAdviceMs = 0;
  static const int _adviceCooldownMs = 10000;

  SensorSample _sensor = const SensorSample(accelX: 0, accelY: 9.8, accelZ: 0);
  GuideMetrics _metrics = GuideMetrics(
    tilt: const TiltInfo(rollDegrees: 0, isLevel: true, hint: ''),
    angle: const AngleAdvice(pitchDegrees: 0, hint: ''),
  );
  bool _ready = false;
  bool _showGrid = true;
  bool _processing = false;
  String? _initError;

  @override
  void initState() {
    super.initState();
    _detector = MlKitPersonDetector();
    _engine = AnalysisEngine(_detector);
    _accelSub = accelerometerEventStream().listen((e) {
      _sensor = SensorSample(accelX: e.x, accelY: e.y, accelZ: e.z);
      final mag = math.sqrt(e.x * e.x + e.y * e.y + e.z * e.z);
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      if (_stillness.update(mag, nowMs)) {
        _maybeAutoAdvise(nowMs);
      }
    });
    _init();
  }

  Future<void> _init() async {
    try {
      await _camera.initialize();
      _camera.startStream(_onFrame);
      if (mounted) setState(() => _ready = true);
    } catch (e) {
      if (mounted) setState(() => _initError = e.toString());
    }
  }

  Future<void> _onFrame(CameraImage image) async {
    if (_processing) return; // 스로틀: 재진입 방지
    _processing = true;
    try {
      final detection = await _detector.detect(
        image,
        _camera.sensorOrientation,
      );
      final m = _engine.buildMetrics(
        person: detection?.person,
        face: detection?.face,
        sensor: _sensor,
      );
      if (mounted) setState(() => _metrics = m);
    } catch (_) {
      // 프레임 단위 실패는 무시(다음 프레임 계속)
    } finally {
      _processing = false;
    }
  }

  Future<void> _capture() async {
    try {
      final path = await _camera.captureAndSave();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('저장됨: $path')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('저장 실패: $e')));
      }
    } finally {
      if (mounted) {
        _camera.startStream(_onFrame);
      }
    }
  }

  Future<void> _requestAdvice() async {
    if (_adviceLoading) return;

    // 최초 1회 동의
    if (!await _consent.hasConsented()) {
      if (!mounted) return;
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('구도 추천 안내'),
          content: const Text(
            '구도 추천 시 현재 화면 1장을 분석 서버로 전송합니다. '
            '이미지는 저장하지 않습니다.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('동의'),
            ),
          ],
        ),
      );
      if (ok != true) return;
      await _consent.setConsented();
    }

    if (!mounted) return;
    setState(() => _adviceLoading = true);
    try {
      final deviceId = await _deviceId.get();
      final framePath = await _camera.captureFrameForAdvice();
      final advice = await _advisor.suggest(framePath, _metrics, deviceId);
      if (mounted) setState(() => _advice = advice);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('추천을 못 받았어요. 다시 시도해 주세요.')),
        );
      }
    } finally {
      if (mounted) setState(() => _adviceLoading = false);
      if (mounted) _camera.startStream(_onFrame);
      _lastAdviceMs = DateTime.now().millisecondsSinceEpoch;
    }
  }

  Future<void> _maybeAutoAdvise(int nowMs) async {
    if (_adviceLoading || _advice != null) return;
    if (nowMs - _lastAdviceMs < _adviceCooldownMs) return;
    if (!await _consent.hasConsented()) return; // 동의 전에는 자동 트리거 안 함
    _lastAdviceMs = nowMs;
    await _requestAdvice();
  }

  @override
  void dispose() {
    _accelSub?.cancel();
    _camera.dispose();
    _detector.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_initError != null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _initError!,
                style: const TextStyle(color: Colors.white),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _initError = null;
                    _ready = false;
                  });
                  _init();
                },
                child: const Text('다시 시도'),
              ),
            ],
          ),
        ),
      );
    }
    if (!_ready) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final hints = _metrics.activeHints;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          CameraPreview(_camera.controller),
          GuideOverlay(metrics: _metrics, showGrid: _showGrid),
          Positioned(
            top: 48,
            left: 16,
            right: 16,
            child: Column(
              children: [
                for (final h in hints)
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 2),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    color: Colors.black54,
                    child: Text(h, style: const TextStyle(color: Colors.white)),
                  ),
              ],
            ),
          ),
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  icon: Icon(
                    _showGrid ? Icons.grid_on : Icons.grid_off,
                    color: Colors.white,
                    size: 32,
                  ),
                  onPressed: () => setState(() => _showGrid = !_showGrid),
                ),
                GestureDetector(
                  onTap: _capture,
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.auto_awesome,
                    color: Colors.white,
                    size: 32,
                  ),
                  onPressed: _requestAdvice,
                ),
              ],
            ),
          ),
          if (_advice != null)
            AdviceOverlay(
              advice: _advice!,
              onClose: () => setState(() => _advice = null),
            ),
          if (_adviceLoading)
            const Positioned.fill(
              child: ColoredBox(
                color: Colors.black38,
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
    );
  }
}
