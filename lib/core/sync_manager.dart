import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'database_helper.dart';

class SyncManager {
  static final SyncManager instance = SyncManager._init();
  SyncManager._init();

  void init() {
    pullAllFromCloud();

    Connectivity().onConnectivityChanged.listen((result) {
      if (result != ConnectivityResult.none) {
        syncPending();
        pullAllFromCloud();
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
    await syncPending();
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
            final data = Map<String, dynamic>.from(records.first);
            data.remove('created_at');
            await client.from(table).upsert(data);
          }
        } else if (action == 'DELETE') {
          await client.from(table).delete().eq('id', recordId);
        }

        await db.delete('sync_queue', where: 'id = ?', whereArgs: [item['id']]);
      } catch (e) {
        debugPrint('Error syncing item: $e');
        break;
      }
    }
  }

  Future<String> pullAllFromCloud() async {
    try {
      final client = Supabase.instance.client;
      final db = await DatabaseHelper.instance.database;

      // 1. مزامنة الأشخاص
      final List<dynamic> persons = await client.from('persons').select();
      for (var p in persons) {
        await db.insert('persons', Map<String, dynamic>.from(p), conflictAlgorithm: ConflictAlgorithm.replace);
      }

      // 2. مزامنة النقلات
      final List<dynamic> trips = await client.from('trips').select();
      for (var t in trips) {
        await db.insert('trips', Map<String, dynamic>.from(t), conflictAlgorithm: ConflictAlgorithm.replace);
      }

      // 3. مزامنة السدادات
      final List<dynamic> payments = await client.from('payments').select();
      for (var py in payments) {
        await db.insert('payments', Map<String, dynamic>.from(py), conflictAlgorithm: ConflictAlgorithm.replace);
      }

      // رفع البيانات المحلية المعلقة
      await uploadAllLocalData();

      return 'ok';
    } catch (e) {
      debugPrint('Sync failed: $e');
      return e.toString();
    }
  }

  Future<void> uploadAllLocalData() async {
    try {
      final client = Supabase.instance.client;
      final db = await DatabaseHelper.instance.database;

      final localPersons = await db.query('persons');
      for (var p in localPersons) {
        final data = Map<String, dynamic>.from(p);
        data.remove('created_at');
        await client.from('persons').upsert(data);
      }

      final localTrips = await db.query('trips');
      for (var t in localTrips) {
        final data = Map<String, dynamic>.from(t);
        data.remove('created_at');
        await client.from('trips').upsert(data);
      }

      final localPayments = await db.query('payments');
      for (var py in localPayments) {
        final data = Map<String, dynamic>.from(py);
        data.remove('created_at');
        await client.from('payments').upsert(data);
      }
    } catch (e) {
      debugPrint('Upload error: $e');
    }
  }
}
