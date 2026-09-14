import 'package:flutter/material.dart';
import 'trips_screen.dart';
import 'persons_screen.dart';
import 'payments_screen.dart';
import 'statement_screen.dart';
import 'profits_screen.dart';
import 'settings_screen.dart';
import '../core/sync_manager.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  bool _isSyncing = false;

  final List<Widget> _pages = const [
    TripsScreen(),
    PaymentsScreen(),
    StatementScreen(),
    PersonsScreen(),
    ProfitsScreen(),
    SettingsScreen(),
  ];

  final List<String> _titles = const [
    'سجل النقلات والمحاصيل',
    'سندات السداد والتحصيل',
    'كشف الحساب المالي',
    'دليل العملاء والموردين',
    'تقرير أرباح الصفقات',
    'إعدادات النظام والأمان',
  ];

  Future<void> _handleCloudSync() async {
    setState(() => _isSyncing = true);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('جارٍ الاتصال بالسحابة ومزامنة البيانات...'),
        duration: Duration(seconds: 1),
      ),
    );

    final String result = await SyncManager.instance.pullAllFromCloud();

    setState(() => _isSyncing = false);

    if (mounted) {
      if (result == 'ok') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم استرجاع وتحديث كافة البيانات بنجاح ✅'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل المزامنة: $result'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_currentIndex]),
        centerTitle: false,
        actions: [
          _isSyncing
              ? const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    ),
                  ),
                )
              : IconButton(
                  icon: const Icon(Icons.cloud_sync, size: 28),
                  tooltip: 'استرجاع ومزامنة البيانات مع السحابة',
                  onPressed: _handleCloudSync,
                ),
        ],
      ),
      body: KeyedSubtree(
        key: ValueKey(_isSyncing),
        child: _pages[_currentIndex],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.local_shipping_outlined),
            selectedIcon: Icon(Icons.local_shipping),
            label: 'النقلات',
          ),
          NavigationDestination(
            icon: Icon(Icons.payments_outlined),
            selectedIcon: Icon(Icons.payments),
            label: 'السداد',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'كشف حساب',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'الأطراف',
          ),
          NavigationDestination(
            icon: Icon(Icons.trending_up_outlined),
            selectedIcon: Icon(Icons.trending_up),
            label: 'الأرباح',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'الإعدادات',
          ),
        ],
      ),
    );
  }
}
