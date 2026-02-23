import 'dart:convert'; 
import 'package:flutter/services.dart';
import '../classes/interaction.dart';

List<Interaction> ddi = [];

Future<void> loadInteractions() async {
  try {
    // 1. Читаем файл из ассетов как строку
    final String response = await rootBundle.loadString('assets/data/test_data.json');
    
    // 2. Декодируем строку в List
    final List<dynamic> data = json.decode(response);
    
    // 3. Преобразуем каждый элемент в объект Interaction и сохраняем в ddi
    ddi = data.map((jsonItem) => Interaction.fromJson(jsonItem)).toList();
    
    print("Загружено взаимодействий: ${ddi.length}");
  } catch (e) {
    print("Ошибка при загрузке JSON: $e");
  }
}

// Функция для проверки наличия взаимодействия между двумя препаратами по первой базе
bool hasInteraction(String a, String b) {
  final drug1 = a.trim().toLowerCase();
  final drug2 = b.trim().toLowerCase();

  return ddi.any((row) {
    final dbA = row.drugA.toLowerCase();
    final dbB = row.drugB.toLowerCase();
    
    return (dbA == drug1 && dbB == drug2) || 
           (dbA == drug2 && dbB == drug1);
  });
}

// Класс для хранения результатов текстового поиска
class TextSearchResult {
  final List<String> fromA;
  final List<String> fromB;

  bool get found => fromA.isNotEmpty || fromB.isNotEmpty;

  TextSearchResult(this.fromA, this.fromB);
}

// Функция для поиска упоминаний в текстах инструкций (база данных 2)
TextSearchResult searchTextEvidence(Interaction interaction, String instruction1, String instruction2) {
  final evidenceFromA = interaction.findMention(instruction1, getRuName(interaction.drugB));
  final evidenceFromB = interaction.findMention(instruction2, getRuName(interaction.drugA));

  return TextSearchResult(
    evidenceFromA != null ? [evidenceFromA] : [],
    evidenceFromB != null ? [evidenceFromB] : [],
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