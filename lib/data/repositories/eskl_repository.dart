import '../../models/eskl_drug_entry.dart';
import '../services/eskl_db_service.dart';

// Подстроки standard_form, которые формально содержат "ТАБЛЕТ"/"КАПСУЛ",
// но по факту не являются пероральными таблетками/капсулами для приёма внутрь
// (вагинальные формы, полуфабрикаты для другой лекарственной формы, вспомогательные
// вещества-оболочки, гомеопатия, ректальные). См. MILESTONE_2_ESKL_INTEGRATION.md.
const List<String> _excludeFormKeywords = [
  'ВАГИНАЛЬН',
  'ДЛЯ ПРИГОТОВЛЕНИЯ',
  'ДЛЯ ИМПЛАНТАЦИИ',
  'ВСПОМОГАТЕЛЬНОЕ ВЕЩЕСТВО',
  'ГОМЕОПАТИЧЕСК',
  'РЕКТАЛЬН',
];

bool _isOralTabletOrCapsule(String standardForm) {
  final upper = standardForm.toUpperCase();
  final isTabletOrCapsule = upper.contains('ТАБЛЕТ') || upper.contains('КАПСУЛ');
  final isExcluded = _excludeFormKeywords.any((kw) => upper.contains(kw));
  return isTabletOrCapsule && !isExcluded;
}

// Среди кандидатов с одинаковым ключом группировки выбирает "лучшую" запись:
// сначала отбрасывает строки без ATC-кода (полуфабрикаты-заготовки без code_atc,
// например "ТАБЛЕТКИ ПОКРЫТЫЕ КИШЕЧНОРАСТВОРИМОЙ ОБОЛОЧКОЙ" без code_atc в источнике —
// пустая строка формально "не составная", поэтому её нужно исключить до проверки на ';'),
// затем предпочитает одиночный (не составной через ';') код ATC,
// при равенстве — по наибольшему source_rows_count.
EsklDrugEntry _pickBest(List<EsklDrugEntry> candidates) {
  final withAtc = candidates.where((c) => c.atcCodesRaw.isNotEmpty).toList();
  final pool0 = withAtc.isNotEmpty ? withAtc : candidates;

  final singleCode = pool0.where((c) => !c.atcCodesRaw.contains(';')).toList();
  final pool = singleCode.isNotEmpty ? singleCode : pool0;

  pool.sort((a, b) => b.sourceRowsCount.compareTo(a.sourceRowsCount));
  return pool.first;
}

List<EsklDrugEntry> _dedupeBy(
  List<EsklDrugEntry> entries,
  String Function(EsklDrugEntry) keyOf,
) {
  final Map<String, List<EsklDrugEntry>> grouped = {};
  for (final e in entries) {
    grouped.putIfAbsent(keyOf(e), () => []).add(e);
  }

  final result = grouped.values.map(_pickBest).toList();
  result.sort((a, b) => b.sourceRowsCount.compareTo(a.sourceRowsCount));
  return result;
}

class EsklRepository {
  // Точный поиск по нормализованному (upper+trim) торговому названию.
  // MVP-скоуп: только пероральные таблетки/капсулы (см. MILESTONE_2_ESKL_INTEGRATION.md).
  Future<List<EsklDrugEntry>> findByTradeName(String query) async {
    final normalized = query.trim().toUpperCase();
    if (normalized.isEmpty) return [];

    final db = await EsklDbService.instance.database;
    final rows = await db.query(
      'eskl_unique',
      where: 'name_trade = ?',
      whereArgs: [normalized],
    );

    final oral = rows.map(EsklDrugEntry.fromMap).where((e) => _isOralTabletOrCapsule(e.standardForm)).toList();
    return _dedupeBy(oral, (e) => '${e.nameTrade}|${e.standardForm}');
  }

  // Точный поиск по нормализованному (upper+trim) МНН.
  Future<List<EsklDrugEntry>> findByInn(String query) async {
    final normalized = query.trim().toUpperCase();
    if (normalized.isEmpty) return [];

    final db = await EsklDbService.instance.database;
    final rows = await db.query(
      'eskl_unique',
      where: 'standard_inn = ?',
      whereArgs: [normalized],
    );

    final oral = rows.map(EsklDrugEntry.fromMap).where((e) => _isOralTabletOrCapsule(e.standardForm)).toList();
    return _dedupeBy(oral, (e) => '${e.nameTrade}|${e.standardForm}');
  }

  // Для автокомплита: LIKE-поиск по подстроке в торговом названии или МНН.
  // Результат схлопнут до одной записи на торговое название (разные лекарственные формы
  // одного бренда не должны давать дублирующиеся на вид подсказки в выпадающем списке).
  Future<List<EsklDrugEntry>> searchAutocomplete(String rawUserInput, {int limit = 20}) async {
    final normalized = rawUserInput.trim().toUpperCase();
    if (normalized.isEmpty) return [];

    final db = await EsklDbService.instance.database;
    final rows = await db.query(
      'eskl_unique',
      where: 'name_trade LIKE ? OR standard_inn LIKE ?',
      whereArgs: ['%$normalized%', '%$normalized%'],
      orderBy: 'source_rows_count DESC',
      limit: limit * 4, // с запасом — часть строк отсеется фильтром формы и дедупликацией
    );

    final oral = rows.map(EsklDrugEntry.fromMap).where((e) => _isOralTabletOrCapsule(e.standardForm)).toList();
    final deduped = _dedupeBy(oral, (e) => e.nameTrade);
    return deduped.take(limit).toList();
  }
}
