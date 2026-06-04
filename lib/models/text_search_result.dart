import 'interaction.dart';

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

enum InteractionStatus {
  confirmedByText,
  ddiOnly,
  textOnly,
  noData,
}

