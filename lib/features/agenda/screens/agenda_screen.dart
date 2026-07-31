import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_constants.dart';
import '../../clientes/controllers/cliente_controller.dart';
import '../controllers/agendamento_controller.dart';
import '../models/agendamento.dart';
import '../widgets/calendar_month_view.dart';
import '../widgets/list_day_view.dart';
import '../widgets/list_week_view.dart';

class AgendaScreen extends ConsumerWidget {
  const AgendaScreen({super.key});

  String _rotulo(AgendaState estado) {
    switch (estado.visao) {
      case VisaoAgenda.dia:
        return DateFormat("EEEE, d 'de' MMMM", 'pt_BR').format(estado.dataReferencia);
      case VisaoAgenda.semana:
        final inicio = estado.dataReferencia.subtract(Duration(days: estado.dataReferencia.weekday % 7));
        return 'Semana de ${DateFormat('dd/MM').format(inicio)}';
      case VisaoAgenda.mes:
        return DateFormat("MMMM 'de' yyyy", 'pt_BR').format(estado.dataReferencia);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estadoAsync = ref.watch(agendamentoControllerProvider);
    final clientesAsync = ref.watch(clienteControllerProvider);
    final clientesPorId = clientesAsync.maybeWhen(
      data: (lista) => {for (final c in lista) c.id: c.nome},
      orElse: () => <String, String>{},
    );
    final moeda = NumberFormat.simpleCurrency(locale: 'pt_BR');

    return Scaffold(
      appBar: AppBar(title: const Text('Agenda')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          final dataAtual = estadoAsync.value?.dataReferencia ?? DateTime.now();
          final dataIso = dataAtual.toIso8601String().split('T').first;
          context.push(Uri(path: AppRoutes.agendaNovo, queryParameters: {'data': dataIso}).toString());
        },
        icon: const Icon(Icons.add),
        label: const Text('Novo Agendamento'),
      ),
      body: estadoAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro ao carregar agenda: $e')),
        data: (estado) {
          final notifier = ref.read(agendamentoControllerProvider.notifier);

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Navegação: anterior - título - próximo
                Row(
                  children: [
                    IconButton(onPressed: notifier.voltar, icon: const Icon(Icons.chevron_left)),
                    Expanded(
                      child: Text(
                        _rotulo(estado),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    IconButton(onPressed: notifier.avancar, icon: const Icon(Icons.chevron_right)),
                  ],
                ),
                const SizedBox(height: 8),

                // Seletor de visão
                SegmentedButton<VisaoAgenda>(
                  segments: const [
                    ButtonSegment(value: VisaoAgenda.dia, label: Text('Dia')),
                    ButtonSegment(value: VisaoAgenda.semana, label: Text('Semana')),
                    ButtonSegment(value: VisaoAgenda.mes, label: Text('Mês')),
                  ],
                  selected: {estado.visao},
                  onSelectionChanged: (novo) => notifier.mudarVisao(novo.first),
                ),
                const SizedBox(height: 12),

                // Corpo principal: renderiza visão apropriada
                Expanded(
                  child: _construirVisualizacao(
                    context: context,
                    visao: estado.visao,
                    estado: estado,
                    clientesPorId: clientesPorId,
                    notifier: notifier,
                    moeda: moeda,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Constrói a visualização apropriada (dia/semana/mês)
  Widget _construirVisualizacao({
    required BuildContext context,
    required VisaoAgenda visao,
    required AgendaState estado,
    required Map<String, String> clientesPorId,
    required AgendamentoController notifier,
    required NumberFormat moeda,
  }) {
    if (estado.lista.isEmpty) {
      return const Center(child: Text('Nenhum agendamento neste período.'));
    }

    switch (visao) {
      case VisaoAgenda.dia:
        return ListDayView(
          agendamentos: estado.lista,
          clientesNomes: clientesPorId,
          onAgendamentoTapado: (agendamento) {
            context.push('${AppRoutes.agenda}/editar/${agendamento.id}');
          },
          onConfirmar: (id) => notifier.confirmar(id),
          onConcluir: (id) => notifier.concluir(id),
          onCancelar: (id) => notifier.cancelar(id),
        );

      case VisaoAgenda.semana:
        return ListWeekView(
          agendamentos: estado.lista,
          clientesNomes: clientesPorId,
          onAgendamentoTapado: (agendamento) {
            context.push('${AppRoutes.agenda}/editar/${agendamento.id}');
          },
          onConfirmar: (id) => notifier.confirmar(id),
          onConcluir: (id) => notifier.concluir(id),
          onCancelar: (id) => notifier.cancelar(id),
        );

      case VisaoAgenda.mes:
        return CalendarMonthView(
          dataReferencia: estado.dataReferencia,
          agendamentos: estado.lista,
          clientesNomes: clientesPorId,
          onDiaSelecionado: (dia) {
            notifier.irPara(dia);
          },
          onAgendamentoTapado: (agendamento) {
            context.push('${AppRoutes.agenda}/editar/${agendamento.id}');
          },
        );
    }
  }
}

