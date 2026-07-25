import 'package:flutter/material.dart';
import 'image_viewer.dart';

/// 게시물 이미지 캐러셀(1:1) — 좌우 스와이프 + 하단 점 인디케이터.
/// 이미지 탭 시 전체화면 뷰어를 현재 인덱스로 연다. 피드·상세 공용.
class PostImageCarousel extends StatefulWidget {
  final List<String> imageUrls;
  const PostImageCarousel({super.key, required this.imageUrls});

  @override
  State<PostImageCarousel> createState() => _PostImageCarouselState();
}

class _PostImageCarouselState extends State<PostImageCarousel> {
  final _page = PageController();
  int _current = 0;

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  void _openViewer(int i) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            FullscreenImageViewer(imageUrls: widget.imageUrls, initialIndex: i),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final urls = widget.imageUrls;
    return AspectRatio(
      aspectRatio: 1,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          PageView.builder(
            controller: _page,
            onPageChanged: (i) => setState(() => _current = i),
            itemCount: urls.length,
            itemBuilder: (context, i) => GestureDetector(
              onTap: () => _openViewer(i),
              child: Image.network(urls[i], fit: BoxFit.cover),
            ),
          ),
          if (urls.length > 1)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < urls.length; i++)
                    Container(
                      width: 6,
                      height: 6,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i == _current ? Colors.white : Colors.white54,
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
