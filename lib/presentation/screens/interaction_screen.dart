import 'package:flutter/material.dart';
import '../../models/text_search_result.dart';
import '../../models/interaction_result.dart';
import '../../models/evidence.dart';
import '../../data/repositories/interaction_repository.dart';
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
  Future<void> _onCheckInteractionsPressed() async {
    if (selectedDrugs.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Пожалуйста, выберите хотя бы 2 препарата')),
      );
      return;
    }

    // 1. Включаем индикатор загрузки перед началом тяжелых операций
    setState(() { isLoading = true; });

    // 2. Оборачиваем всю логику в try / finally, чтобы ГАРАНТИРОВАННО 
    // выключить индикатор загрузки, даже если произойдет ошибка или return.
    try {
      final String drugA = selectedDrugs[0];
      final String drugB = selectedDrugs[1];
      final String drugARu = TextMiningService.getRuName(drugA);
      final String drugBRu = TextMiningService.getRuName(drugB);

      final repo = InteractionRepository();
      // Ждем ответ от базы данных
      final interaction = await repo.findInteraction(drugA, drugB);

      // 3. ПРОВЕРКА MOUNTED. 
      // Пока мы ждали БД, пользователь мог нажать кнопку "Назад" и закрыть экран.
      // Если экран закрыт, context уничтожен. Дальше идти нельзя.
      if (!mounted) return;

      if (interaction == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Взаимодействия между выбранными препаратами не найдены')),
        );

        // Очищаем предыдущие результаты, если они были
        setState(() { checkResult = null; }); 
        return;
      }

      // Загружаем тексты инструкций в фоне
      final tempInstrA = await TextMiningService.loadAndProcessInstruction(drugA);
      final tempInstrB = await TextMiningService.loadAndProcessInstruction(drugB);

      // Проводим лингвистический анализ
      final tempTextResult = TextMiningService.searchTextEvidence(interaction, tempInstrA, tempInstrB);
      
      String tempSection = 'Раздел не определен';
      List<Evidence> tempEvidence = [];

      if (tempTextResult.fromA.isNotEmpty) {
        tempSection = TextMiningService.extractSection(tempInstrA);
        tempEvidence = TextMiningService.extractEvidence(tempSection, drugBRu, contextWindow: 1);
      } else if (tempTextResult.fromB.isNotEmpty) {
        tempSection = TextMiningService.extractSection(tempInstrB);
        tempEvidence = TextMiningService.extractEvidence(tempSection, drugARu, contextWindow: 1);
      }

      // Рассчитываем итоговый статус
      final finalStatus = TextMiningService.interpret(true, tempTextResult.found); // true, потому что взаимодействие уже найдено в базе, а текстовый поиск — это дополнительная проверка
      // но нужно изменить геттер found

      // Сохраняем ВСЁ разом в одну модель данных
      // Снова проверяем mounted, так как были новые await (чтение файлов инструкций)
      if (mounted) {
        setState(() {
          checkResult = InteractionResult(
            drugA: drugA,
            drugB: drugB,
            drugARu: drugARu,
            drugBRu: drugBRu,
            severity: interaction.severity,
            status: finalStatus,
            section: tempSection,
            evidence: tempEvidence,
          );
        });
      }
    } finally {
      // ГАРАНТИРОВАННЫЙ СБРОС ЗАГРУЗКИ
      // Этот код выполнится в 100% случаев: нашли мы результат, не нашли, или вылетела ошибка.
      if (mounted) {
        setState(() { isLoading = false; });
      }
    }
  }

  // Виджет карточки: только верстка, никакой бизнес-логики!
  Widget _buildResultCard(InteractionResult result) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Первая строка: Иконка + Заголовок
            Row(
              children: [
                Icon(
                  Icons.warning, 
                  color: result.severity == 'major' ? Colors.red : Colors.orange,
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

            // Вторая строка: Опасность
            Text(
              'Severity: ${result.severity}',
              style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),

            const Text(
              'Source: ',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              _getLabelForStatus(result.status), // Человекочитаемая интерпретация статуса
              style: TextStyle(
                fontSize: 14,
                color: _getColorForStatus(result.status),
              ),
            ),
            const SizedBox(height: 8),

            const Text(
              'Фрагмент из инструкции:',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              result.evidence.isNotEmpty 
                  ? result.evidence.map((e) => e.context).join('\n\n') 
                  : 'Нет упоминания о взаимодействии в инструкции.',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 8),

            const Text(
              'Section:',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ), 
            const SizedBox(height: 4),
            Text(
              result.section,
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 8),

            const Text(
              'Evidence:',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              result.evidence.isNotEmpty 
                  ? result.evidence.map((e) => e.sentence).join('\n\n') 
                  : 'Нет доказательств взаимодействия в инструкции.',
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ),
      ),
    );
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