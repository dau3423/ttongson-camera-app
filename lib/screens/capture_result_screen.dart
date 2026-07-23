import 'dart:io';
import 'package:flutter/material.dart';
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
  bool _working = false;
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
        title: const Text('AI 보정 안내'),
        content: const Text('AI 보정 시 사진 1장을 분석 서버로 전송합니다. 이미지는 저장하지 않습니다.'),
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
    if (ok == true) await _consent.setConsented();
    return ok == true;
  }

  Future<void> _selectMood(Mood? mood) async {
    final seq = ++_reqSeq;
    setState(() => _selected = mood);

    if (mood == null) {
      setState(() {
        _preview = widget.original;
      });
      return;
    }

    // 1) 프리셋 즉시 미리보기 (디코드 실패 등은 스킵+안내 — 스펙 §8)
    setState(() => _working = true);
    var params = mood.preset;
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('이 사진은 보정할 수 없어요')));
      return;
    }
    if (!mounted || seq != _reqSeq) return;
    setState(() {
      _preview = file;
    });

    // 2) AI 갱신(동의 시). 실패/거부 시 프리셋 유지.
    if (await _ensureConsent()) {
      try {
        final deviceId = await _deviceId.get();
        params = await _advisor.enhance(
          jpegPath: widget.original.path,
          moodWire: mood.wire,
          deviceId: deviceId,
        );
        file = await applyMood(widget.original, params);
        if (!mounted || seq != _reqSeq) return;
        setState(() {
          _preview = file;
        });
      } catch (_) {
        // 프리셋 결과 유지(조용히 폴백)
      }
    }
    if (mounted && seq == _reqSeq) setState(() => _working = false);
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
      setState(() {
        if (_nameController.text.isEmpty) _nameController.text = desc.name;
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
    final messenger = ScaffoldMessenger.of(context);
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
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            (okOriginal && okEdited) ? '저장했어요' : '저장 실패 — 권한을 확인해 주세요',
          ),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('저장 실패: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('오늘의 무드'),
        actions: [
          TextButton(
            onPressed: (_working || _saving) ? null : _save,
            child: const Text('저장'),
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
                  hintText: 'AI가 이름을 지어줘요',
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
                    label: '원본',
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
