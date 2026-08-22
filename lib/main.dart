import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';

import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    // Inicializa o banco de dados no Firebase
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Erro crítico ao inicializar o Firebase: $e');
  }

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'BeautyConnect',
      debugShowCheckedModeBanner: true, // Modo debug ativado
      theme: AppTheme.light,
      routerConfig: appRouter,
      // MODO DETETIVE: Substitui a tela cinza pelo erro real
      builder: (context, widget) {
        ErrorWidget.builder = (FlutterErrorDetails details) {
          return Material(
            child: Container(
              color: Colors.red.shade900,
              padding: const EdgeInsets.all(20),
              alignment: Alignment.center,
              child: SingleChildScrollView(
                child: Text(
                  'ERRO ENCONTRADO:\n\n${details.exceptionAsString()}\n\nTire um print ou copie este texto e mande para a IA resolver!',
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.left,
                ),
              ),
            ),
          );
        };
        return widget!;
      },
    );
  }
}
