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
}
