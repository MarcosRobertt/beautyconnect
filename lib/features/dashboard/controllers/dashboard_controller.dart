import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../agenda/controllers/agendamento_controller.dart';
import '../../agenda/models/agendamento.dart';
import '../../agenda/services/inteligencia_service.dart';
import '../../clientes/controllers/cliente_controller.dart';
import '../../clientes/models/cliente.dart';

/// Métricas do Dashboard: atendimentos de hoje, próximo atendimento,
/// horários vagos (restantes até o fim do expediente de hoje) e
/// aniversariantes do mês.
class DashboardMetrics {
  DashboardMetrics({
    required this.agendaHoje,
    required this.totalAgendamentosHoje,
    required this.atendimentosConcluidosHoje,
    required this.faturamentoPrevisto,
    required this.proximo,
    required this.minutosLivresHoje,
  });

  final List<Agendamento> agendaHoje;
  final int totalAgendamentosHoje;
  final int atendimentosConcluidosHoje;
  final double faturamentoPrevisto;
  final Agendamento? proximo;

  /// Minutos livres restantes hoje, dentro do expediente (ver InteligenciaService).
  final int minutosLivresHoje;
}

/// Busca o dia de hoje direto do repositório — deliberadamente independente
/// da visão/data selecionada na tela de Agenda (dia/semana/mês), para que o
/// Dashboard sempre reflita "hoje" mesmo que a manicure esteja navegando por
/// outra semana ou mês na Agenda.
///
/// `ref.watch(agendamentoControllerProvider)` é usado só como gatilho de
/// atualização: sempre que um agendamento é salvo/editado/cancelado/concluído
/// em qualquer lugar do app, este provider recalcula as métricas de hoje.
final dashboardMetricsProvider = FutureProvider<DashboardMetrics>((ref) async {
  ref.watch(agendamentoControllerProvider);
  final repository = ref.watch(agendamentoRepositoryProvider);

  final agendaHoje = await repository.listarDia(DateTime.now());

  final faturamento = agendaHoje
      .where((a) => a.status != AgendamentoStatus.cancelado)
      .fold<double>(0, (soma, a) => soma + a.valor);

  final concluidos = agendaHoje.where((a) => a.status == AgendamentoStatus.concluido).length;

  Agendamento? proximo;
  for (final a in agendaHoje) {
    if (a.status == AgendamentoStatus.agendado || a.status == AgendamentoStatus.confirmado) {
      proximo = a;
      break;
    }
  }

  return DashboardMetrics(
    agendaHoje: agendaHoje,
    totalAgendamentosHoje: agendaHoje.length,
    atendimentosConcluidosHoje: concluidos,
    faturamentoPrevisto: faturamento,
    proximo: proximo,
    minutosLivresHoje: InteligenciaService.minutosLivresRestantesHoje(agendaHoje),
  );
});

/// Clientes aniversariantes no mês atual, para o card do Dashboard.
final aniversariantesDoMesProvider = FutureProvider<List<Cliente>>((ref) async {
  ref.watch(clienteControllerProvider); // gatilho
  final repository = ref.watch(clienteRepositoryProvider);
  final todos = await repository.listar();
  final mesAtual = DateTime.now().month;
  return todos.where((c) => c.aniversario != null && c.aniversario!.month == mesAtual).toList()
    ..sort((a, b) => a.aniversario!.day.compareTo(b.aniversario!.day));
});
