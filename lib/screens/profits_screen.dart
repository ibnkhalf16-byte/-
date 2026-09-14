import 'package:flutter/material.dart';
import '../core/database_helper.dart';
import '../core/accounting_engine.dart';
import '../models/trip_model.dart';

class ProfitsScreen extends StatefulWidget {
  const ProfitsScreen({Key? key}) : super(key: key);

  @override
  State<ProfitsScreen> createState() => _ProfitsScreenState();
}

class _ProfitsScreenState extends State<ProfitsScreen> {
  Map<String, dynamic>? _profitData;

  @override
  void initState() {
    super.initState();
    _loadProfits();
  }

  Future<void> _loadProfits() async {
    final db = await DatabaseHelper.instance.database;
    final maps = await db.query('trips', orderBy: 'date ASC');
    final trips = maps.map((m) => TripModel.fromMap(m)).toList();

    setState(() {
      _profitData = AccountingEngine.calculateRealProfits(trips);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_profitData == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final items = _profitData!['items'] as Map<String, Map<String, double>>;

    return Scaffold(
      appBar: AppBar(title: const Text('تقرير الأرباح الحقيقي')),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('إجمالي المبيعات:'),
                    Text('${_profitData!['revenue'].toStringAsFixed(2)} ج.م', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('تكلفة البضاعة المباعة (COGS):'),
                    Text('${_profitData!['cogs'].toStringAsFixed(2)} ج.م', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
                  ],
                ),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('الربح الصافي الفعلي:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Text('${_profitData!['profit'].toStringAsFixed(2)} ج.م', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.blue)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: Align(alignment: Alignment.centerRight, child: Text('أرباح الأصناف التقديرية:', style: TextStyle(fontWeight: FontWeight.bold))),
          ),
          Expanded(
            child: ListView(
              children: items.entries.map((e) {
                final profit = e.value['revenue']! - e.value['cogs']!;
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  child: ListTile(
                    title: Text(e.key, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('مبيعات: ${e.value['revenue']!.toStringAsFixed(2)} | تكلفة: ${e.value['cogs']!.toStringAsFixed(2)}'),
                    trailing: Text('${profit.toStringAsFixed(2)} ج.م', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

