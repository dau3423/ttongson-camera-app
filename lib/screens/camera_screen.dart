// lib/screens/camera_screen.dart
import 'dart:async';
import 'dart:io' show File;
import 'dart:typed_data';
import 'dart:ui' as ui;
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
import '../camera/person_segmenter.dart';
import '../camera/portrait_blur.dart';
import '../overlay/guide_overlay.dart';
import '../overlay/mode_selector.dart';
import '../theme/app_colors.dart';
import '../community/auth_service.dart';
import '../community/screens/feed_screen.dart';
import '../community/screens/sign_in_sheet.dart';
import '../cloud/cloud_advisor.dart';
import '../cloud/composition_advice.dart';
import '../cloud/advice_overlay.dart';
import '../cloud/advice_consent.dart';
import '../cloud/device_id.dart';
import '../cloud/target_alignment.dart';
import '../cloud/target_guide_overlay.dart';
import '../cloud/advice_minimap.dart';
import '../poses/pose.dart';
import '../poses/pose_catalog.dart';
import '../poses/pose_advisor.dart';
import '../overlay/pose_overlay.dart';
import '../poses/pose_picker.dart';
import 'capture_result_screen.dart';

/// 카메라 화면 위로 다른 화면(피드·로그인 등)이 뜨고 닫히는 걸 감지하는 옵서버.
/// main.dart의 MaterialApp.navigatorObservers에 등록한다.
final RouteObserver<PageRoute<dynamic>> routeObserver =
    RouteObserver<PageRoute<dynamic>>();

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});
  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with RouteAware, WidgetsBindingObserver {
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

  List<Pose> _poses = const [];
  String? _poseAsset; // 선택된 포즈 실루엣 asset (null=꺼짐)
  final _poseAdvisor = PoseAdvisor();

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

  // 발열 저감: 분석(ML 추론)을 매 프레임이 아니라 최소 간격으로만 수행.
  // 구도 가이드는 초당 ~5회면 충분하고, ML 추론 부하를 크게 줄인다.
  static const _minAnalysisGap = Duration(milliseconds: 200);
  DateTime _lastAnalysis = DateTime.fromMillisecondsSinceEpoch(0);

  // 포트레이트 세그멘테이션은 검출보다 더 드물게 갱신(추가 부하 저감).
  static const _minSegGap = Duration(milliseconds: 400);
  DateTime _lastSeg = DateTime.fromMillisecondsSinceEpoch(0);

  // 인물 배경흐림(포트레이트).
  bool _portrait = false;
  final PersonSegmenter _segmenter = PersonSegmenter();
  ui.Image? _maskImage; // 프리뷰용 배경 알파 마스크(세운 좌표계)
  bool _segmenting = false;

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
    WidgetsBinding.instance.addObserver(this);
    _faceDetector = MlKitPersonDetector();
    _objectDetector = MlKitObjectDetector();
    _engine = AnalysisEngine(null);
    _accelSub = accelerometerEventStream().listen((e) {
      // sensors_plus는 비중력(specific force, 중력 반대) 부호로 값을 준다.
      // 좌우(x)·앞뒤(z) 기울기 안내가 실제와 반대로 나오므로 부호를 뒤집어 보정한다.
      _sensor = SensorSample(accelX: -e.x, accelY: e.y, accelZ: -e.z);
    });
    _init();
    PoseCatalog.load().then((p) {
      if (mounted) setState(() => _poses = p);
    });
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
    if (_processing) return; // 재진입 방지
    // 프레임레이트 스로틀(발열 저감): 최소 간격 이내면 이 프레임은 건너뛴다.
    final now = DateTime.now();
    if (now.difference(_lastAnalysis) < _minAnalysisGap) return;
    _lastAnalysis = now;
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
      // 인물 모드 + 포트레이트 ON일 때만, 그리고 검출보다 드물게 마스크를 갱신.
      if (_portrait &&
          mode == ShootingMode.person &&
          now.difference(_lastSeg) >= _minSegGap) {
        _lastSeg = now;
        await _updateMask(image);
      }
    } catch (_) {
      // 프레임 단위 실패는 무시(다음 프레임 계속)
    } finally {
      _processing = false;
    }
  }

  /// 세그멘테이션 마스크 → 프리뷰용 배경 알파 ui.Image로 변환해 갱신.
  Future<void> _updateMask(CameraImage image) async {
    if (_segmenting) return;
    _segmenting = true;
    try {
      final mask = await _segmenter.process(image, _camera.sensorOrientation);
      if (mask == null) {
        if (mounted && _maskImage != null) {
          setState(() {
            _maskImage?.dispose();
            _maskImage = null;
          });
        }
        return;
      }
      // RGBA(검정 + 배경 알파)로 채운 이미지 생성.
      final rgba = Uint8List(mask.width * mask.height * 4);
      for (var i = 0; i < mask.bgAlpha.length; i++) {
        rgba[i * 4 + 3] = mask.bgAlpha[i];
      }
      final img = await _decodeRgba(rgba, mask.width, mask.height);
      if (!mounted || !_portrait) {
        img.dispose();
        return;
      }
      setState(() {
        _maskImage?.dispose();
        _maskImage = img;
      });
    } finally {
      _segmenting = false;
    }
  }

  Future<ui.Image> _decodeRgba(Uint8List rgba, int w, int h) {
    final c = Completer<ui.Image>();
    ui.decodeImageFromPixels(rgba, w, h, ui.PixelFormat.rgba8888, c.complete);
    return c.future;
  }

  void _clearMask() {
    _maskImage?.dispose();
    _maskImage = null;
  }

  void _togglePortrait() {
    setState(() {
      _portrait = !_portrait;
      if (!_portrait) _clearMask();
    });
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
      // 인물 모드가 아니면 배경흐림 마스크·포즈 오버레이 제거(사물/자연은 미지원).
      if (mode != ShootingMode.person) {
        _clearMask();
        _poseAsset = null;
      }
    });
    await _modeStore.save(mode);
  }

  /// 단계가 앞으로 전진했을 때만 1회 진동+소리. 후퇴는 무음.
  void _handleStepFeedback(GuideStepKind kind) {
    final prev = _prevStepKind;
    _prevStepKind = kind;
    if (prev == null || kind == prev) return;
    if (_stepOrder.indexOf(kind) <= _stepOrder.indexOf(prev)) return;
    // 카메라 화면이 최상위가 아니면(피드·로그인 등이 위에 떠 있음) 피드백 억제.
    if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;
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
    // 전환 중에는 프리뷰를 먼저 트리에서 제거(스피너로 교체)한다.
    // 그렇지 않으면 옛 컨트롤러를 dispose하는 순간 아직 남아 있는 CameraPreview가
    // disposed 컨트롤러에서 buildPreview()를 호출해 예외가 난다.
    setState(() => _ready = false);
    // 위 setState로 예약된 프레임이 실제로 그려질 때까지 기다린 뒤 컨트롤러를 교체.
    await WidgetsBinding.instance.endOfFrame;
    try {
      await _camera.switchCamera(_onFrame);
      if (mounted) {
        setState(() {
          _zoom = _camera.currentZoom;
          _ready = true;
        });
      }
    } catch (e) {
      // switchCamera는 실패 시 원래 렌즈로 복구하므로 프리뷰를 다시 켠다.
      if (mounted) {
        setState(() => _ready = true);
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
      final String shotPath;
      if (_portrait && _mode == ShootingMode.person) {
        final path = await _camera.capturePhoto();
        final blurred = await applyPortraitBlur(
          File(path),
          nowMicros: DateTime.now().microsecondsSinceEpoch,
        );
        shotPath = blurred.path;
      } else {
        shotPath = await _camera.capturePhoto();
      }
      if (mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                CaptureResultScreen(original: File(shotPath), auth: _auth),
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

  void _openPosePicker() {
    if (_poses.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('포즈를 불러오지 못했어요')));
      return;
    }
    showPosePicker(
      context,
      poses: _poses,
      onSelect: (p) => setState(() => _poseAsset = p?.asset),
      onAiRecommend: _recommendPose,
    );
  }

  Future<void> _recommendPose() async {
    if (!_auth.isSignedIn) {
      final ok = await showSignInSheet(context, _auth);
      if (!ok) return;
    }
    if (!await _consent.hasConsented()) {
      if (!mounted) return;
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('AI 추천 안내'),
          content: const Text('추천 시 현재 화면 1장을 분석 서버로 전송합니다. 이미지는 저장하지 않습니다.'),
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
    final messenger = ScaffoldMessenger.of(context);
    try {
      final deviceId = await _deviceId.get();
      final framePath = await _camera.captureFrameForAdvice();
      final suggestion = await _poseAdvisor.suggest(
        jpegPath: framePath,
        candidates: _poses,
        deviceId: deviceId,
      );
      final match = _poses.where((p) => p.id == suggestion.poseId);
      if (match.isNotEmpty && mounted) {
        setState(() => _poseAsset = match.first.asset);
        if (suggestion.reason.isNotEmpty) {
          messenger.showSnackBar(SnackBar(content: Text(suggestion.reason)));
        }
      }
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('추천을 못 받았어요. 다시 시도해 주세요.')),
      );
    } finally {
      if (mounted) _camera.startStream(_onFrame);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) routeObserver.subscribe(this, route);
  }

  /// 앱이 백그라운드로 가면 카메라를 정지(발열·배터리 절감), 복귀 시 재개.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_ready) return;
    if (state == AppLifecycleState.resumed) {
      // 카메라 화면이 최상위일 때만 재개(피드 등이 위에 있으면 정지 유지).
      if (ModalRoute.of(context)?.isCurrent ?? true) _resumeCamera();
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _pauseCamera();
    }
  }

  /// 이 화면 위로 다른 화면이 push됨 → 프레임 분석·프리뷰 중단(발열·배터리 절감).
  @override
  void didPushNext() {
    _pauseCamera();
  }

  /// 위 화면이 닫혀 다시 최상위가 됨 → 재개.
  @override
  void didPopNext() {
    _resumeCamera();
  }

  Future<void> _pauseCamera() async {
    await _camera.stopStream();
    await _camera.pausePreview();
  }

  Future<void> _resumeCamera() async {
    if (!mounted || !_ready) return;
    await _camera.resumePreview();
    _prevStepKind = null; // 복귀 직후 오발 진동 방지
    _camera.startStream(_onFrame);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    routeObserver.unsubscribe(this);
    _accelSub?.cancel();
    _camera.dispose();
    _faceDetector.dispose();
    _objectDetector.dispose();
    _segmenter.dispose();
    _maskImage?.dispose();
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

  Future<void> _openCommunity() async {
    if (!_auth.isSignedIn) {
      final ok = await showSignInSheet(context, _auth);
      if (!ok) return;
    }
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => FeedScreen(auth: _auth)),
    );
  }

  /// 배경만 흐린 프리뷰 오버레이. 맨 아래 '선명한' CameraPreview 위에,
  /// '블러 처리된 CameraPreview 사본'을 배경 알파 마스크로 잘라 덮는다.
  /// (BackdropFilter는 ShaderMask의 saveLayer 안에서 뒤 화면을 못 읽어 무효 →
  ///  ImageFiltered로 자식(프리뷰 사본) 자체를 블러한다.)
  /// 마스크는 세운 좌표계라 정규화 오버레이와 동일하게 프리뷰 박스에 스케일 매핑된다.
  Widget _buildPortraitBlur() {
    final mask = _maskImage!;
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (rect) {
        final sx = rect.width / mask.width;
        final sy = rect.height / mask.height;
        final m = Float64List.fromList([
          sx, 0, 0, 0, //
          0, sy, 0, 0, //
          0, 0, 1, 0, //
          0, 0, 0, 1, //
        ]);
        return ui.ImageShader(mask, ui.TileMode.clamp, ui.TileMode.clamp, m);
      },
      child: ImageFiltered(
        imageFilter: ui.ImageFilter.blur(
          sigmaX: 12,
          sigmaY: 12,
          tileMode: TileMode.decal,
        ),
        child: CameraPreview(_camera.controller),
      ),
    );
  }

  /// 44×44 히트영역의 상단 바 아이콘.
  Widget _topIcon(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: 44,
        height: 44,
        child: Icon(icon, color: Colors.white, size: 26),
      ),
    );
  }

  /// 현재 지시 1개를 담는 검은 pill.
  Widget _stepPill(String message) {
    return IgnorePointer(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
        decoration: BoxDecoration(
          color: AppColors.scrimPill,
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
          message,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  /// 정렬 완료 시 pill을 대체하는 초록 "찍으세요!" 배지.
  Widget _readyBadge() {
    return IgnorePointer(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 11),
        decoration: BoxDecoration(
          color: AppColors.readyBadge,
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
            Icon(Icons.check_circle, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Text(
              '찍으세요!',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 하단 컨트롤 아이콘(정확한 히트영역 [box], 꺼짐 상태는 [dim]).
  Widget _bottomIcon(
    IconData icon,
    VoidCallback onTap, {
    required double box,
    required double iconSize,
    bool dim = false,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: box,
        height: box,
        child: Icon(
          icon,
          color: Colors.white.withValues(alpha: dim ? 0.4 : 1.0),
          size: iconSize,
        ),
      ),
    );
  }

  /// 셔터(72). 안쪽 링 포함, ready면 초록 발광.
  Widget _shutter() {
    final ready = _step.kind == GuideStepKind.ready;
    final fill = ready ? AppColors.ready : Colors.white;
    return GestureDetector(
      onTap: _capture,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: fill,
          shape: BoxShape.circle,
          boxShadow: ready
              ? [
                  BoxShadow(
                    color: AppColors.ready.withValues(alpha: 0.6),
                    blurRadius: 22,
                    spreadRadius: 5,
                  ),
                ]
              : null,
        ),
        child: Center(
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: fill,
              shape: BoxShape.circle,
              border: Border.all(
                color: ready ? const Color(0xFF0B2A18) : Colors.black,
                width: 3,
              ),
            ),
          ),
        ),
      ),
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
                  // 인물 배경흐림: 배경 알파 마스크로 프리뷰 배경만 흐리게(인물은 선명).
                  if (_portrait && _maskImage != null)
                    Positioned.fill(
                      child: IgnorePointer(child: _buildPortraitBlur()),
                    ),
                  GuideOverlay(
                    metrics: _metrics,
                    step: _step,
                    showGrid: _showGrid,
                    // 얼굴이 없는 사물/자연 모드는 감지된 피사체 박스를 상시 표시.
                    showSubjectBox: _mode != ShootingMode.person,
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
                top: MediaQuery.of(context).padding.top + 54,
                right: 12,
                child: AdviceMinimap(
                  target: targetBox,
                  current: person,
                  alignment: alignment,
                ),
              ),
            // 상단 영역: 세이프에어리어 안에 [커뮤니티 · 카메라전환] 바 + 단계 pill/완료 배지.
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      SizedBox(
                        height: 44,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _topIcon(Icons.people, _openCommunity),
                            if (_camera.canSwitch)
                              _topIcon(Icons.cameraswitch, _switchCamera)
                            else
                              const SizedBox(width: 44),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (_step.kind == GuideStepKind.ready)
                        _readyBadge()
                      else if (_step.message.isNotEmpty)
                        _stepPill(_step.message),
                    ],
                  ),
                ),
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
                  const SizedBox(height: 14),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    // 좌우 클러스터를 동일폭 Expanded로 감싸 셔터를 화면 가로 중앙에 고정.
                    // 인물 모드에서 좌측 아이콘이 3개로 늘어 좁은 화면(360px)에선
                    // Expanded 폭을 넘길 수 있어 FittedBox(scaleDown)로 넘침을 막는다.
                    child: Row(
                      children: [
                        // 좌측: 사진첩 바로가기 + (인물 모드) 배경흐림 토글
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _bottomIcon(
                                    Icons.photo_library,
                                    _openGallery,
                                    box: 44,
                                    iconSize: 28,
                                  ),
                                  // 배경흐림·포즈는 인물 모드 전용. 겹치지 않게 간격을 둔다.
                                  if (_mode == ShootingMode.person) ...[
                                    const SizedBox(width: 8),
                                    _bottomIcon(
                                      _portrait
                                          ? Icons.blur_on
                                          : Icons.blur_off,
                                      _togglePortrait,
                                      box: 40,
                                      iconSize: 26,
                                      dim: !_portrait,
                                    ),
                                    const SizedBox(width: 8),
                                    _bottomIcon(
                                      Icons.accessibility_new,
                                      _openPosePicker,
                                      box: 40,
                                      iconSize: 26,
                                      dim: _poseAsset == null,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                        // 중앙: 셔터(72, ready면 초록 발광)
                        _shutter(),
                        // 우측: AI 추천 + 격자 토글(40 히트)
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerRight,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _bottomIcon(
                                    Icons.auto_awesome,
                                    _requestAdvice,
                                    box: 40,
                                    iconSize: 26,
                                  ),
                                  const SizedBox(width: 10),
                                  _bottomIcon(
                                    _showGrid ? Icons.grid_on : Icons.grid_off,
                                    () =>
                                        setState(() => _showGrid = !_showGrid),
                                    box: 40,
                                    iconSize: 26,
                                    dim: !_showGrid,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (_poseAsset != null) PoseOverlay(asset: _poseAsset!),
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
                bottom: 150,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.scrimZoom,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      '${_zoom.toStringAsFixed(1)}x',
                      style: const TextStyle(
                        fontFamily: AppFonts.mono,
                        color: Colors.white,
                        fontSize: 13,
                      ),
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
