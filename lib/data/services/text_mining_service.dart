import '../../models/interaction.dart';
import '../../models/evidence.dart';
import '../../models/text_search_result.dart';
import 'package:flutter/services.dart' show rootBundle;

class TextMiningService {
  // -------------- text_search_result.dart ---------------

  // Функция для поиска упоминаний в текстах инструкций (база данных 2)
  static TextSearchResult searchTextEvidence(Interaction? interaction, String instruction1, String instruction2) {
    final drugEvidenceFromA = findMention(instruction1, getRuName(interaction!.drugB));
    print("Searching for mentions of '${interaction.drugB}' in instruction 1...");
    final drugEvidenceFromB = findMention(instruction2, getRuName(interaction.drugA));
    print("Searching for mentions of '${interaction.drugA}' in instruction 2...");

    return TextSearchResult(
      drugEvidenceFromA != null ? [drugEvidenceFromA] : [],
      drugEvidenceFromB != null ? [drugEvidenceFromB] : [],
    );
  }

  // Функция для интерпретации результатов проверки взаимодействия
  static InteractionStatus interpret(bool ddiExists, bool textFound) {
    if (ddiExists && textFound) return InteractionStatus.confirmedByText;
    if (ddiExists && !textFound) return InteractionStatus.ddiOnly;
    if (!ddiExists && textFound) return InteractionStatus.textOnly;
    return InteractionStatus.noData;
  }

  //-------------- interaction.dart ---------------

  static String? findMention(String text, String drug) {
    print("Searching for mentions of '$drug' in the instruction...");
    final sentences = text.split(RegExp(r'[.!?]'));
    for (final s in sentences) {
        if (s.toLowerCase().contains(drug.toLowerCase())) {
          return s.trim();
        }
      }
      return null;
  }

  static String process_string(String input) { // wtf is this
    return input.trim().toLowerCase();
  }

  static Future<String> loadAndProcessInstruction(String drugName) async {
      try {
        // 1. Читаем весь текстовый файл в одну строку
        String fullText = await rootBundle.loadString('assets/instructions/$drugName.txt');
        //instr_string = fullText.trim();
        return fullText.trim(); 
        
      } catch (e) {
        return "Ошибка при загрузке файла: $e";
      }
    }
  static const Map<String, String> substanceCanonical = {
    "эсциталопрам": "escitalopram",
    "escitalopram": "escitalopram",
    "сертралин": "sertraline",
    "sertraline": "sertraline",
  };

  static const Map<String, Map<String, String>> substanceNames = {
    "escitalopram": {
      "ru": "эсциталопрам",
      "en": "escitalopram",
    },
    "sertraline": {
      "ru": "сертралин",
      "en": "sertraline",
    },
  };

  // Функция для извлечения предложений, содержащих упоминание вещества и ключевых слов взаимодействия
  static List<String> extractInteractionSentences(
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

  static String substanceToCanonical(String userInput) {
    final normalized = userInput.trim().toLowerCase();
    return substanceCanonical[normalized] ?? userInput;
  }

  static String getRuName(String canonical) {
    return substanceNames[canonical]?['ru'] ?? transliterate(canonical);
  }

  // Транслитерация английских названий в русские (запасной вариант, если нет в словаре)
  static String transliterate(String s) {
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

    // Обработка 'x'
    text = text.replaceAll('x', 'кс');

    // 3. Правило для буквы 'c' (ц vs к)
    // Используем RegExp, чтобы найти 'c' перед e, i, y
    text = text.replaceAllMapped(RegExp(r'c(?=[eiy])'), (match) => 'ц');

    // 4. Двубуквенные сочетания
    final doubleChars = {
      "qu": "кв",
      "ph": "ф",
      "th": "т", 
      "ch": "х", 
      "sh": "ш",
      "ae": "е",
      "oe": "е",
      "zh": "ж", // xz
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

  static const interactionKeywords = [
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

  static const negations = [
    "не влияет",
    "не оказывает влияния",
    "не изменяет",
    "не наблюдается",
    "не обнаружено"
  ];
  
  // -------------- evidence.dart ---------------

  // Основная функция для извлечения доказательств из инструкции
  static List<Evidence> extractEvidence(
    String instruction,
    String targetDrug,
    {int contextWindow = 1}
  ) {

    final sentences = instruction
        .toLowerCase()
        .split(RegExp(r'[.!?]'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    final results = <Evidence>[];

    for (int i = 0; i < sentences.length; i++) {

      final s = sentences[i];
      print("Analyzing sentence: $s");

      if (!_containsDrug(s, targetDrug)) continue;

      if (!_containsKeyword(s)) continue;

      if (_hasNegation(s)) continue;

      final context = _buildContext(sentences, i, contextWindow);

      results.add(
        Evidence(
          sentence: s,
          context: context,
          sentenceIndex: i,
        ),
      );
      print("Added evidence: $s with context: $context");
    }

    return results;
  }

  // Функция для извлечения раздела взаимодействий из инструкции
  static String extractSection(String text) {
    final headers = [
      "взаимодействие с другими лекарственными средствами",
      "лекарственные взаимодействия",
      "взаимодействие с другими препаратами",
      "взаимодействия",
      "совместимость с другими",
    ];

    final nextHeaders = [
      "побочные действия",
      "передозировка",
      "особые указания",
      //"фармакокинетика",
      "способ применения",
    ];
    text = text.replaceAll(RegExp(r'\s+'), ' '); // На случай переноса строки внутри заголовка
    final lower = text.toLowerCase();

    int start = -1;

    for (final h in headers) {
      start = lower.indexOf(h);
      if (start != -1) break;
    }

    if (start == -1) return text;

    int end = text.length;

    for (final h in nextHeaders) {
      final idx = lower.indexOf(h, start + 50);
      if (idx != -1 && idx < end) {
        end = idx;
      }
    }

    return text.substring(start, end);
  }


  // Вспомогательные приватные методы evidence.dart

  // Получение окна контекста
  static String _buildContext(List<String> sentences, int index, int window) {
    final start = (index - window).clamp(0, sentences.length - 1);
    final end = (index + window).clamp(0, sentences.length - 1);

    return sentences.sublist(start, end + 1).join(". ");
  }

  static bool _containsKeyword(String sentence) {
    return interactionKeywords.any((k) => sentence.contains(k));
  }

  // Функция для получения основы слова препарата (для более гибкого поиска)
  static String _stemDrug(String word) {
    if (word.length <= 5) return word;
    return word.substring(0, word.length - 2);
  }

  static bool _containsDrug(String sentence, String drug) {
    //final pattern = RegExp(r'\b' + drug + r'\w*');
    // В Dart стандартный символ \b в RegExp часто некорректно работает с не-латинскими символами.
    // Он просто «не видит» границы слова в кириллице.
    // Поэтому используем более простой, но эффективный способ: проверяем, что перед ним нет букв.
    // В стандартном движке регулярных выражений Dart (как и в JavaScript) \w по умолчанию поддерживает только латиницу ([a-zA-Z0-9_]).
    // Русские буквы он часто просто "не видит".
    // проверка слева + слово + ХВОСТ + Проверка СПРАВА
    final pattern = RegExp(r'(?<![а-яА-ЯёЁa-zA-Z])' + drug + r'[а-яА-ЯёЁ]*' + r'(?![а-яА-ЯёЁ])');
    return pattern.hasMatch(sentence);
  }

  static bool _hasNegation(String sentence) {
    for (final n in negations) {
      if (sentence.contains(n)) return true;
    }
    return false;
  }
}