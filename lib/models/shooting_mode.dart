/// 촬영 모드. wire 문자열은 앱·백엔드 공통 계약(person/nature/object).
enum ShootingMode { person, nature, object }

extension ShootingModeWire on ShootingMode {
  String get wire {
    switch (this) {
      case ShootingMode.person:
        return 'person';
      case ShootingMode.nature:
        return 'nature';
      case ShootingMode.object:
        return 'object';
    }
  }

  String get label {
    switch (this) {
      case ShootingMode.person:
        return '인물';
      case ShootingMode.nature:
        return '자연';
      case ShootingMode.object:
        return '사물';
    }
  }

  /// wire 문자열 → 모드. 이상값/누락은 null(호출측이 person으로 폴백).
  static ShootingMode? fromWire(String? s) {
    switch (s) {
      case 'person':
        return ShootingMode.person;
      case 'nature':
        return ShootingMode.nature;
      case 'object':
        return ShootingMode.object;
      default:
        return null;
    }
  }
}
