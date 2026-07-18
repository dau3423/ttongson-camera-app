import 'package:flutter_test/flutter_test.dart';
import 'package:ttongson_camera/poses/pose.dart';

void main() {
  test('4개 카테고리, 라벨·wire 비어있지 않음', () {
    expect(PoseCategory.values.length, 4);
    for (final c in PoseCategory.values) {
      expect(c.label.isNotEmpty, isTrue);
      expect(c.wire.isNotEmpty, isTrue);
    }
  });

  test('poseCategoryFromWire: 유효값 매핑, 이상값 null', () {
    expect(poseCategoryFromWire('selfie'), PoseCategory.selfie);
    expect(poseCategoryFromWire('friends'), PoseCategory.friends);
    expect(poseCategoryFromWire('bogus'), isNull);
  });

  test('parsePoses: 유효 항목을 Pose로', () {
    const json =
        '[{"id":"selfie_01","category":"selfie","label":"턱 괴기","asset":"assets/poses/selfie_01.png"}]';
    final poses = parsePoses(json);
    expect(poses.length, 1);
    expect(poses.first.id, 'selfie_01');
    expect(poses.first.category, PoseCategory.selfie);
    expect(poses.first.asset, 'assets/poses/selfie_01.png');
  });

  test('parsePoses: 이상 항목(카테고리 불명/필드 누락)은 건너뜀', () {
    const json =
        '[{"id":"x","category":"nope","label":"a","asset":"p.png"},'
        '{"id":"y","category":"couple"},'
        '{"id":"ok","category":"couple","label":"어깨동무","asset":"assets/poses/couple_01.png"}]';
    final poses = parsePoses(json);
    expect(poses.length, 1);
    expect(poses.first.id, 'ok');
  });

  test('parsePoses: JSON이 아니면 빈 리스트', () {
    expect(parsePoses('not json'), isEmpty);
  });

  test('groupByCategory: 카테고리별로 묶음', () {
    final poses = [
      const Pose(
        id: 's1',
        category: PoseCategory.selfie,
        label: 'a',
        asset: 'a.png',
      ),
      const Pose(
        id: 'c1',
        category: PoseCategory.couple,
        label: 'b',
        asset: 'b.png',
      ),
      const Pose(
        id: 's2',
        category: PoseCategory.selfie,
        label: 'c',
        asset: 'c.png',
      ),
    ];
    final grouped = groupByCategory(poses);
    expect(grouped[PoseCategory.selfie]!.length, 2);
    expect(grouped[PoseCategory.couple]!.length, 1);
  });
}
