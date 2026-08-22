import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_constants.dart';
import '../../clientes/controllers/cliente_controller.dart';
import '../controllers/agendamento_controller.dart';
import '../models/agendamento.dart';
import '../widgets/modal_fechar_comanda.dart';
import '../widgets/timeline_day_view.dart';
import '../widgets/timeline_week_view.dart';
import '../widgets/calendar_month_view.dart';

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

  void _abrirModalComanda(
    BuildContext context,
    WidgetRef ref,
    Agendamento agendamento,
    String nomeCliente,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => ModalFecharComanda(
        agendamento: agendamento,
        nomeCliente: nomeCliente,
        onConfirmar: (forma, valorFinal) {
          final atualizado = agendamento.copyWith(
            status: AgendamentoStatus.concluido,
            formaPagamento: forma,
            valor: valorFinal,
          );
          ref.read(agendamentoControllerProvider.notifier).salvar(atualizado, novo: false);
        },
      ),
    );
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
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          final dataAtual = estadoAsync.value?.dataReferencia ?? DateTime.now();
          final dataIso = dataAtual.toIso8601String().split('T').first;
          context.push(Uri(path: AppRoutes.agendaNovo, queryParameters: {'data': dataIso}).toString());
        },
        child: const Icon(Icons.add),
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
                SegmentedButton<VisaoAgenda>(
                  segments: const [
                    ButtonSegment(value: VisaoAgenda.dia, label: Text('Hoje')),
                    ButtonSegment(value: VisaoAgenda.semana, label: Text('Semana')),
                    ButtonSegment(value: VisaoAgenda.mes, label: Text('Mês')),
                  ],
                  selected: {estado.visao},
                  onSelectionChanged: (novo) => notifier.mudarVisao(novo.first),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: estado.visao == VisaoAgenda.dia
                      ? (estado.lista.isEmpty
                          ? const Center(child: Text('Nenhum agendamento neste dia.'))
                          : TimelineDayView(
                              agendamentos: estado.lista,
                              clientesPorId: clientesPorId,
                              moeda: moeda,
                              dataReferencia: estado.dataReferencia,
                              onNovoAgendamento: (horaInicio) {
                                final dataIso = estado.dataReferencia.toIso8601String().split('T').first;
                                context.push(Uri(
                                  path: AppRoutes.agendaNovo,
                                  queryParameters: {'data': dataIso, 'hora': horaInicio},
                                ).toString());
                              },
                              onEditar: (id) => context.push('${AppRoutes.agenda}/editar/$id'),
                              onConfirmar: (id) => notifier.confirmar(id),
                              onConcluir: (id) {
                                final agendamento = estado.lista.firstWhere((a) => a.id == id);
                                final nomeCliente = clientesPorId[agendamento.clienteId] ??
                                    (agendamento.clienteId == 'BLOQUEIO'
                                        ? 'Compromisso Pessoal'
                                        : 'Cliente');
                                _abrirModalComanda(context, ref, agendamento, nomeCliente);
                              },
                              onCancelar: (id) => notifier.cancelar(id),
                            ))
                      : estado.visao == VisaoAgenda.semana
                          ? TimelineWeekView(
                              agendamentos: estado.lista,
                              dataReferencia: estado.dataReferencia,
                              onIrParaDia: (dataCerta) {
                                notifier.mudarData(dataCerta);
                                notifier.mudarVisao(VisaoAgenda.dia);
                              },
                            )
                          : CalendarMonthView(
                              agendamentos: estado.lista,
                              dataReferencia: estado.dataReferencia,
                              onIrParaDia: (dataCerta) {
                                notifier.mudarData(dataCerta);
                                notifier.mudarVisao(VisaoAgenda.dia);
                              },
                            ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
