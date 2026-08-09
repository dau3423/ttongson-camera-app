import 'dart:io';
import 'package:flutter/material.dart';
import 'package:ttongson_camera/l10n/app_localizations.dart';
import '../community/auth_service.dart';
import '../community/screens/sign_in_sheet.dart';
import '../cloud/advice_consent.dart';
import '../cloud/device_id.dart';
import '../cloud/mood_advisor.dart';
import '../camera/camera_service.dart';
import '../edit/mood.dart';
import '../edit/mood_processor.dart';
import '../analysis/photo_naming.dart';
import '../cloud/describe_advisor.dart';
import '../edit/named_saver.dart';

/// 촬영 직후 결과 화면 — AI 이름 자동 생성 + 무드 보정.
/// 저장은 이 화면 [저장]에서 이름을 파일명으로 붙여 수행(셔터 즉시저장 없음).
/// 무드 탭 → 프리셋 즉시 미리보기 → AI 값 도착 시 갱신(무드별 캐시).
class CaptureResultScreen extends StatefulWidget {
  final File original;
  final AuthService auth;
  const CaptureResultScreen({
    super.key,
    required this.original,
    required this.auth,
  });

  @override
  State<CaptureResultScreen> createState() => _CaptureResultScreenState();
}

class _CaptureResultScreenState extends State<CaptureResultScreen> {
  final _advisor = MoodAdvisor();
  final _deviceId = DeviceId();
  final _consent = AdviceConsentStore();
  final _camera = CameraService();
  final _describe = DescribeAdvisor();
  final _nameController = TextEditingController();
  bool _naming = false;
  bool _saving = false; // 저장 중 재진입(더블탭) 방지

  Mood? _selected; // null = 원본
  File _preview = File(''); // 표시용(초기엔 원본)
  bool _working = false; // 로컬 프리셋 처리(짧음) — 전체 스피너
  bool _enhancing = false; // AI 서버 개선(왕복) — 비차단 소형 인디케이터
  int _reqSeq = 0; // 늦게 도착한 이전 요청 무시용

  @override
  void initState() {
    super.initState();
    _preview = widget.original;
    _generateName();
  }

  Future<bool> _ensureConsent() async {
    if (!widget.auth.isSignedIn) {
      final ok = await showSignInSheet(context, widget.auth);
      if (!ok) return false;
      if (!mounted) return false;
    }
    if (await _consent.hasConsented()) return true;
    if (!mounted) return false;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(ctx)!.captureAiEnhanceConsentTitle),
        content: Text(AppLocalizations.of(ctx)!.captureAiEnhanceConsentBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppLocalizations.of(ctx)!.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(AppLocalizations.of(ctx)!.commonAgree),
          ),
        ],
      ),
    );
    if (ok == true) await _consent.setConsented();
    return ok == true;
  }

  Future<void> _selectMood(Mood? mood) async {
    final seq = ++_reqSeq;
    // 새 선택은 진행 중이던 AI 개선(_enhancing)을 무효화한다.
    setState(() {
      _selected = mood;
      _enhancing = false;
    });

    if (mood == null) {
      setState(() {
        _preview = widget.original;
        _working = false;
      });
      return;
    }

    // 필터는 온디바이스 프리셋을 즉시 적용한다(네트워크·AI 불필요).
    // 더 나은 튜닝이 필요하면 사용자가 'AI로 더 예쁘게'를 눌러 개선한다.
    setState(() => _working = true);
    final params = mood.preset;
    File file;
    try {
      file = await applyMood(widget.original, params);
    } catch (_) {
      if (!mounted || seq != _reqSeq) return;
      setState(() {
        _selected = null;
        _preview = widget.original;
        _working = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.captureEnhanceFailed),
        ),
      );
      return;
    }
    if (!mounted || seq != _reqSeq) return;
    setState(() {
      _preview = file;
      _working = false;
    });
  }

  /// 'AI로 더 예쁘게' — 현재 무드를 이 사진에 맞게 서버가 튜닝한 값으로 다시 적용.
  /// 선택 사항이며, 거부/실패 시 이미 적용된 프리셋 결과를 그대로 유지한다.
  Future<void> _enhanceWithAi() async {
    final mood = _selected;
    if (mood == null || _working) return;
    final seq = ++_reqSeq;
    if (!await _ensureConsent()) return;
    if (!mounted || seq != _reqSeq) return;
    setState(() => _enhancing = true);
    try {
      final deviceId = await _deviceId.get();
      final params = await _advisor.enhance(
        jpegPath: widget.original.path,
        moodWire: mood.wire,
        deviceId: deviceId,
      );
      final file = await applyMood(widget.original, params);
      if (!mounted || seq != _reqSeq) return;
      setState(() => _preview = file);
    } catch (_) {
      if (mounted && seq == _reqSeq) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.captureAiEnhanceFailed),
          ),
        );
      }
    } finally {
      if (mounted && seq == _reqSeq) setState(() => _enhancing = false);
    }
  }

  Future<void> _generateName() async {
    // 진입 시 팝업을 띄우지 않는다 — 이미 로그인+동의된 경우에만 조용히 생성.
    if (!widget.auth.isSignedIn) return;
    if (!await _consent.hasConsented()) return;
    if (!mounted) return;
    setState(() => _naming = true);
    try {
      final deviceId = await _deviceId.get();
      final desc = await _describe.describe(
        jpegPath: widget.original.path,
        deviceId: deviceId,
      );
      if (!mounted) return;
      // 사용자가 입력란을 이미 터치(포커스)했을 수 있다. 이때 `.text`만 대입하면
      // 선택 영역이 갱신되지 않아 IME가 새 텍스트를 표시하지 않는 경우가 있다.
      // 전체 TextEditingValue(텍스트+끝 커서)로 넣어 포커스 여부와 무관히 반영한다.
      // 사용자가 직접 입력한 값은 덮어쓰지 않는다(isEmpty 가드).
      setState(() {
        if (_nameController.text.isEmpty) {
          _nameController.value = TextEditingValue(
            text: desc.name,
            selection: TextSelection.collapsed(offset: desc.name.length),
          );
        }
      });
    } catch (_) {
      // 이름 없이 진행(폴백)
    } finally {
      if (mounted) setState(() => _naming = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return; // 재진입(더블탭) 방지
    setState(() => _saving = true);
    // 메신저는 앱 최상위(MaterialApp) 소유라 이 화면을 pop해도 스낵바가 유지된다.
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final l = AppLocalizations.of(context)!;
    final name = sanitizeFilename(_nameController.text);
    // 파일명 충돌(같은 이름·빈 이름 photo.jpg) 방지용 고유 접미. 이름은 검색 가능한 접두로 유지.
    final tail = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    try {
      final originalNamed = await saveAsNamed(
        src: widget.original,
        filename: '${name}_$tail',
      );
      final okOriginal = await _camera.saveToGallery(originalNamed.path);
      var okEdited = true;
      if (_selected != null) {
        final editedNamed = await saveAsNamed(
          src: _preview,
          filename: '${name}_보정_$tail',
        );
        okEdited = await _camera.saveToGallery(editedNamed.path);
      }
      final ok = okOriginal && okEdited;
      messenger.showSnackBar(
        SnackBar(
          content: Text(ok ? l.captureSaved : l.captureSavePermissionFailed),
        ),
      );
      // 저장 성공 시 결과 화면을 닫고 카메라로 복귀. 실패면 재시도할 수 있게 유지.
      if (ok) {
        navigator.pop();
        return;
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(l.saveFailed(e.toString()))),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.captureMoodTitle),
        actions: [
          // AI 개선은 선택 사항. 기본 필터(프리셋)는 온디바이스로 즉시 적용되고,
          // 이 버튼을 눌렀을 때만 서버가 이 사진에 맞게 파라미터를 튜닝한다.
          if (_enhancing)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            IconButton(
              tooltip: AppLocalizations.of(context)!.captureAiEnhanceTooltip,
              icon: const Icon(Icons.auto_awesome),
              onPressed: (_selected == null || _working || _saving)
                  ? null
                  : _enhanceWithAi,
            ),
          TextButton(
            onPressed: (_working || _saving) ? null : _save,
            child: Text(AppLocalizations.of(context)!.captureSaveButton),
          ),
        ],
      ),
      // 하단 무드 칩이 시스템 내비게이션 바와 겹치지 않도록 바텀 세이프에어리어 적용.
      // (상단은 AppBar가 이미 처리하므로 top: false)
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Image.file(
                    _preview,
                    fit: BoxFit.contain,
                    key: ValueKey(_preview.path),
                  ),
                  if (_working) const CircularProgressIndicator(),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: TextField(
                controller: _nameController,
                maxLength: 40,
                decoration: InputDecoration(
                  hintText: AppLocalizations.of(context)!.captureNameHint,
                  counterText: '',
                  suffixIcon: _naming
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : null,
                ),
              ),
            ),
            SizedBox(
              height: 92,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                children: [
                  _MoodChip(
                    label: AppLocalizations.of(context)!.captureOriginalLabel,
                    selected: _selected == null,
                    onTap: () => _selectMood(null),
                  ),
                  for (final m in Mood.values)
                    _MoodChip(
                      label: m.label,
                      selected: _selected == m,
                      onTap: () => _selectMood(m),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MoodChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _MoodChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
      ),
    );
  }
}
