import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/sync_manager.dart';
import 'core/database_helper.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. تهيئة قاعدة البيانات المحلية SQLite
  await DatabaseHelper.instance.database;

  // 2. تهيئة الاتصال بمشروع Supabase الخاص بك
  await Supabase.initialize(
    url: 'https://llifjaouiosdvwogfnot.supabase.co',
    anonKey: 'sb_publishable_PQh_xQEI2bQgVp5WtdHyKg_BQUtWYly',
  );

  // 3. بدء تشغيل المزامنة وسحب البيانات السحابية
  await SyncManager.instance.init();

  runApp(const AlaaAccountsApp());
}

class AlaaAccountsApp extends StatelessWidget {
  const AlaaAccountsApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'حسابات علاء أبو شادي',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Segoe UI',
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1E293B),
          primary: const Color(0xFF2563EB),
          background: const Color(0xFFF8FAFC),
        ),
      ),
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const HomeScreen(),
    );
  }
}
