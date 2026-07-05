// lib/screens/camera_screen.dart
import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../analysis/guide_step.dart';
import 'package:sensors_plus/sensors_plus.dart';
import '../camera/camera_service.dart';
import '../analysis/analysis_engine.dart';
import '../analysis/person_detector.dart';
import '../analysis/guide_metrics.dart';
import '../analysis/tilt.dart';
import '../analysis/angle_zoom.dart';
import '../models/shooting_mode.dart';
import '../analysis/object_detector.dart';
import '../camera/mode_store.dart';
import '../camera/gallery_launcher.dart';
import '../overlay/guide_overlay.dart';
import '../overlay/mode_selector.dart';
import '../community/auth_service.dart';
import '../community/screens/sign_in_sheet.dart';
import '../cloud/cloud_advisor.dart';
import '../cloud/composition_advice.dart';
import '../cloud/advice_overlay.dart';
import '../cloud/advice_consent.dart';
import '../cloud/device_id.dart';
import '../cloud/target_alignment.dart';
import '../cloud/target_guide_overlay.dart';
import '../cloud/advice_minimap.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});
  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  final _camera = CameraService();
  late final PersonDetector _faceDetector;
  late final PersonDetector _objectDetector;
  final ModeStore _modeStore = ModeStore();
  ShootingMode _mode = ShootingMode.person;
  late final AnalysisEngine _engine;
  StreamSubscription<AccelerometerEvent>? _accelSub;

  final AuthService _auth = AuthService();
  final CloudAdvisor _advisor = CloudAdvisor();
  final AdviceConsentStore _consent = AdviceConsentStore();
  final DeviceId _deviceId = DeviceId();
  CompositionAdvice? _advice;
  bool _adviceLoading = false;

  SensorSample _sensor = const SensorSample(accelX: 0, accelY: 9.8, accelZ: 0);
  GuideMetrics _metrics = GuideMetrics(
    tilt: const TiltInfo(rollDegrees: 0, isLevel: true, hint: ''),
    angle: const AngleAdvice(pitchDegrees: 0, hint: ''),
  );
  bool _ready = false;
  bool _showGrid = true;
  bool _processing = false;
  bool _flash = false; // 촬영 순간 화면 번쩍임
  String? _initError;

  GuideStep _step = const GuideStep(kind: GuideStepKind.level, message: '');
  GuideStepKind? _prevStepKind;

  static const _stepOrder = <GuideStepKind>[
    GuideStepKind.level,
    GuideStepKind.crop,
    GuideStepKind.distance,
    GuideStepKind.position,
    GuideStepKind.headroom,
    GuideStepKind.angle,
    GuideStepKind.ready,
  ];

  double _zoom = 1.0;
  double _baseZoom = 1.0;

  @override
  void initState() {
    super.initState();
    _faceDetector = MlKitPersonDetector();
    _objectDetector = MlKitObjectDetector();
    _engine = AnalysisEngine(null);
    _accelSub = accelerometerEventStream().listen((e) {
      // sensors_plus는 비중력(specific force, 중력 반대) 부호로 값을 준다.
      // 좌우(x)·앞뒤(z) 기울기 안내가 실제와 반대로 나오므로 부호를 뒤집어 보정한다.
      _sensor = SensorSample(accelX: -e.x, accelY: e.y, accelZ: -e.z);
    });
    _init();
  }

  Future<void> _init() async {
    try {
      await _camera.initialize();
      final savedMode = await _modeStore.load();
      _zoom = _camera.currentZoom;
      if (mounted) setState(() => _mode = savedMode);
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
      final mode = _mode;
      Detection? detection;
      if (mode == ShootingMode.person) {
        detection = await _faceDetector.detect(
          image,
          _camera.sensorOrientation,
        );
      } else {
        // 사물·자연: 객체 검출로 주제 박스 확보(자연은 미검출 시 null).
        detection = await _objectDetector.detect(
          image,
          _camera.sensorOrientation,
        );
      }
      final m = _engine.buildMetrics(
        person: detection?.person,
        face: detection?.face,
        sensor: _sensor,
        mode: mode,
      );
      final step = computeCurrentStep(m);
      _handleStepFeedback(step.kind);
      if (mounted) {
        setState(() {
          _metrics = m;
          _step = step;
        });
      }
    } catch (_) {
      // 프레임 단위 실패는 무시(다음 프레임 계속)
    } finally {
      _processing = false;
    }
  }

  Future<void> _onModeChanged(ShootingMode mode) async {
    setState(() {
      _mode = mode;
      _advice = null; // 이전 추천/시각 가이드 무효화
      // 이전 대상 박스 즉시 제거(다음 프레임까지 잔상 방지).
      _metrics = GuideMetrics(
        tilt: const TiltInfo(rollDegrees: 0, isLevel: true, hint: ''),
        angle: const AngleAdvice(pitchDegrees: 0, hint: ''),
      );
      _prevStepKind = null;
      _step = const GuideStep(kind: GuideStepKind.level, message: '');
    });
    await _modeStore.save(mode);
  }

  /// 단계가 앞으로 전진했을 때만 1회 진동+소리. 후퇴는 무음.
  void _handleStepFeedback(GuideStepKind kind) {
    final prev = _prevStepKind;
    _prevStepKind = kind;
    if (prev == null || kind == prev) return;
    if (_stepOrder.indexOf(kind) <= _stepOrder.indexOf(prev)) return;
    if (kind == GuideStepKind.ready) {
      HapticFeedback.heavyImpact();
      SystemSound.play(SystemSoundType.alert);
    } else {
      HapticFeedback.mediumImpact();
      SystemSound.play(SystemSoundType.click);
    }
  }

  void _onScaleStart(ScaleStartDetails details) {
    _baseZoom = _zoom;
  }

  Future<void> _onScaleUpdate(ScaleUpdateDetails details) async {
    // 두 손가락 핀치가 아니면(scale==1) 무시.
    if (details.pointerCount < 2) return;
    final applied = await _camera.setZoom(_baseZoom * details.scale);
    if (mounted && applied != _zoom) setState(() => _zoom = applied);
  }

  Future<void> _switchCamera() async {
    try {
      await _camera.switchCamera(_onFrame);
      if (mounted) setState(() => _zoom = _camera.currentZoom);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('카메라 전환에 실패했어요')));
      }
    }
  }

  Future<void> _openGallery() async {
    try {
      final ok = await openDeviceGallery();
      if (!ok && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('사진첩을 열 수 없어요')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('사진첩을 열 수 없어요')));
      }
    }
  }

  /// 촬영됐다는 걸 인지하도록 셔터음 + 진동 + 화면 번쩍임.
  void _triggerCaptureFeedback() {
    SystemSound.play(SystemSoundType.click);
    HapticFeedback.mediumImpact();
    setState(() => _flash = true);
    Future.delayed(const Duration(milliseconds: 60), () {
      if (mounted) setState(() => _flash = false);
    });
  }

  Future<void> _capture() async {
    _triggerCaptureFeedback();
    try {
      final saved = await _camera.captureAndSave();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(saved ? '사진첩에 저장했어요' : '저장 실패 — 사진첩 권한을 확인해 주세요'),
          ),
        );
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

    if (!_auth.isSignedIn) {
      final signedIn = await showSignInSheet(context, _auth);
      if (!signedIn) return;
    }

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
      final advice = await _advisor.suggest(
        framePath,
        _metrics,
        deviceId,
        _mode,
      );
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
    }
  }

  @override
  void dispose() {
    _accelSub?.cancel();
    _camera.dispose();
    _faceDetector.dispose();
    _objectDetector.dispose();
    super.dispose();
  }

  /// 센서 전체 프레임을 왜곡·크롭 없이 그대로 보여준다(contain).
  /// 화면 비율과 센서 비율이 달라 위아래(또는 좌우)에 검은 여백이 생길 수 있으나,
  /// 프리뷰에 보이는 영역이 저장 사진과 정확히 일치한다(WYSIWYG).
  /// [child]는 프리뷰 위에 겹칠 좌표 기반 오버레이(격자·인물 박스 등)이며,
  /// 프리뷰와 같은 박스를 공유하므로 정규화 좌표가 정확히 정렬된다.
  Widget _buildPreviewArea({required Widget child}) {
    final controller = _camera.controller;
    final size = MediaQuery.of(context).size;
    final isPortrait = size.height >= size.width;
    // controller.value.aspectRatio는 가로 기준(폭/높이). 세로 화면에선 역수.
    final aspect = isPortrait
        ? 1 / controller.value.aspectRatio
        : controller.value.aspectRatio;
    return Center(
      child: AspectRatio(aspectRatio: aspect, child: child),
    );
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
    final person = _metrics.person;
    final targetBox = _advice?.targetBox;
    final alignment = (targetBox != null && person != null)
        ? computeAlignment(person, targetBox)
        : null;
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onScaleStart: _onScaleStart,
        onScaleUpdate: _onScaleUpdate,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _buildPreviewArea(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CameraPreview(_camera.controller),
                  GuideOverlay(
                    metrics: _metrics,
                    step: _step,
                    showGrid: _showGrid,
                  ),
                  if (targetBox != null)
                    TargetGuideOverlay(
                      target: targetBox,
                      current: person,
                      alignment: alignment,
                    ),
                ],
              ),
            ),
            if (targetBox != null)
              Positioned(
                top: 100,
                right: 12,
                child: AdviceMinimap(
                  target: targetBox,
                  current: person,
                  alignment: alignment,
                ),
              ),
            if (_step.kind != GuideStepKind.ready && _step.message.isNotEmpty)
              Positioned(
                top: 48,
                left: 16,
                right: 16,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 11,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xD9000000),
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black38,
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      _step.message,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            if (_step.kind == GuideStepKind.ready)
              Positioned(
                top: 44,
                left: 0,
                right: 0,
                child: IgnorePointer(
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 22,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xF22E7D32),
                        borderRadius: BorderRadius.circular(26),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black38,
                            blurRadius: 10,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.check_circle,
                            color: Colors.white,
                            size: 22,
                          ),
                          SizedBox(width: 8),
                          Text(
                            '찍으세요!',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            if (_camera.canSwitch)
              Positioned(
                top: 44,
                right: 8,
                child: IconButton(
                  icon: const Icon(
                    Icons.cameraswitch,
                    color: Colors.white,
                    size: 30,
                  ),
                  onPressed: _switchCamera,
                ),
              ),
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ModeSelector(current: _mode, onChanged: _onModeChanged),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      // 좌측: 사진첩 바로가기
                      Expanded(
                        child: Center(
                          child: IconButton(
                            icon: const Icon(
                              Icons.photo_library,
                              color: Colors.white,
                              size: 32,
                            ),
                            onPressed: _openGallery,
                          ),
                        ),
                      ),
                      // 중앙: 촬영 버튼(고정). ready('찍으세요!')면 초록으로 발광.
                      GestureDetector(
                        onTap: _capture,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 76,
                          height: 76,
                          decoration: BoxDecoration(
                            color: _step.kind == GuideStepKind.ready
                                ? const Color(0xFF69F0AE)
                                : Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: _step.kind == GuideStepKind.ready
                                ? const [
                                    BoxShadow(
                                      color: Color(0xAA69F0AE),
                                      blurRadius: 20,
                                      spreadRadius: 4,
                                    ),
                                  ]
                                : null,
                          ),
                        ),
                      ),
                      // 우측: AI 추천 + 격자 토글(격자를 맨 오른쪽)
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              icon: const Icon(
                                Icons.auto_awesome,
                                color: Colors.white,
                                size: 32,
                              ),
                              onPressed: _requestAdvice,
                            ),
                            IconButton(
                              icon: Icon(
                                _showGrid ? Icons.grid_on : Icons.grid_off,
                                color: Colors.white,
                                size: 32,
                              ),
                              onPressed: () =>
                                  setState(() => _showGrid = !_showGrid),
                            ),
                          ],
                        ),
                      ),
                    ],
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
            if (_camera.maxZoom > _camera.minZoom)
              Positioned(
                bottom: 160,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      '${_zoom.toStringAsFixed(1)}x',
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ),
                ),
              ),
            // 촬영 순간 화면 번쩍임(플래시). 나타났다 짧게 사라짐.
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedOpacity(
                  opacity: _flash ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 180),
                  child: const ColoredBox(color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
