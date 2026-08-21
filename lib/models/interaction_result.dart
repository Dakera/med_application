import 'atc_code.dart';
import 'evidence.dart';
import 'text_search_result.dart';

class InteractionResult {
  final String drugA;
  final String drugB;
  final String drugARu;
  final String drugBRu;
  final String severity;
  final InteractionStatus status;
  final String section;
  final List<Evidence> evidence;
  final String? instructionUsed;
  final List<AtcCode> atcCodesA; // ChEMBL — вторичный/резервный источник (см. CLAUDE.md)
  final List<AtcCode> atcCodesB;

  // ЕСКЛП (eskl_unique.db) — первичный источник ATC-кода и фармгруппы на русском.
  final List<String> esklAtcCodesA;
  final List<String> esklAtcCodesB;
  final String? ftgNameRuA;
  final String? ftgNameRuB;

  InteractionResult({
    required this.drugA,
    required this.drugB,
    required this.drugARu,
    required this.drugBRu,
    required this.severity,
    required this.status,
    required this.section,
    required this.evidence,
    required this.instructionUsed,
    this.atcCodesA = const [],
    this.atcCodesB = const [],
    this.esklAtcCodesA = const [],
    this.esklAtcCodesB = const [],
    this.ftgNameRuA,
    this.ftgNameRuB,
  });
}