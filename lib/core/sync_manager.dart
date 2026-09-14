import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'database_helper.dart';

class SyncManager {
  static final SyncManager instance = SyncManager._init();
  SyncManager._init();

  void init() {
    Connectivity().onConnectivityChanged.listen((result) {
      if (result != ConnectivityResult.none) {
        syncPending();
      }
    });
  }

  Future<void> queueSync(String table, String action, String recordId) async {
    final db = await DatabaseHelper.instance.database;
    await db.insert('sync_queue', {
      'table_name': table,
      'action': action,
      'record_id': recordId,
      'created_at': DateTime.now().toIso8601String(),
    });
    syncPending();
  }

  Future<void> syncPending() async {
    final db = await DatabaseHelper.instance.database;
    final List<Map<String, dynamic>> queue = await db.query('sync_queue', orderBy: 'id ASC');
    if (queue.isEmpty) return;

    final client = Supabase.instance.client;

    for (var item in queue) {
      try {
        final table = item['table_name'] as String;
        final action = item['action'] as String;
        final recordId = item['record_id'] as String;

        if (action == 'INSERT' || action == 'UPDATE') {
          final records = await db.query(table, where: 'id = ?', whereArgs: [recordId]);
          if (records.isNotEmpty) {
            await client.from(table).upsert(records.first);
          }
        } else if (action == 'DELETE') {
          await client.from(table).delete().eq('id', recordId);
        }

        await db.delete('sync_queue', where: 'id = ?', whereArgs: [item['id']]);
      } catch (_) {
        break; // التوقف في حال تعذر الاتصال وإعادة المحاولة لاحقاً
      }
    }
  }
}

