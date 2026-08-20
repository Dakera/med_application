import 'package:flutter/material.dart';
import '../../models/text_search_result.dart';
import '../../models/interaction_result.dart';
import '../../models/evidence.dart';
import '../../models/atc_code.dart';
import '../../data/repositories/interaction_repository.dart';
import '../../data/repositories/atc_repository.dart';
import '../../data/services/text_mining_service.dart';

class InteractionCheckScreen extends StatefulWidget {
  const InteractionCheckScreen({super.key});

  @override
  State<InteractionCheckScreen> createState() => _InteractionCheckScreenState();
}

class _InteractionCheckScreenState extends State<InteractionCheckScreen> {
  bool isLoading = false;
  List<String> selectedDrugs = []; // Выбранные препараты (каноничные названия)
  
  // ВСЕ предыдущие 12 переменных результата заменены на ОДИН чистый объект!
  InteractionResult? checkResult; 

  // Метод для добавления препарата в список при нажатии на Enter или кнопку
  void _addDrug(TextEditingController controller, FocusNode focusNode) {
    final text = controller.text.trim();
    if (text.isNotEmpty) {
      final String canonical = TextMiningService.substanceToCanonical(text);
      setState(() {
        if (!selectedDrugs.contains(canonical)) {
          selectedDrugs.add(canonical);
        }
      });
      controller.clear();
      // Возвращаем фокус в поле ввода, чтобы сразу писать следующее лекарство
      focusNode.requestFocus(); 
    }
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
            
            // Поле ввода Autocomplete
            Autocomplete<String>(
              optionsBuilder: (textEditingValue) => const Iterable<String>.empty(),
              fieldViewBuilder: (context, controller, focusNode, onEditingComplete) {
                return TextField(
                  controller: controller,
                  focusNode: focusNode,
                  // Вот этот метод вернет обработку Enter!
                  onSubmitted: (value) => _addDrug(controller, focusNode), 
                  decoration: InputDecoration(
                    labelText: 'Введите название препарата',
                    hintText: 'Например: escitalopram sertraline',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.add),
                      // Вызываем ту же самую функцию при клике на плюсик
                      onPressed: () => _addDrug(controller, focusNode),
                    ),
                  ),
                );
              },
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
                    label: Text(drug),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), //Скругляем до состояния "квадратика"
                    deleteIcon: const Icon(Icons.close, size: 18),
                    onDeleted: () {
                      setState(() {
                        selectedDrugs.remove(drug);
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
      final String drugARu = TextMiningService.getRuName(drugA);
      final String drugBRu = TextMiningService.getRuName(drugB);

      final repo = InteractionRepository();
      final interaction = await repo.findInteraction(drugA, drugB);

      final atcRepo = AtcRepository();
      final atcCodesA = await atcRepo.findAtcCodes(drugA);
      final atcCodesB = await atcRepo.findAtcCodes(drugB);

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
              'ATC (${result.drugARu}): ${_formatAtcCodes(result.atcCodesA)}',
              style: TextStyle(fontSize: 14, color: Colors.grey[700]),
            ),
            Text(
              'ATC (${result.drugBRu}): ${_formatAtcCodes(result.atcCodesB)}',
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

  // Форматирует список ATC-кодов (level5) препарата для строки в карточке
  String _formatAtcCodes(List<AtcCode> codes) {
    if (codes.isEmpty) return 'нет данных';
    return codes.map((c) => c.level5).join(', ');
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