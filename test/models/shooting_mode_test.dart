import 'package:flutter_test/flutter_test.dart';
import 'package:ttongson_camera/models/shooting_mode.dart';

void main() {
  test('wire 문자열은 person/nature/object', () {
    expect(ShootingMode.person.wire, 'person');
    expect(ShootingMode.nature.wire, 'nature');
    expect(ShootingMode.object.wire, 'object');
  });

  test('label 은 한국어', () {
    expect(ShootingMode.person.label, '인물');
    expect(ShootingMode.nature.label, '자연');
    expect(ShootingMode.object.label, '사물');
  });

  test('fromWire 는 유효값을 파싱하고 이상값/누락은 null', () {
    expect(ShootingModeWire.fromWire('person'), ShootingMode.person);
    expect(ShootingModeWire.fromWire('nature'), ShootingMode.nature);
    expect(ShootingModeWire.fromWire('object'), ShootingMode.object);
    expect(ShootingModeWire.fromWire('bogus'), isNull);
    expect(ShootingModeWire.fromWire(null), isNull);
  });
}
