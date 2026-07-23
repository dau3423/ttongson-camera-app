import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../masking.dart';
import '../mask_processor.dart';
import '../models/mask_region.dart';
import '../theme/community_theme.dart';

/// 업로드 전 가림 편집. 얼굴 자동 모자이크(기본 ON, 토글) + 수동 박스.
/// 완료 시 처리된 JPEG File을 반환, 취소 시 null.
class MaskEditorScreen extends StatefulWidget {
  final File image;
  const MaskEditorScreen({super.key, required this.image});

  @override
  State<MaskEditorScreen> createState() => _MaskEditorScreenState();
}

class _MaskEditorScreenState extends State<MaskEditorScreen> {
  final List<MaskRegion> _regions = [];
  ui.Image? _decoded; // 표시 이미지 크기(종횡비) 계산용
  int? _selected;
  bool _detecting = true;
  bool _processing = false;

  // 드래그 진행 상태(정규화 좌표)
  NormPoint? _dragStart;
  NormPoint? _dragNow;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _decoded?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    // 이미지 종횡비 확보
    final bytes = await widget.image.readAsBytes();
    final decoded = await decodeImageFromList(bytes);
    // 얼굴 자동 감지
    final faces = await detectFaceRegions(widget.image);
    if (!mounted) return;
    setState(() {
      _decoded = decoded;
      _regions.addAll(faces);
      _detecting = false;
    });
  }

  Future<void> _done() async {
    if (_processing) return;
    setState(() => _processing = true);
    try {
      final out = await applyMasks(widget.image, _regions);
      if (mounted) Navigator.pop(context, out);
    } catch (_) {
      if (mounted) {
        setState(() => _processing = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('가림 처리에 실패했어요')));
      }
    }
  }

  void _onPanStart(Offset local, FitRect fit) {
    setState(() {
      _dragStart = normFromWidget(local.dx, local.dy, fit);
      _dragNow = _dragStart;
      _selected = null;
    });
  }

  void _onPanUpdate(Offset local, FitRect fit) {
    setState(() => _dragNow = normFromWidget(local.dx, local.dy, fit));
  }

  void _onPanEnd() {
    final a = _dragStart;
    final b = _dragNow;
    setState(() {
      _dragStart = null;
      _dragNow = null;
    });
    if (a == null || b == null) return;
    final left = a.x < b.x ? a.x : b.x;
    final top = a.y < b.y ? a.y : b.y;
    final w = (a.x - b.x).abs();
    final h = (a.y - b.y).abs();
    // 너무 작은 드래그는 무시(오탭 방지)
    if (w < 0.02 || h < 0.02) {
      return;
    }
    setState(() {
      _regions.add(MaskRegion(left: left, top: top, width: w, height: h));
      _selected = _regions.length - 1;
    });
  }

  void _onTap(Offset local, FitRect fit) {
    final pt = normFromWidget(local.dx, local.dy, fit);
    int? hit;
    for (var i = _regions.length - 1; i >= 0; i--) {
      final r = _regions[i];
      if (pt.x >= r.left &&
          pt.x <= r.right &&
          pt.y >= r.top &&
          pt.y <= r.bottom) {
        hit = i;
        break;
      }
    }
    setState(() => _selected = hit);
  }

  void _deleteSelected() {
    final i = _selected;
    if (i == null) return;
    setState(() {
      _regions.removeAt(i);
      _selected = null;
    });
  }

  void _toggleSelected() {
    final i = _selected;
    if (i == null) return;
    setState(() {
      _regions[i] = _regions[i].copyWith(enabled: !_regions[i].enabled);
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = CommunityTheme.paletteOf(context);
    final decoded = _decoded;
    final selected = _selected;
    return Theme(
      data: CommunityTheme.themeOf(context),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('개인정보 가림'),
          actions: [
            TextButton(
              onPressed: _processing ? null : _done,
              child: const Text('완료'),
            ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: (decoded == null)
                  ? const Center(child: CircularProgressIndicator())
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        final fit = containRect(
                          constraints.maxWidth,
                          constraints.maxHeight,
                          decoded.width.toDouble(),
                          decoded.height.toDouble(),
                        );
                        return GestureDetector(
                          onPanStart: (d) => _onPanStart(d.localPosition, fit),
                          onPanUpdate: (d) =>
                              _onPanUpdate(d.localPosition, fit),
                          onPanEnd: (_) => _onPanEnd(),
                          onTapUp: (d) => _onTap(d.localPosition, fit),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Center(
                                child: Image.file(
                                  widget.image,
                                  fit: BoxFit.contain,
                                ),
                              ),
                              CustomPaint(
                                painter: _MaskPainter(
                                  regions: _regions,
                                  selected: _selected,
                                  fit: fit,
                                  dragStart: _dragStart,
                                  dragNow: _dragNow,
                                ),
                              ),
                              if (_detecting || _processing)
                                const ColoredBox(
                                  color: Colors.black45,
                                  child: Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            _Controls(
              palette: p,
              hasSelection: selected != null,
              selectedEnabled: selected != null
                  ? _regions[selected].enabled
                  : false,
              onDelete: _deleteSelected,
              onToggle: _toggleSelected,
            ),
          ],
        ),
      ),
    );
  }
}

class _Controls extends StatelessWidget {
  final CommunityPalette palette;
  final bool hasSelection;
  final bool selectedEnabled;
  final VoidCallback onDelete;
  final VoidCallback onToggle;
  const _Controls({
    required this.palette,
    required this.hasSelection,
    required this.selectedEnabled,
    required this.onDelete,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Expanded(
              child: Text(
                '드래그로 가릴 영역 추가 · 탭으로 선택',
                style: TextStyle(fontSize: 12, color: palette.textMuted),
              ),
            ),
            TextButton.icon(
              onPressed: hasSelection ? onToggle : null,
              icon: Icon(
                selectedEnabled ? Icons.visibility_off : Icons.visibility,
              ),
              label: Text(selectedEnabled ? '가림 끄기' : '가림 켜기'),
            ),
            TextButton.icon(
              onPressed: hasSelection ? onDelete : null,
              icon: const Icon(Icons.delete_outline),
              label: const Text('삭제'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MaskPainter extends CustomPainter {
  final List<MaskRegion> regions;
  final int? selected;
  final FitRect fit;
  final NormPoint? dragStart;
  final NormPoint? dragNow;
  _MaskPainter({
    required this.regions,
    required this.selected,
    required this.fit,
    required this.dragStart,
    required this.dragNow,
  });

  Rect _toWidget(double l, double t, double w, double h) => Rect.fromLTWH(
    fit.left + l * fit.width,
    fit.top + t * fit.height,
    w * fit.width,
    h * fit.height,
  );

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < regions.length; i++) {
      final r = regions[i];
      final rect = _toWidget(r.left, r.top, r.width, r.height);
      final fill = Paint()
        ..color = r.enabled
            ? Colors.black.withValues(alpha: 0.55)
            : Colors.white.withValues(alpha: 0.15);
      canvas.drawRect(rect, fill);
      final border = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = i == selected ? 3 : 1.5
        ..color = i == selected
            ? Colors.amber
            : (r.enabled ? Colors.white70 : Colors.white30);
      canvas.drawRect(rect, border);
    }
    // 드래그 프리뷰
    final a = dragStart;
    final b = dragNow;
    if (a != null && b != null) {
      final left = a.x < b.x ? a.x : b.x;
      final top = a.y < b.y ? a.y : b.y;
      final w = (a.x - b.x).abs();
      final h = (a.y - b.y).abs();
      final rect = _toWidget(left, top, w, h);
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.amberAccent;
      canvas.drawRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(_MaskPainter old) => true;
}
