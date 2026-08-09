// lib/screens/remote_pairing_screen.dart
// 역할 선택 + 호스트 QR 표시. 판단 없음: 표시·선택만.
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:ttongson_camera/l10n/app_localizations.dart';

import '../remote/protocol/pairing_payload.dart';

enum RemoteRole { host, remote }

/// 역할 선택. pop 값: RemoteRole 또는 null(뒤로가기).
class RemotePairingScreen extends StatelessWidget {
  const RemotePairingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l.remotePairingTitle)),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _roleCard(
              context,
              icon: Icons.photo_camera,
              title: l.remotePairingHostTitle,
              subtitle: l.remotePairingHostSubtitle,
              role: RemoteRole.host,
            ),
            const SizedBox(height: 16),
            _roleCard(
              context,
              icon: Icons.settings_remote,
              title: l.remotePairingRemoteTitle,
              subtitle: l.remotePairingRemoteSubtitle,
              role: RemoteRole.remote,
            ),
            const SizedBox(height: 24),
            Text(
              l.remotePairingWifiHint,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _roleCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required RemoteRole role,
  }) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Icon(icon, size: 36),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        onTap: () => Navigator.pop(context, role),
      ),
    );
  }
}

/// 호스트의 QR 대기 화면. 클라이언트가 접속하면 호출측이 pop한다.
class RemoteHostQrScreen extends StatelessWidget {
  const RemoteHostQrScreen({super.key, required this.payload});

  final PairingPayload payload;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l.remoteHostQrTitle)),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              child: QrImageView(data: payload.encode(), size: 240),
            ),
            const SizedBox(height: 24),
            Text(l.remoteHostQrInstruction, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
