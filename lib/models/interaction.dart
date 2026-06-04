import 'package:flutter/services.dart' show rootBundle;

class Interaction {
  final String drugA;
  final String drugB;
  final String severity;
  String? instr_string;

  Interaction({
    required this.drugA, 
    required this.drugB, 
    required this.severity,
    this.instr_string = null,
  });

  // Конвертация из Map<String, dynamic> в объект класса Interaction (например, при чтении из базы данных)
  factory Interaction.fromMap(Map<String, dynamic> map) { 
    return Interaction(
      drugA: (map['Drug_A'] ?? 'Unknown drug A') as String,
      drugB: (map['Drug_B'] ?? 'Unknown drug B') as String,
      severity: (map['Level'] ?? 'Unknown severity') as String,
    );
  }

/*
  String extractInteractionSection(String text) {
    final headers = [
      "взаимодействие с другими лекарственными средствами",
      "лекарственные взаимодействия",
      "взаимодействие с другими препаратами",
      "взаимодействия",
      "другие препараты и препарат",
      "совместимость с другими",
    ];

    final lowerText = text.toLowerCase();
    int start = -1;

    // Ищем первое совпадение из списка
    for (var header in headers) {
      start = lowerText.indexOf(header);
      if (start != -1) break; // Если нашли, выходим из цикла
    }

    // Если ни один заголовок не найден, возвращаем весь текст (или пустую строку)
    if (start == -1) return text;

    // Возвращаем фрагмент текста (1000 символов — это примерная длина раздела)
    // Используем clamp, чтобы не выйти за границы текста, если он короткий
    int end = (start + 1000).clamp(0, text.length);
    return text.substring(start, end);
  }*/

}

// Функция для нормализации и получения канонических названий веществ
// void setDrugNames(String userInput) {
//   // 1. Нормализуем ввод (удаляем пробелы и приводим к нижнему регистру)
//   final String normalized = userInput.trim().toLowerCase();

//   // 2. Получаем каноническое (английское) название из первого словаря
//   final String? canonicalKey = substanceCanonical[normalized];

//   String innRu;
//   String innEn;

//   // 3. Условие присвоения
//   if (canonicalKey != null && substanceNames.containsKey(canonicalKey)) {
//     // Если ключ найден в обоих словарях
//     innRu = substanceNames[canonicalKey]!['ru']!;
//     innEn = substanceNames[canonicalKey]!['en']!;
//   } else {
//     // Если препарата нет в базе, используем ввод пользователя для обоих полей
//     innRu = userInput;
//     innEn = userInput;
//   }

//   print('Результат: RU=$innRu, EN=$innEn');
// }


