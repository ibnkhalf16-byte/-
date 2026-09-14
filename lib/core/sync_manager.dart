import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'database_helper.dart';

class SyncManager {
  static final SyncManager instance = SyncManager._init();
  SyncManager._init();

  void init() {
    // محاولة جلب السجلات من السحابة فور تشغيل التطبيق
    pullAllFromCloud();

    // الاستماع لحالة الإنترنت والمزامنة التلقائية فور توفر اتصال
    Connectivity().onConnectivityChanged.listen((result) {
      if (result != ConnectivityResult.none) {
        syncPending();
        pullAllFromCloud();
      }
    });
  }

  /// تسجيل العملية ليتم رفعها للسحابة فوراً
  Future<void> queueSync(String table, String action, String recordId) async {
    final db = await DatabaseHelper.instance.database;
    await db.insert('sync_queue', {
      'table_name': table,
      'action': action,
      'record_id': recordId,
      'created_at': DateTime.now().toIso8601String(),
    });
    await syncPending();
  }

  /// رفع العمليات المعلقة إلى Supabase
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

  /// سحب كامل البيانات من Supabase وتخزينها في الهاتف (Restore)
  Future<bool> pullAllFromCloud() async {
    try {
      final client = Supabase.instance.client;
      final db = await DatabaseHelper.instance.database;

      // سحب جدول العملاء والموردين
      final List<dynamic> persons = await client.from('persons').select();
      for (var p in persons) {
        await db.insert('persons', Map<String, dynamic>.from(p), conflictAlgorithm: ConflictAlgorithm.replace);
      }

      // سحب جدول النقلات
      final List<dynamic> trips = await client.from('trips').select();
      for (var t in trips) {
        await db.insert('trips', Map<String, dynamic>.from(t), conflictAlgorithm: ConflictAlgorithm.replace);
      }

      // سحب جدول السدادات
      final List<dynamic> payments = await client.from('payments').select();
      for (var py in payments) {
        await db.insert('payments', Map<String, dynamic>.from(py), conflictAlgorithm: ConflictAlgorithm.replace);
      }

      return true;
    } catch (_) {
      return false;
    }
  }
}
