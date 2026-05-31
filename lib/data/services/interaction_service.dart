import 'dart:convert'; 
import 'package:flutter/services.dart';
import '../../classes/interaction.dart';

List<Interaction?> ddi = [];

// Класс для хранения результатов текстового поиска
class TextSearchResult {
  final List<String> fromA;
  final List<String> fromB;

  bool get found => fromA.isNotEmpty || fromB.isNotEmpty;

  String? get bestMention {
    if (fromA.isNotEmpty) return fromA.join('\n\n');
    if (fromB.isNotEmpty) return fromB.join('\n\n');
    return null;
  }

  String get sourceLabel {
    if (fromA.isNotEmpty && fromB.isNotEmpty) return "Найдено в обеих инструкциях";
    if (fromA.isNotEmpty) return "Из инструкции первого препарата";
    if (fromB.isNotEmpty) return "Из инструкции второго препарата";
    return "Источник не определен";
  }

  TextSearchResult(this.fromA, this.fromB);
}

// Функция для поиска упоминаний в текстах инструкций (база данных 2)
TextSearchResult searchTextEvidence(Interaction? interaction, String instruction1, String instruction2) {
  final drugEvidenceFromA = interaction?.findMention(instruction1, getRuName(interaction.drugB));
  print("Searching for mentions of '${interaction?.drugB}' in instruction 1...");
  final drugEvidenceFromB = interaction?.findMention(instruction2, getRuName(interaction.drugA));
  print("Searching for mentions of '${interaction?.drugA}' in instruction 2...");

  return TextSearchResult(
    drugEvidenceFromA != null ? [drugEvidenceFromA] : [],
    drugEvidenceFromB != null ? [drugEvidenceFromB] : [],
  );
}

enum InteractionStatus {
  confirmedByText,
  ddiOnly,
  textOnly,
  noData,
}

// Функция для интерпретации результатов проверки взаимодействия
InteractionStatus interpret(bool ddiExists, bool textFound) {
  if (ddiExists && textFound) return InteractionStatus.confirmedByText;
  if (ddiExists && !textFound) return InteractionStatus.ddiOnly;
  if (!ddiExists && textFound) return InteractionStatus.textOnly;
  return InteractionStatus.noData;
}