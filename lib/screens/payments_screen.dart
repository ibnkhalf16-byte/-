import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import '../core/database_helper.dart';
import '../core/sync_manager.dart';
import '../models/payment_model.dart';
import '../models/person_model.dart';
import 'settings_screen.dart';

class PaymentsScreen extends StatefulWidget {
  const PaymentsScreen({Key? key}) : super(key: key);

  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
  List<PaymentModel> _payments = [];
  List<PersonModel> _persons = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final db = await DatabaseHelper.instance.database;
    final pMaps = await db.query('persons', orderBy: 'name ASC');
    final payMaps = await db.rawQuery('''
      SELECT py.*, p.name as person_name 
      FROM payments py 
      JOIN persons p ON py.person_id = p.id 
      ORDER BY py.date DESC
    ''');

    setState(() {
      _persons = pMaps.map((m) => PersonModel.fromMap(m)).toList();
      _payments = payMaps.map((m) => PaymentModel.fromMap(m)).toList();
    });
  }

  void _openPaymentDialog({PaymentModel? existing}) {
    final isEdit = existing != null;
    final formKey = GlobalKey<FormState>();
    String? selectedPerson = existing?.personId;
    String direction = existing?.direction ?? 'to_supplier';

    // تاريخ السند
    DateTime selectedDate = existing != null
        ? (DateTime.tryParse(existing.date) ?? DateTime.now())
        : DateTime.now();

    final dateCtrl = TextEditingController(
      text: DateFormat('yyyy-MM-dd').format(selectedDate),
    );
    final amtCtrl = TextEditingController(text: existing?.amount.toString() ?? '');
    final descCtrl = TextEditingController(text: existing?.description ?? '');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: Text(isEdit ? 'تعديل سند' : 'تسجيل سند جديد'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // اختيار تاريخ السند
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(color: Colors.grey.shade300),
                    ),
                    title: Text(
                      'تاريخ السند: ${dateCtrl.text}',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    trailing: const Icon(Icons.calendar_month, color: Colors.green),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2035),
                      );
                      if (picked != null) {
                        setModalState(() {
                          selectedDate = picked;
                          dateCtrl.text = DateFormat('yyyy-MM-dd').format(picked);
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: selectedPerson,
                    decoration: const InputDecoration(labelText: 'اختر الطرف'),
                    items: _persons.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name))).toList(),
                    onChanged: (v) => setModalState(() => selectedPerson = v),
                    validator: (v) => v == null ? 'مطلوب' : null,
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'to_supplier', label: Text('سداد لمورد')),
                      ButtonSegment(value: 'from_customer', label: Text('سداد من عميل')),
                    ],
                    selected: {direction},
                    onSelectionChanged: (s) => setModalState(() => direction = s.first),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: amtCtrl,
                    decoration: const InputDecoration(labelText: 'المبلغ (جنيه)'),
                    keyboardType: TextInputType.number,
                    validator: (v) => v!.isEmpty ? 'مطلوب' : null,
                  ),
                  TextFormField(
                    controller: descCtrl,
                    decoration: const InputDecoration(labelText: 'الوصف أو البيان'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate() || selectedPerson == null) return;
                final amt = double.parse(amtCtrl.text);
                final db = await DatabaseHelper.instance.database;

                if (isEdit) {
                  final authOk = await SettingsScreen.verifyPassword(context);
                  if (!authOk) return;

                  final updated = PaymentModel(
                    id: existing.id,
                    personId: selectedPerson!,
                    paymentType: 'cash',
                    direction: direction,
                    date: dateCtrl.text,
                    amount: amt,
                    description: descCtrl.text,
                  );
                  await db.update('payments', updated.toMap(), where: 'id = ?', whereArgs: [existing.id]);
                  await SyncManager.instance.queueSync('payments', 'UPDATE', existing.id);
                } else {
                  final newPay = PaymentModel(
                    id: const Uuid().v4(),
                    personId: selectedPerson!,
                    paymentType: 'cash',
                    direction: direction,
                    date: dateCtrl.text,
                    amount: amt,
                    description: descCtrl.text,
                  );
                  await db.insert('payments', newPay.toMap());
                  await SyncManager.instance.queueSync('payments', 'INSERT', newPay.id);
                }
                Navigator.pop(ctx);
                _loadData();
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('السندات والمقبوضات')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openPaymentDialog(),
        child: const Icon(Icons.add),
      ),
      body: ListView.builder(
        itemCount: _payments.length,
        itemBuilder: (ctx, i) {
          final p = _payments[i];
          final isFromCust = p.direction == 'from_customer';

          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: ListTile(
              leading: Icon(Icons.payment, color: isFromCust ? Colors.green : Colors.blue),
              title: Text('${p.personName} - ${p.amount.toStringAsFixed(2)} ج.م'),
              subtitle: Text('${isFromCust ? "وارد من عميل" : "صادر لمورد"} | ${p.date}\n${p.description}'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit, size: 20),
                    onPressed: () => _openPaymentDialog(existing: p),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                    onPressed: () async {
                      final authOk = await SettingsScreen.verifyPassword(context);
                      if (!authOk) return;
                      final db = await DatabaseHelper.instance.database;
                      await db.delete('payments', where: 'id = ?', whereArgs: [p.id]);
                      await SyncManager.instance.queueSync('payments', 'DELETE', p.id);
                      _loadData();
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
