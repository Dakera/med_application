import 'package:flutter/material.dart';
import '../../models/text_search_result.dart';
import '../../models/interaction.dart';
import '../../models/evidence.dart';
import '../../data/repositories/interaction_repository.dart';
import '../../data/services/text_mining_service.dart';


class InteractionCheckScreen extends StatefulWidget {
  const InteractionCheckScreen({super.key});

  @override
  State<InteractionCheckScreen> createState() => _InteractionCheckScreenState();
}

class _InteractionCheckScreenState extends State<InteractionCheckScreen> {
  bool isLoading = false; // потому что теперь ленивая загрузка, мы не грузим целиком бд в память
  List<String> selectedDrugs = []; // Список для хранения выбранных препаратов в уже нормализованном виде
  List<Interaction?> foundInteractions = []; // может быть заменить на ddi (из service), но пока так для удобства доступа к методам класса Interaction
  String? sectionA = '';
  String? sectionB = '';
  String? section = '';
  //List<String> evidences = [];
  List<String> sentencesA = [];
  List<String> sentencesB = [];
  List<String> sentences = [];
  List<Evidence> evidenceA = [];
  List<Evidence> evidenceB = [];
  List<Evidence> evidence = [];
  String instr_A = '';
  String instr_B = '';
  String instr_Used = '';


  @override
  // Инициализация состояния и загрузка данных при открытии экрана
  void initState() {
    super.initState();
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
        actions: [
          IconButton(
            icon: const Icon(Icons.favorite),
            tooltip: 'Отслеживаемые',
            onPressed: () {
              /*Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TrackedMedicationsScreen(
                    initialMedications: TrackedMedicationsStore().trackedMedications,
                  ),
                ),
              );*/
            },
          ),
          IconButton(
            icon: const Icon(Icons.list),
            tooltip: 'Все препараты',
            onPressed: () {
              /*Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MedicationListScreen()),
              );*/
            },
          ),
        ],
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
            Autocomplete<String>(
              optionsBuilder: (TextEditingValue textEditingValue) {
                return const Iterable<String>.empty();
              },
              onSelected: (String selection) {
                // Добавляем выбранное лекарство в наш массив
                setState(() {
                  if (!selectedDrugs.contains(selection)) {
                    selectedDrugs.add(selection);
                  }
                });
                print('Добавлено: $selection');
              },
              fieldViewBuilder:(context, controller, focusNode, onEditingComplete) {
                return TextField(
                  controller: controller,
                  focusNode: focusNode,
                  onEditingComplete: onEditingComplete,
                  decoration: InputDecoration(
                    labelText: 'Введите название препарата',
                    hintText: 'Например: escitalopram sertraline',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    suffixIcon: IconButton( // Добавим кнопку для явного добавления
                      icon: const Icon(Icons.add),
                      onPressed: () {
                        if (controller.text.isNotEmpty) {
                          // 1. Сразу превращаем в каноничный ключ (например, "escitalopram")
                          final String canonical = TextMiningService.substanceToCanonical(controller.text);

                          setState(() {
                            if (!selectedDrugs.contains(canonical)) {
                              selectedDrugs.add(canonical);
                            }
                          });
                          print('Добавлено: $canonical');
                          controller.clear(); // Очищаем поле после добавления
                        }
                      },
                    ),
                  ),
                  onSubmitted: (value) {
                    final String canonical = TextMiningService.substanceToCanonical(value);
                    if (value.isNotEmpty) {
                      setState(() {
                        if (!selectedDrugs.contains(canonical)) {
                          selectedDrugs.add(canonical);
                        }
                      });
                      print('Добавлено: $canonical');
                      controller.clear(); // Очищаем поле после добавления
                    }
                  },
                );
              },
            ),
            const SizedBox(height: 16), // Отступ сверху
            Center(
              child: Wrap(
                spacing: 8.0, // Расстояние между квадратиками по горизонтали
                runSpacing: 4.0, // Расстояние между строками, если будет перенос
                children: selectedDrugs.map((drug) {
                  return Chip(
                    backgroundColor: Colors.blue.shade100, // Цвет квадратика
                    label: Text(drug),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8), // Скругляем до состояния "квадратика"
                    ),
                    deleteIcon: const Icon(Icons.close, size: 18),
                    onDeleted: () {
                      setState(() {
                        selectedDrugs.remove(drug); // Удаление из списка
                      });
                    },
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),
              Center(
                child: ElevatedButton(
                  onPressed: () async {
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
                        // Экран жив, можем безопасно показывать SnackBar
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Взаимодействия между выбранными препаратами не найдены')),
                        );
                        
                        // Очищаем предыдущие результаты, если они были
                        setState(() { foundInteractions = []; }); 
                        return; // Выходим. Блок finally сам выключит isLoading!
                      }

                      // 4. ПРАВИЛЬНОЕ ПРИСВОЕНИЕ В СПИСОК
                      // Создаем новый список с одним элементом, вместо обращения к несуществующему индексу [0]
                      foundInteractions = [interaction];

                      // Загружаем инструкции
                      final tempInstrA = await TextMiningService.loadAndProcessInstruction(drugA);
                      final tempInstrB = await TextMiningService.loadAndProcessInstruction(drugB);

                      // Ищем текст
                      TextSearchResult tempTextResult = TextMiningService.searchTextEvidence(interaction, tempInstrA, tempInstrB);
                      
                      String tempSection = 'Раздел не определен';
                      List<Evidence> tempEvidence = [];

                      if (tempTextResult.fromA.isNotEmpty) {
                        tempSection = TextMiningService.extractSection(tempInstrA);
                        tempEvidence = TextMiningService.extractEvidence(tempSection, drugBRu, contextWindow: 1);
                      } else if (tempTextResult.fromB.isNotEmpty) {
                        tempSection = TextMiningService.extractSection(tempInstrB);
                        tempEvidence = TextMiningService.extractEvidence(tempSection, drugARu, contextWindow: 1);
                      }

                      // 5. ФИНАЛЬНЫЙ ОБНОВЛЕННЫЙ STATE
                      // Снова проверяем mounted, так как были новые await (чтение файлов инструкций)
                      if (mounted) {
                        setState(() {
                          instr_A = tempInstrA;
                          instr_B = tempInstrB;
                          section = tempSection;
                          evidence = tempEvidence;
                          // isLoading = false; <-- Убираем отсюда, это сделает finally
                        });
                      }

                    } finally {
                      // 6. ГАРАНТИРОВАННЫЙ СБРОС ЗАГРУЗКИ
                      // Этот код выполнится в 100% случаев: нашли мы результат, не нашли, или вылетела ошибка.
                      if (mounted) {
                        setState(() { isLoading = false; });
                      }
                    }
                  },
                  child: const Text('Проверить взаимодействия'),
                ),
              ),  
            const SizedBox(height: 24),
            if (foundInteractions.isNotEmpty) 
              Expanded(
                child: ListView.builder(
                  itemCount: foundInteractions.length,
                  itemBuilder: (context, index) {
                    final interaction = foundInteractions[index];
                    final String? drugARu = TextMiningService.getRuName(interaction?.drugA ?? '');
                    final String? drugBRu = TextMiningService.getRuName(interaction?.drugB ?? '');
                    TextSearchResult textSearchResult = TextMiningService.searchTextEvidence(interaction, instr_A, instr_B);
                    final status = TextMiningService.interpret(interaction != null, textSearchResult.found); // переделать второе, не на основе просто секции, а на основе доказательств

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start, // Выравнивание текста по левому краю
                          children: [
                            // Первая строка: Иконка + Заголовок
                            Row(
                              children: [
                                Icon(Icons.warning, color: interaction?.severity == 'major' ? Colors.red : Colors.orange),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    '$drugARu + $drugBRu', // Показываем названия на русском, если есть
                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8), // Промежуток

                            // Вторая строка: Опасность
                            Text(
                              'Severity: ${interaction?.severity}',
                              style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 8),

                            Text(
                              'Source: ',
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              status == InteractionStatus.confirmedByText
                                  ? 'База + инструкция'
                                  : status == InteractionStatus.ddiOnly
                                      ? 'Взаимодействие указано в базе\nПодтверждение в инструкции не найдено'
                                      : status == InteractionStatus.textOnly
                                          ? 'Потенциальное взаимодействие\nУпоминание найдено в инструкции'
                                          : 'Нет данных о взаимодействии',
                              style: TextStyle(
                                fontSize: 14,
                                color: status == InteractionStatus.confirmedByText
                                    ? const Color.fromARGB(255, 255, 12, 12)
                                    : status == InteractionStatus.ddiOnly
                                        ? Colors.orange
                                        : status == InteractionStatus.textOnly
                                            ? Colors.blue
                                            : Colors.grey,
                                //fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),

                            // Третья строка: Инструкция (теперь она может быть любой длины)
                            const Text(
                              'Фрагмент из инструкции:',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              //sentences.isNotEmpty ? sentences.join('\n\n') : 'Нет упоминания о взаимодействии в инструкции.',
                              evidence.isNotEmpty ? evidence.map((e) => e.context).join('\n\n') : 'Нет упоминания о взаимодействии в инструкции.',
                              style: const TextStyle(fontSize: 14),
                            ),
                            const SizedBox(height: 8),

                            // Четвертая строка
                            const Text(
                              'section:',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                            ), 
                            const SizedBox(height: 4),
                            Text(
                              section ?? "Нет информации о разделе инструкции, где упоминается взаимодействие.",
                              style: const TextStyle(fontSize: 14),
                            ),
                            const SizedBox(height: 8),

                            // Пятая строка
                            const Text(
                              'evidence:',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              evidence.isNotEmpty ? evidence.map((e) => e.sentence).join('\n\n') : 'Нет доказательств взаимодействия в инструкции.',
                              style: const TextStyle(fontSize: 14),
                            ),
                            
                            
                          ],
                        ),
                      ),
                    );
                  },
                )
              )
          ],
        ),
      ),

    );
  }
}