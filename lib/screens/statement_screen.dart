import 'package:flutter/material.dart';
import '../core/database_helper.dart';
import '../models/person_model.dart';
import '../models/trip_model.dart';
import '../models/payment_model.dart';
import '../core/pdf_generator.dart';

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

    List<Map<String, dynamic>> rawEvents = [];

    // 1. تجميع النقلات
    for (var t in trips) {
      final isSale = t.operation == 'sale';
      rawEvents.add({
        'date': t.date,
        'action': isSale ? 'بيع' : 'شراء',
        'item': t.item,
        'desc': t.item,
        'vehicle': t.vehicle,
        'driver': t.driver,
        'weight': t.weight,
        'price': t.price,
        'debit': isSale ? t.total : 0.0,
        'credit': isSale ? 0.0 : t.total,
      });
    }

    // 2. تجميع السندات
    for (var p in payments) {
      final isFromCustomer = p.direction == 'from_customer';
      rawEvents.add({
        'date': p.date,
        'action': 'سداد',
        'item': p.description.isNotEmpty ? p.description : 'دفعة نقدية',
        'desc': p.description.isNotEmpty ? p.description : 'دفعة نقدية',
        'vehicle': '',
        'driver': '',
        'weight': 0.0,
        'price': 0.0,
        'debit': isFromCustomer ? 0.0 : p.amount,
        'credit': isFromCustomer ? p.amount : 0.0,
      });
    }

    // 3. ترتيب الأحداث بالتاريخ تصاعدياً
    rawEvents.sort((a, b) => (a['date'] as String).compareTo(b['date'] as String));

    // 4. احتساب الرصيد التراكمي
    double runningBalance = 0.0;
    for (var ev in rawEvents) {
      final debit = (ev['debit'] as num).toDouble();
      final credit = (ev['credit'] as num).toDouble();
      runningBalance += (debit - credit);
      ev['balance'] = runningBalance;
    }

    setState(() {
      _selectedPerson = person;
      _events = rawEvents;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('كشف الحساب المالي'),
        actions: [
          if (_selectedPerson != null && _events.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.picture_as_pdf, color: Colors.red),
              tooltip: 'تصدير PDF',
              onPressed: () {
                PdfGenerator.generateAndPrintStatement(
                  person: _selectedPerson!,
                  events: _events,
                );
              },
            ),
        ],
      ),
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
                  Text(
                    'الرصيد النهائي: ${_events.last['balance'].toStringAsFixed(2)} ج.م',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  Text(
                    _events.last['balance'] >= 0 ? 'لك عنده' : 'له عندك',
                    style: TextStyle(
                      color: _events.last['balance'] >= 0 ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
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
                    title: Text('${ev['action']} - ${ev['desc']}'),
                    subtitle: Text('التاريخ: ${ev['date']} | مدين: ${ev['debit']} | دائن: ${ev['credit']}'),
                    trailing: Text(
                      '${ev['balance'].toStringAsFixed(2)} ج.م',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
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
