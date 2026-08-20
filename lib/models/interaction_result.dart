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
  final List<AtcCode> atcCodesA;
  final List<AtcCode> atcCodesB;

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
  });
}