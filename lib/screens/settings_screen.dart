import 'package:flutter/material.dart';
import 'package:crypto/crypto.dart';
import 'package:sqflite/sqflite.dart';
import 'dart:convert';
import '../core/database_helper.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  static Future<bool> verifyPassword(BuildContext context) async {
    final pwdCtrl = TextEditingController();
    final db = await DatabaseHelper.instance.database;
    final row = await db.query('settings', where: 'key = ?', whereArgs: ['password_hash']);
    final storedHash = row.isNotEmpty ? row.first['value'] as String : sha256.convert(utf8.encode('1234')).toString();

    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('حماية العمليات'),
        content: TextField(
          controller: pwdCtrl,
          decoration: const InputDecoration(labelText: 'أدخل كلمة المرور لتأكيد العملية'),
          obscureText: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () {
              final enteredHash = sha256.convert(utf8.encode(pwdCtrl.text)).toString();
              if (enteredHash == storedHash) {
                Navigator.pop(ctx, true);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('كلمة المرور غير صحيحة!')));
              }
            },
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _oldPwdCtrl = TextEditingController();
  final _newPwdCtrl = TextEditingController();

  Future<void> _updatePassword() async {
    final db = await DatabaseHelper.instance.database;
    final row = await db.query('settings', where: 'key = ?', whereArgs: ['password_hash']);
    final storedHash = row.isNotEmpty ? row.first['value'] as String : sha256.convert(utf8.encode('1234')).toString();

    if (sha256.convert(utf8.encode(_oldPwdCtrl.text)).toString() != storedHash) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('كلمة المرور الحالية غير صحيحة!')));
      return;
    }

    if (_newPwdCtrl.text.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يجب أن تكون كلمة المرور 4 رموز على الأقل')));
      return;
    }

    final newHash = sha256.convert(utf8.encode(_newPwdCtrl.text)).toString();
    await db.insert('settings', {'key': 'password_hash', 'value': newHash}, conflictAlgorithm: ConflictAlgorithm.replace);

    _oldPwdCtrl.clear();
    _newPwdCtrl.clear();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تغيير كلمة المرور بنجاح ✅')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الإعدادات والأمان')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('تغيير كلمة المرور الرئيسية', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 10),
            TextField(controller: _oldPwdCtrl, decoration: const InputDecoration(labelText: 'كلمة المرور الحالية'), obscureText: true),
            TextField(controller: _newPwdCtrl, decoration: const InputDecoration(labelText: 'كلمة المرور الجديدة'), obscureText: true),
            const SizedBox(height: 15),
            ElevatedButton(onPressed: _updatePassword, child: const Text('تحديث كلمة المرور')),
            const SizedBox(height: 20),
            const Text('كلمة المرور الافتراضية لأول تشغيل هي: 1234', style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
