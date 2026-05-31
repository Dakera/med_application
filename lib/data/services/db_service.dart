import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

// Singleton + Lazy initialization для управления базой данных взаимодействий
class DatabaseService { 
  static final DatabaseService instance = 
      DatabaseService._();              // Создаём единственный экземпляр класса DatabaseService
  
  DatabaseService._();                  // Приватный конструктор для реализации паттерна Singleton
  // Единственный способ взаимодействия с классом — использование созданной выше переменной DatabaseService.instance

  Database? _database;                  // Приватная переменная для хранения экземпляра базы данных, изначально null (lazy initialization)
  Future<Database> get database async { // Геттер для получения экземпляра базы данных, который инициализируется при первом обращении
    if (_database != null) {
      return _database!;
    }
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final documentsDir =
        await getApplicationDocumentsDirectory(); // path_provider ios/android

    final dbPath = join(      // path package для кроссплатформенной работы с путями
      documentsDir.path,      // объединяет путь к директории документов (documentsDir.path) и имя файла 'Interaction_pairs.db'
      'Interaction_pairs.db', // Она автоматически учитывает специфику ОС (ставит / для iOS/Android или \ для Windows)
    );
    
    await deleteDatabase(dbPath); // Удаляем существующую базу данных (для разработки, чтобы всегда начинать с чистой базы)

    final exists = await File(dbPath).exists(); // Проверяем, существует ли уже база данных по этому пути
    if (!exists) {                              // Если база данных не существует, копируем её из ассетов
      final data = await rootBundle.load(       // Читаем файл
        'assets/database/Interaction_pairs.db',
      );                                        // Получаем данные в виде ByteData

      final bytes = data.buffer.asUint8List();  // Преобразуем ByteData в Uint8List, который можно записать в файл
      await File(dbPath).writeAsBytes(          // Записываем байты в новый рабочий файл по пути dbPath
        bytes,
        flush: true,                            // flush: true гарантирует, что данные будут записаны на диск немедленно, а не сохранены в буфере. Это важно для обеспечения целостности данных, особенно при работе с базами данных.
      );
    }
    return await openDatabase(dbPath);          // Открываем базу данных и возвращаем её
  }
}