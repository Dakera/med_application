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

  InteractionResult({
    required this.drugA,
    required this.drugB,
    required this.drugARu,
    required this.drugBRu,
    required this.severity,
    required this.status,
    required this.section,
    required this.evidence,
  });
}