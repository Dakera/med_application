import 'dart:convert'; 
import 'package:flutter/services.dart';
import '../classes/interaction.dart';

List<Interaction> ddi = []; // Наш пустой список

Future<void> loadInteractions() async {
  try {
    // 1. Читаем файл из ассетов как строку
    final String response = await rootBundle.loadString('assets/data/test_data.json');
    
    // 2. Декодируем строку в List
    final List<dynamic> data = json.decode(response);
    
    // 3. Преобразуем каждый элемент в объект Interaction и сохраняем в ddi
    ddi = data.map((jsonItem) => Interaction.fromJson(jsonItem)).toList();
    
    print("Загружено взаимодействий: ${ddi.length}");
  } catch (e) {
    print("Ошибка при загрузке JSON: $e");
  }
}

bool hasInteraction(String a, String b) {
  final drug1 = a.trim().toLowerCase();
  final drug2 = b.trim().toLowerCase();

  return ddi.any((row) {
    final dbA = row.drugA.toLowerCase();
    final dbB = row.drugB.toLowerCase();
    
    return (dbA == drug1 && dbB == drug2) || 
           (dbA == drug2 && dbB == drug1);
  });
}