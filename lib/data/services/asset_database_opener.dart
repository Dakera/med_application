import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

// Общая логика открытия SQLite-базы, поставляемой как asset:
// копирует файл из assets в documents dir приложения (если его там ещё нет) и открывает его.
// Используется всеми *DbService, чтобы не дублировать этот код под каждую базу.
Future<Database> openAssetDatabase({
  required String assetPath, // например 'assets/database/chembl_37.db'
  required String dbFileName, // например 'chembl_37.db'
  bool forceRecopy = false, // true — пересоздавать локальную копию при каждом запуске (dev-режим)
}) async {
  final documentsDir = await getApplicationDocumentsDirectory();
  final dbPath = join(documentsDir.path, dbFileName);

  if (forceRecopy) {
    await deleteDatabase(dbPath);
  }

  final exists = await File(dbPath).exists();
  if (!exists) {
    final data = await rootBundle.load(assetPath);
    final bytes = data.buffer.asUint8List();
    await File(dbPath).writeAsBytes(bytes, flush: true);
  }

  return await openDatabase(dbPath);
}
