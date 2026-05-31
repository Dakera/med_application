import 'package:sqflite/sqflite.dart';
import '../../classes/interaction.dart';
import '../services/db_service.dart';

class InteractionRepository {
  Future<Interaction?> findInteraction(
    String drugA,
    String drugB,
  ) async {

    final db =
        await DatabaseService.instance.database;


    final result = await db.query(
      'PAIRS',
      where: '''
        (Drug_A = ? AND Drug_B = ?)
        OR
        (Drug_A = ? AND Drug_B = ?)
      ''',
      whereArgs: [
        drugA.trim().toLowerCase(), // Только если в базе данные в нижнем регистре
        drugB.trim().toLowerCase(),
        drugB.trim().toLowerCase(),
        drugA.trim().toLowerCase(),
      ],
      limit: 1,
    );

    final count = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM Pairs'
    );
    print(count);
        

    if (result.isEmpty) {
      return null;
    }

    return Interaction.fromMap(result.first);
    /*
    final row = result.first;
    return Interaction(
      drugA: row['Drug_A'] as String,
      drugB: row['Drug_B'] as String,
      severity: row['Level'] as String,
    );*/
  }
}

