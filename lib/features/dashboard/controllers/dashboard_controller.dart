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

/// Converte "HH:mm" em minutos desde a meia-noite para ordenação e comparação precisa
int _horaParaMinutos(String hhmm) {
  try {
    final p = hhmm.split(':');
    if (p.length >= 2) {
      final h = int.parse(p[0].replaceAll(RegExp(r'\D'), ''));
      final m = int.parse(p[1].replaceAll(RegExp(r'\D'), ''));
      return h * 60 + m;
    }
  } catch (_) {}
  return 0;
}

/// Busca o dia de hoje direto do repositório de forma reativa e sanitizada.
final dashboardMetricsProvider = FutureProvider<DashboardMetrics>((ref) async {
  ref.watch(agendamentoControllerProvider);
  final repository = ref.watch(agendamentoRepositoryProvider);

  final agora = DateTime.now();
  final agendaHojeBruta = await repository.listarDia(agora);

  // 1. FILTRAGEM: Remove bloqueios e cancelados para ter apenas clientes reais de hoje
  final agendaHojeValida = agendaHojeBruta.where((a) {
    final ehBloqueio = a.clienteId == 'BLOQUEIO';
    final ehCancelado = a.status == AgendamentoStatus.cancelado;
    return !ehBloqueio && !ehCancelado;
  }).toList();

  // 2. ORDENAÇÃO: Garante ordem cronológica rígida por horário de início
  agendaHojeValida.sort((a, b) {
    return _horaParaMinutos(a.horaInicio).compareTo(_horaParaMinutos(b.horaInicio));
  });

  // 3. FATURAMENTO PREVISTO: Soma de todos os atendimentos válidos de hoje
  final faturamento = agendaHojeValida.fold<double>(0, (soma, a) => soma + a.valor);

  // 4. CONCLUÍDOS: Quantidade de atendimentos já finalizados hoje
  final concluidos = agendaHojeValida.where((a) => a.status == AgendamentoStatus.concluido).length;

  // 5. PRÓXIMO ATENDIMENTO: Encontra o próximo cliente do horário atual em diante
  final minutosAgora = agora.hour * 60 + agora.minute;
  Agendamento? proximo;

  for (final a in agendaHojeValida) {
    final ehPendente = a.status == AgendamentoStatus.agendado || a.status == AgendamentoStatus.confirmado;
    if (ehPendente) {
      final minutosFim = _horaParaMinutos(a.horaFim);
      // Pega o primeiro atendimento que ainda não terminou em relação ao relógio atual
      if (minutosFim >= minutosAgora) {
        proximo = a;
        break; // Encontrou o atendimento futuro/em andamento mais próximo
      }
    }
  }

  // Caso todos já tenham passado no relógio mas ainda existam pendentes, mantém o último válido
  proximo ??= agendaHojeValida.cast<Agendamento?>().firstWhere(
        (a) => a != null && (a.status == AgendamentoStatus.agendado || a.status == AgendamentoStatus.confirmado),
        orElse: () => null,
      );

  return DashboardMetrics(
    agendaHoje: agendaHojeValida,
    totalAgendamentosHoje: agendaHojeValida.length,
    atendimentosConcluidosHoje: concluidos,
    faturamentoPrevisto: faturamento,
    proximo: proximo,
    minutosLivresHoje: InteligenciaService.minutosLivresRestantesHoje(agendaHojeBruta),
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

/// Receita do dia (soma de atendimentos Confirmados e Concluídos do dia).
final receitaDoDiaProvider = FutureProvider<double>((ref) async {
  ref.watch(agendamentoControllerProvider);
  final repository = ref.watch(agendamentoRepositoryProvider);

  final agendaHoje = await repository.listarDia(DateTime.now());

  // Soma atendimentos válidos (Confirmados + Concluídos), descartando cancelados e bloqueios
  final receita = agendaHoje
      .where((a) =>
          a.clienteId != 'BLOQUEIO' &&
          a.status != AgendamentoStatus.cancelado &&
          (a.status == AgendamentoStatus.confirmado || a.status == AgendamentoStatus.concluido))
      .fold<double>(0, (soma, a) => soma + a.valor);

  return receita;
});
