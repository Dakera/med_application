// Файл: lib/models/interaction_result.dart

class InteractionResult {
  final String drugA;
  final String drugB;
  final String severity;

  final List<String> evidenceFromA; // Предложения из инструкции А
  final List<String> evidenceFromB; // Предложения из инструкции Б

  final bool confirmedByText;

  // Конструктор
  InteractionResult({
    required this.drugA,
    required this.drugB,
    required this.severity,
    required this.evidenceFromA,
    required this.evidenceFromB,
    required this.confirmedByText,
  });

  // Полезный геттер для объединения всех доказательств
  List<String> get allEvidence => [...evidenceFromA, ...evidenceFromB];
}