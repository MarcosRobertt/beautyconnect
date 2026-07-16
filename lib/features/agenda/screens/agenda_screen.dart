import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_constants.dart';
import '../../../shared/widgets/status_chip.dart';
import '../../clientes/controllers/cliente_controller.dart';
import '../controllers/agendamento_controller.dart';
import '../models/agendamento.dart';

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
          // CORREÇÃO (Sprint 1): antes, este botão sempre criava o agendamento
          // para "hoje", ignorando o dia/semana/mês que a manicure estava
          // vendo na Agenda. Agora repassamos a data atualmente visualizada.
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
                  child: estado.lista.isEmpty
                      ? const Center(child: Text('Nenhum agendamento neste período.'))
                      : ListView.separated(
                          itemCount: estado.lista.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, i) {
                            final a = estado.lista[i];
                            return _AgendamentoTile(
                              agendamento: a,
                              nomeCliente: clientesPorId[a.clienteId] ?? 'Cliente removido',
                              mostrarData: estado.visao != VisaoAgenda.dia,
                              moeda: moeda,
                              onEditar: () => context.push('${AppRoutes.agenda}/editar/${a.id}'),
                              onConfirmar: () => notifier.confirmar(a.id),
                              onConcluir: () => notifier.concluir(a.id),
                              onCancelar: () => notifier.cancelar(a.id),
                            );
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

class _AgendamentoTile extends StatelessWidget {
  const _AgendamentoTile({
    required this.agendamento,
    required this.nomeCliente,
    required this.mostrarData,
    required this.moeda,
    required this.onEditar,
    required this.onConfirmar,
    required this.onConcluir,
    required this.onCancelar,
  });

  final Agendamento agendamento;
  final String nomeCliente;
  final bool mostrarData;
  final NumberFormat moeda;
  final VoidCallback onEditar;
  final VoidCallback onConfirmar;
  final VoidCallback onConcluir;
  final VoidCallback onCancelar;

  bool get _podeAgir =>
      agendamento.status == AgendamentoStatus.agendado || agendamento.status == AgendamentoStatus.confirmado;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 84,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${agendamento.horaInicio}–${agendamento.horaFim}', style: const TextStyle(fontWeight: FontWeight.w600)),
                if (mostrarData)
                  Text(DateFormat('dd/MM').format(agendamento.data), style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(nomeCliente, style: Theme.of(context).textTheme.titleSmall),
                Text('${agendamento.servico} · ${moeda.format(agendamento.valor)}', style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          Wrap(
            spacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              StatusChip(status: agendamento.status),
              if (agendamento.status == AgendamentoStatus.agendado)
                IconButton(tooltip: 'Confirmar', onPressed: onConfirmar, icon: const Icon(Icons.verified_outlined, size: 20)),
              if (_podeAgir) ...[
                IconButton(tooltip: 'Concluir', onPressed: onConcluir, icon: const Icon(Icons.check_circle_outline, size: 20)),
                IconButton(tooltip: 'Editar', onPressed: onEditar, icon: const Icon(Icons.edit_outlined, size: 20)),
                IconButton(tooltip: 'Cancelar', onPressed: onCancelar, icon: const Icon(Icons.cancel_outlined, size: 20)),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
