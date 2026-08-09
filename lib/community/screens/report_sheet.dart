import 'package:flutter/material.dart';
import 'package:ttongson_camera/l10n/app_localizations.dart';
import '../theme/community_theme.dart';

/// 신고 사유 선택 바텀시트. 선택 시 사유 문자열, 취소 시 null.
Future<String?> showReportSheet(BuildContext context) {
  final l = AppLocalizations.of(context)!;
  final reasons = [
    l.reportReasonSpam,
    l.reportReasonHate,
    l.reportReasonInappropriate,
    l.reportReasonPrivacy,
    l.reportReasonEtc,
  ];
  return showModalBottomSheet<String>(
    context: context,
    builder: (ctx) {
      final p = CommunityTheme.paletteOf(ctx);
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                l.reportTitle,
                style: TextStyle(fontWeight: FontWeight.bold, color: p.text),
              ),
            ),
            for (final reason in reasons)
              ListTile(
                title: Text(reason),
                onTap: () => Navigator.pop(ctx, reason),
              ),
          ],
        ),
      );
    },
  );
}
