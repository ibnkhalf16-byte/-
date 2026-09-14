import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import '../core/database_helper.dart';
import '../core/sync_manager.dart';
import '../core/accounting_engine.dart';
import '../models/trip_model.dart';
import '../models/person_model.dart';
import 'settings_screen.dart';

class TripsScreen extends StatefulWidget {
  const TripsScreen({Key? key}) : super(key: key);

  @override
  State<TripsScreen> createState() => _TripsScreenState();
}

class _TripsScreenState extends State<TripsScreen> {
  List<TripModel> _trips = [];
  List<PersonModel> _persons = [];
  Map<String, String> _statuses = {};
  String _filterItem = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final db = await DatabaseHelper.instance.database;
    final pMaps = await db.query('persons', orderBy: 'name ASC');
    final tMaps = await db.rawQuery('''
      SELECT t.*, p.name as person_name 
      FROM trips t 
      JOIN persons p ON t.person_id = p.id 
      ORDER BY t.date DESC
    ''');

    setState(() {
      _persons = pMaps.map((m) => PersonModel.fromMap(m)).toList();
      _trips = tMaps.map((m) => TripModel.fromMap(m)).toList();
      _statuses = AccountingEngine.calculateTripStatuses(_trips);
    });
  }

  void _openTripDialog({TripModel? existing}) {
    final isEdit = existing != null;
    final formKey = GlobalKey<FormState>();
    String? selectedPerson = existing?.personId;
    String operation = existing?.operation ?? 'purchase';

    // تاريخ النقلة
    DateTime selectedDate = existing != null
        ? (DateTime.tryParse(existing.date) ?? DateTime.now())
        : DateTime.now();

    final dateCtrl = TextEditingController(
      text: DateFormat('yyyy-MM-dd').format(selectedDate),
    );
    final carCtrl = TextEditingController(text: existing?.vehicle ?? '');
    final driverCtrl = TextEditingController(text: existing?.driver ?? '');
    final itemCtrl = TextEditingController(text: existing?.item ?? '');
    final weightCtrl = TextEditingController(text: existing?.weight.toString() ?? '');
    final priceCtrl = TextEditingController(text: existing?.price.toString() ?? '');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: Text(isEdit ? 'تعديل نقلة' : 'تسجيل نقلة جديدة'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // اختيار تاريخ النقلة
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(color: Colors.grey.shade300),
                    ),
                    title: Text(
                      'تاريخ النقلة: ${dateCtrl.text}',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    trailing: const Icon(Icons.calendar_month, color: Colors.blue),
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
                    validator: (v) => v == null ? 'يرجى اختيار الطرف' : null,
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'purchase', label: Text('شراء من مورد')),
                      ButtonSegment(value: 'sale', label: Text('بيع لعميل')),
                    ],
                    selected: {operation},
                    onSelectionChanged: (s) => setModalState(() => operation = s.first),
                  ),
                  TextFormField(
                    controller: itemCtrl,
                    decoration: const InputDecoration(labelText: 'نوع البضاعة'),
                    validator: (v) => v!.isEmpty ? 'مطلوب' : null,
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: weightCtrl,
                          decoration: const InputDecoration(labelText: 'الوزن بالطن'),
                          keyboardType: TextInputType.number,
                          validator: (v) => v!.isEmpty ? 'مطلوب' : null,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          controller: priceCtrl,
                          decoration: const InputDecoration(labelText: 'سعر الطن'),
                          keyboardType: TextInputType.number,
                          validator: (v) => v!.isEmpty ? 'مطلوب' : null,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(child: TextFormField(controller: carCtrl, decoration: const InputDecoration(labelText: 'رقم السيارة'))),
                      const SizedBox(width: 8),
                      Expanded(child: TextFormField(controller: driverCtrl, decoration: const InputDecoration(labelText: 'اسم السائق'))),
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
                if (!formKey.currentState!.validate() || selectedPerson == null) return;
                final weight = double.parse(weightCtrl.text);
                final price = double.parse(priceCtrl.text);
                final total = weight * price;
                final db = await DatabaseHelper.instance.database;

                if (isEdit) {
                  final authOk = await SettingsScreen.verifyPassword(context);
                  if (!authOk) return;

                  final updated = TripModel(
                    id: existing.id,
                    personId: selectedPerson!,
                    operation: operation,
                    date: dateCtrl.text,
                    vehicle: carCtrl.text,
                    driver: driverCtrl.text,
                    item: itemCtrl.text,
                    weight: weight,
                    price: price,
                    total: total,
                    sourceTripId: existing.sourceTripId,
                  );
                  await db.update('trips', updated.toMap(), where: 'id = ?', whereArgs: [existing.id]);
                  await SyncManager.instance.queueSync('trips', 'UPDATE', existing.id);
                } else {
                  final newTrip = TripModel(
                    id: const Uuid().v4(),
                    personId: selectedPerson!,
                    operation: operation,
                    date: dateCtrl.text,
                    vehicle: carCtrl.text,
                    driver: driverCtrl.text,
                    item: itemCtrl.text,
                    weight: weight,
                    price: price,
                    total: total,
                  );
                  await db.insert('trips', newTrip.toMap());
                  await SyncManager.instance.queueSync('trips', 'INSERT', newTrip.id);
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

  void _openSellPurchaseModal(TripModel purchase) {
    final status = _statuses[purchase.id] ?? '';
    double remaining = purchase.weight;
    if (status.startsWith("متبقي للبيع:")) {
      remaining = double.tryParse(status.replaceAll("متبقي للبيع:", "").replaceAll("طن", "").trim()) ?? 0.0;
    } else if (status == "تم بيع الوزنة") {
      remaining = 0.0;
    }

    if (remaining <= 0.0001) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('النقلة مباعة بالكامل!')));
      return;
    }

    String? selectedCustomer;
    DateTime saleDate = DateTime.now();
    final dateCtrl = TextEditingController(text: DateFormat('yyyy-MM-dd').format(saleDate));
    final weightCtrl = TextEditingController(text: remaining.toString());
    final priceCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSaleState) => AlertDialog(
          title: const Text('تحويل النقلة المشتراة لعميل'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${purchase.item} - سيارة: ${purchase.vehicle} - المتاح: $remaining طن', style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(color: Colors.grey.shade300),
                  ),
                  title: Text(
                    'تاريخ البيع: ${dateCtrl.text}',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  trailing: const Icon(Icons.calendar_month, color: Colors.green),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: saleDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2035),
                    );
                    if (picked != null) {
                      setSaleState(() {
                        saleDate = picked;
                        dateCtrl.text = DateFormat('yyyy-MM-dd').format(picked);
                      });
                    }
                  },
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'العميل المشتري'),
                  items: _persons.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name))).toList(),
                  onChanged: (v) => selectedCustomer = v,
                ),
                TextFormField(controller: weightCtrl, decoration: const InputDecoration(labelText: 'الوزن المباع (طن)'), keyboardType: TextInputType.number),
                TextFormField(controller: priceCtrl, decoration: const InputDecoration(labelText: 'سعر بيع الطن'), keyboardType: TextInputType.number),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () async {
                final w = double.tryParse(weightCtrl.text) ?? 0;
                final p = double.tryParse(priceCtrl.text) ?? 0;
                if (selectedCustomer == null || w <= 0 || p <= 0) return;
                if (w > remaining + 0.0001) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الوزن يتجاوز المتبقي!')));
                  return;
                }

                final authOk = await SettingsScreen.verifyPassword(context);
                if (!authOk) return;

                final db = await DatabaseHelper.instance.database;
                final saleTrip = TripModel(
                  id: const Uuid().v4(),
                  personId: selectedCustomer!,
                  operation: 'sale',
                  date: dateCtrl.text,
                  vehicle: purchase.vehicle,
                  driver: purchase.driver,
                  item: purchase.item,
                  weight: w,
                  price: p,
                  total: w * p,
                  sourceTripId: purchase.id,
                );
                await db.insert('trips', saleTrip.toMap());
                await SyncManager.instance.queueSync('trips', 'INSERT', saleTrip.id);
                Navigator.pop(ctx);
                _loadData();
              },
              child: const Text('تأكيد البيع'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _trips.where((t) => _filterItem.isEmpty || t.item.contains(_filterItem)).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('حركة النقلات والوزنات'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('تصفية بالبضاعة'),
                  content: TextField(onChanged: (v) => setState(() => _filterItem = v)),
                  actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('تم'))],
                ),
              );
            },
          )
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openTripDialog(),
        child: const Icon(Icons.add),
      ),
      body: ListView.builder(
        itemCount: filtered.length,
        itemBuilder: (ctx, i) {
          final t = filtered[i];
          final st = _statuses[t.id] ?? '';
          final isSale = t.operation == 'sale';

          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: ListTile(
              leading: Icon(isSale ? Icons.arrow_upward : Icons.arrow_downward, color: isSale ? Colors.green : Colors.orange),
              title: Text('${t.personName} - ${t.item}'),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${t.weight} طن × ${t.price} = ${t.total.toStringAsFixed(2)} ج.م | ${t.date}'),
                  Text(st, style: TextStyle(fontWeight: FontWeight.bold, color: st.contains('تم') ? Colors.green : Colors.red)),
                ],
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!isSale)
                    IconButton(
                      icon: const Icon(Icons.sell, color: Colors.blue),
                      tooltip: 'بيع لعميل',
                      onPressed: () => _openSellPurchaseModal(t),
                    ),
                  IconButton(
                    icon: const Icon(Icons.edit, size: 20),
                    onPressed: () => _openTripDialog(existing: t),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                    onPressed: () async {
                      final authOk = await SettingsScreen.verifyPassword(context);
                      if (!authOk) return;
                      final db = await DatabaseHelper.instance.database;
                      await db.delete('trips', where: 'id = ?', whereArgs: [t.id]);
                      await SyncManager.instance.queueSync('trips', 'DELETE', t.id);
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
