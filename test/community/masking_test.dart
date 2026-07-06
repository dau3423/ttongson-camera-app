import 'package:flutter_test/flutter_test.dart';
import 'package:ttongson_camera/community/masking.dart';
import 'package:ttongson_camera/community/models/mask_region.dart';

void main() {
  group('pixelRect', () {
    test('정규화 영역을 픽셀 사각형으로', () {
      const r = MaskRegion(left: 0.25, top: 0.5, width: 0.25, height: 0.25);
      final pr = pixelRect(r, 400, 200);
      expect(pr.left, 100);
      expect(pr.top, 100);
      expect(pr.right, lessThanOrEqualTo(400));
      expect(pr.width, greaterThan(0));
    });

    test('이미지 경계를 벗어나면 clamp', () {
      const r = MaskRegion(left: 0.9, top: 0.9, width: 0.5, height: 0.5);
      final pr = pixelRect(r, 100, 100);
      expect(pr.left, 90);
      expect(pr.right, 100);
      expect(pr.bottom, 100);
      expect(pr.width, lessThanOrEqualTo(10));
    });

    test('음수 시작도 0으로 clamp', () {
      const r = MaskRegion(left: -0.1, top: -0.1, width: 0.3, height: 0.3);
      final pr = pixelRect(r, 100, 100);
      expect(pr.left, 0);
      expect(pr.top, 0);
    });
  });

  group('mosaicBlockSize', () {
    test('긴 변 기준 약 targetBlocks 개 블록', () {
      // 긴 변 120px, 12블록 → 블록 10px
      expect(mosaicBlockSize(120, 60), 10);
    });
    test('아주 작은 영역은 minBlock floor', () {
      // 긴 변 12px / 12 = 1 → minBlock 4로 상승
      expect(mosaicBlockSize(12, 8), 4);
    });
    test('minBlock 조정 가능', () {
      expect(mosaicBlockSize(12, 8, minBlock: 2), 2);
    });
  });

  group('faceBoxToRegion', () {
    test('픽셀 박스를 정규화하고 isAuto true', () {
      final r = faceBoxToRegion(100, 50, 200, 100, 400, 200);
      expect(r.left, closeTo(0.25, 1e-9));
      expect(r.top, closeTo(0.25, 1e-9));
      expect(r.width, closeTo(0.5, 1e-9));
      expect(r.height, closeTo(0.5, 1e-9));
      expect(r.isAuto, isTrue);
      expect(r.enabled, isTrue);
    });
    test('이미지 경계를 넘는 박스는 0~1로 clamp', () {
      final r = faceBoxToRegion(-20, -20, 500, 500, 400, 400);
      expect(r.left, 0);
      expect(r.top, 0);
      expect(r.right, lessThanOrEqualTo(1.0));
      expect(r.bottom, lessThanOrEqualTo(1.0));
    });
  });

  group('fitDimensions', () {
    test('최장변이 상한을 넘으면 비율 유지 축소', () {
      final d = fitDimensions(3200, 1600, 1600);
      expect(d.width, 1600);
      expect(d.height, 800);
    });
    test('이미 작으면 그대로(업스케일 금지)', () {
      final d = fitDimensions(800, 600, 1600);
      expect(d.width, 800);
      expect(d.height, 600);
    });
  });

  group('containRect (BoxFit.contain)', () {
    test('가로가 더 넓은 이미지: 너비 맞춤, 상하 레터박스', () {
      // box 200x200, image 400x200(aspect 2) → w=200, h=100, top=50
      final fit = containRect(200, 200, 400, 200);
      expect(fit.width, closeTo(200, 1e-6));
      expect(fit.height, closeTo(100, 1e-6));
      expect(fit.left, closeTo(0, 1e-6));
      expect(fit.top, closeTo(50, 1e-6));
    });
    test('세로가 더 긴 이미지: 높이 맞춤, 좌우 레터박스', () {
      // box 200x200, image 100x400(aspect 0.25) → h=200, w=50, left=75
      final fit = containRect(200, 200, 100, 400);
      expect(fit.height, closeTo(200, 1e-6));
      expect(fit.width, closeTo(50, 1e-6));
      expect(fit.top, closeTo(0, 1e-6));
      expect(fit.left, closeTo(75, 1e-6));
    });
  });

  group('normFromWidget', () {
    test('표시 영역 내부 좌표를 정규화', () {
      final fit = containRect(200, 200, 400, 200); // left0 top50 w200 h100
      final p = normFromWidget(100, 100, fit); // 중앙
      expect(p.x, closeTo(0.5, 1e-6));
      expect(p.y, closeTo(0.5, 1e-6));
    });
    test('표시 영역 밖은 0~1로 clamp', () {
      final fit = containRect(200, 200, 400, 200);
      final p = normFromWidget(-50, 0, fit);
      expect(p.x, 0.0);
      expect(p.y, 0.0);
    });
  });
}
