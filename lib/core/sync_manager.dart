import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'database_helper.dart';

class SyncManager {
  static final SyncManager instance = SyncManager._init();
  SyncManager._init();

  void init() {
    // 1. استرجاع البيانات من السحابة فوراً عند فتح التطبيق
    pullAllFromCloud();

    // 2. مراقبة عودة الاتصال لمزامنة التعديلات المعلقة
    Connectivity().onConnectivityChanged.listen((result) {
      if (result != ConnectivityResult.none) {
        syncPending();
        pullAllFromCloud();
      }
    });
  }

  /// إرسال العمليات المحلية إلى السحابة
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
        break;
      }
    }
  }

  /// استرجاع وسحب كل البيانات من Supabase وتخزينها محلياً (Restore)
  Future<void> pullAllFromCloud() async {
    try {
      final client = Supabase.instance.client;
      final db = await DatabaseHelper.instance.database;

      // سحب الأشخاص
      final personsData = await client.from('persons').select();
      for (var p in personsData) {
        await db.insert('persons', Map<String, dynamic>.from(p), conflictAlgorithm: ConflictAlgorithm.replace);
      }

      // سحب النقلات
      final tripsData = await client.from('trips').select();
      for (var t in tripsData) {
        await db.insert('trips', Map<String, dynamic>.from(t), conflictAlgorithm: ConflictAlgorithm.replace);
      }

      // سحب السدادات
      final paymentsData = await client.from('payments').select();
      for (var py in paymentsData) {
        await db.insert('payments', Map<String, dynamic>.from(py), conflictAlgorithm: ConflictAlgorithm.replace);
      }
    } catch (_) {
      // التجاهل في حال عدم وجود إنترنت، والاستمرار بالبيانات المحلية
    }
  }
}
