import '../../models/atc_code.dart';
import '../services/chembl_db_service.dart';

class AtcRepository {
  // Препарат может иметь несколько ATC-кодов (разные формы/пути введения),
  // поэтому возвращаем список, а не одиночное значение.
  Future<List<AtcCode>> findAtcCodes(String prefName) async {
    final db = await ChemblDbService.instance.database;

    final result = await db.rawQuery(
      '''
      SELECT a.level5, a.who_name, a.level3, a.level3_description, a.level4, a.level4_description
      FROM molecule_dictionary md
      JOIN molecule_atc_classification mac ON mac.molregno = md.molregno
      JOIN atc_classification a ON a.level5 = mac.level5
      WHERE UPPER(md.pref_name) = UPPER(?)
      ''',
      [prefName.trim()],
    );

    return result.map(AtcCode.fromMap).toList();
  }

  // Мост ATC-код → каноническое EN-название действующего вещества (pref_name в ChEMBL).
  // Используется для сведения препарата, найденного в ESKL (RU, торговое название/МНН),
  // к имени, по которому ищет PAIRS/файлы инструкций (см. MILESTONE_2_ESKL_INTEGRATION.md).
  // Если по коду в ChEMBL несколько разных pref_name (комбинированные коды) — берём первый,
  // это не идеальный tie-break, но детерминированный.
  Future<String?> findPrefNameByAtcCode(String atcCode) async {
    final trimmed = atcCode.trim();
    if (trimmed.isEmpty) return null;

    final db = await ChemblDbService.instance.database;
    final result = await db.rawQuery(
      '''
      SELECT DISTINCT md.pref_name
      FROM molecule_dictionary md
      JOIN molecule_atc_classification mac ON mac.molregno = md.molregno
      WHERE mac.level5 = ?
      ''',
      [trimmed],
    );

    if (result.isEmpty) return null;
    return (result.first['pref_name'] as String?)?.toLowerCase();
  }

  // Пробует ATC-коды по очереди (актуально для составных code_atc из ESKL,
  // где часть компонентов может отсутствовать в ChEMBL) и возвращает первое
  // каноническое EN-имя, которое удалось найти.
  Future<String?> resolveCanonicalName(List<String> atcCodes) async {
    for (final code in atcCodes) {
      final prefName = await findPrefNameByAtcCode(code);
      if (prefName != null) return prefName;
    }
    return null;
  }
}
