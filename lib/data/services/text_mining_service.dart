import '../../models/interaction.dart';
import '../../models/evidence.dart';
import '../../models/text_search_result.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

class TextMiningService {
  // -------------- text_search_result.dart ---------------

  // Функция для поиска упоминаний в текстах инструкций (база данных 2)
  // ИЗМЕНЕНО: Теперь функция принимает названия напрямую и независима от наличия объекта Interaction в БД
  static TextSearchResult searchTextEvidence(String drugA, String drugB, String instruction1, String instruction2) {
    final drugBRu = getRuName(drugB);
    final drugARu = getRuName(drugA);

    debugPrint("Searching for mentions of '$drugBRu' in instruction 1...");
    final drugEvidenceFromA = findMention(instruction1, drugBRu);
    
    debugPrint("Searching for mentions of '$drugARu' in instruction 2...");
    final drugEvidenceFromB = findMention(instruction2, drugARu);

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

  // УЛУЧШЕНО: Теперь использует стемминг для поиска упоминаний, чтобы падежи не ломали логику
  static String? findMention(String text, String drug) {
    final sentences = text.split(RegExp(r'[.!?]'));
    for (final s in sentences) {
        if (_containsDrug(s, drug)) {
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
        debugPrint('Нашел препарат в: $s');
        debugPrint('Есть ли ключевое слово? $hasKeyword');
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
      text = 'э${text.substring(1)}';
      // text = 'э' + text.substring(1);
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
  } // transliterate

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
  } // extractSection

  // Основная улучшенная функция для извлечения доказательств с умной обработкой списков и сохранением регистра
  static List<Evidence> extractEvidence(
    String instruction,
    String targetDrug,
    {int contextWindow = 1}
    ) {
    // 1. Сначала разбиваем текст на строки, чтобы понять структуру списков
    final rawLines = instruction.split(RegExp(r'[\n\r]+'));
    
    final List<String> sentences = [];
    String currentHeader = "";

    for (var line in rawLines) {
      line = line.trim();
      if (line.isEmpty) continue;

      // Если строка заканчивается на двоеточие — это родительский заголовок для списка
      if (line.endsWith(':')) {
        currentHeader = line;
        sentences.add(line); // Добавляем сам заголовок как отдельный элемент
        continue;
      }

      // Проверяем, является ли строка элементом списка.
      // Признаки: начинается с маркера (- • *), с цифры с точкой/скобкой (1. или 1)) 
      // или заканчивается на точку с запятой / запятую.
      final isBullet = line.startsWith(RegExp(r'^[-•*♦○◘■□▪▫]')) || 
                       line.startsWith(RegExp(r'^\d+[\).]\s*')) ||
                       line.endsWith(';') || 
                       line.endsWith(',');

      if (isBullet && currentHeader.isNotEmpty) {
        // Очищаем маркер списка на конце и в начале для красивой склейки
        final cleanLine = line.replaceAll(RegExp(r'^[-•*♦○◘■□▪▫]\s*'), '');
        
        // Создаем "виртуальное предложение", обогащенное контекстом заголовка!
        sentences.add("$currentHeader $cleanLine");
      } else {
        // Если это обычный текст (не список), разбиваем его стандартно по точкам
        // и по ';' — в схлопнутых extractSection'ом разделах между двумя точками
        // часто лежит несколько '• категория: препараты;' клауз подряд
        final subSentences = line.split(RegExp(r'[.!?;]')).map((s) => s.trim()).where((s) => s.isNotEmpty);
        for (final s in subSentences) {
          sentences.add(s);
        }
      }

      // Если строка завершилась точкой, значит мысль или весь список точно закончились.
      // Сбрасываем контекст заголовка.
      if (line.endsWith('.')) {
        currentHeader = "";
      }
    }

    final results = <Evidence>[];

    // 2. Основной цикл анализа сегментов текста
    for (int i = 0; i < sentences.length; i++) {
      final s = sentences[i];
      
      // Переводим в нижний регистр ТОЛЬКО для проверок, чтобы сохранить исходный регистр для UI
      final lowerSentence = s.toLowerCase();
      debugPrint("Analyzing sentence: $s");

      // Передаем lowerSentence во все поисковые утилиты
      if (!_containsDrug(lowerSentence, targetDrug)) continue;

      if (!_containsKeyword(lowerSentence)) continue;

      if (_hasNegation(lowerSentence)) continue;

      // Строим окно контекста из нашего красивого структурированного списка сегментов
      final context = _buildContext(sentences, i, contextWindow);

      results.add(
        Evidence(
          sentence: s, // Сюда уйдет красивая строка с правильным регистром букв!
          context: context,
          sentenceIndex: i,
        ),
      );
      debugPrint("Added evidence: $s with context: $context");
    }

    return results;
  } // extractEvidence


  // Вспомогательные приватные методы evidence.dart

  // Функция для получения основы слова препарата (для более гибкого поиска)
  /*static String _stemDrug(String word) {
    if (word.length <= 5) return word;
    return word.substring(0, word.length - 2);
  }*/

  // Полноценный алгоритм Стемминга Портера для русского языка (OFFLINE NLP)
  static String rusPorterStem(String word) {
    word = word.toLowerCase().trim().replaceAll('ё', 'е');
    
    // Находим первую гласную, чтобы определить начало области RV (после первой гласной)
    final vowels = RegExp(r'[аеиоуыэюя]');
    final match = vowels.firstMatch(word);
    if (match == null) return word; // Если гласных нет вообще, возвращаем как есть

    final int rvStart = match.end;
    final String preRv = word.substring(0, rvStart);
    String rv = word.substring(rvStart);

    if (rv.isEmpty) return word;

    // Шаг 1: Проверяем и удаляем окончания идеального деепричастия (Perfective Gerund)
    final perfectiveGerund = RegExp(r'(ив|ивши|ившись|ыв|ывши|ывшись)$');
    final perfectiveGerundWithA = RegExp(r'([ая])(в|вши|вшись)$');

    if (perfectiveGerund.hasMatch(rv)) {
      rv = rv.replaceAll(perfectiveGerund, '');
    } else if (perfectiveGerundWithA.hasMatch(rv)) {
      rv = rv.replaceAll(RegExp(r'(в|вши|вшись)$'), '');
    } else {
      // Шаг 2: Удаляем возвратные суффиксы (Reflexive)
      rv = rv.replaceAll(RegExp(r'(с[яь])$'), '');

      // Шаг 3: Удаляем окончания прилагательных, причастий, глаголов или существительных
      final adjective = RegExp(r'(ее|ие|ое|ые|ними|ыми|ей|ой|уй|ым|им|ом|ем|ая|оя|яя|ою|ею|ую|юю|их|ых|ова|ева|ого|его)$');
      final noun = RegExp(r'(а|ев|ов|ами|ями|ах|ях|е|и|ий|ия|о|у|ы|ь|ю|я|ом|ем|ей|ией|ием|ия|ям|ам)$');
      final verb = RegExp(r'(ила|ыла|ена|ейте|уйте|ите|или|ыли|ий|уй|де|ыть|ись|ысь|илась|ылась|ала|яла|не|ете|ны|ть|ешь|нно)$');

      if (adjective.hasMatch(rv)) {
        rv = rv.replaceAll(adjective, '');
      } else if (verb.hasMatch(rv)) {
        rv = rv.replaceAll(verb, '');
      } else if (noun.hasMatch(rv)) {
        rv = rv.replaceAll(noun, '');
      }
    }

    // Шаг 4: Удаляем производные суффиксы (Derivational), если остались
    rv = rv.replaceAll(RegExp(r'(ост|ость)$'), '');

    // Шаг 5: Очищаем возможный мягкий знак на конце получившейся основы
    rv = rv.replaceAll(RegExp(r'ь$'), '');

    return preRv + rv;
  } // rusPorterStem

  // Обновленная функция проверки наличия лекарства в предложении
  static bool _containsDrug(String sentence, String drug) {
    final lowerSentence = sentence.toLowerCase();
    
    // Получаем качественную основу для поиска (например, "сертралин")
    final String stem = rusPorterStem(drug); 

    // Регулярное выражение ищет основу слова, за которой могут идти любые русские буквы (окончания)
    // Используем твою отличную заготовку с негативной ретроспективной проверкой границ
    final pattern = RegExp(
      r'(?<![а-яА-ЯёЁa-zA-Z])' + RegExp.escape(stem) + r'[а-яА-ЯёЁ]*',
      caseSensitive: false,
    );
    
    return pattern.hasMatch(lowerSentence);
  }
  

  /*static bool _containsDrug(String sentence, String drug) {
    //final pattern = RegExp(r'\b' + drug + r'\w*');
    // В Dart стандартный символ \b в RegExp часто некорректно работает с не-латинскими символами.
    // Он просто «не видит» границы слова в кириллице.
    // Поэтому используем более простой, но эффективный способ: проверяем, что перед ним нет букв.
    // В стандартном движке регулярных выражений Dart (как и в JavaScript) \w по умолчанию поддерживает только латиницу ([a-zA-Z0-9_]).
    // Русские буквы он часто просто "не видит".
    // проверка слева + слово + ХВОСТ + Проверка СПРАВА
    final pattern = RegExp(r'(?<![а-яА-ЯёЁa-zA-Z])' + drug + r'[а-яА-ЯёЁ]*' + r'(?![а-яА-ЯёЁ])');
    return pattern.hasMatch(sentence);
  }*/

  // Получение окна контекста
  static String _buildContext(List<String> sentences, int index, int window) {
    final start = (index - window).clamp(0, sentences.length - 1);
    final end = (index + window).clamp(0, sentences.length - 1);

    return sentences.sublist(start, end + 1).join(". ");
  }

  static bool _containsKeyword(String sentence) {
    return interactionKeywords.any((k) => sentence.contains(k));
  }

  static bool _hasNegation(String sentence) {
    for (final n in negations) {
      if (sentence.contains(n)) return true;
    }
    return false;
  }
}