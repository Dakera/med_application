import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/text_search_result.dart';
import '../../models/interaction_result.dart';
import '../../models/evidence.dart';
import '../../models/atc_code.dart';
import '../../models/eskl_drug_entry.dart';
import '../../data/repositories/interaction_repository.dart';
import '../../data/repositories/atc_repository.dart';
import '../../data/repositories/eskl_repository.dart';
import '../../data/services/text_mining_service.dart';

class InteractionCheckScreen extends StatefulWidget {
  const InteractionCheckScreen({super.key});

  @override
  State<InteractionCheckScreen> createState() => _InteractionCheckScreenState();
}

class _InteractionCheckScreenState extends State<InteractionCheckScreen> {
  bool isLoading = false;
  List<String> selectedDrugs = []; // Выбранные препараты (каноничные EN-названия для PAIRS/инструкций)

  // ВСЕ предыдущие 12 переменных результата заменены на ОДИН чистый объект!
  InteractionResult? checkResult;

  final EsklRepository _esklRepository = EsklRepository();
  final AtcRepository _atcRepository = AtcRepository();
  final TextEditingController _drugInputController = TextEditingController();
  final FocusNode _drugInputFocusNode = FocusNode();
  List<EsklDrugEntry> _suggestions = [];
  Timer? _debounce;

  // Надёжное RU-название (МНН из ESKL) для препаратов, добавленных через автокомплит —
  // подменяет собой хрупкую TextMiningService.getRuName()/transliterate() для отображения,
  // раз уж точное название у нас и так уже есть на момент выбора подсказки.
  final Map<String, String> _ruDisplayNames = {};

  @override
  void dispose() {
    _debounce?.cancel();
    _drugInputController.dispose();
    _drugInputFocusNode.dispose();
    super.dispose();
  }

  String _resolveRuName(String canonical) {
    return _ruDisplayNames[canonical] ?? TextMiningService.getRuName(canonical);
  }

  void _addCanonical(String canonical, {String? ruDisplayName}) {
    setState(() {
      if (!selectedDrugs.contains(canonical)) {
        selectedDrugs.add(canonical);
        if (ruDisplayName != null) {
          _ruDisplayNames[canonical] = ruDisplayName;
        }
      }
    });
  }

  // Метод для добавления препарата в список при нажатии на Enter или кнопку (ручной ввод текста)
  void _addDrug(TextEditingController controller, FocusNode focusNode) {
    final text = controller.text.trim();
    if (text.isNotEmpty) {
      final String canonical = TextMiningService.substanceToCanonical(text);
      _addCanonical(canonical);
      controller.clear();
      setState(() { _suggestions = []; });
      // Возвращаем фокус в поле ввода, чтобы сразу писать следующее лекарство
      focusNode.requestFocus();
    }
  }

  // Приводит название из БД (ВЕРХНИЙ РЕГИСТР) к читаемому виду для отображения пользователю,
  // не трогая исходные данные в БД.
  String _toTitleCase(String input) {
    if (input.isEmpty) return input;
    return input
        .toLowerCase()
        .split(' ')
        .map((word) => word.isEmpty ? word : word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  // Асинхронный (debounced) поиск подсказок по ЕСКЛП — вызывается при каждом изменении ввода.
  void _onDrugInputChanged(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () async {
      if (text.trim().isEmpty) {
        if (mounted) setState(() { _suggestions = []; });
        return;
      }
      final results = await _esklRepository.searchAutocomplete(text);
      if (mounted) {
        setState(() { _suggestions = results; });
      }
    });
  }

  // Выбор подсказки автокомплита. Независимо от того, было выбрано торговое название
  // или МНН, в selectedDrugs всегда попадает ДЕЙСТВУЮЩЕЕ ВЕЩЕСТВО — канонический EN-код,
  // по которому реально ищут PAIRS/файлы инструкций. Сведение делается через мост
  // ATC-код (из ESKL) → ChEMBL.pref_name (AtcRepository.resolveCanonicalName), а не через
  // подстановку торгового названия/МНН напрямую — см. разбор в MILESTONE_2_ESKL_INTEGRATION.md.
  // Если для ATC-кода нет соответствия в ChEMBL (бывает — не все 21к+ препаратов ESKL входят
  // в ChEMBL), используем МНН как есть: DDI/инструкция для него корректно не найдутся,
  // а ATC/фармгруппа всё равно отобразятся через прямой поиск по ESKL.
  Future<void> _selectSuggestion(EsklDrugEntry entry) async {
    setState(() { _suggestions = []; });
    _drugInputController.clear();

    final String? bridged = await _atcRepository.resolveCanonicalName(entry.atcCodes);
    final String canonical = bridged ?? entry.standardInn.toLowerCase();
    if (!mounted) return;

    _addCanonical(canonical, ruDisplayName: _toTitleCase(entry.standardInn));
    _drugInputFocusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Interaction Check'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Проверка взаимодействий',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              'Введите названия двух препаратов, чтобы проверить их взаимодействия.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            
            // Поле ввода с автокомплитом по eskl_unique.db.
            // Flutter'овский Autocomplete-виджет требует синхронный optionsBuilder,
            // а поиск идёт в SQLite асинхронно — поэтому здесь простой TextField
            // с debounced-поиском и собственным выпадающим списком подсказок.
            TextField(
              controller: _drugInputController,
              focusNode: _drugInputFocusNode,
              onChanged: _onDrugInputChanged,
              // Вот этот метод вернет обработку Enter! (ручной ввод без выбора подсказки)
              onSubmitted: (value) => _addDrug(_drugInputController, _drugInputFocusNode),
              decoration: InputDecoration(
                labelText: 'Введите название препарата',
                hintText: 'Например: Нурофен, ибупрофен',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.add),
                  // Вызываем ту же самую функцию при клике на плюсик
                  onPressed: () => _addDrug(_drugInputController, _drugInputFocusNode),
                ),
              ),
            ),
            if (_suggestions.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 4),
                constraints: const BoxConstraints(maxHeight: 220),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _suggestions.length,
                  itemBuilder: (context, index) {
                    final entry = _suggestions[index];
                    return ListTile(
                      dense: true,
                      title: Text(_toTitleCase(entry.nameTrade)),
                      subtitle: Text(_toTitleCase(entry.standardInn)),
                      onTap: () => _selectSuggestion(entry),
                    );
                  },
                ),
              ),
            const SizedBox(height: 16), // Отступ сверху
            
            // Отображение выбранных чипсов-квадратиков
            Center(
              child: Wrap(
                spacing: 8.0, // Расстояние между квадратиками по горизонтали
                runSpacing: 4.0, // Расстояние между строками, если будет перенос
                children: selectedDrugs.map((drug) {
                  return Chip(
                    backgroundColor: Colors.blue.shade100,
                    label: Text(_resolveRuName(drug)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), //Скругляем до состояния "квадратика"
                    deleteIcon: const Icon(Icons.close, size: 18),
                    onDeleted: () {
                      setState(() {
                        selectedDrugs.remove(drug);
                        _ruDisplayNames.remove(drug);
                      });
                    },
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),
            
            // Кнопка проверки
            Center(
              child: ElevatedButton(
                onPressed: _onCheckInteractionsPressed, // Вынесем логику в отдельный метод для чистоты кода
                child: const Text('Проверить взаимодействия'),
              ),
            ),  
            const SizedBox(height: 24),
            
            // КАРТОЧКА РЕЗУЛЬТАТА: Больше никакого ListView.builder!
            // Если результат есть — показываем его в скроллящейся области.
            if (checkResult != null)
              Expanded(
                child: SingleChildScrollView(
                  child: _buildResultCard(checkResult!),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Логика нажатия на кнопку: инкапсулирует все тяжелые расчеты
  // ИЗМЕНЕННЫЙ ЛОГИЧЕСКИЙ МЕТОД НАЖАТИЯ НА КНОПКУ: независимый параллельный поиск
  Future<void> _onCheckInteractionsPressed() async {
    if (selectedDrugs.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Пожалуйста, выберите хотя бы 2 препарата')),
      );
      return;
    }

    setState(() { isLoading = true; });

    try {
      final String drugA = selectedDrugs[0];
      final String drugB = selectedDrugs[1];
      final String drugARu = _resolveRuName(drugA);
      final String drugBRu = _resolveRuName(drugB);

      final repo = InteractionRepository();
      final interaction = await repo.findInteraction(drugA, drugB);

      // ЕСКЛП (eskl_unique.db) — первичный источник ATC-кода и фармгруппы на русском.
      final esklEntriesA = await _esklRepository.findByInn(drugARu);
      final esklEntriesB = await _esklRepository.findByInn(drugBRu);
      final esklBestA = esklEntriesA.isNotEmpty ? esklEntriesA.first : null;
      final esklBestB = esklEntriesB.isNotEmpty ? esklEntriesB.first : null;

      // ChEMBL — вторичный/резервный источник, используется только если ЕСКЛП не нашёл совпадение.
      final atcRepo = AtcRepository();
      final atcCodesA = esklBestA == null ? await atcRepo.findAtcCodes(drugA) : <AtcCode>[];
      final atcCodesB = esklBestB == null ? await atcRepo.findAtcCodes(drugB) : <AtcCode>[];

      if (!mounted) return;

      final tempInstrA = await TextMiningService.loadAndProcessInstruction(drugA);
      final tempInstrB = await TextMiningService.loadAndProcessInstruction(drugB);

      final tempTextResult = TextMiningService.searchTextEvidence(drugA, drugB, tempInstrA, tempInstrB);
      
      String tempSection = 'Раздел не определен';
      List<Evidence> tempEvidence = [];
      String tempInstructionUsed = 'Не использовалась (информация из базы данных)'; // По умолчанию

      // Извлекаем конкретные предложения-доказательства
      if (tempTextResult.fromA.isNotEmpty) {
        tempSection = TextMiningService.extractSection(tempInstrA);
        tempEvidence = TextMiningService.extractEvidence(tempSection, drugBRu, contextWindow: 1);
        if (tempEvidence.isNotEmpty) {
          tempInstructionUsed = drugARu; // Совпадение найдено в инструкции Препарата А
        }
      } 
      
      // Если в первой инструкции не нашли, пробуем забрать доказательства из второй
      if (tempEvidence.isEmpty && tempTextResult.fromB.isNotEmpty) {
        tempSection = TextMiningService.extractSection(tempInstrB);
        tempEvidence = TextMiningService.extractEvidence(tempSection, drugARu, contextWindow: 1);
        if (tempEvidence.isNotEmpty) {
          tempInstructionUsed = drugBRu; // Совпадение найдено в инструкции Препарата Б
        }
      }

      final bool ddiExists = interaction != null;
      final bool textFound = tempEvidence.isNotEmpty;

      if (!ddiExists && !textFound) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Взаимодействия между выбранными препаратами не найдены ни в базе, ни в инструкциях')),
        );
        setState(() { checkResult = null; }); 
        return;
      }

      final finalStatus = TextMiningService.interpret(ddiExists, textFound);

      if (mounted) {
        setState(() {
          checkResult = InteractionResult(
            drugA: drugA,
            drugB: drugB,
            drugARu: drugARu,
            drugBRu: drugBRu,
            severity: interaction?.severity ?? 'unknown', 
            status: finalStatus,
            section: tempSection,
            evidence: tempEvidence,
            instructionUsed: tempInstructionUsed, // <-- Передаем зафиксированное имя
            atcCodesA: atcCodesA,
            atcCodesB: atcCodesB,
            esklAtcCodesA: esklBestA?.atcCodes ?? const [],
            esklAtcCodesB: esklBestB?.atcCodes ?? const [],
            ftgNameRuA: esklBestA?.ftgNameRu,
            ftgNameRuB: esklBestB?.ftgNameRu,
          );
        });
      }
    } catch (e) {
      print("Ошибка при проверке взаимодействий: $e");
    } finally {
      if (mounted) {
        setState(() { isLoading = false; });
      }
    }
  }

// Вспомогательный метод для динамической подсветки целевого предложения маркером
  Widget _buildHighlightedContext(Evidence e) {
    final String contextText = e.context;
    final String matchText = e.sentence;

    // Ищем точное вхождение предложения внутри окна контекста
    final int index = contextText.indexOf(matchText);
    if (index == -1) {
      // Если по какой-то причине не сошлось, выводим обычный текст
      return Text(contextText, style: const TextStyle(fontSize: 14));
    }

    // Делим строку на до, совпадение и после
    final String before = contextText.substring(0, index);
    final String after = contextText.substring(index + matchText.length);

    return RichText(
      text: TextSpan(
        style: const TextStyle(fontSize: 14, color: Colors.black87, height: 1.4),
        children: [
          TextSpan(text: before),
          TextSpan(
            text: matchText,
            style: TextStyle(
              backgroundColor: Colors.yellow.shade300, // Цвет маркера-хайлайтера
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          TextSpan(text: after),
        ],
      ),
    );
  }

  // Виджет карточки: только верстка, никакой бизнес-логики!
  // Обновленный виджет карточки результата
  Widget _buildResultCard(InteractionResult result) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.warning, 
                  color: result.severity == 'major' 
                      ? Colors.red 
                      : (result.severity == 'unknown' ? Colors.blue : Colors.orange),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '${result.drugARu} + ${result.drugBRu}',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            Text(
              'Severity: ${result.severity}',
              style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),

            Text(
              'ATC (${result.drugARu}): ${_formatAtcAndPharmGroup(result.esklAtcCodesA, result.ftgNameRuA, result.atcCodesA)}',
              style: TextStyle(fontSize: 14, color: Colors.grey[700]),
            ),
            Text(
              'ATC (${result.drugBRu}): ${_formatAtcAndPharmGroup(result.esklAtcCodesB, result.ftgNameRuB, result.atcCodesB)}',
              style: TextStyle(fontSize: 14, color: Colors.grey[700]),
            ),
            const SizedBox(height: 8),

            const Text(
              'Source: ',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              _getLabelForStatus(result.status),
              style: TextStyle(
                fontSize: 14,
                color: _getColorForStatus(result.status),
              ),
            ),
            const SizedBox(height: 12),

            // НОВАЯ СТРОКА: Вывод используемой инструкции
            const Text(
              'Использованный документ:',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Официальная инструкция препарата: ${result.instructionUsed}',
              style: TextStyle(fontSize: 14, fontStyle: FontStyle.italic, color: Colors.blueGrey.shade700),
            ),
            const SizedBox(height: 12),

            const Text(
              'Section:',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ), 
            const SizedBox(height: 4),
            Text(
              result.section,
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),

            const Text(
              'Фрагмент из инструкции (Контекст):',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            // УЛУЧШЕНО: Мапим контекст с применением умного маркера подсветки
            result.evidence.isEmpty
                ? const Text('Нет упоминания о взаимодействии в инструкции.', style: TextStyle(fontSize: 14))
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: result.evidence.map((e) => Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: _buildHighlightedContext(e),
                    )).toList(),
                  ),
            const SizedBox(height: 12),

            const Text(
              'Evidence (Сработавшее предложение):',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            // УЛУЧШЕНО: Само изолированное предложение выделяем стильной плашкой
            result.evidence.isEmpty
                ? const Text('Нет доказательств взаимодействия в инструкции.', style: TextStyle(fontSize: 14))
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: result.evidence.map((e) => Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 6.0),
                      padding: const EdgeInsets.all(8.0),
                      decoration: BoxDecoration(
                        color: Colors.yellow.shade100,
                        border: Border(left: BorderSide(width: 4, color: Colors.amber.shade700)),
                        borderRadius: const BorderRadius.horizontal(right: Radius.circular(6)),
                      ),
                      child: Text(
                        e.sentence,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.black87),
                      ),
                    )).toList(),
                  ),
          ],
        ),
      ),
    );
  } // ИЗМЕНЕННЫЙ КОНСТРУКТОР: теперь он принимает весь InteractionResult, а не отдельные поля

  // Форматирует ATC-код + русскую фармгруппу для строки в карточке.
  // ЕСКЛП — первичный источник (RU); ChEMBL используется только как fallback,
  // если ЕСКЛП не нашёл совпадение (см. MILESTONE_2_ESKL_INTEGRATION.md).
  String _formatAtcAndPharmGroup(List<String> esklAtcCodes, String? ftgNameRu, List<AtcCode> chemblFallback) {
    if (esklAtcCodes.isNotEmpty) {
      final codesStr = esklAtcCodes.join(', ');
      final ftg = (ftgNameRu != null && ftgNameRu.isNotEmpty) ? ftgNameRu : 'фармгруппа не определена';
      return '$codesStr — $ftg';
    }
    if (chemblFallback.isNotEmpty) {
      final codesStr = chemblFallback.map((c) => c.level5).join(', ');
      return '$codesStr (источник: ChEMBL, рус. фармгруппа недоступна)';
    }
    return 'нет данных';
  }

  // Вспомогательные методы отображения для UI
  String _getLabelForStatus(InteractionStatus status) {
    switch (status) {
      case InteractionStatus.confirmedByText:
        return 'База + инструкция';
      case InteractionStatus.ddiOnly:
        return 'Взаимодействие указано в базе\nПодтверждение в инструкции не найдено';
      case InteractionStatus.textOnly:
        return 'Потенциальное взаимодействие\nУпоминание найдено в инструкции';
      default:
        return 'Нет данных о взаимодействии';
    }
  }

  Color _getColorForStatus(InteractionStatus status) {
    switch (status) {
      case InteractionStatus.confirmedByText:
        return const Color.fromARGB(255, 255, 12, 12);
      case InteractionStatus.ddiOnly:
        return Colors.orange;
      case InteractionStatus.textOnly:
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }
}