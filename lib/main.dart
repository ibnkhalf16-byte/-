import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/sync_manager.dart';
import 'core/database_helper.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. تهيئة محرك قواعد البيانات لنظام Windows أو Linux
  if (Platform.isWindows || Platform.isLinux) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // 2. تهيئة قاعدة البيانات المحلية SQLite
  await DatabaseHelper.instance.database;

  // 3. تهيئة الاتصال بمشروع Supabase
  await Supabase.initialize(
    url: 'https://llifjaouiosdvwogfnot.supabase.co',
    anonKey: 'sb_publishable_PQh_xQEI2bQgVp5WtdHyKg_BQUtWYly',
  );

  // 4. بدء تشغيل المزامنة وسحب البيانات السحابية
  SyncManager.instance.init();

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
          surface: const Color(0xFFF8FAFC),
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
