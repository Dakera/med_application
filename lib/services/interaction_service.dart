import 'dart:convert'; 
import 'package:flutter/services.dart';
import '../classes/interaction.dart';

List<Interaction?> ddi = [];

Future<void> loadInteractions() async {
  try {
    // 1. Читаем файл из ассетов как строку
    final String response = await rootBundle.loadString('assets/data/test_data.json');
    
    // 2. Декодируем строку в List
    final List<dynamic> data = json.decode(response);
    
    // 3. Преобразуем каждый элемент в объект Interaction и сохраняем в ddi
    ddi = data.map((jsonItem) => Interaction.fromJson(jsonItem)).toList();
    String test = ddi[0]?.toString() ?? 'null';
    print("LOaded: $test");
    
    print("Загружено взаимодействий: ${ddi.length}");

  } catch (e) {
    print("Ошибка при загрузке JSON: $e");
  }
}

// Функция для проверки наличия взаимодействия между двумя препаратами по первой базе
bool hasInteraction(String a, String b) {
  if (ddi.isEmpty) {
    print("База данных взаимодействий не загружена!");
    return false;
  }

  final drug1 = a.trim().toLowerCase();
  final drug2 = b.trim().toLowerCase();

  return ddi.any((row) {
    final dbA = row?.drugA.toLowerCase();
    final dbB = row?.drugB.toLowerCase();
    
    return (dbA == drug1 && dbB == drug2) || 
           (dbA == drug2 && dbB == drug1);
  });
}

// Класс для хранения результатов текстового поиска
class TextSearchResult {
  final List<String> fromA;
  final List<String> fromB;

  bool get found => fromA.isNotEmpty || fromB.isNotEmpty;

  String get bestMention {
    if (fromA.isNotEmpty) return fromA.join('\n\n');
    if (fromB.isNotEmpty) return fromB.join('\n\n');
    return 'Упоминание в инструкциях не найдено.';
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
  final drugEvidenceFromA = interaction?.findMention(instruction1, getRuName(interaction.drugB)) ?? '';
  print("Searching for mentions of '${interaction?.drugB}' in instruction 1...");
  final drugEvidenceFromB = interaction?.findMention(instruction2, getRuName(interaction.drugA)) ?? '';
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