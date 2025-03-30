import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'screens/entrada_screen.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart'; // Importa o sqflite_common_ffi
import 'package:sqflite/sqflite.dart'; // Importa o sqflite
import 'dart:io'; // Adicione este import para usar a classe Platform
import 'screens/home_screen.dart'; // Importa a nova tela inicial
import 'package:shared_preferences/shared_preferences.dart';
import 'sync_helper.dart';

void main() async{
  // Inicializa o sqflite_common_ffi para Windows/Linux
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit(); // Inicializa o FFI
    databaseFactory = databaseFactoryFfi; // Define o databaseFactory global
  }
  WidgetsFlutterBinding.ensureInitialized();
  // Sincronizar dados ao iniciar o aplicativo
  await SyncHelper.sincronizarDados();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  // Verifica se o usuário já está logado
  Future<bool> _checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('isLoggedIn') ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Entradas PEV',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: FutureBuilder<bool>(
        future: _checkLoginStatus(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasData && snapshot.data == true) {
            return const HomeScreen(); // Usuário já logado, vai direto para Home
          }
          return const LoginScreen(); // Usuário não logado, mostra tela de login
        },
      ),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/home': (context) => const HomeScreen(),
        '/entrada': (context) => const EntradaScreen(),
        // Adicione outras rotas conforme necessário
      },
    );
  }
}