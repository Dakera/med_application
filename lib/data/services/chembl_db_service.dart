import 'package:sqflite/sqflite.dart';
import 'asset_database_opener.dart';

// Singleton + Lazy initialization для справочной базы ChEMBL (ATC-коды, торговые названия и т.д.)
class ChemblDbService {
  static final ChemblDbService instance = ChemblDbService._();

  ChemblDbService._();

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
      assetPath: 'assets/database/chembl_37.db',
      dbFileName: 'chembl_37.db',
      forceRecopy: false, // read-only справочник, пересоздавать локальную копию при каждом запуске не нужно
    );
  }
}
