// lib/screens/remote_pairing_screen.dart
// 역할 선택 + 호스트 QR 표시. 판단 없음: 표시·선택만.
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../remote/protocol/pairing_payload.dart';

enum RemoteRole { host, remote }

/// 역할 선택. pop 값: RemoteRole 또는 null(뒤로가기).
class RemotePairingScreen extends StatelessWidget {
  const RemotePairingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('리모컨 촬영')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _roleCard(
              context,
              icon: Icons.photo_camera,
              title: '이 폰으로 촬영하기',
              subtitle: '삼각대에 두고, 다른 폰에서 QR을 스캔해요',
              role: RemoteRole.host,
            ),
            const SizedBox(height: 16),
            _roleCard(
              context,
              icon: Icons.settings_remote,
              title: '이 폰을 리모컨으로',
              subtitle: '촬영 폰에 뜬 QR을 스캔해서 연결해요',
              role: RemoteRole.remote,
            ),
            const SizedBox(height: 24),
            Text(
              '두 폰이 같은 Wi-Fi(또는 한 폰의 핫스팟)에 있어야 해요.',
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
    return Scaffold(
      appBar: AppBar(title: const Text('리모컨 연결 대기')),
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
            const Text(
              '리모컨 폰의 똥손카메라에서\n[리모컨 촬영 → 이 폰을 리모컨으로]를 눌러\n이 QR을 스캔하세요.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
