import 'package:sqflite/sqflite.dart';
import 'asset_database_opener.dart';

// Singleton + Lazy initialization для справочника ЕСКЛП (торговые названия, МНН, ATC, фармгруппы на русском).
class EsklDbService {
  static final EsklDbService instance = EsklDbService._();

  EsklDbService._();

  Database? _database;
  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    return openAssetDatabase(
      assetPath: 'assets/database/eskl_unique.db',
      dbFileName: 'eskl_unique.db',
      forceRecopy: false, // read-only справочник, пересоздавать локальную копию при каждом запуске не нужно
    );
  }
}
