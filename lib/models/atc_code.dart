class AtcCode {
  final String level5;              // полный ATC-код, напр. N06AB05
  final String whoName;             // название по ВОЗ

  final String level3;              // код 3-го уровня, напр. N06A
  final String level3Description;   // англ. описание (кандидат на будущую рус. фармгруппу)

  final String level4;              // код 4-го уровня, напр. N06AB
  final String level4Description;   // англ. описание

  AtcCode({
    required this.level5,
    required this.whoName,
    required this.level3,
    required this.level3Description,
    required this.level4,
    required this.level4Description,
  });

  factory AtcCode.fromMap(Map<String, Object?> map) {
    return AtcCode(
      level5: map['level5'] as String,
      whoName: map['who_name'] as String,
      level3: map['level3'] as String,
      level3Description: map['level3_description'] as String,
      level4: map['level4'] as String,
      level4Description: map['level4_description'] as String,
    );
  }
}
