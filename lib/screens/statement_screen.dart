import 'package:flutter/material.dart';
import '../core/database_helper.dart';
import '../core/accounting_engine.dart';
import '../models/person_model.dart';
import '../models/trip_model.dart';
import '../models/payment_model.dart';

class StatementScreen extends StatefulWidget {
  const StatementScreen({Key? key}) : super(key: key);

  @override
  State<StatementScreen> createState() => _StatementScreenState();
}

class _StatementScreenState extends State<StatementScreen> {
  List<PersonModel> _persons = [];
  PersonModel? _selectedPerson;
  List<Map<String, dynamic>> _events = [];

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

  Future<void> _generateStatement(PersonModel person) async {
    final db = await DatabaseHelper.instance.database;
    final tMaps = await db.query('trips', where: 'person_id = ?', whereArgs: [person.id]);
    final pMaps = await db.query('payments', where: 'person_id = ?', whereArgs: [person.id]);

    final trips = tMaps.map((m) => TripModel.fromMap(m)).toList();
    final payments = pMaps.map((m) => PaymentModel.fromMap(m)).toList();

    setState(() {
      _selectedPerson = person;
      _events = AccountingEngine.calculateStatement(person, trips, payments);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('كشف الحساب المالي')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: DropdownButtonFormField<PersonModel>(
              value: _selectedPerson,
              decoration: const InputDecoration(labelText: 'اختر الطرف لعرض كشف الحساب'),
              items: _persons.map((p) => DropdownMenuItem(value: p, child: Text(p.name))).toList(),
              onChanged: (p) => p != null ? _generateStatement(p) : null,
            ),
          ),
          if (_selectedPerson != null && _events.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              color: Colors.blue.shade50,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('الرصيد النهائي: ${_events.last['balance'].toStringAsFixed(2)} ج.م',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(_events.last['balance'] > 0 ? 'لك عنده' : 'له عندك',
                      style: TextStyle(color: _events.last['balance'] > 0 ? Colors.green : Colors.red, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          Expanded(
            child: ListView.builder(
              itemCount: _events.length,
              itemBuilder: (ctx, i) {
                final ev = _events[i];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  child: ListTile(
                    title: Text('${ev['type']} - ${ev['desc']}'),
                    subtitle: Text('التاريخ: ${ev['date']} | مدين: ${ev['debit']} | دائن: ${ev['credit']}'),
                    trailing: Text('${ev['balance'].toStringAsFixed(2)} ج.م', style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
