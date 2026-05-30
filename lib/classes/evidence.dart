import '../classes/interaction.dart';

class Evidence {
  final String sentence;
  final String context;
  final int sentenceIndex;

  Evidence({
    required this.sentence,
    required this.context,
    required this.sentenceIndex,
  });
}

bool containsKeyword(String sentence) {
  return interactionKeywords.any((k) => sentence.contains(k));
}

// Функция для получения основы слова препарата (для более гибкого поиска)
String stemDrug(String word) {
  if (word.length <= 5) return word;
  return word.substring(0, word.length - 2);
}

bool containsDrug(String sentence, String drug) {
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

bool hasNegation(String sentence) {
  for (final n in negations) {
    if (sentence.contains(n)) return true;
  }
  return false;
}

// Получение окна контекста
String buildContext(List<String> sentences, int index, int window) {
  final start = (index - window).clamp(0, sentences.length - 1);
  final end = (index + window).clamp(0, sentences.length - 1);

  return sentences.sublist(start, end + 1).join(". ");
}

// Основная функция для извлечения доказательств из инструкции
List<Evidence> extractEvidence(
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

    if (!containsDrug(s, targetDrug)) continue;

    if (!containsKeyword(s)) continue;

    if (hasNegation(s)) continue;

    final context = buildContext(sentences, i, contextWindow);

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
String extractSection(String text) {
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