import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../core/database_helper.dart';
import '../core/sync_manager.dart';
import '../models/person_model.dart';
import 'settings_screen.dart';

class PersonsScreen extends StatefulWidget {
  const PersonsScreen({Key? key}) : super(key: key);

  @override
  State<PersonsScreen> createState() => _PersonsScreenState();
}

class _PersonsScreenState extends State<PersonsScreen> {
  List<PersonModel> _persons = [];

  @override
  void initState() {
    super.initState();
    _loadPersons();
  }

  Future<void> _loadPersons() async {
    final db = await DatabaseHelper.instance.database;
    final maps = await db.query('persons', orderBy: 'name ASC');
    setState(() {
      _persons = maps.map((m) => PersonModel.fromMap(m)).toList();
    });
  }

  void _openPersonDialog({PersonModel? existing}) {
    final isEdit = existing != null;
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final phoneCtrl = TextEditingController(text: existing?.phone ?? '');
    final addressCtrl = TextEditingController(text: existing?.address ?? '');
    final recCtrl = TextEditingController(text: existing?.openingReceivable.toString() ?? '0');
    final payCtrl = TextEditingController(text: existing?.openingPayable.toString() ?? '0');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEdit ? 'تعديل طرف' : 'إضافة طرف جديد'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'الاسم الكامل'), validator: (v) => v!.isEmpty ? 'مطلوب' : null),
                TextFormField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'رقم الهاتف'), keyboardType: TextInputType.phone),
                TextFormField(controller: addressCtrl, decoration: const InputDecoration(labelText: 'العنوان')),
                Row(
                  children: [
                    Expanded(child: TextFormField(controller: recCtrl, decoration: const InputDecoration(labelText: 'أول المدة: لك عنده'), keyboardType: TextInputType.number)),
                    const SizedBox(width: 8),
                    Expanded(child: TextFormField(controller: payCtrl, decoration: const InputDecoration(labelText: 'أول المدة: له عندك'), keyboardType: TextInputType.number)),
                  ],
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final rec = double.tryParse(recCtrl.text) ?? 0.0;
              final pay = double.tryParse(payCtrl.text) ?? 0.0;
              final db = await DatabaseHelper.instance.database;

              if (isEdit) {
                final authOk = await SettingsScreen.verifyPassword(context);
                if (!authOk) return;

                final updated = PersonModel(id: existing.id, name: nameCtrl.text.trim(), phone: phoneCtrl.text, address: addressCtrl.text, openingReceivable: rec, openingPayable: pay);
                await db.update('persons', updated.toMap(), where: 'id = ?', whereArgs: [existing.id]);
                await SyncManager.instance.queueSync('persons', 'UPDATE', existing.id);
              } else {
                final newP = PersonModel(id: const Uuid().v4(), name: nameCtrl.text.trim(), phone: phoneCtrl.text, address: addressCtrl.text, openingReceivable: rec, openingPayable: pay);
                await db.insert('persons', newP.toMap());
                await SyncManager.instance.queueSync('persons', 'INSERT', newP.id);
              }
              Navigator.pop(ctx);
              _loadPersons();
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('العملاء والموردون')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openPersonDialog(),
        child: const Icon(Icons.person_add),
      ),
      body: ListView.builder(
        itemCount: _persons.length,
        itemBuilder: (ctx, i) {
          final p = _persons[i];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person)),
              title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('${p.phone.isNotEmpty ? p.phone : "بدون هاتف"} | ${p.address}'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(icon: const Icon(Icons.edit, size: 20), onPressed: () => _openPersonDialog(existing: p)),
                  IconButton(
                    icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                    onPressed: () async {
                      final authOk = await SettingsScreen.verifyPassword(context);
                      if (!authOk) return;
                      final db = await DatabaseHelper.instance.database;
                      await db.delete('persons', where: 'id = ?', whereArgs: [p.id]);
                      await SyncManager.instance.queueSync('persons', 'DELETE', p.id);
                      _loadPersons();
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

