import 'package:sqflite/sqflite.dart';
import 'asset_database_opener.dart';

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
    return openAssetDatabase(
      assetPath: 'assets/database/Interaction_pairs.db',
      dbFileName: 'Interaction_pairs.db',
      forceRecopy: true, // для разработки, чтобы всегда начинать с чистой базы
    );
  }
}
