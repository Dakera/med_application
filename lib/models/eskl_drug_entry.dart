// Одна запись справочника eskl_unique.db (см. MILESTONE_2_ESKL_INTEGRATION.md).
// Все текстовые поля в БД хранятся в ВЕРХНЕМ РЕГИСТРЕ.
class EsklDrugEntry {
  final String klpCode;
  final String nameTrade;
  final String standardInn;
  final String standardForm;
  final String normalizedForm;
  final String atcCodesRaw; // необработанное поле code_atc, может быть составным через ';'
  final List<String> atcCodes;
  final String atcNamesRaw;
  final List<String> atcNames;
  final String ftgNameRu;
  final bool actual;
  final int sourceRowsCount;

  EsklDrugEntry({
    required this.klpCode,
    required this.nameTrade,
    required this.standardInn,
    required this.standardForm,
    required this.normalizedForm,
    required this.atcCodesRaw,
    required this.atcCodes,
    required this.atcNamesRaw,
    required this.atcNames,
    required this.ftgNameRu,
    required this.actual,
    required this.sourceRowsCount,
  });

  factory EsklDrugEntry.fromMap(Map<String, Object?> map) {
    final atcCodesRaw = (map['code_atc'] as String?)?.trim() ?? '';
    final atcNamesRaw = (map['name_atc'] as String?)?.trim() ?? '';

    return EsklDrugEntry(
      klpCode: map['klp_code'] as String? ?? '',
      nameTrade: map['name_trade'] as String? ?? '',
      standardInn: map['standard_inn'] as String? ?? '',
      standardForm: map['standard_form'] as String? ?? '',
      normalizedForm: map['normalized_form'] as String? ?? '',
      atcCodesRaw: atcCodesRaw,
      atcCodes: atcCodesRaw.isEmpty ? const [] : atcCodesRaw.split(';'),
      atcNamesRaw: atcNamesRaw,
      atcNames: atcNamesRaw.isEmpty ? const [] : atcNamesRaw.split(';'),
      ftgNameRu: map['ftg_name_ru'] as String? ?? '',
      actual: (map['actual'] as String?) == 'true',
      sourceRowsCount: map['source_rows_count'] as int? ?? 0,
    );
  }
}
