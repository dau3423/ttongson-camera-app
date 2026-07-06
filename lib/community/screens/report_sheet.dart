import 'package:flutter/material.dart';

/// 신고 사유(사전 정의).
const List<String> reportReasons = [
  '스팸/광고',
  '욕설·혐오 발언',
  '부적절한 사진',
  '개인정보 노출',
  '기타',
];

/// 신고 사유 선택 바텀시트. 선택 시 사유 문자열, 취소 시 null.
Future<String?> showReportSheet(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              '신고 사유를 선택하세요',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          for (final reason in reportReasons)
            ListTile(
              title: Text(reason),
              onTap: () => Navigator.pop(ctx, reason),
            ),
        ],
      ),
    ),
  );
}
