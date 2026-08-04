import 'package:flutter/material.dart';

/// 전체화면 이미지 뷰어 — 좌우 스와이프(PageView) + 핀치/더블탭 줌(InteractiveViewer).
class FullscreenImageViewer extends StatefulWidget {
  final List<String> imageUrls;
  final int initialIndex;
  const FullscreenImageViewer({
    super.key,
    required this.imageUrls,
    this.initialIndex = 0,
  });

  @override
  State<FullscreenImageViewer> createState() => _FullscreenImageViewerState();
}

class _FullscreenImageViewerState extends State<FullscreenImageViewer> {
  late final PageController _page = PageController(
    initialPage: widget.initialIndex,
  );
  late int _current = widget.initialIndex;
  final Map<int, TransformationController> _controllers = {};
  TapDownDetails? _lastDoubleTap;

  TransformationController _controllerFor(int i) =>
      _controllers.putIfAbsent(i, () => TransformationController());

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _precacheAround(_current);
  }

  /// 현재 페이지의 양옆 이미지를 미리 받아 스와이프 시 바로 뜨게 한다.
  void _precacheAround(int i) {
    for (final j in [i - 1, i + 1]) {
      if (j >= 0 && j < widget.imageUrls.length) {
        precacheImage(NetworkImage(widget.imageUrls[j]), context);
      }
    }
  }

  @override
  void dispose() {
    _page.dispose();
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _handleDoubleTap(int i) {
    final c = _controllerFor(i);
    if (c.value != Matrix4.identity()) {
      c.value = Matrix4.identity();
      return;
    }
    final pos = _lastDoubleTap?.localPosition ?? Offset.zero;
    const scale = 2.5;
    c.value = Matrix4.identity()
      ..setEntry(0, 3, -pos.dx * (scale - 1))
      ..setEntry(1, 3, -pos.dy * (scale - 1))
      ..setEntry(0, 0, scale)
      ..setEntry(1, 1, scale);
  }

  @override
  Widget build(BuildContext context) {
    final urls = widget.imageUrls;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _page,
            // 양옆 페이지를 미리 빌드해 이미지 로딩을 앞당긴다.
            allowImplicitScrolling: true,
            onPageChanged: (i) {
              setState(() => _current = i);
              _precacheAround(i);
            },
            itemCount: urls.length,
            itemBuilder: (context, i) => GestureDetector(
              onDoubleTapDown: (d) => _lastDoubleTap = d,
              onDoubleTap: () => _handleDoubleTap(i),
              child: InteractiveViewer(
                transformationController: _controllerFor(i),
                minScale: 1,
                maxScale: 4,
                child: Center(
                  child: Image.network(
                    urls[i],
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return Center(
                        child: CircularProgressIndicator(
                          color: Colors.white54,
                          value: progress.expectedTotalBytes != null
                              ? progress.cumulativeBytesLoaded /
                                    progress.expectedTotalBytes!
                              : null,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 8,
            right: 8,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                const Spacer(),
                if (urls.length > 1)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_current + 1}/${urls.length}',
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ),
                const SizedBox(width: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
