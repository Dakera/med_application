import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/material.dart';

class Interaction {
  final String drugA;
  final String drugB;
  final String severity;
  String instr_string;

  Interaction({
    required this.drugA, 
    required this.drugB, 
    required this.severity,
    this.instr_string = '',
  });

  // Фабричный конструктор для создания объекта из Map (JSON)
  factory Interaction.fromJson(Map<String, dynamic> json) {
    return Interaction(
      drugA: json['drugA'] as String,
      drugB: json['drugB'] as String,
      severity: json['severity'] as String,
    );
  }

  Future<String> loadAndProcessInstruction(String drugName) async {
    try {
      // 1. Читаем весь текстовый файл в одну строку
      String fullText = await rootBundle.loadString('assets/instructions/$drugName.txt');

      instr_string = fullText.trim();
      return fullText.trim(); 
      
    } catch (e) {
      return "Ошибка при загрузке файла: $e";
    }
  }

  String extractInteractionSection(String text) {
    final start = text.toLowerCase().indexOf(
      "взаимодействие с другими лекарственными средствами",
    );
    if (start == -1) return text;
    return text.substring(start, start + 1000);
  }

  String? findMention(String text, String drug) {
  final sentences = text.split(RegExp(r'[.!?]'));
  for (final s in sentences) {
      if (s.toLowerCase().contains(drug.toLowerCase())) {
        return s.trim();
      }
    }
    return null;
  }

  String process_string(String input) {
    return input.trim().toLowerCase();
  }
}

const Map<String, String> substanceCanonical = {
  "эсциталопрам": "escitalopram",
  "escitalopram": "escitalopram",
  "сертралин": "sertraline",
  "sertraline": "sertraline",
};

const Map<String, Map<String, String>> substanceNames = {
  "escitalopram": {
    "ru": "эсциталопрам",
    "en": "escitalopram",
  },
  "sertraline": {
    "ru": "сертралин",
    "en": "sertraline",
  },
};

String substanceToCanonical(String userInput) {
  final normalized = userInput.trim().toLowerCase();
  return substanceCanonical[normalized] ?? userInput;
}

String getRuName(String canonical) {
  return substanceNames[canonical]?['ru'] ?? transliterate(canonical);
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

// Функция для извлечения предложений, содержащих упоминание вещества и ключевых слов взаимодействия
List<String> extractInteractionSentences(
  String instruction,
  String substanceRu,
) {
  // 1. Разбиваем на предложения, но сразу убираем пустые элементы и лишние пробелы
  final sentences = instruction
      .split(RegExp(r'(?<=[.!?])\s+')) // Более умное разбиение: по знаку + пробел
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();

  final searchTarget = substanceRu.toLowerCase().trim();

  return sentences.where((s) {
    final lower = s.toLowerCase();
    final hasSubstance = lower.contains(searchTarget);
    final hasKeyword = interactionKeywords.any((k) => lower.contains(k));
    
    if (hasSubstance) {
      print('Нашел препарат в: $s');
      print('Есть ли ключевое слово? $hasKeyword');
    }
    
    return hasSubstance && hasKeyword;
  }).toList();
}

const interactionKeywords = [
  'повыс',
  'содерж',
  //'примен', 
  'лечен',
  "взаимод",
  "совместн",
  "одновременн",
  "ингибитор",
  "индуктор",
  "усилив",
  "ослаб",
  "повыш",
  //"уменьшает концентрацию", 
  "уменьш",
  "другие препараты и препарат",
  "другие препараты и лекарственные средства",
  "другие препараты и медикаменты",
  "другие препараты и лекарства",

];

// Транслитерация английских названий в русские (запасной вариант, если нет в словаре)
String transliterate(String s) {
  String text = s.toLowerCase().trim();

  // 1. Правило первой буквы: 'e' в начале слова -> 'э'
  if (text.startsWith('e')) {
    text = 'э' + text.substring(1);
  }

  // 2. Обработка окончаний (чтобы sertraline -> сертралин)
  final suffixes = {
    'ine': 'ин',
    'ide': 'ид',
    'one': 'он',
  };
  for (var entry in suffixes.entries) {
    if (text.endsWith(entry.key)) {
      text = text.substring(0, text.length - entry.key.length) + entry.value;
      break;
    }
  }

  // 3. Правило для буквы 'c' (ц vs к)
  // Используем RegExp, чтобы найти 'c' перед e, i, y
  text = text.replaceAllMapped(RegExp(r'c(?=[eiy])'), (match) => 'ц');

  // 4. Двубуквенные сочетания
  final doubleChars = {
    "ph": "ф", "th": "т", "ch": "х", "sh": "ш",
  };
  doubleChars.forEach((key, value) {
    text = text.replaceAll(key, value);
  });

  // 5. Оставшаяся карта одиночных символов
  final map = {
    "a": "а", "b": "б", "c": "к", "d": "д", "e": "е",
    "f": "ф", "g": "г", "h": "х", "i": "и", "j": "й",
    "k": "к", "l": "л", "m": "м", "n": "н", "o": "о",
    "p": "п", "r": "р", "s": "с", "t": "т", "u": "у",
    "v": "в", "y": "и", "z": "з"
  };

  StringBuffer result = StringBuffer();
  for (int i = 0; i < text.length; i++) {
    String char = text[i];
    // Если буква уже заменена (на кириллицу), оставляем, иначе ищем в карте
    result.write(map[char] ?? char);
  }

  return result.toString();
}