import 'package:flutter/material.dart';
import '../services/interaction_service.dart';
import '../classes/interaction.dart';


class InteractionCheckScreen extends StatefulWidget {
  const InteractionCheckScreen({super.key});

  @override
  State<InteractionCheckScreen> createState() => _InteractionCheckScreenState();
}

class _InteractionCheckScreenState extends State<InteractionCheckScreen> {
  bool isLoading = true;
  List<String> selectedDrugs = []; // Список для хранения выбранных препаратов в уже нормализованном виде
  List<Interaction> foundInteractions = []; // может быть заменить на ddi (из service), но пока так для удобства доступа к методам класса Interaction
  String section = '';
  String? evidence = '';
  List<String> evidences = [];
  List<String> sentences = [];
  String instr_A = '';
  String instr_B = '';

  @override
  // Инициализация состояния и загрузка данных при открытии экрана
  void initState() {
    super.initState();
    // Вызываем загрузку данных при открытии экрана
    loadData();
  }

// Метод для проверки взаимодействий между выбранными препаратами
  /*void checkInteractions(List<String> drugs) {
    if (drugs.length < 2) return; // Проверяем, что выбрано хотя бы 2 препарата

    //final results = generateInteractions(drugs);
    final results = ddi.where((interaction) {
      return drugs.contains(interaction.drugA) && drugs.contains(interaction.drugB);
    }).toList();

    setState(() {
      foundInteractions = results;
    });
  }*/

  List<Interaction> getInteractions(List<String> drugs) {
    return ddi.where((interaction) {
      return drugs.contains(interaction.drugA) && drugs.contains(interaction.drugB);
    }).toList();
  }

 // функция JSON загрузки из interaction_service.dart
  Future<void> loadData() async {
    await loadInteractions();
    setState(() {
      isLoading = false; // Данные загружены, перерисовываем экран
    });
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
                          final String canonical = substanceToCanonical(controller.text);

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
                    final String canonical = substanceToCanonical(value);
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
                  onPressed: () async{
                    if (selectedDrugs.length < 2) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Пожалуйста, выберите хотя бы 2 препарата для проверки')),
                      );
                      return;
                    }

                    //checkInteractions(selectedDrugs);
                    foundInteractions = getInteractions(selectedDrugs); 

                    //instr_A = await loadAndProcessInstruction(selectedDrugs[0]);
                    //instr_B = await loadAndProcessInstruction(selectedDrugs[1]);
                    final tempInstrA = await loadAndProcessInstruction(selectedDrugs[0]);
                    final tempInstrB = await loadAndProcessInstruction(selectedDrugs[1]);

                    final String drugARu = getRuName(selectedDrugs[0]);
                    final String drugBRu = getRuName(selectedDrugs[1]);

                    //section = foundInteractions[0].extractInteractionSection(instr_A);
                    //evidence = foundInteractions[0].findMention(section, drugBRu);
                    //foundInteractions[0].instr_string = evidence ?? 'Информация о взаимодействии не найдена';
                    String tempSection = '';
                    String? tempEvidence = '';
                    List<String> tempSentences = [];
                    if (foundInteractions.isNotEmpty) {
                      tempSection = foundInteractions[0].extractInteractionSection(tempInstrA);
                      tempEvidence = foundInteractions[0].findMention(tempSection, drugBRu);
                      foundInteractions[0].instr_string = tempEvidence ?? 'Информация о взаимодействии не найдена';
                    }
                    
                    //sentences = extractInteractionSentences(instr_A, drugBRu);
                    tempSentences = extractInteractionSentences(tempInstrA, drugBRu);

                    setState(() {
                      //foundInteractions = results;
                      instr_A = tempInstrA;
                      instr_B = tempInstrB;
                      section = tempSection;
                      evidence = tempEvidence;
                      sentences = tempSentences;
                    });
                    
                    print(tempSentences);
                    print(transliterate("escitalopram")); // Проверка транслитерации

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
                    final String drugARu = getRuName(interaction.drugA);
                    final String drugBRu = getRuName(interaction.drugB);
                    TextSearchResult textSearchResult = searchTextEvidence(interaction, instr_A, instr_B);
                    final status = interpret(hasInteraction(interaction.drugA, interaction.drugB), textSearchResult.found);
                    //final status = InteractionStatus.ddiOnly; // status для тестирования отображения разных вариантов

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
                                const Icon(Icons.warning, color: Colors.red),
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
                              'Severity: ${interaction.severity}',
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
                              sentences.isNotEmpty ? sentences.join('\n\n') : 'Нет упоминания о взаимодействии в инструкции.',
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
                              section,
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
                              evidence ?? 'Нет упоминания о взаимодействии в инструкции.',
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