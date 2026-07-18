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

/// 촬영 직후 무드 보정 화면. 원본은 이미 갤러리에 저장됨.
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

  Mood? _selected; // null = 원본
  File _preview = File(''); // 표시용(초기엔 원본)
  bool _working = false;
  int _reqSeq = 0; // 늦게 도착한 이전 요청 무시용

  @override
  void initState() {
    super.initState();
    _preview = widget.original;
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

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      if (_selected == null) {
        messenger.showSnackBar(
          const SnackBar(content: Text('원본은 이미 저장되어 있어요')),
        );
        return;
      }
      final ok = await _camera.saveToGallery(_preview.path);
      messenger.showSnackBar(
        SnackBar(content: Text(ok ? '보정본을 저장했어요' : '저장 실패 — 권한을 확인해 주세요')),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('저장 실패: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('오늘의 무드'),
        actions: [
          TextButton(
            onPressed: _working ? null : _save,
            child: const Text('저장'),
          ),
        ],
      ),
      body: Column(
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
          SizedBox(
            height: 92,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
