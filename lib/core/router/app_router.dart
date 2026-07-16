import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/agenda/screens/agenda_inteligente_screen.dart';
import '../../features/agenda/screens/agenda_screen.dart';
import '../../features/agenda/screens/agendamento_form_screen.dart';
import '../../features/clientes/screens/cliente_form_screen.dart';
import '../../features/clientes/screens/clientes_screen.dart';
import '../../features/clientes/screens/historico_cliente_screen.dart';
import '../../features/configuracoes/screens/configuracoes_screen.dart';
import '../../features/dashboard/screens/dashboard_screen.dart';
import '../../features/servicos/screens/servico_form_screen.dart';
import '../../features/servicos/screens/servicos_screen.dart';
import '../../shared/widgets/app_scaffold.dart';
import '../constants/app_constants.dart';

/// Rotas do app, conforme documento técnico:
/// /, /clientes, /clientes/novo, /clientes/editar, /agenda, /agenda/novo,
/// /configuracoes.
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<NavigatorState> shellNavigatorKey = GlobalKey<NavigatorState>();

final appRouter = GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: AppRoutes.dashboard,
  routes: [
    // Shell com navegação lateral/inferior — Dashboard, Clientes, Agenda, Configurações.
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) => AppScaffold(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(routes: [
          GoRoute(path: AppRoutes.dashboard, builder: (context, state) => const DashboardScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: AppRoutes.clientes, builder: (context, state) => const ClientesScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: AppRoutes.servicos, builder: (context, state) => const ServicosScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: AppRoutes.agenda, builder: (context, state) => const AgendaScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: AppRoutes.configuracoes, builder: (context, state) => const ConfiguracoesScreen()),
        ]),
      ],
    ),

    // Telas de formulário abrem por cima do shell (rota de nível raiz).
    GoRoute(
      path: AppRoutes.clienteNovo,
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) => const ClienteFormScreen(),
    ),
    GoRoute(
      path: '${AppRoutes.clienteEditar}/:id',
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) => ClienteFormScreen(clienteId: state.pathParameters['id']),
    ),
    GoRoute(
      path: '${AppRoutes.clienteHistorico}/:id',
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) => HistoricoClienteScreen(clienteId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: AppRoutes.servicoNovo,
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) => const ServicoFormScreen(),
    ),
    GoRoute(
      path: '${AppRoutes.servicoEditar}/:id',
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) => ServicoFormScreen(servicoId: state.pathParameters['id']),
    ),
    GoRoute(
      path: AppRoutes.agendaNovo,
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) {
        final dataInicial = state.uri.queryParameters['data'];
        return AgendamentoFormScreen(dataInicialIso: dataInicial);
      },
    ),
    GoRoute(
      path: '${AppRoutes.agenda}/editar/:id',
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) => AgendamentoFormScreen(agendamentoId: state.pathParameters['id']),
    ),
    GoRoute(
      path: AppRoutes.agendaInteligente,
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) => const AgendaInteligenteScreen(),
    ),
  ],
);
