import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'core/constants/app_constants.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/agenda/models/agendamento.dart';
import 'features/clientes/models/cliente.dart';
import 'features/servicos/models/servico.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Formatação de datas em português (nomes de dia/mês no Dashboard e na Agenda).
  await initializeDateFormatting('pt_BR', null);

  // Inicializa o Hive. No Flutter Web, isso persiste automaticamente em
  // IndexedDB — sem servidor, sem banco remoto, conforme documento técnico.
  await Hive.initFlutter();

  Hive.registerAdapter(ClienteAdapter());
  Hive.registerAdapter(AgendamentoAdapter());
  Hive.registerAdapter(AgendamentoStatusAdapter());
  Hive.registerAdapter(ServicoAdapter());

  await Hive.openBox<Cliente>(HiveBoxes.clientes);
  await Hive.openBox<Agendamento>(HiveBoxes.agendamentos);
  await Hive.openBox<Servico>(HiveBoxes.servicos);

  runApp(const ProviderScope(child: BeautyConnectApp()));
}

class BeautyConnectApp extends StatelessWidget {
  const BeautyConnectApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'BeautyConnect',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: appRouter,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('pt', 'BR')],
      locale: const Locale('pt', 'BR'),
    );
  }
}
