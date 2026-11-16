import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'models/modelos.dart';
import 'screens/grupos_screen.dart';
import 'screens/grupo_screen.dart';
import 'screens/gasto_screen.dart';
import 'screens/saldos_screen.dart';
import 'screens/divisas_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // En escritorio sqflite necesita el backend FFI; en Android/iOS usa el nativo.
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  runApp(const CuentasClarasApp());
}

class CuentasClarasApp extends StatelessWidget {
  const CuentasClarasApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cuentas Claras',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
      initialRoute: '/',
      onGenerateRoute: (s) {
        Widget pantalla;
        switch (s.name) {
          case '/':
            pantalla = const GruposScreen();
            break;
          case '/grupo':
            pantalla = GrupoScreen(grupo: s.arguments as Grupo);
            break;
          case '/gasto':
            pantalla = GastoScreen(grupo: s.arguments as Grupo);
            break;
          case '/saldos':
            pantalla = SaldosScreen(grupo: s.arguments as Grupo);
            break;
          case '/divisas':
            pantalla = const DivisasScreen();
            break;
          default:
            pantalla = const GruposScreen();
        }
        return MaterialPageRoute(builder: (_) => pantalla, settings: s);
      },
    );
  }
}
